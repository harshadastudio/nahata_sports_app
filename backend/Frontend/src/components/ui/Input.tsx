/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { ReactNode, forwardRef, useId } from 'react';

/**
 * Premium input component with validation states, icons, and accessibility features.
 * 
 * @component
 * @example
 * // Basic input with label
 * <Input
 * label="Email"
 * type="email"
 * placeholder="Enter your email"
 * value={email}
 * onChange={(e) => setEmail(e.target.value)}
 * />
 * 
 * @example
 * // Input with error state
 * <Input
 * label="Password"
 * type="password"
 * error="Password must be at least 8 characters"
 * value={password}
 * onChange={(e) => setPassword(e.target.value)}
 * />
 * 
 * @example
 * // Input with prefix icon
 * <Input
 * label="Search"
 * prefix={<Search size={16} />}
 * placeholder="Search..."
 * />
 * 
 * @example
 * // Input with success state
 * <Input
 * label="Username"
 * success={true}
 * value={username}
 * onChange={(e) => setUsername(e.target.value)}
 * />
 */
interface InputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'prefix'> {
 /** Input label displayed above the field */
 label?: string;
 /** Helper text displayed below the field */
 hint?: string;
 /** Error message (shows red border and error text) */
 error?: string;
 /** Success state (shows green border and checkmark) */
 success?: boolean;
 /** Icon or element displayed at the start of the input */
 prefix?: ReactNode;
 /** Icon or element displayed at the end of the input */
 suffix?: ReactNode;
 /** Visual variant: 'default' (white bg) or 'filled' (gray bg) */
 variant?: 'default' | 'filled';
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
 ({ label, hint, error, success, prefix, suffix, variant = 'default', className = '', id, ...props }, ref) => {
 const generatedId = useId();
 const inputId = id || generatedId;
 const errorId = error ? `${inputId}-error` : undefined;

 const stateStyles = error
 ? 'border-red-400 focus:border-red-500 focus:ring-red-500/15 bg-red-50/30'
 : success
 ? 'border-emerald-400 focus:border-emerald-500 focus:ring-emerald-500/15'
 : 'border-border focus:border-brand-bright focus:ring-brand-bright/15';

 const variantStyles = variant === 'filled'
 ? 'bg-bg-main border-bg-main focus:bg-white'
 : 'bg-white';

 return (
 <div className="w-full">
 {label && (
 <label
 htmlFor={inputId}
 className="block text-[13px] text-text-primary mb-2"
 >
 {label}
 </label>
 )}

 <div className="relative">
 {prefix && (
 <div className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted pointer-events-none">
 {prefix}
 </div>
 )}

 <input
 ref={ref}
 id={inputId}
 aria-describedby={errorId}
 aria-invalid={error ? 'true' : 'false'}
 className={`
 w-full px-4 py-3 rounded-xl border-2 font-sans text-[15px]
 text-text-primary placeholder:text-text-muted
 transition-all duration-200
 focus:outline-none focus:ring-4
 disabled:opacity-50 disabled:cursor-not-allowed
 ${variantStyles}
 ${stateStyles}
 ${prefix ? 'pl-11' : ''}
 ${suffix ? 'pr-11' : ''}
 ${className}
 `}
 {...props}
 />

 {suffix && (
 <div className="absolute right-4 top-1/2 -translate-y-1/2 text-text-muted">
 {suffix}
 </div>
 )}

 {/* Success icon */}
 {success && !error && (
 <div className="absolute right-4 top-1/2 -translate-y-1/2 text-emerald-500">
 <svg className="w-4 h-4"fill="none"viewBox="0 0 24 24"stroke="currentColor"strokeWidth={2.5}>
 <path strokeLinecap="round"strokeLinejoin="round"d="M5 13l4 4L19 7"/>
 </svg>
 </div>
 )}
 </div>

 {/* Hint */}
 {hint && !error && (
 <p className="mt-1.5 text-[12px] text-text-muted">{hint}</p>
 )}

 {/* Error */}
 {error && (
 <p id={errorId} className="mt-1.5 text-[12px] text-red-600 flex items-center gap-1.5">
 <svg className="w-3.5 h-3.5 shrink-0"fill="currentColor"viewBox="0 0 20 20">
 <path fillRule="evenodd"d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"clipRule="evenodd"/>
 </svg>
 {error}
 </p>
 )}
 </div>
 );
 }
);

Input.displayName = 'Input';

