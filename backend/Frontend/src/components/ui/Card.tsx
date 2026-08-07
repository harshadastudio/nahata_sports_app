/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { ReactNode } from 'react';
import { motion } from 'motion/react';

/**
 * Card component with 4 visual tiers for different use cases.
 * 
 * @component
 * @example
 * // Interactive card (booking wizard, selectable items)
 * <Card tier="interactive"selected={isSelected} onClick={handleSelect}>
 * <h3>Option 1</h3>
 * </Card>
 * 
 * @example
 * // Content card (programs, events)
 * <Card tier="content">
 * <img src="..."/>
 * <h3>Cricket Program</h3>
 * </Card>
 * 
 * @example
 * // Stat card (dashboard metrics)
 * <Card tier="stat"accentColor="#6C52E8">
 * <p className="text-xs text-slate-500">Total Users</p>
 * <p className="text-4xl">1,234</p>
 * </Card>
 * 
 * @example
 * // Glass card (overlays, modals)
 * <Card tier="glass">
 * <p>Floating content</p>
 * </Card>
 */
interface CardProps {
 /** Visual tier: 'interactive' (selectable), 'content' (programs), 'stat' (metrics), 'glass' (overlays) */
 tier: 'interactive' | 'content' | 'stat' | 'glass';
 /** Card content */
 children: ReactNode;
 /** Additional CSS classes */
 className?: string;
 /** Click handler (makes card interactive) */
 onClick?: () => void;
 /** Selected state (for interactive tier) */
 selected?: boolean;
 /** Accent color for left stripe (stat tier only) */
 accentColor?: string;
 /** Padding size: 'none', 'sm' (16px), 'md' (24px), 'lg' (32px) */
 padding?: 'none' | 'sm' | 'md' | 'lg';
}

const paddingMap = {
 none: '',
 sm: 'p-4',
 md: 'p-6',
 lg: 'p-8',
};

export const Card = ({
 tier,
 children,
 className = '',
 onClick,
 selected = false,
 accentColor = '#6C52E8',
 padding,
}: CardProps) => {

 const defaultPadding = padding
 ? paddingMap[padding]
 : tier === 'stat' ? 'p-6 pl-8' : 'p-6';

 const tierStyles: Record<string, string> = {
 interactive: [
 'bg-white border-[1.5px] rounded-[20px] cursor-pointer transition-all duration-300',
 selected
 ? 'border-transparent shadow-[0_0_0_2px_#6C52E8,0_8px_32px_rgba(108,82,232,0.25)] gradient-brand text-white'
 : 'border-[#EAE8F7] hover:border-brand-bright hover:-translate-y-[3px] hover:shadow-[0_8px_32px_rgba(108,82,232,0.12)]',
 ].join(' '),

 content: [
 'bg-white rounded-3xl border border-border-muted',
 'shadow-[0_1px_3px_rgba(14,11,31,0.05),0_8px_24px_rgba(14,11,31,0.04)]',
 'hover:shadow-[0_8px_24px_rgba(14,11,31,0.1),0_24px_48px_rgba(14,11,31,0.08)]',
 'hover:scale-[1.01] transition-all duration-350',
 ].join(' '),

 stat: [
 'bg-white rounded-2xl border border-border-muted relative overflow-hidden',
 'shadow-[0_1px_3px_rgba(14,11,31,0.05),0_4px_12px_rgba(14,11,31,0.04)]',
 'hover:shadow-[0_4px_20px_rgba(14,11,31,0.08)] hover:-translate-y-0.5 transition-all duration-300',
 ].join(' '),

 glass: 'glass-card rounded-3xl',
 };

 const isInteractive = !!onClick;

 const inner = (
 <>
 {/* Accent stripe for stat */}
 {tier === 'stat' && (
 <div
 className="absolute left-0 top-0 bottom-0 w-1 rounded-l-2xl"
 style={{ background: accentColor }}
 aria-hidden="true"
 />
 )}
 {/* Corner glow for stat */}
 {tier === 'stat' && (
 <div
 className="absolute top-0 right-0 w-28 h-28 opacity-8 pointer-events-none rounded-tr-2xl"
 style={{ background: `radial-gradient(circle at top right, ${accentColor}, transparent 70%)` }}
 aria-hidden="true"
 />
 )}
 {/* Selected checkmark for interactive */}
 {tier === 'interactive' && selected && (
 <div className="absolute top-3 right-3 w-6 h-6 bg-white/20 rounded-full flex items-center justify-center">
 <svg className="w-3.5 h-3.5 text-white"fill="none"viewBox="0 0 24 24"stroke="currentColor"strokeWidth={3}>
 <path strokeLinecap="round"strokeLinejoin="round"d="M5 13l4 4L19 7"/>
 </svg>
 </div>
 )}
 <div className={defaultPadding}>{children}</div>
 </>
 );

 if (isInteractive) {
 return (
 <motion.div
 onClick={onClick}
 whileHover={selected ? {} : { y: -3 }}
 whileTap={{ scale: 0.98 }}
 transition={{ type: 'spring', stiffness: 400, damping: 25 }}
 className={`relative ${tierStyles[tier]} ${className}`}
 >
 {inner}
 </motion.div>
 );
 }

 return (
 <div className={`relative ${tierStyles[tier]} ${className}`}>
 {inner}
 </div>
 );
};

