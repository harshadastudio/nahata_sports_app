import React from 'react';

/**
 * Column definition for DataTable component
 */
export interface Column<T> {
 key: keyof T | 'action' | 'selection' | 'index';
 label: string;
 render?: (row: T, index: number) => React.ReactNode;
 className?: string;
}

