import React from 'react';
import { cn } from '@/src/lib/utils';
import { Check } from 'lucide-react';

interface CheckboxProps extends React.InputHTMLAttributes<HTMLInputElement> {
 className?: string;
}

export const Checkbox: React.FC<CheckboxProps> = ({ className, checked, ...props }) => {
 return (
 <label className={cn("relative flex items-center cursor-pointer group", className)}>
 <input 
 type="checkbox"
 className="peer sr-only"
 checked={checked}
 {...props} 
 />
 <div className={cn(
"w-4 h-4 rounded border-2 border-gray-300 transition-all duration-200 bg-white",
"peer-checked:bg-blue-600 peer-checked:border-blue-600",
"group-hover:border-blue-400 group-active:scale-95"
 )}>
 <Check 
 size={12} 
 className={cn(
"text-white absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 transition-opacity duration-200 opacity-0",
 checked &&"opacity-100"
 )} 
 />
 </div>
 </label>
 );
};

