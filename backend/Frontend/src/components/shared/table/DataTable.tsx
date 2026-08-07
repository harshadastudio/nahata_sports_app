import { useState, useMemo } from 'react';
import { Column } from '@/src/types';
import { TableHeader } from './TableHeader';
import { TableRow } from './TableRow';
import { Pagination } from './Pagination';
import { Search } from 'lucide-react';

interface DataTableProps<T extends { id: string | number }> {
 columns: Column<T>[];
 data: T[];
 loading?: boolean;
 totalRecords?: number;
 pageSize?: number;
 onPageChange?: (page: number) => void;
 currentPage?: number;
 onRowClick?: (row: T) => void;
 title?: string;
 actions?: React.ReactNode;
 searchPlaceholder?: string;
}

export function DataTable<T extends { id: string | number }>({ 
 columns, 
 data, 
 loading,
 pageSize = 10,
 onPageChange,
 currentPage = 1,
 totalRecords,
 onRowClick,
 title,
 actions,
 searchPlaceholder ="Search..."
}: DataTableProps<T>) {
 const [selectedIds, setSelectedIds] = useState<Set<string | number>>(new Set());
 const [searchQuery, setSearchQuery] = useState("");

 const filteredData = useMemo(() => {
 if (!searchQuery) return data;
 const query = searchQuery.toLowerCase();
 return data.filter(row => 
 Object.values(row).some(val => 
 String(val).toLowerCase().includes(query)
 )
 );
 }, [data, searchQuery]);

 // Handle local pagination if no external handler is provided
 const paginatedData = useMemo(() => {
 if (onPageChange) return filteredData;
 const start = (currentPage - 1) * pageSize;
 return filteredData.slice(start, start + pageSize);
 }, [filteredData, currentPage, pageSize, onPageChange]);

 const totalCount = totalRecords !== undefined ? totalRecords : filteredData.length;
 const totalPages = Math.ceil(totalCount / pageSize);

 const handleSelectAll = (checked: boolean) => {
 if (checked) {
 setSelectedIds(new Set(paginatedData.map(r => r.id)));
 } else {
 setSelectedIds(new Set());
 }
 };

 const handleSelectRow = (id: string | number, checked: boolean) => {
 const next = new Set(selectedIds);
 if (checked) next.add(id);
 else next.delete(id);
 setSelectedIds(next);
 };

 return (
 <div className="flex flex-col h-full bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
 {/* Table Toolbar */}
 <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between p-6 gap-4 border-b border-gray-200">
 <div>
 {title && <h2 className="text-xl text-gray-900 tracking-tight">{title}</h2>}
 <p className="text-[10px] text-gray-600 uppercase tracking-wider">Total: {filteredData.length} records</p>
 </div>
 
 <div className="flex items-center gap-3 w-full sm:w-auto">
 <div className="relative flex-1 sm:w-64">
 <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-4 h-4"/>
 <input 
 type="text"
 placeholder={searchPlaceholder}
 value={searchQuery}
 onChange={(e) => setSearchQuery(e.target.value)}
 className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-transparent rounded-full text-xs focus:outline-none focus:ring-2 focus:ring-blue-600/10 focus:bg-white focus:border-blue-600 transition-all shadow-inner"
 />
 </div>
 {actions}
 </div>
 </div>

 {/* Action Bar when selection exists */}
 {selectedIds.size > 0 && (
 <div className="flex items-center justify-between px-6 py-2.5 bg-blue-600 text-white animate-in slide-in-from-top-4">
 <span className="text-xs uppercase tracking-widest">{selectedIds.size} Selected</span>
 <div className="flex items-center gap-6">
 <button className="text-[10px] uppercase tracking-widest hover:text-blue-200 transition-colors">EXPORT CSV</button>
 <button className="text-[10px] uppercase tracking-widest hover:text-red-300 transition-colors">DELETE PERMANENTLY</button>
 </div>
 </div>
 )}

 {/* Table Content */}
 <div className="flex-1 overflow-auto relative">
 <table className="w-full border-collapse">
 <TableHeader<T>
 columns={columns} 
 onSelectAll={handleSelectAll}
 isAllSelected={paginatedData.length > 0 && selectedIds.size === paginatedData.length}
 />
 <tbody>
 {loading ? (
 Array.from({ length: 5 }).map((_, i) => (
 <tr key={i} className="animate-pulse border-b border-slate-100">
 {columns.map((_, j) => (
 <td key={j} className="px-4 py-3">
 <div className="h-4 bg-slate-100 rounded-md w-full"/>
 </td>
 ))}
 </tr>
 ))
 ) : paginatedData.length > 0 ? (
 paginatedData.map((row, index) => (
 <TableRow<T>
 key={String(row.id)}
 row={row}
 columns={columns}
 index={(currentPage - 1) * pageSize + index}
 isSelected={selectedIds.has(row.id)}
 onSelect={(checked) => handleSelectRow(row.id, checked)}
 onRowClick={onRowClick}
 />
 ))
 ) : (
 <tr>
 <td colSpan={columns.length} className="px-4 py-20 text-center">
 <div className="flex flex-col items-center gap-2 text-slate-400">
 <Search size={40} className="opacity-20"/>
 <p className="">No results found</p>
 <p className="text-xs">Try adjusting your search or filters</p>
 </div>
 </td>
 </tr>
 )}
 </tbody>
 </table>
 </div>

 {/* Pagination */}
 <Pagination 
 currentPage={currentPage}
 totalPages={totalPages}
 onPageChange={onPageChange || (() => {})}
 />
 </div>
 );
}

