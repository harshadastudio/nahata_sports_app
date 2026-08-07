'use strict';

const razorpayService = require('../services/razorpayService');
const { Booking, EventPassBooking, EventPass, EventPassSlot, User, Court, Sport, SportComplex, StudentBatches, Student, Batch, sequelize } = require('../models');
const { Op } = require('sequelize');
const { resolveComplexId } = require('../middleware/complexScope');
const logger = require('../utils/logger');

const payLog = logger.child({ module: 'payment-controller' });

const STAFF_ROLES = new Set(['ADMIN', 'SUPER_ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE']);
const isStaff = (user) => !!user && STAFF_ROLES.has(String(user.role || '').toUpperCase());

/** Load the source booking (facility|event) with the fields payment needs. */
async function loadPayable(bookingType, bookingId) {
  if (bookingType === 'facility') {
    const b = await Booking.findByPk(bookingId, {
      attributes: ['id', 'userId', 'totalAmount', 'paymentStatus', 'razorpayOrderId'],
    });
    return b && { kind: 'facility', id: b.id, userId: b.userId, amount: Number(b.totalAmount), row: b };
  }
  const e = await EventPassBooking.findByPk(bookingId, {
    attributes: ['id', 'userId', 'totalAmount', 'status', 'razorpayOrderId'],
  });
  return e && { kind: 'event', id: e.id, userId: e.userId, amount: Number(e.totalAmount), row: e };
}

/**
 * POST /api/payments/create-order
 *
 * Body:
 *   amount      {number}  - Amount in INR (e.g. 500)
 *   bookingType {string}  - 'facility' | 'event'
 *   bookingId   {number}  - ID of the booking record
 *
 * Returns Razorpay order details the frontend needs to open the checkout.
 */
exports.createOrder = async (req, res) => {
  try {
    const { bookingType, bookingId } = req.body;

    if (!bookingType || !bookingId) {
      return res.status(400).json({
        success: false,
        message: 'bookingType and bookingId are required',
      });
    }

    if (!['facility', 'event'].includes(bookingType)) {
      return res.status(400).json({
        success: false,
        message: "bookingType must be 'facility' or 'event'",
      });
    }

    // Load the booking and derive the amount SERVER-SIDE. The client-supplied
    // amount is ignored for the charge — this is what stops a tampered "₹1"
    // order from being created for a ₹2000 booking.
    const payable = await loadPayable(bookingType, bookingId);
    if (!payable) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    // Ownership: a logged-in non-staff user may only pay for their own booking.
    if (req.user && !isStaff(req.user) && payable.userId && payable.userId !== req.user.id) {
      return res.status(403).json({ success: false, message: 'You cannot pay for this booking.' });
    }

    if (!(payable.amount > 0)) {
      return res.status(400).json({ success: false, message: 'Booking amount is invalid.' });
    }

    if (req.body.amount != null && Number(req.body.amount) !== payable.amount) {
      payLog.warn('createOrder.amount_override', {
        bookingType, bookingId, clientAmount: req.body.amount, serverAmount: payable.amount,
      });
    }

    const receipt = `${bookingType.toUpperCase()}_${bookingId}`;
    const notes = { bookingType, bookingId: String(bookingId) };

    const order = await razorpayService.createOrder(payable.amount, receipt, notes);

    // Bind the order to the booking so /verify can prove the payment is for THIS
    // booking (facility parity with events, which already stored it).
    await payable.row.update({ razorpayOrderId: order.orderId });

    payLog.info('createOrder.created', { bookingType, bookingId, orderId: order.orderId, amount: payable.amount });

    return res.status(200).json({
      success: true,
      data: order,
    });
  } catch (error) {
    payLog.error('createOrder.failed', { err: error });
    return res.status(500).json({
      success: false,
      message: 'Failed to create payment order',
    });
  }
};

/**
 * POST /api/payments/verify
 *
 * Body:
 *   razorpay_order_id   {string}
 *   razorpay_payment_id {string}
 *   razorpay_signature  {string}
 *   bookingType         {string}  - 'facility' | 'event'
 *   bookingId           {number}
 *
 * On success: marks the booking as Paid / Confirmed.
 */
exports.verifyPayment = async (req, res) => {
  try {
    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      bookingType,
      bookingId,
    } = req.body;

    if (
      !razorpay_order_id ||
      !razorpay_payment_id ||
      !razorpay_signature ||
      !bookingType ||
      !bookingId
    ) {
      return res.status(400).json({
        success: false,
        message: 'All payment verification fields are required',
      });
    }

    if (!['facility', 'event'].includes(bookingType)) {
      return res.status(400).json({ success: false, message: "Invalid bookingType" });
    }

    // 1. Verify the Razorpay signature (HMAC over order_id|payment_id).
    const isValid = razorpayService.verifyPayment(
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature
    );
    if (!isValid) {
      payLog.warn('verify.bad_signature', { bookingType, bookingId, orderId: razorpay_order_id });
      return res.status(400).json({
        success: false,
        message: 'Payment verification failed: invalid signature',
      });
    }

    // 2. Confirm the booking — each path is idempotent, ownership-checked,
    //    order-bound and amount-verified against Razorpay.
    let pass = null;
    if (bookingType === 'facility') {
      const courtService = require('../services/courtService');
      let result;
      try {
        result = await courtService.confirmFacilityPayment({
          bookingId,
          orderId: razorpay_order_id,
          paymentId: razorpay_payment_id,
          requestUser: req.user,
        });
      } catch (err) {
        // Hard payment-integrity failures (amount/order/capture mismatch).
        if (['AMOUNT_MISMATCH', 'ORDER_MISMATCH', 'NOT_CAPTURED'].includes(err.code)) {
          payLog.warn('verify.integrity_failed', { bookingType, bookingId, code: err.code });
          return res.status(400).json({ success: false, message: err.message });
        }
        throw err;
      }

      if (result.status === 'not_found') {
        return res.status(404).json({ success: false, message: 'Booking not found' });
      }
      if (result.status === 'forbidden') {
        return res.status(403).json({ success: false, message: 'You cannot confirm this booking.' });
      }
      if (result.status === 'order_mismatch') {
        return res.status(400).json({ success: false, message: 'Payment does not match this booking.' });
      }
      // 'confirmed' and 'already' both return success (idempotent).

      // The pass exists only from this point on — read it back so the checkout
      // can show it straight away (booking creation no longer returns one).
      const paid = await Booking.findByPk(bookingId, {
        attributes: ['id', 'passCode', 'qrCode', 'maxPersons'],
      });
      if (paid) {
        pass = {
          bookingId: paid.id,
          passCode: paid.passCode,
          qrCode: paid.qrCode,
          maxPersons: paid.maxPersons,
        };
      }
    } else {
      const result = await confirmEventPayment({
        bookingId,
        orderId: razorpay_order_id,
        paymentId: razorpay_payment_id,
        requestUser: req.user,
      });
      if (result.status === 'not_found') {
        return res.status(404).json({ success: false, message: 'Event booking not found' });
      }
      if (result.status === 'forbidden') {
        return res.status(403).json({ success: false, message: 'You cannot confirm this booking.' });
      }
      if (['order_mismatch', 'amount_mismatch', 'not_captured'].includes(result.status)) {
        return res.status(400).json({ success: false, message: result.message || 'Payment could not be verified.' });
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Payment verified successfully',
      data: {
        paymentId: razorpay_payment_id,
        orderId: razorpay_order_id,
        pass, // facility only: { bookingId, passCode, qrCode, maxPersons }
      },
    });
  } catch (error) {
    payLog.error('verify.failed', { err: error });
    return res.status(500).json({
      success: false,
      message: 'Payment verification failed',
    });
  }
};

/**
 * Event-pass payment confirmation with the same protections as facility:
 * ownership, order-binding, captured status, amount, idempotency, and a locked
 * transaction. Kept in the controller since events are a thin booking.update().
 */
async function confirmEventPayment({ bookingId, orderId, paymentId, requestUser }) {
  const pre = await EventPassBooking.findByPk(bookingId, {
    attributes: ['id', 'userId', 'totalAmount', 'status', 'razorpayOrderId'],
  });
  if (!pre) return { status: 'not_found' };

  if (requestUser && !isStaff(requestUser) && pre.userId && pre.userId !== requestUser.id) {
    return { status: 'forbidden' };
  }
  if (orderId && pre.razorpayOrderId && pre.razorpayOrderId !== orderId) {
    return { status: 'order_mismatch', message: 'Payment does not match this booking.' };
  }
  if (pre.status === 'Confirmed') return { status: 'already' };

  // Authoritative Razorpay check (outside the txn).
  const expectedPaise = Math.round(Number(pre.totalAmount) * (razorpayService.MULTIPLIER || 100));
  try {
    const payment = await razorpayService.fetchPayment(paymentId);
    if (orderId && payment.order_id && payment.order_id !== orderId) {
      return { status: 'order_mismatch', message: 'Payment does not belong to this order.' };
    }
    if (!['captured', 'authorized'].includes(payment.status)) {
      return { status: 'not_captured', message: `Payment has not been captured (status: ${payment.status}).` };
    }
    if (typeof payment.amount === 'number' && payment.amount !== expectedPaise) {
      payLog.error('verify.event_amount_mismatch', { bookingId, paid: payment.amount, expectedPaise });
      return { status: 'amount_mismatch', message: 'Paid amount does not match the booking amount.' };
    }
  } catch (err) {
    payLog.warn('verify.event_fetch_failed_fallback', { bookingId, err });
    // Degrade to signature + order-binding + server-side amount (already checked).
  }

  const result = await sequelize.transaction(async (t) => {
    const booking = await EventPassBooking.findByPk(bookingId, { transaction: t, lock: t.LOCK.UPDATE });
    if (!booking) return { status: 'not_found' };
    if (booking.status === 'Confirmed') return { status: 'already' };
    await booking.update(
      { status: 'Confirmed', razorpayPaymentId: paymentId, razorpayOrderId: orderId || booking.razorpayOrderId },
      { transaction: t }
    );
    return { status: 'confirmed' };
  });

  if (result.status === 'confirmed' || result.status === 'already') {
    if (result.status === 'confirmed') {
      payLog.info('verify.event_confirmed', { bookingId, paymentId });
    }
    // The pass is created HERE, not at booking time — a cancelled or failed
    // checkout leaves the booking Pending with no pass. Awaited so the caller
    // only gets a success response once the pass actually exists. The helper is
    // idempotent (no duplicate pass, no duplicate email) and swallows its own
    // errors, so re-verifying also repairs a booking confirmed without a pass.
    await require('../services/eventPassService').issueAndSendPassAfterPayment(bookingId);
  }
  return result;
}

/**
 * GET /api/payments/all
 *
 * Aggregates payment data from 3 sources:
 *   1. Court Bookings  (Bookings table)
 *   2. Event Pass Bookings (EventPassBookings table)
 *   3. Coaching Fees (StudentBatches table)
 *
 * Query params:
 *   type        {string}  - 'facility' | 'event' | 'coaching' | '' (all)
 *   status      {string}  - filter by payment status
 *   page        {number}  - default 1
 *   limit       {number}  - default 20
 *   search      {string}  - search by user name / transaction ID
 *   dateFrom    {string}  - YYYY-MM-DD
 *   dateTo      {string}  - YYYY-MM-DD
 */
exports.getAllPayments = async (req, res) => {
  try {
    const {
      type = '',
      status = '',
      page = 1,
      limit = 20,
      search = '',
      dateFrom = '',
      dateTo = '',
    } = req.query;

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);

    // Per-complex admin scoping (null = all complexes for super admin). Each payment
    // source is scoped through its complex-bearing association:
    //   facility → Court.sportComplexId, event → EventPass.sportComplexId,
    //   coaching → Batch.sportComplexId. A scoped complex admin therefore only sees
    //   payments belonging to their complex.
    const complexId = resolveComplexId(req);
    const scopeWhere = complexId != null ? { where: { sportComplexId: complexId }, required: true } : {};

    const unified = [];

    // ── 1. Court Bookings ────────────────────────────────────────────────────
    if (!type || type === 'facility') {
      const where = { isDeleted: false };
      if (status) {
        // Map unified status to booking paymentStatus
        const statusMap = { Paid: 'Paid', Pending: 'Pending', Failed: 'Failed', Refunded: 'Refunded' };
        if (statusMap[status]) where.paymentStatus = statusMap[status];
      }
      if (dateFrom || dateTo) {
        where.date = {};
        if (dateFrom) where.date[Op.gte] = dateFrom;
        if (dateTo) where.date[Op.lte] = dateTo;
      }

      const bookings = await Booking.findAll({
        where,
        include: [
          { model: User, as: 'user', attributes: ['id', 'name', 'email', 'phone_number'] },
          {
            model: Court, as: 'court', attributes: ['id', 'name'],
            include: [{ model: SportComplex, attributes: ['id', 'name'] }],
            ...scopeWhere,
          },
          { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        ],
        order: [['createdAt', 'DESC']],
      });

      for (const b of bookings) {
        const userName = b.user?.name || 'Unknown';
        if (search && !userName.toLowerCase().includes(search.toLowerCase()) &&
            !(b.transactionId || '').toLowerCase().includes(search.toLowerCase())) continue;

        unified.push({
          id: `FAC_${b.id}`,
          sourceId: b.id,
          type: 'facility',
          typeLabel: 'Court Booking',
          transactionId: b.transactionId || null,
          razorpayPaymentId: b.transactionId || null,
          userName,
          userEmail: b.user?.email || '',
          userPhone: b.user?.phone_number || '',
          amount: parseFloat(b.totalAmount) || 0,
          paymentMode: 'Online',
          status: b.paymentStatus,          // Paid | Pending | Failed | Refunded
          description: `${b.court?.name || 'Court'} — ${b.sport?.name || ''} | ${b.date} ${b.startTime}–${b.endTime}`,
          venue: b.court?.SportComplex?.name || '',
          createdAt: b.createdAt,
          date: b.date,
        });
      }
    }

    // ── 2. Event Pass Bookings ───────────────────────────────────────────────
    if (!type || type === 'event') {
      const where = {};
      if (status) {
        // Map: Paid→Confirmed, Pending→Pending, Failed→Cancelled
        const statusMap = { Paid: 'Confirmed', Pending: 'Pending', Failed: 'Cancelled' };
        if (statusMap[status]) where.status = statusMap[status];
      }
      if (dateFrom || dateTo) {
        where.createdAt = {};
        if (dateFrom) where.createdAt[Op.gte] = new Date(dateFrom);
        if (dateTo) where.createdAt[Op.lte] = new Date(dateTo + 'T23:59:59');
      }

      const eventBookings = await EventPassBooking.findAll({
        where,
        include: [
          { model: EventPass, as: 'event', attributes: ['id', 'title'], ...scopeWhere },
          { model: EventPassSlot, as: 'slot', attributes: ['id', 'name', 'date', 'passType'] },
        ],
        order: [['createdAt', 'DESC']],
      });

      for (const eb of eventBookings) {
        const userName = eb.name || 'Unknown';
        if (search && !userName.toLowerCase().includes(search.toLowerCase()) &&
            !(eb.razorpayPaymentId || '').toLowerCase().includes(search.toLowerCase())) continue;

        // Normalise status to Paid/Pending/Failed
        const statusNorm = eb.status === 'Confirmed' ? 'Paid'
          : eb.status === 'Cancelled' ? 'Failed'
          : 'Pending';

        unified.push({
          id: `EVT_${eb.id}`,
          sourceId: eb.id,
          type: 'event',
          typeLabel: 'Event Pass',
          transactionId: eb.razorpayPaymentId || null,
          razorpayPaymentId: eb.razorpayPaymentId || null,
          razorpayOrderId: eb.razorpayOrderId || null,
          userName,
          userEmail: eb.email || '',
          userPhone: '',
          amount: parseFloat(eb.totalAmount) || 0,
          paymentMode: 'Online',
          status: statusNorm,
          description: `${eb.event?.title || 'Event'} — ${eb.slot?.passType || eb.slot?.name || ''} | ${eb.numberOfPasses} pass(es)`,
          venue: '',
          createdAt: eb.createdAt,
          date: eb.slot?.date || eb.createdAt?.toISOString().split('T')[0],
        });
      }
    }

    // ── 3. Coaching Fees ─────────────────────────────────────────────────────
    if (!type || type === 'coaching') {
      const where = {};
      if (status) {
        const statusMap = { Paid: 'Paid', Pending: 'Pending', Failed: 'Overdue' };
        if (statusMap[status]) where.paymentStatus = statusMap[status];
      }
      if (dateFrom || dateTo) {
        where.createdAt = {};
        if (dateFrom) where.createdAt[Op.gte] = new Date(dateFrom);
        if (dateTo) where.createdAt[Op.lte] = new Date(dateTo + 'T23:59:59');
      }

      const fees = await StudentBatches.findAll({
        where,
        include: [
          {
            model: Student, as: 'student',
            include: [{ model: User, as: 'User', attributes: ['id', 'name', 'email', 'phone_number'] }],
          },
          {
            model: Batch, as: 'batch',
            attributes: ['id', 'name', 'fees'],
            include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
            ...scopeWhere,
          },
        ],
        order: [['createdAt', 'DESC']],
      });

      for (const f of fees) {
        const userName = f.student?.User?.name || 'Unknown';
        if (search && !userName.toLowerCase().includes(search.toLowerCase())) continue;

        // Normalise: Paid→Paid, Overdue→Failed, else Pending
        const statusNorm = f.paymentStatus === 'Paid' ? 'Paid'
          : f.paymentStatus === 'Overdue' ? 'Failed'
          : 'Pending';

        unified.push({
          id: `FEE_${f.id}`,
          sourceId: f.id,
          type: 'coaching',
          typeLabel: 'Coaching Fee',
          transactionId: null,
          razorpayPaymentId: null,
          userName,
          userEmail: f.student?.User?.email || '',
          userPhone: f.student?.User?.phone_number || '',
          amount: parseFloat(f.amountPaid) || parseFloat(f.batch?.fees) || 0,
          paymentMode: f.paymentMode || 'Cash',
          status: statusNorm,
          description: `${f.batch?.name || 'Batch'} — ${f.batch?.sport?.name || ''}`,
          venue: '',
          createdAt: f.createdAt,
          date: f.enrollmentDate || f.createdAt?.toISOString().split('T')[0],
        });
      }
    }

    // ── Sort all by createdAt DESC ────────────────────────────────────────────
    unified.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    // ── Pagination ────────────────────────────────────────────────────────────
    const totalCount = unified.length;
    const totalPages = Math.ceil(totalCount / limitNum);
    const offset = (pageNum - 1) * limitNum;
    const paginated = unified.slice(offset, offset + limitNum);

    // ── Summary stats ─────────────────────────────────────────────────────────
    const totalRevenue = unified.filter(t => t.status === 'Paid').reduce((s, t) => s + t.amount, 0);
    const successCount = unified.filter(t => t.status === 'Paid').length;
    const pendingCount = unified.filter(t => t.status === 'Pending').length;
    const failedCount = unified.filter(t => t.status === 'Failed').length;

    return res.status(200).json({
      success: true,
      data: paginated,
      stats: { totalRevenue, successCount, pendingCount, failedCount, totalCount },
      pagination: {
        currentPage: pageNum,
        totalPages,
        totalCount,
        limit: limitNum,
      },
    });
  } catch (error) {
    console.error('❌ getAllPayments error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch payments',
      error: error.message,
    });
  }
};
