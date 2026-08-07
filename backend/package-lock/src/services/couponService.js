const db = require('../models');
const { Coupon, SportComplex, Sport, EventPass } = db;
const { Op } = require('sequelize');
const { platformLabel } = require('../utils/clientPlatform');

/** Associations pulled in wherever a coupon is shown to an admin. */
const SCOPE_INCLUDES = [
  { model: SportComplex, attributes: ['id', 'name'], required: false },
  { model: Sport, attributes: ['id', 'name'], required: false },
  { model: EventPass, as: 'eventPass', attributes: ['id', 'title'], required: false },
];

/** Normalise an incoming id: '' / null / undefined / 0 → null. */
const toId = (value) => {
  if (value === undefined || value === null || value === '') return null;
  const n = parseInt(value, 10);
  return Number.isNaN(n) || n <= 0 ? null : n;
};

/** Only 'All' | 'Web' | 'App' are storable; anything else falls back to 'All'. */
const normalizePlatform = (value) => {
  const v = String(value ?? '').trim().toLowerCase();
  if (v === 'web') return 'Web';
  if (v === 'app') return 'App';
  return 'All';
};

class CouponService {
  /**
   * Work out the {complex, sport, event} a coupon should be stored with, and
   * reject combinations that can never match a booking.
   *
   * A sport belongs to exactly one complex, so picking a sport implies its
   * complex — the complex is derived when the caller left it blank, and a
   * mismatch is an error rather than a silently dead coupon.
   */
  async resolveScope({ appliesTo, sportComplexId, sportId, eventPassId }) {
    if (appliesTo === 'Event') {
      const eventId = toId(eventPassId);
      if (eventId) {
        const event = await EventPass.findByPk(eventId, { attributes: ['id'] });
        if (!event) throw new Error('Selected event not found');
      }
      // Event coupons are never complex/sport restricted.
      return { sportComplexId: null, sportId: null, eventPassId: eventId };
    }

    let complexId = toId(sportComplexId);
    const sportRef = toId(sportId);

    if (sportRef) {
      const sport = await Sport.findByPk(sportRef, { attributes: ['id', 'sportComplexId'] });
      if (!sport) throw new Error('Selected sport not found');

      if (complexId == null) {
        // Sport chosen without a complex → derive it from the sport.
        complexId = sport.sportComplexId;
      } else if (Number(sport.sportComplexId) !== Number(complexId)) {
        throw new Error('Selected sport does not belong to the selected sports complex');
      }
    }

    // Court coupons are never event restricted.
    return { sportComplexId: complexId, sportId: sportRef, eventPassId: null };
  }

  // Get all coupons with pagination and filters
  async getAllCoupons(page = 1, limit = 10, search = '', status = '', sportComplexId = null) {
    const offset = (page - 1) * limit;

    // Build where clause
    const where = {};

    if (status) {
      where.status = status;
    }

    // Per-complex admin scoping: only that complex's coupons (no-op when null)
    if (sportComplexId != null) {
      where.sportComplexId = sportComplexId;
    }

    if (search) {
      where[Op.or] = [
        { code: { [Op.iLike]: `%${search}%` } }
      ];
    }

    const { count, rows } = await Coupon.findAndCountAll({
      where,
      include: SCOPE_INCLUDES,
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['createdAt', 'DESC']]
    });

    return {
      data: rows,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(count / limit),
        total: count,
        itemsPerPage: parseInt(limit)
      }
    };
  }

  // Get single coupon by ID
  async getCouponById(id) {
    const coupon = await Coupon.findByPk(id, { include: SCOPE_INCLUDES });

    if (!coupon) {
      throw new Error('Coupon not found');
    }

    return coupon;
  }

  // Get coupon by code
  async getCouponByCode(code) {
    const coupon = await Coupon.findOne({ where: { code: code.toUpperCase() } });

    if (!coupon) {
      throw new Error('Coupon not found');
    }

    return coupon;
  }

  // Create new coupon
  async createCoupon(data) {
    const {
      code, discountType, discountValue, maxDiscount, description, validUntil,
      usageLimit, status, appliesTo, sportComplexId, sportId, eventPassId, platform,
    } = data;

    // Check if coupon code already exists
    const existingCoupon = await Coupon.findOne({ where: { code: code.toUpperCase() } });
    if (existingCoupon) {
      throw new Error('Coupon code already exists');
    }

    const scope = appliesTo === 'Event' ? 'Event' : 'Court';
    const target = await this.resolveScope({ appliesTo: scope, sportComplexId, sportId, eventPassId });

    // Create coupon
    const coupon = await Coupon.create({
      code: code.toUpperCase(),
      discountType,
      discountValue,
      maxDiscount: maxDiscount || null,
      description: description || null,
      validUntil,
      usageLimit: usageLimit || 100,
      usedCount: 0,
      status: status || 'Active',
      appliesTo: scope,
      sportComplexId: target.sportComplexId,
      sportId: target.sportId,
      eventPassId: target.eventPassId,
      platform: normalizePlatform(platform),
    });

    return this.getCouponById(coupon.id);
  }

  // Update coupon
  async updateCoupon(id, data) {
    const {
      discountType, discountValue, maxDiscount, description, validUntil,
      usageLimit, status, appliesTo, sportComplexId, sportId, eventPassId, platform,
    } = data;

    const coupon = await Coupon.findByPk(id);

    if (!coupon) {
      throw new Error('Coupon not found');
    }

    // Resolve the new scope (each field falls back to the current value when omitted).
    const scope = appliesTo !== undefined ? (appliesTo === 'Event' ? 'Event' : 'Court') : coupon.appliesTo;
    const target = await this.resolveScope({
      appliesTo: scope,
      sportComplexId: sportComplexId !== undefined ? sportComplexId : coupon.sportComplexId,
      sportId: sportId !== undefined ? sportId : coupon.sportId,
      eventPassId: eventPassId !== undefined ? eventPassId : coupon.eventPassId,
    });

    // Update coupon data (code cannot be changed)
    await coupon.update({
      discountType: discountType || coupon.discountType,
      discountValue: discountValue !== undefined ? discountValue : coupon.discountValue,
      maxDiscount: maxDiscount !== undefined ? maxDiscount : coupon.maxDiscount,
      description: description !== undefined ? description : coupon.description,
      validUntil: validUntil || coupon.validUntil,
      usageLimit: usageLimit !== undefined ? usageLimit : coupon.usageLimit,
      status: status || coupon.status,
      appliesTo: scope,
      sportComplexId: target.sportComplexId,
      sportId: target.sportId,
      eventPassId: target.eventPassId,
      platform: platform !== undefined ? normalizePlatform(platform) : coupon.platform,
    });

    return this.getCouponById(coupon.id);
  }

  // Delete coupon
  async deleteCoupon(id) {
    const coupon = await Coupon.findByPk(id);

    if (!coupon) {
      throw new Error('Coupon not found');
    }

    await coupon.destroy();

    return { message: 'Coupon deleted successfully' };
  }

  // Validate and apply coupon.
  // `context` scopes the check:
  //   { appliesTo: 'Court' | 'Event', sportComplexId, sportId, eventPassId, platform }
  // When a context field is omitted that dimension is not enforced (legacy /
  // admin-side calls); every public booking path passes the full context.
  async validateCoupon(code, context = {}) {
    const coupon = await Coupon.findOne({
      where: { code: code.toUpperCase() },
      include: SCOPE_INCLUDES,
    });

    if (!coupon) {
      throw new Error('Invalid coupon code');
    }

    // Check if coupon is active
    if (coupon.status !== 'Active') {
      throw new Error('Coupon is not active');
    }

    // Check if coupon has expired
    if (new Date(coupon.validUntil) < new Date()) {
      throw new Error('Coupon has expired');
    }

    // Check if usage limit reached
    if (coupon.usedCount >= coupon.usageLimit) {
      throw new Error('Coupon usage limit reached');
    }

    // ── Scope checks ──────────────────────────────────────────────────────────
    const { appliesTo, sportComplexId, sportId, eventPassId, platform } = context;

    // Platform restriction — a Web-only coupon must not work in the app, and
    // vice versa. Not enforced when the caller could not resolve a platform.
    if (platform && coupon.platform && coupon.platform !== 'All' && coupon.platform !== platform) {
      throw new Error(`This coupon can only be used on ${platformLabel(coupon.platform)}`);
    }

    if (appliesTo && coupon.appliesTo !== appliesTo) {
      throw new Error(
        `This coupon is only valid for ${coupon.appliesTo === 'Court' ? 'court' : 'event'} bookings`
      );
    }

    if (coupon.appliesTo === 'Court') {
      // Complex restriction only applies to court coupons that name a complex.
      if (coupon.sportComplexId != null) {
        if (sportComplexId == null || Number(coupon.sportComplexId) !== Number(sportComplexId)) {
          throw new Error('This coupon is not valid for the selected sports complex');
        }
      }

      // Sport restriction — e.g. a Badminton-only coupon.
      if (coupon.sportId != null) {
        if (sportId == null || Number(coupon.sportId) !== Number(sportId)) {
          const name = coupon.Sport && coupon.Sport.name;
          throw new Error(
            name
              ? `This coupon is only valid for ${name} bookings`
              : 'This coupon is not valid for the selected sport'
          );
        }
      }
    }

    // Event restriction — a coupon tied to one event.
    if (coupon.appliesTo === 'Event' && coupon.eventPassId != null) {
      if (eventPassId == null || Number(coupon.eventPassId) !== Number(eventPassId)) {
        const title = coupon.eventPass && coupon.eventPass.title;
        throw new Error(
          title
            ? `This coupon is only valid for the event "${title}"`
            : 'This coupon is not valid for the selected event'
        );
      }
    }

    return coupon;
  }

  // Get active coupons for frontend display (any authenticated user).
  // `context` filters by booking flow:
  //   { appliesTo, sportComplexId, sportId, eventPassId, platform }
  // A user is only shown offers they could actually redeem, so the list never
  // advertises a coupon that validation would then reject.
  async getActiveCoupons(context = {}) {
    const { appliesTo, sportComplexId, sportId, eventPassId, platform } = context;
    const now = new Date();

    const and = [Coupon.sequelize.literal('"usedCount" < "usageLimit"')];

    const where = {
      status: 'Active',
      validUntil: { [Op.gt]: now },
    };

    if (appliesTo) {
      where.appliesTo = appliesTo;
    }

    // Platform: 'All' coupons always show; platform-specific ones only on their
    // own client.
    if (platform) {
      and.push({ [Op.or]: [{ platform: 'All' }, { platform }] });
    }

    // For court coupons, also honour the per-complex restriction:
    // show "all complex" coupons (sportComplexId NULL) plus any matching the
    // selected complex.
    if (appliesTo === 'Court') {
      if (sportComplexId != null) {
        and.push({
          [Op.or]: [{ sportComplexId: null }, { sportComplexId: Number(sportComplexId) }],
        });
      } else {
        where.sportComplexId = null;
      }

      // Same rule one level down, for sport-specific coupons.
      if (sportId != null) {
        and.push({ [Op.or]: [{ sportId: null }, { sportId: Number(sportId) }] });
      } else {
        and.push({ sportId: null });
      }
    }

    // Event coupons: all-event coupons plus any tied to the event being booked.
    if (appliesTo === 'Event') {
      if (eventPassId != null) {
        and.push({ [Op.or]: [{ eventPassId: null }, { eventPassId: Number(eventPassId) }] });
      } else {
        and.push({ eventPassId: null });
      }
    }

    where[Op.and] = and;

    const coupons = await Coupon.findAll({
      where,
      attributes: [
        'id', 'code', 'discountType', 'discountValue', 'maxDiscount', 'description',
        'validUntil', 'usageLimit', 'usedCount', 'appliesTo', 'sportComplexId',
        'sportId', 'eventPassId', 'platform',
      ],
      order: [['createdAt', 'DESC']],
    });

    return coupons;
  }

  // Increment coupon usage count
  async incrementUsageCount(id, options = {}) {
    const coupon = await Coupon.findByPk(id, options);

    if (!coupon) {
      throw new Error('Coupon not found');
    }

    await coupon.increment('usedCount', options);

    return coupon;
  }

  /**
   * Give a coupon use back — used when the booking that claimed it never got
   * paid for (cancelled/abandoned checkout). Accepts the coupon id or its code.
   * Never drops below 0, and a missing coupon is a no-op (nothing to restore).
   */
  async decrementUsageCount(idOrCode, options = {}) {
    const where = typeof idOrCode === 'number' || /^\d+$/.test(String(idOrCode))
      ? { id: parseInt(idOrCode, 10) }
      : { code: String(idOrCode).trim() };

    const coupon = await Coupon.findOne({ ...options, where });
    if (!coupon || !(coupon.usedCount > 0)) return coupon || null;

    await coupon.decrement('usedCount', options);

    return coupon;
  }
}

module.exports = new CouponService();
