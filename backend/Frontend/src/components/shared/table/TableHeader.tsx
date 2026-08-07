import { Column } from '@/src/types';
import { cn } from '@/src/lib/utils';
import { Checkbox } from '../form/Checkbox';

interface TableHeaderProps<T> {
 columns: Column<T>[];
 onSelectAll: (checked: boolean) => void;
 isAllSelected: boolean;
 className?: string;
}

export function TableHeader<T>({ 
 columns, 
 onSelectAll, 
 isAllSelected,
 className 
}: TableHeaderProps<T>) {
 return (
 <thead className={cn("bg-slate-50 border-b border-slate-200 sticky top-0 z-10", className)}>
 <tr>
 {columns.map((column) => (
 <th 
 key={String(column.key)}
 className={cn(
"px-4 py-3 text-left",
 column.className
 )}
 >
 {column.key === 'selection' ? (
 <Checkbox 
 checked={isAllSelected}
 onChange={(e) => onSelectAll(e.target.checked)}
 />
 ) : (
 <span className="text-[11px] font-inter font-600 uppercase tracking-wider text-slate-500">
 {column.label}
 </span>
 )}
 </th>
 ))}
 </tr>
 </thead>
 );
}

