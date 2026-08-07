/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { ReactNode } from 'react';

/**
 * Badge component for status indicators, labels, and tags.
 * 
 * @component
 * @example
 * // Status badge
 * <Badge variant="success">Confirmed</Badge>
 * <Badge variant="warning">Pending</Badge>
 * <Badge variant="error">Cancelled</Badge>
 * 
 * @example
 * // Sport badge with custom color
 * <Badge variant="sport"sportColor="#059669">Cricket</Badge>
 * 
 * @example
 * // Role badge (auto-colored based on role name)
 * <Badge variant="role">EMPLOYEE</Badge>
 * <Badge variant="role">COACH</Badge>
 * 
 * @example
 * // Badge with status dot
 * <Badge variant="success"dot>Active</Badge>
 * 
 * @example
 * // Different sizes
 * <Badge size="sm">Small</Badge>
 * <Badge size="md">Medium</Badge>
 * <Badge size="lg">Large</Badge>
 */
interface BadgeProps {
 /** Badge content */
 children: ReactNode;
 /** Visual variant: 'default', 'success', 'warning', 'error', 'info', 'sport', 'pill', 'role' */
 variant?: 'default' | 'success' | 'warning' | 'error' | 'info' | 'sport' | 'pill' | 'role';
 /** Size: 'sm' (10px), 'md' (11px), 'lg' (12px) */
 size?: 'sm' | 'md' | 'lg';
 /** Additional CSS classes */
 className?: string;
 /** Custom color for sport variant (hex or CSS color) */
 sportColor?: string;
 /** Show status dot before text */
 dot?: boolean;
}

const roleColors: Record<string, string> = {
 USER: 'bg-blue-50 text-blue-700 border-blue-200',
 EMPLOYEE: 'bg-emerald-50 text-emerald-700 border-emerald-200',
 COACH: 'bg-amber-50 text-amber-700 border-amber-200',
 SECURITY: 'bg-red-50 text-red-700 border-red-200',
};

export const Badge = ({
 children,
 variant = 'default',
 size = 'md',
 className = '',
 sportColor = '#6C52E8',
 dot = false,
}: BadgeProps) => {

 const sizes = {
 sm: 'px-2 py-0.5 text-[10px] gap-1',
 md: 'px-2.5 py-1 text-[11px] gap-1.5',
 lg: 'px-3 py-1.5 text-xs gap-2',
 };

 const variants: Record<string, string> = {
 default: 'bg-slate-100 text-slate-600 border border-slate-200',
 success: 'bg-emerald-50 text-emerald-700 border border-emerald-200',
 warning: 'bg-amber-50 text-amber-700 border border-amber-200',
 error: 'bg-red-50 text-red-700 border border-red-200',
 info: 'bg-blue-50 text-blue-700 border border-blue-200',
 sport: 'text-white border-0',
 pill: 'bg-brand-bright/10 text-brand-bright border border-brand-bright/20',
 role: '',
 };

 const dotColors: Record<string, string> = {
 default: 'bg-slate-400',
 success: 'bg-emerald-500',
 warning: 'bg-amber-500',
 error: 'bg-red-500',
 info: 'bg-blue-500',
 sport: 'bg-white',
 pill: 'bg-brand-bright',
 role: 'bg-current',
 };

 const childStr = typeof children === 'string' ? children.toUpperCase() : '';
 const isRole = variant === 'role';
 const roleClass = isRole ? (roleColors[childStr] ?? roleColors.USER) : '';

 return (
 <span
 className={`
 inline-flex items-center justify-center uppercase
 tracking-wider rounded-full transition-all
 ${sizes[size]}
 ${isRole ? `${roleClass} border` : variants[variant]}
 ${className}
 `}
 style={variant === 'sport' ? { background: sportColor } : undefined}
 >
 {dot && (
 <span
 className={`rounded-full shrink-0 ${size === 'lg' ? 'w-1.5 h-1.5' : 'w-1 h-1'} ${dotColors[variant]}`}
 />
 )}
 {children}
 </span>
 );
};

