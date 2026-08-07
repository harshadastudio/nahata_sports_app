import React from 'react';
import { cn } from '@/src/lib/utils';

interface SpinnerProps {
 size?: 'sm' | 'md' | 'lg';
 className?: string;
}

export const Spinner: React.FC<SpinnerProps> = ({ size = 'md', className }) => {
 const sizeClasses = {
 sm: 'h-6 w-6 border-2',
 md: 'h-12 w-12 border-2',
 lg: 'h-16 w-16 border-4'
 };

 return (
 <div className="flex items-center justify-center h-full">
 <div 
 className={cn(
"animate-spin rounded-full border-b-blue-600",
 sizeClasses[size],
 className
 )}
 />
 </div>
 );
};

