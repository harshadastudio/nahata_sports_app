import React from 'react';
import { cn } from '@/src/lib/utils';
import { ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight } from 'lucide-react';

interface PaginationProps {
 currentPage: number;
 totalPages: number;
 onPageChange: (page: number) => void;
 className?: string;
}

export const Pagination: React.FC<PaginationProps> = ({ 
 currentPage, 
 totalPages, 
 onPageChange,
 className
}) => {
 if (totalPages <= 1) return null;

 const pages = Array.from({ length: totalPages }, (_, i) => i + 1);
 
 // Show only a few nearby pages
 const visiblePages = pages.filter(p => 
 p === 1 || 
 p === totalPages || 
 (p >= currentPage - 1 && p <= currentPage + 1)
 );

 return (
 <div className={cn("flex items-center justify-between py-3 px-6 bg-[#fcfcfd] border-t border-gray-200", className)}>
 <div className="text-xs text-gray-600">
 Page {currentPage} of {totalPages}
 </div>
 <div className="flex items-center gap-1">
 <button
 onClick={() => onPageChange(1)}
 disabled={currentPage === 1}
 className="p-1.5 hover:bg-slate-100 rounded-md disabled:opacity-30 disabled:cursor-not-allowed transition-colors text-gray-600"
 >
 <ChevronsLeft size={14} />
 </button>
 <button
 onClick={() => onPageChange(currentPage - 1)}
 disabled={currentPage === 1}
 className="p-1.5 hover:bg-slate-100 rounded-md disabled:opacity-30 disabled:cursor-not-allowed transition-colors text-gray-600"
 >
 <ChevronLeft size={14} />
 </button>

 <div className="flex items-center gap-1 mx-2">
 {visiblePages.map((page, index) => (
 <React.Fragment key={page}>
 {index > 0 && visiblePages[index - 1] !== page - 1 && (
 <span className="px-1 text-slate-300">...</span>
 )}
 <button
 onClick={() => onPageChange(page)}
 className={cn(
"w-7 h-7 flex items-center justify-center text-[10px] rounded-md transition-all",
 currentPage === page 
 ?"bg-blue-600 text-white shadow-sm"
 :"hover:bg-slate-100 text-gray-600"
 )}
 >
 {page}
 </button>
 </React.Fragment>
 ))}
 </div>

 <button
 onClick={() => onPageChange(currentPage + 1)}
 disabled={currentPage === totalPages}
 className="p-1.5 hover:bg-slate-100 rounded-md disabled:opacity-30 disabled:cursor-not-allowed transition-colors text-gray-600"
 >
 <ChevronRight size={14} />
 </button>
 <button
 onClick={() => onPageChange(totalPages)}
 disabled={currentPage === totalPages}
 className="p-1.5 hover:bg-slate-100 rounded-md disabled:opacity-30 disabled:cursor-not-allowed transition-colors text-gray-600"
 >
 <ChevronsRight size={14} />
 </button>
 </div>
 </div>
 );
};

