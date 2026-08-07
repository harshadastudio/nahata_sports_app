import React from 'react';
import { LucideIcon } from 'lucide-react';
import { cn } from '@/src/lib/utils';

interface EmptyStateProps {
 icon?: LucideIcon;
 title: string;
 description?: string;
 action?: React.ReactNode;
 className?: string;
}

export const EmptyState: React.FC<EmptyStateProps> = ({
 icon: Icon,
 title,
 description,
 action,
 className
}) => {
 return (
 <div className={cn("flex flex-col items-center justify-center py-20 text-gray-500", className)}>
 {Icon && <Icon size={48} className="mb-4 opacity-50"/>}
 <p className="text-lg text-gray-900">{title}</p>
 {description && <p className="text-sm text-gray-600 mt-1">{description}</p>}
 {action && <div className="mt-4">{action}</div>}
 </div>
 );
};

