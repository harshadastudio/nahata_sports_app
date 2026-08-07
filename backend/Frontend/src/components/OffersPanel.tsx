/**
 * OffersPanel
 * Displays all active coupons fetched from the backend.
 * Users can click"Apply"on any offer card to instantly apply it.
 * Falls back to a manual code entry input below the list.
 *
 * Props:
 * amount — current booking amount (used to preview savings)
 * appliedCoupon — currently applied coupon (if any)
 * onApply — called when a coupon is applied (via card click or manual input)
 * onRemove — called when the applied coupon is removed
 */

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
 Tag,
 Percent,
 IndianRupee,
 Calendar,
 ChevronDown,
 ChevronUp,
 CheckCircle2,
 Loader2,
 Sparkles,
 X,
 Lock,
} from 'lucide-react';
import {
 getActiveCoupons,
 validateCoupon,
 ActiveCoupon,
 CouponValidationResult,
 CouponScope,
} from '../services/couponService';

interface OffersPanelProps {
 amount: number;
 appliedCoupon: CouponValidationResult | null;
 onApply: (result: CouponValidationResult) => void;
 onRemove: () => void;
 /** Scopes which coupons are shown / accepted (court+complex vs event). */
 scope?: CouponScope;
 /** When true, clicking Apply on a card triggers onLoginRequired instead of applying */
 loginRequired?: boolean;
 /** Called with the coupon code when user tries to apply before login */
 onLoginRequired?: (code: string) => void;
 className?: string;
}

/** Format"2026-12-31T00:00:00.000Z"→"31 Dec 2026"*/
function fmtExpiry(dateStr: string): string {
 const d = new Date(dateStr);
 return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

/** Calculate preview savings for a coupon against the current amount */
function calcSavings(coupon: ActiveCoupon, amount: number): number {
 if (amount <= 0) return 0;
 if (coupon.discountType === 'Percentage') {
 let saving = (amount * coupon.discountValue) / 100;
 if (coupon.maxDiscount && saving > coupon.maxDiscount) saving = coupon.maxDiscount;
 return Math.round(saving * 100) / 100;
 }
 return Math.min(coupon.discountValue, amount);
}

export const OffersPanel: React.FC<OffersPanelProps> = ({
 amount,
 appliedCoupon,
 onApply,
 onRemove,
 scope,
 loginRequired = false,
 onLoginRequired,
 className = '',
}) => {
 const [offers, setOffers] = useState<ActiveCoupon[]>([]);
 const [loadingOffers, setLoadingOffers] = useState(true);
 const [applyingCode, setApplyingCode] = useState<string | null>(null);
 const [applyError, setApplyError] = useState<string | null>(null);

 // Manual input state
 const [manualCode, setManualCode] = useState('');
 const [manualLoading, setManualLoading] = useState(false);
 const [manualError, setManualError] = useState<string | null>(null);

 // Collapse state — panel starts open
 const [isOpen, setIsOpen] = useState(true);

 useEffect(() => {
 let cancelled = false;
 setLoadingOffers(true);
 getActiveCoupons(scope).then((data) => {
 if (cancelled) return;
 setOffers(data);
 setLoadingOffers(false);
 });
 return () => { cancelled = true; };
 // Depend on primitive scope fields so a fresh scope object each render
 // doesn't retrigger the fetch in a loop.
 // eslint-disable-next-line react-hooks/exhaustive-deps
 }, [scope?.appliesTo, scope?.sportComplexId]);

 // ── Apply a coupon from the offers list ───────────────────────────────────
 const handleApplyOffer = async (code: string) => {
 if (amount <= 0) return;

 // If login is required, notify parent and stop — don't call the API
 if (loginRequired) {
 onLoginRequired?.(code);
 return;
 }

 setApplyingCode(code);
 setApplyError(null);
 try {
 const result = await validateCoupon(code, amount, scope);
 onApply(result);
 } catch (err: any) {
 setApplyError(err.message || 'Could not apply this offer');
 } finally {
 setApplyingCode(null);
 }
 };

 // ── Apply from manual input ───────────────────────────────────────────────
 const handleManualApply = async () => {
 if (!manualCode.trim()) {
 setManualError('Please enter a coupon code');
 return;
 }
 if (amount <= 0) {
 setManualError('Cannot apply coupon to a zero-amount booking');
 return;
 }

 // If login is required, notify parent and stop
 if (loginRequired) {
 onLoginRequired?.(manualCode.trim().toUpperCase());
 setManualCode('');
 return;
 }

 setManualLoading(true);
 setManualError(null);
 try {
 const result = await validateCoupon(manualCode.trim(), amount, scope);
 onApply(result);
 setManualCode('');
 } catch (err: any) {
 setManualError(err.message || 'Invalid coupon code');
 } finally {
 setManualLoading(false);
 }
 };

 // ── Applied state — compact banner ────────────────────────────────────────
 if (appliedCoupon) {
 const discountLabel =
 appliedCoupon.discountType === 'Percentage'
 ? `${appliedCoupon.discountValue}% off${appliedCoupon.maxDiscount ? ` (max ₹${appliedCoupon.maxDiscount})` : ''}`
 : `₹${appliedCoupon.discountValue} off`;

 return (
 <div className={`rounded-2xl border-2 border-emerald-200 bg-emerald-50 px-4 py-3 ${className}`}>
 <div className="flex items-center justify-between gap-3">
 <div className="flex items-center gap-3 min-w-0">
 <div className="w-8 h-8 rounded-xl bg-emerald-100 flex items-center justify-center shrink-0">
 <CheckCircle2 size={16} className="text-emerald-600"/>
 </div>
 <div className="min-w-0">
 <div className="flex items-center gap-2">
 <p className="text-xs text-emerald-700 uppercase tracking-widest">
 {appliedCoupon.code}
 </p>
 <span className="text-[9px] bg-emerald-200 text-emerald-700 px-2 py-0.5 rounded-full uppercase tracking-wider">
 Applied
 </span>
 </div>
 <p className="text-[11px] text-emerald-600 mt-0.5">
 {discountLabel} — you save{' '}
 <span className="">₹{appliedCoupon.discountAmount.toFixed(2)}</span>
 </p>
 </div>
 </div>
 <button
 onClick={onRemove}
 className="shrink-0 p-1.5 rounded-lg hover:bg-emerald-100 text-emerald-500 transition-colors"
 title="Remove coupon"
 >
 <X size={14} />
 </button>
 </div>
 </div>
 );
 }

 // ── Offers panel ──────────────────────────────────────────────────────────
 return (
 <div className={`rounded-2xl border border-slate-200 bg-white overflow-hidden ${className}`}>
 {/* Header — toggle */}
 <button
 onClick={() => setIsOpen((v) => !v)}
 className="w-full flex items-center justify-between px-4 py-3 hover:bg-slate-50 transition-colors"
 >
 <div className="flex items-center gap-2">
 <div className="w-7 h-7 rounded-lg bg-brand-secondary flex items-center justify-center">
 <Sparkles size={14} className="text-brand-primary"/>
 </div>
 <span className="text-xs text-slate-700 uppercase tracking-widest">
 Offers & Coupons
 </span>
 {offers.length > 0 && (
 <span className="text-[9px] bg-brand-primary text-white px-2 py-0.5 rounded-full">
 {offers.length} available
 </span>
 )}
 </div>
 {isOpen ? (
 <ChevronUp size={16} className="text-slate-400"/>
 ) : (
 <ChevronDown size={16} className="text-slate-400"/>
 )}
 </button>

 <AnimatePresence initial={false}>
 {isOpen && (
 <motion.div
 initial={{ height: 0, opacity: 0 }}
 animate={{ height: 'auto', opacity: 1 }}
 exit={{ height: 0, opacity: 0 }}
 transition={{ duration: 0.2, ease: 'easeInOut' }}
 className="overflow-hidden"
 >
 <div className="px-4 pb-4 space-y-3 border-t border-slate-100 pt-3">

 {/* Error from offer apply */}
 {applyError && (
 <div className="flex items-center gap-2 text-[11px] text-red-500 bg-red-50 border border-red-100 rounded-xl px-3 py-2">
 <X size={12} className="shrink-0"/>
 {applyError}
 </div>
 )}

 {/* Offer cards */}
 {loadingOffers ? (
 <div className="flex items-center justify-center py-6 text-slate-300">
 <Loader2 size={20} className="animate-spin"/>
 </div>
 ) : offers.length === 0 ? (
 <p className="text-center text-[11px] text-slate-400 py-4">
 No active offers right now
 </p>
 ) : (
 <div className="space-y-2 max-h-56 overflow-y-auto pr-1 scrollbar-thin">
 {offers.map((offer) => {
 const savings = calcSavings(offer, amount);
 const isApplying = applyingCode === offer.code;

 return (
 <div
 key={offer.id}
 className="flex items-center gap-3 p-3 rounded-xl border-2 border-dashed border-slate-200 hover:border-brand-primary/40 hover:bg-brand-secondary/20 transition-all group"
 >
 {/* Icon */}
 <div className="w-9 h-9 rounded-xl bg-slate-100 group-hover:bg-brand-secondary flex items-center justify-center shrink-0 transition-colors">
 {offer.discountType === 'Percentage' ? (
 <Percent size={16} className="text-brand-primary"/>
 ) : (
 <IndianRupee size={16} className="text-brand-primary"/>
 )}
 </div>

 {/* Details */}
 <div className="flex-1 min-w-0">
 <div className="flex items-center gap-2 mb-0.5">
 <span className="text-xs text-slate-800 uppercase tracking-wider">
 {offer.code}
 </span>
 {amount > 0 && savings > 0 && (
 <span className="text-[9px] bg-emerald-100 text-emerald-700 px-1.5 py-0.5 rounded-full whitespace-nowrap">
 Save ₹{savings.toFixed(0)}
 </span>
 )}
 </div>
 <p className="text-[10px] text-slate-500 truncate">
 {offer.description ||
 (offer.discountType === 'Percentage'
 ? `${offer.discountValue}% off${offer.maxDiscount ? ` up to ₹${offer.maxDiscount}` : ''}`
 : `Flat ₹${offer.discountValue} off`)}
 </p>
 <div className="flex items-center gap-1 mt-0.5">
 <Calendar size={9} className="text-slate-300"/>
 <span className="text-[9px] text-slate-400">
 Valid till {fmtExpiry(offer.validUntil)}
 </span>
 </div>
 </div>

 {/* Apply button */}
 <button
 onClick={() => handleApplyOffer(offer.code)}
 disabled={isApplying || (amount <= 0 && !loginRequired)}
 className={`shrink-0 px-3 py-1.5 text-[10px] uppercase tracking-widest rounded-lg transition-all disabled:opacity-40 disabled:cursor-not-allowed active:scale-95 flex items-center gap-1 border-2 ${
 loginRequired
 ? 'border-amber-400 text-amber-600 hover:bg-amber-400 hover:text-white'
 : 'border-brand-primary text-brand-primary hover:bg-brand-primary hover:text-white'
 }`}
 >
 {isApplying ? (
 <Loader2 size={11} className="animate-spin"/>
 ) : loginRequired ? (
 <>
 <Lock size={10} />
 Apply
 </>
 ) : (
 'Apply'
 )}
 </button>
 </div>
 );
 })}
 </div>
 )}

 {/* Divider */}
 <div className="flex items-center gap-3">
 <div className="flex-1 h-px bg-slate-100"/>
 <span className="text-[9px] text-slate-300 uppercase tracking-widest whitespace-nowrap">
 or enter code
 </span>
 <div className="flex-1 h-px bg-slate-100"/>
 </div>

 {/* Manual code input */}
 <div className="space-y-1.5">
 <div className="flex items-center gap-2">
 <div className="relative flex-1">
 <Tag
 size={13}
 className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
 />
 <input
 type="text"
 value={manualCode}
 onChange={(e) => {
 setManualCode(e.target.value.toUpperCase().replace(/\s/g, ''));
 setManualError(null);
 }}
 onKeyDown={(e) => {
 if (e.key === 'Enter') {
 e.preventDefault();
 handleManualApply();
 }
 }}
 placeholder="COUPON CODE"
 className={`w-full pl-9 pr-3 py-2 text-[11px] uppercase tracking-widest rounded-xl border-2 transition-all focus:outline-none focus:ring-2 focus:ring-brand-primary/20 ${
 manualError
 ? 'border-red-300 bg-red-50 focus:border-red-400'
 : 'border-slate-200 bg-slate-50 focus:border-brand-primary focus:bg-white'
 }`}
 />
 </div>
 <button
 onClick={handleManualApply}
 disabled={manualLoading || !manualCode.trim()}
 className="shrink-0 px-4 py-2 bg-brand-primary hover:bg-brand-dark text-white text-[10px] uppercase tracking-widest rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed active:scale-95 flex items-center gap-1"
 >
 {manualLoading ? (
 <Loader2 size={12} className="animate-spin"/>
 ) : (
 'Apply'
 )}
 </button>
 </div>
 {manualError && (
 <p className="text-[11px] text-red-500 flex items-center gap-1.5 pl-1">
 <X size={11} className="shrink-0"/>
 {manualError}
 </p>
 )}
 </div>

 </div>
 </motion.div>
 )}
 </AnimatePresence>
 </div>
 );
};

export default OffersPanel;

