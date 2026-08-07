import React from 'react';
import { cn } from '@/src/lib/utils';

interface SkeletonProps {
 className?: string;
 rows?: number;
 variant?: 'default' | 'sport-card' | 'stat-card' | 'table-row';
}

export const Skeleton: React.FC<SkeletonProps> = ({ className, rows = 1, variant = 'default' }) => {
 const getVariantStyles = () => {
 switch (variant) {
 case 'sport-card':
 return 'aspect-[3/4] rounded-2xl';
 case 'stat-card':
 return 'h-32 rounded-2xl';
 case 'table-row':
 return 'h-12 rounded-lg';
 default:
 return 'h-4 rounded-md';
 }
 };

 return (
 <>
 {Array.from({ length: rows }).map((_, i) => (
 <div 
 key={i}
 className={cn(
"relative overflow-hidden bg-slate-200",
 getVariantStyles(),
 className
 )}
 >
 {/* Shimmer effect */}
 <div 
 className="absolute inset-0 -translate-x-full animate-[shimmer_2s_infinite]"
 style={{
 background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)'
 }}
 />
 </div>
 ))}
 </>
 );
};

interface SkeletonTableProps {
 columns: number;
 rows?: number;
}

export const SkeletonTable: React.FC<SkeletonTableProps> = ({ columns, rows = 5 }) => {
 return (
 <>
 {Array.from({ length: rows }).map((_, i) => (
 <tr key={i} className="border-b border-slate-100">
 {Array.from({ length: columns }).map((_, j) => (
 <td key={j} className="px-4 py-4">
 <div className="relative overflow-hidden h-4 bg-slate-200 rounded-md w-full">
 {/* Shimmer effect */}
 <div 
 className="absolute inset-0 -translate-x-full animate-[shimmer_2s_infinite]"
 style={{
 background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)'
 }}
 />
 </div>
 </td>
 ))}
 </tr>
 ))}
 </>
 );
};

// Sport Card Skeleton
export const SkeletonSportCard: React.FC = () => (
 <div className="relative aspect-[3/4] rounded-2xl overflow-hidden bg-slate-200">
 <div 
 className="absolute inset-0 -translate-x-full animate-[shimmer_2s_infinite]"
 style={{
 background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)'
 }}
 />
 </div>
);

// Stat Card Skeleton
export const SkeletonStatCard: React.FC = () => (
 <div className="relative h-32 rounded-2xl overflow-hidden bg-slate-200 p-6">
 <div className="space-y-3">
 <div className="h-3 w-20 bg-slate-300 rounded"/>
 <div className="h-8 w-24 bg-slate-300 rounded"/>
 <div className="h-2 w-16 bg-slate-300 rounded"/>
 </div>
 <div 
 className="absolute inset-0 -translate-x-full animate-[shimmer_2s_infinite]"
 style={{
 background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)'
 }}
 />
 </div>
);

