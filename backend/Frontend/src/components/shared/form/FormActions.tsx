import React from 'react';
import { Save, RotateCcw, X } from 'lucide-react';
import { cn } from '@/src/lib/utils';

interface FormActionsProps {
 onSave?: () => void;
 onCancel?: () => void;
 onReset?: () => void;
 saveText?: string;
 cancelText?: string;
 resetText?: string;
 showReset?: boolean;
 disabled?: boolean;
 className?: string;
}

export const FormActions: React.FC<FormActionsProps> = ({
 onSave,
 onCancel,
 onReset,
 saveText = 'Save',
 cancelText = 'Cancel',
 resetText = 'Reset',
 showReset = false,
 disabled = false,
 className
}) => {
 return (
 <div className={cn('p-8 bg-slate-50 border-t border-gray-200 flex items-center gap-4 shrink-0', className)}>
 {showReset && (
 <button
 type="button"
 onClick={onReset}
 className="flex-1 bg-white border border-gray-300 text-gray-600 px-6 py-4 rounded-3xl text-[11px] uppercase tracking-[0.2em] transition-all hover:bg-slate-50 flex items-center justify-center gap-2"
 >
 <RotateCcw size={18} />
 {resetText}
 </button>
 )}
 <button
 type="submit"
 onClick={onSave}
 disabled={disabled}
 className="flex-1 bg-blue-600 hover:bg-blue-700 text-white px-6 py-4 rounded-3xl text-[11px] uppercase tracking-[0.2em] shadow-xl shadow-blue-600/20 transition-all flex items-center justify-center gap-2 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
 >
 <Save size={18} />
 {saveText}
 </button>
 <button
 type="button"
 onClick={onCancel}
 className="flex-1 bg-white border border-gray-300 text-gray-600 px-6 py-4 rounded-3xl text-[11px] uppercase tracking-[0.2em] transition-all hover:bg-slate-50 flex items-center justify-center gap-2"
 >
 <X size={18} />
 {cancelText}
 </button>
 </div>
 );
};

