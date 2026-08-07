/**
 * Razorpay Payment Service
 *
 * Handles:
 * 1. Loading the Razorpay checkout script
 * 2. Creating a Razorpay order via our backend
 * 3. Opening the Razorpay checkout popup
 * 4. Verifying the payment via our backend
 */

// razorpayService appends /api/... paths itself, so strip /api from base
const _rawRazorBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
const API_BASE = _rawRazorBase.endsWith('/api') ? _rawRazorBase.slice(0, -4) : _rawRazorBase;
const RAZORPAY_KEY_ID = import.meta.env.VITE_RAZORPAY_KEY_ID || '';

import { fetchWithAuth } from '../lib/fetchWithAuth';

export type BookingType = 'facility' | 'event';

export interface RazorpayOrderResponse {
 orderId: string;
 amount: number; // in paise
 currency: string;
 keyId: string;
}

export interface PaymentResult {
 razorpay_order_id: string;
 razorpay_payment_id: string;
 razorpay_signature: string;
}

/** Court booking pass — issued by the backend only after the payment is verified. */
export interface BookingPass {
 bookingId: number;
 passCode: string | null;
 qrCode: string | null;
 maxPersons: number | null;
}

export interface VerifiedPayment {
 paymentId: string;
 orderId: string;
 pass: BookingPass | null;
}

/**
 * Where the payment flow broke.
 *  'order'    — we never reached the checkout (no money moved)
 *  'checkout' — user dismissed the popup, or the payment itself failed (no money moved)
 *  'verify'   — the payment went through but our confirmation call failed. The
 *               booking must NOT be released here: the charge may be real, so it
 *               is left for the backend/staff to reconcile.
 */
export type PaymentStage = 'order' | 'checkout' | 'verify';

export interface PaymentError extends Error {
 stage: PaymentStage;
}

function paymentError(message: string, stage: PaymentStage): PaymentError {
 const err = new Error(message) as PaymentError;
 err.stage = stage;
 return err;
}

/** True when the failure happened before any money could be taken. */
export function isPaymentAbandoned(err: unknown): boolean {
 const stage = (err as Partial<PaymentError> | null)?.stage;
 return stage === 'order' || stage === 'checkout';
}

/** Dynamically load the Razorpay checkout script (idempotent). */
function loadRazorpayScript(): Promise<void> {
 return new Promise((resolve, reject) => {
 if (document.getElementById('razorpay-script')) {
 resolve();
 return;
 }
 const script = document.createElement('script');
 script.id = 'razorpay-script';
 script.src = 'https://checkout.razorpay.com/v1/checkout.js';
 script.onload = () => resolve();
 script.onerror = () => reject(paymentError('Failed to load Razorpay script', 'order'));
 document.body.appendChild(script);
 });
}

/**
 * Step 1 — Ask our backend to create a Razorpay order.
 */
async function createOrder(
 amount: number,
 bookingType: BookingType,
 bookingId: number
): Promise<RazorpayOrderResponse> {
 const res = await fetchWithAuth(`${API_BASE}/api/payments/create-order`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({ amount, bookingType, bookingId }),
 });
 const json = await res.json();
 if (!res.ok) throw paymentError(json.message || 'Failed to create payment order', 'order');
 return json.data as RazorpayOrderResponse;
}

/**
 * Step 2 — Open the Razorpay checkout popup.
 * Resolves with payment details on success, rejects on failure/dismiss.
 */
function openCheckout(
 order: RazorpayOrderResponse,
 prefill: { name?: string; email?: string; contact?: string },
 description: string
): Promise<PaymentResult> {
 return new Promise((resolve, reject) => {
 const options = {
 key: RAZORPAY_KEY_ID || order.keyId,
 amount: order.amount,
 currency: order.currency,
 name: 'Nahata Sports Complex',
 description,
 order_id: order.orderId,
 prefill: {
 name: prefill.name || '',
 email: prefill.email || '',
 contact: prefill.contact || '',
 },
 theme: { color: '#2563EB' },
 handler: (response: PaymentResult) => resolve(response),
 modal: {
 ondismiss: () => reject(paymentError('Payment cancelled by user', 'checkout')),
 },
 };

 // @ts-ignore — Razorpay is loaded via script tag
 const rzp = new window.Razorpay(options);
 rzp.on('payment.failed', (response: any) => {
 reject(paymentError(response.error?.description || 'Payment failed', 'checkout'));
 });
 rzp.open();
 });
}

/**
 * Step 3 — Verify the payment signature with our backend.
 * On success the backend marks the booking as Paid/Confirmed and issues the pass.
 */
async function verifyPayment(
 paymentResult: PaymentResult,
 bookingType: BookingType,
 bookingId: number
): Promise<VerifiedPayment> {
 const res = await fetchWithAuth(`${API_BASE}/api/payments/verify`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({ ...paymentResult, bookingType, bookingId }),
 });
 const json = await res.json();
 if (!res.ok) throw paymentError(json.message || 'Payment verification failed', 'verify');
 return {
 paymentId: json.data?.paymentId ?? paymentResult.razorpay_payment_id,
 orderId: json.data?.orderId ?? paymentResult.razorpay_order_id,
 pass: json.data?.pass ?? null,
 };
}

/**
 * Full payment flow:
 * loadScript → createOrder → openCheckout → verifyPayment
 *
 * Rejects if the user cancels/dismisses the checkout or the payment fails — the
 * booking then stays unpaid and never receives a pass, so callers should release
 * the held booking in their catch block.
 *
 * @param amount Amount in INR (e.g. 500)
 * @param bookingType 'facility' | 'event'
 * @param bookingId ID of the booking record in our DB
 * @param prefill User details to pre-fill in the checkout
 * @param description Short description shown in the checkout popup
 * @returns the verified payment, including the freshly issued pass (facility)
 */
export async function initiatePayment(
 amount: number,
 bookingType: BookingType,
 bookingId: number,
 prefill: { name?: string; email?: string; contact?: string },
 description: string
): Promise<VerifiedPayment> {
 await loadRazorpayScript();
 const order = await createOrder(amount, bookingType, bookingId);
 const paymentResult = await openCheckout(order, prefill, description);
 return verifyPayment(paymentResult, bookingType, bookingId);
}

