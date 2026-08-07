/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

interface SkeletonProps {
 className?: string;
 rounded?: 'sm' | 'md' | 'lg' | 'full';
 animate?: boolean;
}

/**
 * Skeleton — premium shimmer loader.
 * Usage: <Skeleton className="h-4 w-48"/>
 */
export const Skeleton = ({ className = '', rounded = 'md', animate = true }: SkeletonProps) => {
 const roundedMap = {
 sm: 'rounded',
 md: 'rounded-lg',
 lg: 'rounded-2xl',
 full: 'rounded-full',
 };

 return (
 <div
 className={`
 relative overflow-hidden bg-slate-100
 ${roundedMap[rounded]}
 ${animate ? 'after:absolute after:inset-0 after:bg-gradient-to-r after:from-transparent after:via-white/60 after:to-transparent after:-translate-x-full after:animate-shimmer' : ''}
 ${className}
 `}
 aria-busy="true"
 aria-label="Loading..."
 />
 );
};

/** Pre-built skeleton for a stat card */
export const StatCardSkeleton = () => (
 <div className="bg-white rounded-2xl border border-border-muted p-6 pl-8 relative overflow-hidden">
 <div className="absolute left-0 top-0 bottom-0 w-1 bg-slate-100 rounded-l-2xl"/>
 <Skeleton className="h-3 w-20 mb-4"/>
 <Skeleton className="h-8 w-28 mb-2"/>
 <Skeleton className="h-3 w-16"/>
 </div>
);

/** Pre-built skeleton for a booking row */
export const BookingRowSkeleton = () => (
 <div className="flex items-center gap-4 py-4 px-2">
 <Skeleton className="w-10 h-10 shrink-0"rounded="full"/>
 <div className="flex-1 space-y-2">
 <Skeleton className="h-4 w-40"/>
 <Skeleton className="h-3 w-28"/>
 </div>
 <Skeleton className="h-6 w-20"rounded="full"/>
 <Skeleton className="h-5 w-16"/>
 </div>
);

/** Pre-built skeleton for a sport/program card */
export const SportCardSkeleton = () => (
 <div className="bg-white rounded-3xl border border-border-muted overflow-hidden">
 <Skeleton className="aspect-[3/4] w-full"rounded="sm"/>
 <div className="p-4 space-y-2">
 <Skeleton className="h-4 w-3/4"/>
 <Skeleton className="h-3 w-1/2"/>
 </div>
 </div>
);

