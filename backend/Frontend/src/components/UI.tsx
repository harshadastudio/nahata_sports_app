/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import React, { ReactNode } from 'react';
import { viewportOnce } from './ui/MotionPresets';

// ── Button ────────────────────────────────────────────────────────────

interface ButtonProps {
 children: ReactNode;
 variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'energy' | 'dark';
 size?: 'sm' | 'md' | 'lg' | 'xl';
 className?: string;
 onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
 type?: 'button' | 'submit';
 disabled?: boolean;
 loading?: boolean;
 icon?: ReactNode;
}

export const Button = ({
 children,
 variant = 'primary',
 size = 'md',
 className = '',
 onClick,
 type = 'button',
 disabled = false,
 loading = false,
 icon,
}: ButtonProps) => {
 const baseStyles =
 'group relative inline-flex items-center justify-center gap-2 rounded-full uppercase tracking-wide overflow-hidden transition-all duration-300 select-none shrink-0';

 const sizes = {
 sm: 'px-4 py-2 text-[11px] tracking-wider',
 md: 'px-6 py-2.5 text-xs tracking-wider',
 lg: 'px-8 py-3.5 text-sm',
 xl: 'px-10 py-4 text-sm',
 };

 const variants: Record<string, string> = {
 primary:
 'gradient-brand text-white shadow-[0_4px_20px_rgba(108,82,232,0.3)] hover:shadow-[0_8px_32px_rgba(108,82,232,0.45)] hover:brightness-110',
 secondary:
 'bg-brand-secondary text-brand-primary hover:bg-[#EDE9FF] border border-brand-secondary',
 outline:
 'border-2 border-brand-bright text-brand-bright hover:bg-brand-bright hover:text-white',
 ghost:
 'text-text-secondary hover:text-brand-primary hover:bg-brand-secondary border border-transparent',
 energy:
 'gradient-energy text-white shadow-[0_4px_20px_rgba(255,107,44,0.3)] hover:shadow-[0_8px_32px_rgba(255,107,44,0.45)] hover:brightness-110',
 dark:
 'bg-bg-hero text-white border border-white/10 hover:bg-white/10',
 };

 const isDisabled = disabled || loading;

 return (
 <motion.button
 whileHover={isDisabled ? {} : { y: -2 }}
 whileTap={isDisabled ? {} : { scale: 0.97 }}
 transition={{ type: 'spring', stiffness: 500, damping: 25 }}
 type={type}
 onClick={isDisabled ? undefined : onClick}
 disabled={isDisabled}
 className={`${baseStyles} ${sizes[size]} ${variants[variant]} ${isDisabled ? 'opacity-50 cursor-not-allowed' : ''} ${className}`}
 >
 {/* Animated shine sweep for brand/energy variants */}
 {(variant === 'primary' || variant === 'energy') && !isDisabled && (
 <span
 className="absolute inset-0 -translate-x-full group-hover:translate-x-full transition-transform duration-700 bg-gradient-to-r from-transparent via-white/20 to-transparent pointer-events-none"
 aria-hidden="true"
 />
 )}

 {loading ? (
 <>
 <svg className="animate-spin h-4 w-4 shrink-0"xmlns="http://www.w3.org/2000/svg"fill="none"viewBox="0 0 24 24">
 <circle className="opacity-25"cx="12"cy="12"r="10"stroke="currentColor"strokeWidth="4"/>
 <path className="opacity-75"fill="currentColor"d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"/>
 </svg>
 <span>Loading...</span>
 </>
 ) : (
 <>
 {children}
 {icon && <span className="transition-transform duration-200 group-hover:translate-x-0.5">{icon}</span>}
 </>
 )}
 </motion.button>
 );
};

// ── Section Header ─────────────────────────────────────────────────────

interface SectionHeaderProps {
 eyebrow?: string;
 title: string;
 subtitle?: string;
 centered?: boolean;
 dark?: boolean; // For dark background sections
 className?: string;
}

export const SectionHeader = ({
  eyebrow,
  title,
  subtitle,
  centered = true,
  dark = false,
  className = '',
}: SectionHeaderProps) => (
  <div className={`mb-10 md:mb-16 ${centered ? 'text-center' : 'text-left'} ${className}`}>
    {eyebrow && (
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={viewportOnce}
        transition={{ duration: 0.4 }}
        className={`inline-flex items-center mb-4 md:mb-5 text-[10px] md:text-[11px] uppercase tracking-[0.1em] ${
          dark ? 'text-brand-glow' : 'text-brand-bright'
        }`}
      >
        {eyebrow}
      </motion.div>
    )}

    <motion.h2
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={viewportOnce}
      transition={{ duration: 0.55, ease: [0.22, 1, 0.36, 1], delay: eyebrow ? 0.08 : 0 }}
      className={`text-2xl md:text-3xl lg:text-4xl font-semibold tracking-tight mb-4 md:mb-5 leading-[1.1] ${
        dark ? 'text-white' : 'text-slate-900'
      }`}
    >
      {title}
    </motion.h2>

    {subtitle && (
      <motion.p
        initial={{ opacity: 0, y: 16 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={viewportOnce}
        transition={{ duration: 0.5, delay: (eyebrow ? 0.08 : 0) + 0.1 }}
        className={`text-sm md:text-[15px] leading-relaxed ${centered ? 'max-w-2xl mx-auto' : 'max-w-xl'} ${
          dark ? 'text-white/60' : 'text-slate-600'
        }`}
      >
        {subtitle}
      </motion.p>
    )}
  </div>
);

