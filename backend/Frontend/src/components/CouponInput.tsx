/**
 * CouponInput — Reusable coupon code entry + apply UI.
 *
 * Usage:
 * <CouponInput
 * amount={totalAmount}
 * onApply={(result) => { ... }}
 * onRemove={() => { ... }}
 * />
 */

import { useState } from 'react';
import { Tag, X, CheckCircle2, Loader2, ChevronRight } from 'lucide-react';
import { validateCoupon, CouponValidationResult } from '../services/couponService';

interface CouponInputProps {
 /** Original booking amount in INR */
 amount: number;
 /** Called when a valid coupon is applied */
 onApply: (result: CouponValidationResult) => void;
 /** Called when the applied coupon is removed */
 onRemove: () => void;
 /** Whether a coupon is currently applied */
 appliedCoupon?: CouponValidationResult | null;
 className?: string;
}

export const CouponInput: React.FC<CouponInputProps> = ({
 amount,
 onApply,
 onRemove,
 appliedCoupon,
 className = '',
}) => {
 const [code, setCode] = useState('');
 const [isLoading, setIsLoading] = useState(false);
 const [error, setError] = useState<string | null>(null);

 const handleApply = async () => {
 if (!code.trim()) {
 setError('Please enter a coupon code');
 return;
 }
 if (amount <= 0) {
 setError('Cannot apply coupon to a zero-amount booking');
 return;
 }

 setIsLoading(true);
 setError(null);

 try {
 const result = await validateCoupon(code.trim(), amount);
 onApply(result);
 setCode('');
 } catch (err: any) {
 setError(err.message || 'Invalid coupon code');
 } finally {
 setIsLoading(false);
 }
 };

 const handleRemove = () => {
 setCode('');
 setError(null);
 onRemove();
 };

 const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
 if (e.key === 'Enter') {
 e.preventDefault();
 handleApply();
 }
 };

 // ── Applied state ─────────────────────────────────────────────────────────
 if (appliedCoupon) {
 const discountLabel =
 appliedCoupon.discountType === 'Percentage'
 ? `${appliedCoupon.discountValue}% off${appliedCoupon.maxDiscount ? ` (max ₹${appliedCoupon.maxDiscount})` : ''}`
 : `₹${appliedCoupon.discountValue} off`;

 return (
 <div className={`rounded-2xl border-2 border-emerald-200 bg-emerald-50 px-4 py-3 ${className}`}>
 <div className="flex items-center justify-between gap-3">
 <div className="flex items-center gap-2 min-w-0">
 <CheckCircle2 size={18} className="text-emerald-500 shrink-0"/>
 <div className="min-w-0">
 <p className="text-xs text-emerald-700 uppercase tracking-widest truncate">
 {appliedCoupon.code}
 </p>
 <p className="text-[10px] text-emerald-600 mt-0.5">
 {discountLabel} — saving ₹{appliedCoupon.discountAmount.toFixed(2)}
 </p>
 </div>
 </div>
 <button
 onClick={handleRemove}
 className="shrink-0 p-1.5 rounded-lg hover:bg-emerald-100 text-emerald-500 transition-colors"
 title="Remove coupon"
 >
 <X size={14} />
 </button>
 </div>
 </div>
 );
 }

 // ── Input state ───────────────────────────────────────────────────────────
 return (
 <div className={`space-y-2 ${className}`}>
 <div className="flex items-center gap-2">
 <div className="relative flex-1">
 <Tag
 size={14}
 className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
 />
 <input
 type="text"
 value={code}
 onChange={(e) => {
 setCode(e.target.value.toUpperCase().replace(/\s/g, ''));
 setError(null);
 }}
 onKeyDown={handleKeyDown}
 placeholder="Enter coupon code"
 className={`w-full pl-9 pr-3 py-2.5 text-xs uppercase tracking-widest rounded-xl border-2 transition-all focus:outline-none focus:ring-2 focus:ring-brand-primary/20 ${
 error
 ? 'border-red-300 bg-red-50 focus:border-red-400'
 : 'border-slate-200 bg-slate-50 focus:border-brand-primary focus:bg-white'
 }`}
 />
 </div>
 <button
 onClick={handleApply}
 disabled={isLoading || !code.trim()}
 className="shrink-0 flex items-center gap-1.5 px-4 py-2.5 bg-brand-primary hover:bg-brand-dark text-white text-xs uppercase tracking-widest rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm shadow-brand-primary/20 active:scale-95"
 >
 {isLoading ? (
 <Loader2 size={14} className="animate-spin"/>
 ) : (
 <>
 Apply
 <ChevronRight size={13} />
 </>
 )}
 </button>
 </div>

 {error && (
 <p className="text-[11px] text-red-500 flex items-center gap-1.5 pl-1">
 <X size={12} className="shrink-0"/>
 {error}
 </p>
 )}
 </div>
 );
};

export default CouponInput;

