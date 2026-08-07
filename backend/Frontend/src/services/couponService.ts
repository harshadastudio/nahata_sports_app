/**
 * Coupon Service
 * Validates coupon codes against the backend and returns discount details.
 * Also fetches active offers for display in booking flows.
 */

// couponService appends /api/... paths itself, so strip /api from base
const _rawCouponBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
const API_BASE = _rawCouponBase.endsWith('/api') ? _rawCouponBase.slice(0, -4) : _rawCouponBase;

import { fetchWithAuth } from '../lib/fetchWithAuth';

export interface ActiveCoupon {
 id: number;
 code: string;
 discountType: 'Percentage' | 'Flat';
 discountValue: number;
 maxDiscount: number | null;
 description: string | null;
 validUntil: string;
 usageLimit: number;
 usedCount: number;
}

export interface CouponValidationResult {
 id: number;
 code: string;
 discountType: 'Percentage' | 'Flat';
 discountValue: number;
 maxDiscount: number | null;
 description: string | null;
 validUntil: string;
 // Calculated fields — present when `amount` is passed
 discountAmount: number;
 finalAmount: number;
 originalAmount: number;
}

/**
 * Scope for a booking flow. Court bookings pass the selected complex + sport so
 * the backend only returns coupons valid for them (plus unrestricted ones);
 * event bookings pass the event id.
 *
 * The platform (web vs app) is NOT sent — the API derives it from the request
 * itself, so it cannot be spoofed by the client.
 */
export interface CouponScope {
 appliesTo: 'Court' | 'Event';
 sportComplexId?: string | number | null;
 sportId?: string | number | null;
 eventPassId?: string | number | null;
}

/**
 * Fetch the active, non-expired, non-exhausted coupons valid for a given flow.
 * Used to display the"Available Offers"panel in booking flows.
 */
export async function getActiveCoupons(scope?: CouponScope): Promise<ActiveCoupon[]> {
 try {
 const qs = new URLSearchParams();
 if (scope?.appliesTo) qs.set('appliesTo', scope.appliesTo);
 if (scope?.sportComplexId != null && scope.sportComplexId !== '') {
 qs.set('sportComplexId', String(scope.sportComplexId));
 }
 if (scope?.sportId != null && scope.sportId !== '') {
 qs.set('sportId', String(scope.sportId));
 }
 if (scope?.eventPassId != null && scope.eventPassId !== '') {
 qs.set('eventPassId', String(scope.eventPassId));
 }
 const suffix = qs.toString() ? `?${qs.toString()}` : '';
 const res = await fetchWithAuth(`${API_BASE}/api/coupons/active${suffix}`, { method: 'GET' });
 const json = await res.json();
 if (!res.ok || !json.success) return [];
 return json.data as ActiveCoupon[];
 } catch {
 return [];
 }
}

/**
 * Validate a coupon code and calculate the discount for a given amount.
 *
 * @param code - The coupon code entered by the user
 * @param amount - The original booking amount in INR
 * @returns CouponValidationResult with discount breakdown
 * @throws Error with a user-friendly message on failure
 */
export async function validateCoupon(
 code: string,
 amount: number,
 scope?: CouponScope
): Promise<CouponValidationResult> {
 const res = await fetchWithAuth(`${API_BASE}/api/coupons/validate`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({
 code: code.trim().toUpperCase(),
 amount,
 appliesTo: scope?.appliesTo,
 sportComplexId: scope?.sportComplexId ?? null,
 sportId: scope?.sportId ?? null,
 eventPassId: scope?.eventPassId ?? null,
 }),
 });

 const json = await res.json();

 if (!res.ok || !json.success) {
 throw new Error(json.message || 'Invalid coupon code');
 }

 return json.data as CouponValidationResult;
}

