import { Column } from '@/src/types';
import { cn } from '@/src/lib/utils';
import { Checkbox } from '../form/Checkbox';

interface TableRowProps<T extends { id: string | number }> {
 row: T;
 columns: Column<T>[];
 index: number;
 isSelected?: boolean;
 onSelect?: (checked: boolean) => void;
 className?: string;
 onRowClick?: (row: T) => void;
}

export function TableRow<T extends { id: string | number }>({ 
 row, 
 columns, 
 index,
 isSelected,
 onSelect,
 className,
 onRowClick
}: TableRowProps<T>) {
 return (
 <tr 
 onClick={() => onRowClick?.(row)}
 className={cn(
"border-b border-slate-100 hover:bg-slate-50 transition-colors",
 isSelected &&"bg-blue-50/50 hover:bg-blue-50",
 onRowClick &&"cursor-pointer",
 className
 )}
 >
 {columns.map((column) => (
 <td 
 key={String(column.key)}
 className={cn(
"px-4 py-3 text-sm font-inter text-slate-700",
 column.className
 )}
 >
 {column.key === 'selection' ? (
 <div onClick={(e) => e.stopPropagation()}>
 <Checkbox 
 checked={isSelected || false}
 onChange={(e) => onSelect?.(e.target.checked)}
 />
 </div>
 ) : column.key === 'index' ? (
 index + 1
 ) : column.render ? (
 column.render(row, index)
 ) : (
 String(row[column.key as keyof T] ?? '')
 )}
 </td>
 ))}
 </tr>
 );
}

