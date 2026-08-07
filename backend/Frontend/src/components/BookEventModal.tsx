/**
 * Book Event Passes Modal
 *
 * Layout:
 * ┌──────────────────────────────────────────────────────┐
 * │ [Offers Panel — left col] │ [Booking Form — right] │
 * └──────────────────────────────────────────────────────┘
 * On mobile: offers on top, form below (stacked).
 *
 * Coupon logic:
 * - Offers panel is always visible (even before login) so users can browse.
 * - Clicking"Apply"before login shows an inline login prompt.
 * - After login the coupon is applied automatically.
 */

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
 X,
 Loader2,
 User,
 Mail,
 Ticket,
 ArrowRight,
 CheckCircle,
 Lock,
 Minus,
 Plus,
 Sparkles,
} from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { AuthModal } from './AuthModal';
import { Button } from './UI';
import { initiatePayment } from '../services/razorpayService';
import { OffersPanel } from './OffersPanel';
import type { CouponValidationResult } from '../services/couponService';
import { fetchWithAuth } from '../lib/fetchWithAuth';

// BookEventModal appends /api/... paths itself, so strip /api from base
const _rawBookBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
const API_BASE = _rawBookBase.endsWith('/api') ? _rawBookBase.slice(0, -4) : _rawBookBase;
const API = `${API_BASE}/api`;

export interface EventPassSlot {
 id: string;
 name: string;
 date: string;
 price: number;
 passType?: string;
 startTime?: string;
 endTime?: string;
}

/**
 * An extra input the admin defined for this event in CMS → Events →
 * Custom Booking Fields. Rendered below the built-in fields; `required` ones
 * block submission (and are re-checked server-side).
 */
export interface EventCustomField {
 key: string;
 label: string;
 type: 'text' | 'textarea' | 'number' | 'email' | 'phone' | 'date' | 'select';
 required: boolean;
 placeholder?: string | null;
 options?: string[];
}

export interface EventPassData {
 id: string;
 title: string;
 eventDate?: string;
 slots: EventPassSlot[];
 customFields?: EventCustomField[];
}

interface BookEventModalProps {
 event: EventPassData | null;
 isOpen: boolean;
 onClose: () => void;
}

/** Bounds for the pass-quantity stepper. */
const MIN_PASSES = 1;
const MAX_PASSES = 20;

/**"2025-09-26"→"26-09-2025"*/
function fmtDate(d?: string) {
 if (!d) return '';
 const [y, m, day] = d.split('-');
 return `${day}-${m}-${y}`;
}

/** Dropdown option label */
function slotLabel(slot: EventPassSlot) {
 const type = slot.passType ? slot.passType.toUpperCase() : slot.name.toUpperCase();
 return `${slot.date} (${type})`;
}

/** Map a custom field's type to the right <input type>. */
const CUSTOM_INPUT_TYPE: Record<string, string> = {
 text: 'text',
 number: 'number',
 email: 'email',
 phone: 'tel',
 date: 'date',
};

/**
 * Client-side check of one custom field. Mirrors the server rules so the user
 * gets the error before a round trip; the server remains the authority.
 */
function validateCustomField(field: EventCustomField, raw: string): string | null {
 const value = (raw ?? '').trim();
 if (!value) return field.required ? `${field.label} is required.` : null;

 switch (field.type) {
 case 'number':
 return Number.isNaN(Number(value)) ? `${field.label} must be a number.` : null;
 case 'email':
 return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value)
 ? null
 : `${field.label} must be a valid email address.`;
 case 'phone': {
 const digits = value.replace(/\D/g, '');
 return digits.length >= 7 && digits.length <= 15
 ? null
 : `${field.label} must be a valid phone number.`;
 }
 case 'date':
 return Number.isNaN(new Date(value).getTime()) ? `${field.label} must be a valid date.` : null;
 case 'select':
 return field.options && field.options.length > 0 && !field.options.includes(value)
 ? `Please choose a valid option for ${field.label}.`
 : null;
 default:
 return null;
 }
}

export const BookEventModal: React.FC<BookEventModalProps> = ({ event, isOpen, onClose }) => {
 const { isAuthenticated, user } = useAuth();

 const [name, setName] = useState('');
 const [email, setEmail] = useState('');
 const [selectedSlotId, setSelectedSlotId] = useState('');
 const [numPasses, setNumPasses] = useState(1);
 // Answers to the event's admin-defined fields, keyed by field key.
 const [customValues, setCustomValues] = useState<Record<string, string>>({});

 const [isSubmitting, setIsSubmitting] = useState(false);
 const [formError, setFormError] = useState<string | null>(null);
 const [bookingSuccess, setBookingSuccess] = useState(false);

 const [showLoginModal, setShowLoginModal] = useState(false);
 const [pendingBooking, setPendingBooking] = useState(false);

 // Coupon state
 const [appliedCoupon, setAppliedCoupon] = useState<CouponValidationResult | null>(null);
 // Pending coupon — saved when user tries to apply before login
 const [pendingCouponCode, setPendingCouponCode] = useState<string | null>(null);

 // Pre-fill from logged-in user
 useEffect(() => {
 if (user) {
 setName(user.name || '');
 setEmail(user.email || '');
 }
 }, [user]);

 // Auto-submit after login completes
 useEffect(() => {
 if (isAuthenticated && pendingBooking && !showLoginModal) {
 setPendingBooking(false);
 submitBooking();
 }
 }, [isAuthenticated, showLoginModal, pendingBooking]);

 // Reset when modal opens for a new event
 useEffect(() => {
 if (isOpen) {
 setSelectedSlotId('');
 setNumPasses(1);
 setCustomValues({});
 setFormError(null);
 setBookingSuccess(false);
 setPendingBooking(false);
 setAppliedCoupon(null);
 setPendingCouponCode(null);
 if (!user) {
 setName('');
 setEmail('');
 }
 }
 }, [isOpen, event?.id]);

 if (!isOpen || !event) return null;

 // Extra inputs the admin configured for this event — empty for most events.
 const customFields = event.customFields ?? [];
 const setCustomValue = (key: string, value: string) =>
 setCustomValues((prev) => ({ ...prev, [key]: value }));

 // ── Pass quantity ─────────────────────────────────────────────────────────
 // Single entry point for the − / + buttons and typed input so the value is
 // always clamped to [MIN_PASSES, MAX_PASSES]. Changing the quantity changes
 // the amount, so any applied coupon is dropped and must be re-applied.
 const setPasses = (next: number) => {
 const clamped = Number.isNaN(next) ? MIN_PASSES : Math.min(MAX_PASSES, Math.max(MIN_PASSES, next));
 setNumPasses(clamped);
 setAppliedCoupon(null);
 setPendingCouponCode(null);
 };

 // ── Coupon apply handler — called by OffersPanel ──────────────────────────
 // If not logged in: save the code and prompt login instead of applying.
 const handleCouponApply = (result: CouponValidationResult) => {
 setAppliedCoupon(result);
 setPendingCouponCode(null);
 };

 const handleCouponApplyAttempt = (result: CouponValidationResult) => {
 if (!isAuthenticated) {
 // Save the code so we can re-apply after login
 setPendingCouponCode(result.code);
 return;
 }
 handleCouponApply(result);
 };

 // ── Booking form submit ───────────────────────────────────────────────────
 const handleProceed = (e: React.FormEvent) => {
 e.preventDefault();
 setFormError(null);

 if (!name.trim()) return setFormError('Please enter your full name.');
 if (!email.trim()) return setFormError('Please enter your email address.');
 if (!selectedSlotId) return setFormError('Please select a pass.');
 if (numPasses < 1) return setFormError('Number of passes must be at least 1.');

 for (const field of customFields) {
 const problem = validateCustomField(field, customValues[field.key] ?? '');
 if (problem) return setFormError(problem);
 }

 if (!isAuthenticated) {
 setPendingBooking(true);
 setShowLoginModal(true);
 return;
 }

 submitBooking();
 };

 const submitBooking = async () => {
 setIsSubmitting(true);
 setFormError(null);
 try {
 const res = await fetchWithAuth(`${API}/event-passes/bookings/create`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({
 eventPassId: event.id,
 slotId: selectedSlotId,
 name: name.trim(),
 email: email.trim(),
 numberOfPasses: numPasses,
 couponCode: appliedCoupon?.code ?? null,
 // One set of answers per booking, whatever the pass count.
 customFieldValues: customFields.map((f) => ({
 key: f.key,
 value: (customValues[f.key] ?? '').trim(),
 })),
 }),
 });
 const json = await res.json();
 if (!res.ok) throw new Error(json.message || 'Booking failed');

 const booking = json.data;

 // Paid events: the booking is created as Pending and carries NO pass. The
 // pass is issued by the backend only once /payments/verify confirms the
 // payment, so cancelling or failing checkout never yields a pass.
 if (totalAmount > 0) {
 await initiatePayment(
 totalAmount,
 'event',
 booking.id,
 { name: name.trim(), email: email.trim() },
 `Event Pass — ${event.title} (${numPasses} pass${numPasses > 1 ? 'es' : ''})`
 );
 }

 setBookingSuccess(true);
 } catch (err: any) {
 const msg = String(err?.message || 'Booking failed');
 setFormError(
 /cancel/i.test(msg)
 ? 'Payment was cancelled — no pass has been issued. Please complete the payment to receive your event pass.'
 : msg
 );
 } finally {
 setIsSubmitting(false);
 }
 };

 const selectedSlot = event.slots.find((s) => String(s.id) === String(selectedSlotId));
 const baseAmount = selectedSlot ? selectedSlot.price * numPasses : 0;
 const totalAmount = appliedCoupon ? appliedCoupon.finalAmount : baseAmount;

 // A free event = every pass option costs ₹0. Highlighted with a corner banner.
 const isFreeEvent = event.slots.length > 0 && event.slots.every((s) => Number(s.price) <= 0);

 const headerLabel = event.eventDate
 ? `${fmtDate(event.eventDate)} | ${event.title}`
 : event.title;

 const inputClass =
 'w-full bg-slate-50 border border-slate-100 rounded-2xl py-3.5 pl-12 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all';
 const labelClass = 'text-[10px] uppercase text-slate-400 tracking-widest ml-1';

 return (
 <>
 {/* ── Booking Modal ── */}
 <AnimatePresence>
 {!showLoginModal && (
 <div className="fixed inset-0 z-200 flex items-center justify-center p-3 sm:p-4">
 {/* Backdrop */}
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onClick={onClose}
 className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
 />

 {/* Wide card — two-column layout */}
 <motion.div
 initial={{ opacity: 0, scale: 0.95, y: 20 }}
 animate={{ opacity: 1, scale: 1, y: 0 }}
 exit={{ opacity: 0, scale: 0.95, y: 20 }}
 className={`relative bg-white w-full max-w-3xl rounded-4xl shadow-2xl overflow-hidden max-h-[95vh] flex flex-col ${
 isFreeEvent ? 'ring-2 ring-emerald-400' : ''
 }`}
 >
 {/* FREE banner — top-left corner, only when every pass costs ₹0 */}
 {isFreeEvent && (
 <div className="absolute top-0 left-0 z-20 flex items-center gap-1.5 bg-emerald-500 text-white pl-4 pr-5 py-2 rounded-br-2xl shadow-lg">
 <Sparkles size={14} />
 <span className="text-xs uppercase tracking-widest">Free Entry</span>
 </div>
 )}

 {/* Close button */}
 <button
 onClick={onClose}
 className="absolute top-5 right-5 z-20 w-8 h-8 flex items-center justify-center bg-slate-100 hover:bg-slate-200 text-slate-500 rounded-xl transition-colors"
 >
 <X size={16} />
 </button>

 {bookingSuccess ? (
 /* ── Success state — full width ── */
 <div className="p-10 text-center space-y-5">
 <div className="flex items-center justify-center">
 <div className="w-20 h-20 rounded-full bg-brand-secondary flex items-center justify-center">
 <CheckCircle size={40} className="text-brand-primary"/>
 </div>
 </div>
 <div>
 <h2 className="text-3xl text-slate-900 tracking-tighter uppercase mb-2">
 Booking Confirmed!
 </h2>
 <p className="text-slate-500 text-sm">
 Your {numPasses} pass{numPasses > 1 ? 'es' : ''} for{' '}
 <strong className="text-slate-700">{event.title}</strong>{' '}
 {numPasses > 1 ? 'have' : 'has'} been booked.
 </p>
 {totalAmount > 0 && (
 <p className="mt-2 text-brand-primary text-base">
 Total: ₹{totalAmount.toFixed(2)}
 {appliedCoupon && (
 <span className="ml-2 text-xs text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">
 Saved ₹{appliedCoupon.discountAmount.toFixed(2)}
 </span>
 )}
 </p>
 )}
 <p className="mt-1 text-slate-400 text-xs">
 Confirmation will be sent to {email}
 </p>
 </div>
 <Button
 onClick={onClose}
 className="w-full max-w-xs mx-auto py-4 uppercase tracking-widest"
 >
 Done
 <ArrowRight size={18} />
 </Button>
 </div>
 ) : (
 /* ── Two-column layout ── */
 <div className="flex flex-col md:flex-row overflow-y-auto md:overflow-hidden flex-1 min-h-0">

 {/* ── LEFT — Offers Panel ─────────────────────────────── */}
 <div className="md:w-[42%] bg-slate-50 border-b md:border-b-0 md:border-r border-slate-100 flex flex-col">
 {/* Header — extra top padding clears the FREE corner banner */}
 <div className={`px-6 pb-4 border-b border-slate-100 ${isFreeEvent ? 'pt-16' : 'pt-6'}`}>
 <div className="flex items-center gap-2 mb-1">
 <div className="w-8 h-8 rounded-xl bg-brand-secondary flex items-center justify-center">
 <Ticket size={16} className="text-brand-primary"/>
 </div>
 <div>
 <h2 className="text-sm text-slate-800 uppercase tracking-tight leading-none">
 {event.title}
 </h2>
 {event.eventDate && (
 <p className="text-[10px] text-slate-400 mt-0.5">
 {fmtDate(event.eventDate)}
 </p>
 )}
 </div>
 </div>
 </div>

 {/* Offers — scrollable */}
 <div className="flex-1 overflow-y-auto px-4 py-4">
 {/* Login notice when not authenticated */}
 {!isAuthenticated && (
 <div className="flex items-start gap-2 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2.5 mb-3">
 <Lock size={13} className="text-amber-500 shrink-0 mt-0.5"/>
 <p className="text-[11px] text-amber-700 leading-snug">
 Browse offers below. Log in to apply a coupon before booking.
 </p>
 </div>
 )}

 {/* Pending coupon notice — saved code waiting for login */}
 {pendingCouponCode && !isAuthenticated && (
 <div className="flex items-start gap-2 bg-brand-secondary border border-brand-primary/20 rounded-xl px-3 py-2.5 mb-3">
 <CheckCircle size={13} className="text-brand-primary shrink-0 mt-0.5"/>
 <p className="text-[11px] text-brand-primary leading-snug">
 <span className="">{pendingCouponCode}</span> will be applied after you log in.
 </p>
 </div>
 )}

 <OffersPanel
 amount={baseAmount}
 scope={{ appliesTo: 'Event', eventPassId: event?.id }}
 appliedCoupon={appliedCoupon}
 onApply={handleCouponApplyAttempt}
 onRemove={() => {
 setAppliedCoupon(null);
 setPendingCouponCode(null);
 }}
 loginRequired={!isAuthenticated}
 onLoginRequired={(code) => setPendingCouponCode(code)}
 />
 </div>
 </div>

 {/* ── RIGHT — Booking Form ────────────────────────────── */}
 <div className="md:w-[58%] flex flex-col overflow-y-auto">
 <div className="px-7 pt-7 pb-6 flex-1">
 {/* Form header */}
 <div className="mb-6">
 <h2 className="text-xl text-slate-900 tracking-tighter uppercase leading-tight">
 Book Event Passes
 </h2>
 <p className="text-slate-400 text-xs mt-1">{headerLabel}</p>
 </div>

 {/* Error */}
 {formError && (
 <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl">
 <p className="text-red-600 text-sm">{formError}</p>
 </div>
 )}

 <form className="space-y-4"onSubmit={handleProceed}>
 {/* Name */}
 <div className="space-y-1">
 <label className={labelClass}>Your Name</label>
 <div className="relative">
 <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={16} />
 <input
 type="text"
 value={name}
 onChange={(e) => setName(e.target.value)}
 placeholder="Enter your full name"
 className={inputClass}
 />
 </div>
 </div>

 {/* Email */}
 <div className="space-y-1">
 <label className={labelClass}>Email Address</label>
 <div className="relative">
 <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={16} />
 <input
 type="email"
 value={email}
 onChange={(e) => setEmail(e.target.value)}
 placeholder="name@example.com"
 className={inputClass}
 />
 </div>
 </div>

 {/* Custom fields — configured per event by the admin.
 Placed right after Email so the guest finishes their own details
 before moving on to pass selection. */}
 {customFields.map((field) => {
 const value = customValues[field.key] ?? '';
 return (
 <div key={field.key} className="space-y-1">
 <label className={labelClass}>
 {field.label}
 {field.required && <span className="text-red-500 ml-1">*</span>}
 </label>

 {field.type === 'textarea' ? (
 <textarea
 rows={3}
 value={value}
 onChange={(e) => setCustomValue(field.key, e.target.value)}
 placeholder={field.placeholder ?? ''}
 className={`${inputClass} pl-4 resize-none`}
 />
 ) : field.type === 'select' ? (
 <div className="relative">
 <select
 value={value}
 onChange={(e) => setCustomValue(field.key, e.target.value)}
 className={`${inputClass} pl-4 appearance-none cursor-pointer pr-10`}
 >
 <option value="">
 {field.placeholder || `-- Select ${field.label} --`}
 </option>
 {(field.options ?? []).map((opt) => (
 <option key={opt} value={opt}>
 {opt}
 </option>
 ))}
 </select>
 <svg
 className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
 width="14" height="14" viewBox="0 0 24 24"
 fill="none" stroke="currentColor" strokeWidth="2.5"
 >
 <polyline points="6 9 12 15 18 9"/>
 </svg>
 </div>
 ) : (
 <input
 type={CUSTOM_INPUT_TYPE[field.type] ?? 'text'}
 inputMode={field.type === 'phone' ? 'numeric' : undefined}
 value={value}
 onChange={(e) => setCustomValue(field.key, e.target.value)}
 placeholder={field.placeholder ?? ''}
 className={`${inputClass} pl-4`}
 />
 )}
 </div>
 );
 })}

 {/* Select Pass */}
 <div className="space-y-1">
 <label className={labelClass}>Select Pass</label>
 <div className="relative">
 <Ticket className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={16} />
 <select
 value={selectedSlotId}
 onChange={(e) => {
 setSelectedSlotId(e.target.value);
 setAppliedCoupon(null);
 setPendingCouponCode(null);
 }}
 className={`${inputClass} appearance-none cursor-pointer pr-10`}
 >
 <option value="">-- Choose a Date --</option>
 {event.slots.map((slot) => (
 <option key={slot.id} value={slot.id}>
 {slotLabel(slot)}
 </option>
 ))}
 </select>
 <svg
 className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
 width="14"height="14"viewBox="0 0 24 24"
 fill="none"stroke="currentColor"strokeWidth="2.5"
 >
 <polyline points="6 9 12 15 18 9"/>
 </svg>
 </div>
 </div>

 {/* Number of Passes — stepper: [−] qty [+] */}
 <div className="space-y-1">
 <label className={labelClass}>Number of Passes</label>
 <div className="flex items-center justify-between gap-3 bg-slate-50 border border-slate-100 rounded-2xl p-2">
 <button
 type="button"
 aria-label="Decrease number of passes"
 onClick={() => setPasses(numPasses - 1)}
 disabled={numPasses <= MIN_PASSES}
 className="w-11 h-11 shrink-0 flex items-center justify-center rounded-xl bg-white border border-slate-200 text-slate-600 hover:bg-brand-primary hover:border-brand-primary hover:text-white disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-white disabled:hover:text-slate-600 disabled:hover:border-slate-200 transition-all active:scale-95"
 >
 <Minus size={16} />
 </button>

 <input
 type="text"
 inputMode="numeric"
 aria-label="Number of passes"
 value={numPasses}
 onChange={(e) => setPasses(parseInt(e.target.value.replace(/\D/g, ''), 10))}
 className="flex-1 min-w-0 bg-transparent text-center text-lg text-slate-900 focus:outline-none"
 />

 <button
 type="button"
 aria-label="Increase number of passes"
 onClick={() => setPasses(numPasses + 1)}
 disabled={numPasses >= MAX_PASSES}
 className="w-11 h-11 shrink-0 flex items-center justify-center rounded-xl bg-white border border-slate-200 text-slate-600 hover:bg-brand-primary hover:border-brand-primary hover:text-white disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-white disabled:hover:text-slate-600 disabled:hover:border-slate-200 transition-all active:scale-95"
 >
 <Plus size={16} />
 </button>
 </div>
 </div>

 {/* Price summary */}
 {selectedSlot && (
 <div className="rounded-2xl bg-slate-50 border border-slate-100 px-4 py-3 space-y-1.5">
 <div className="flex items-center justify-between text-xs">
 <span className="text-slate-500">
 {numPasses} × ₹{selectedSlot.price}
 </span>
 <span className="text-slate-700">₹{baseAmount.toFixed(2)}</span>
 </div>
 {appliedCoupon && (
 <div className="flex items-center justify-between text-xs">
 <span className="text-emerald-600 flex items-center gap-1">
 <CheckCircle size={11} />
 {appliedCoupon.code}
 </span>
 <span className="text-emerald-600">
 − ₹{appliedCoupon.discountAmount.toFixed(2)}
 </span>
 </div>
 )}
 <div className="flex items-center justify-between border-t border-slate-200 pt-1.5">
 <span className="text-xs text-slate-700 uppercase tracking-widest">Total</span>
 <span className={`text-base ${appliedCoupon ? 'text-emerald-600' : 'text-brand-primary'}`}>
 ₹{totalAmount.toFixed(2)}
 </span>
 </div>
 </div>
 )}

 {/* Login notice */}
 {!isAuthenticated && (
 <p className="text-[11px] text-slate-400 text-center tracking-wide">
 You'll be asked to log in before completing your booking.
 </p>
 )}

 {/* Submit */}
 <Button
 type="submit"
 className="w-full py-4 uppercase tracking-widest"
 onClick={() => {}}
 >
 {isSubmitting ? (
 <>
 <Loader2 className="animate-spin"size={18} />
 Processing...
 </>
 ) : (
 <>
 Proceed to Payment
 <ArrowRight size={18} />
 </>
 )}
 </Button>
 </form>
 </div>
 </div>

 </div>
 )}
 </motion.div>
 </div>
 )}
 </AnimatePresence>

 {/* ── Login Modal ── */}
 <AnimatePresence>
 {showLoginModal && (
 <AuthModal
 isOpen={showLoginModal}
 onClose={() => {
 setShowLoginModal(false);
 setPendingBooking(false);
 }}
 initialMode="login"
 />
 )}
 </AnimatePresence>
 </>
 );
};

