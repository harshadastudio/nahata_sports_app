/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { ReactNode, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { X } from 'lucide-react';

/**
 * Modal component with backdrop blur, animations, and accessibility features.
 * Automatically converts to bottom sheet on mobile for better UX.
 * 
 * @component
 * @example
 * // Basic modal
 * const [isOpen, setIsOpen] = useState(false);
 * 
 * <Modal
 * isOpen={isOpen}
 * onClose={() => setIsOpen(false)}
 * title="Edit User"
 * >
 * <UserForm />
 * </Modal>
 * 
 * @example
 * // Large modal with subtitle
 * <Modal
 * isOpen={isOpen}
 * onClose={handleClose}
 * title="Booking Details"
 * subtitle="Review your booking information"
 * size="lg"
 * >
 * <BookingDetails />
 * </Modal>
 * 
 * @example
 * // Modal without close button (force user action)
 * <Modal
 * isOpen={isOpen}
 * onClose={handleClose}
 * title="Confirm Action"
 * showCloseButton={false}
 * closeOnBackdrop={false}
 * closeOnEscape={false}
 * >
 * <ConfirmationDialog />
 * </Modal>
 */
interface ModalProps {
 /** Controls modal visibility */
 isOpen: boolean;
 /** Called when modal should close */
 onClose: () => void;
 /** Modal content */
 children: ReactNode;
 /** Modal title (displayed in header) */
 title?: string;
 /** Subtitle text below title */
 subtitle?: string;
 /** Modal width: 'sm' (448px), 'md' (512px), 'lg' (672px), 'xl' (896px), 'full' (95vw) */
 size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
 /** Allow closing by clicking backdrop (default: true) */
 closeOnBackdrop?: boolean;
 /** Allow closing with Escape key (default: true) */
 closeOnEscape?: boolean;
 /** Show X close button in header (default: true) */
 showCloseButton?: boolean;
 /** Shows as a bottom-sheet on mobile (default: true) */
 mobileBottomSheet?: boolean;
}

const sizes = {
 sm: 'max-w-md',
 md: 'max-w-lg',
 lg: 'max-w-2xl',
 xl: 'max-w-4xl',
 full: 'max-w-[95vw]',
};

export const Modal = ({
 isOpen,
 onClose,
 children,
 title,
 subtitle,
 size = 'md',
 closeOnBackdrop = true,
 closeOnEscape = true,
 showCloseButton = true,
 mobileBottomSheet = true,
}: ModalProps) => {
 const modalRef = useRef<HTMLDivElement>(null);

 // Escape key
 useEffect(() => {
 if (!isOpen || !closeOnEscape) return;
 const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
 document.addEventListener('keydown', handler);
 return () => document.removeEventListener('keydown', handler);
 }, [isOpen, closeOnEscape, onClose]);

 // Focus trap
 useEffect(() => {
 if (!isOpen || !modalRef.current) return;
 const focusable = modalRef.current.querySelectorAll<HTMLElement>(
 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
 );
 const first = focusable[0];
 const last = focusable[focusable.length - 1];
 const handleTab = (e: KeyboardEvent) => {
 if (e.key !== 'Tab') return;
 if (e.shiftKey ? document.activeElement === first : document.activeElement === last) {
 e.preventDefault();
 (e.shiftKey ? last : first)?.focus();
 }
 };
 document.addEventListener('keydown', handleTab);
 first?.focus();
 return () => document.removeEventListener('keydown', handleTab);
 }, [isOpen]);

 // Body scroll lock
 useEffect(() => {
 document.body.style.overflow = isOpen ? 'hidden' : '';
 return () => { document.body.style.overflow = ''; };
 }, [isOpen]);

 return (
 <AnimatePresence>
 {isOpen && (
 <>
 {/* Backdrop */}
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 transition={{ duration: 0.2 }}
 onClick={closeOnBackdrop ? onClose : undefined}
 className="fixed inset-0 z-50 bg-black/55 backdrop-blur-sm"
 aria-hidden="true"
 />

 {/* Modal container — desktop centered, mobile bottom-sheet */}
 <div
 className={`fixed inset-0 z-50 flex pointer-events-none ${
 mobileBottomSheet
 ? 'items-end sm:items-center justify-center'
 : 'items-center justify-center p-4'
 }`}
 >
 <motion.div
 ref={modalRef}
 initial={mobileBottomSheet
 ? { opacity: 0, y: 60 }
 : { opacity: 0, scale: 0.96, y: 16 }}
 animate={mobileBottomSheet
 ? { opacity: 1, y: 0 }
 : { opacity: 1, scale: 1, y: 0 }}
 exit={mobileBottomSheet
 ? { opacity: 0, y: 60 }
 : { opacity: 0, scale: 0.96, y: 16 }}
 transition={{ type: 'spring', stiffness: 340, damping: 30 }}
 className={`
 relative w-full ${sizes[size]} bg-white pointer-events-auto
 shadow-[0_24px_64px_rgba(14,11,31,0.18),0_4px_16px_rgba(14,11,31,0.08)]
 max-h-[92vh] overflow-hidden flex flex-col
 ${mobileBottomSheet
 ? 'rounded-t-[28px] sm:rounded-3xl sm:mx-4 sm:mb-0'
 : 'rounded-3xl mx-4'}
 `}
 role="dialog"
 aria-modal="true"
 aria-labelledby={title ? 'modal-title' : undefined}
 >
 {/* Mobile drag handle */}
 {mobileBottomSheet && (
 <div className="flex justify-center pt-3 pb-1 sm:hidden shrink-0">
 <div className="w-10 h-1 rounded-full bg-slate-200"/>
 </div>
 )}

 {/* Header */}
 {(title || showCloseButton) && (
 <div className="flex items-start justify-between px-7 py-5 border-b border-border-muted shrink-0">
 <div>
 {title && (
 <h2 id="modal-title"className="text-xl text-text-primary leading-tight">
 {title}
 </h2>
 )}
 {subtitle && (
 <p className="text-sm text-text-muted mt-1">{subtitle}</p>
 )}
 </div>
 {showCloseButton && (
 <button
 onClick={onClose}
 className="ml-4 p-2 rounded-xl text-text-muted hover:text-text-primary hover:bg-bg-main transition-all shrink-0 -mt-0.5"
 aria-label="Close"
 >
 <X size={20} />
 </button>
 )}
 </div>
 )}

 {/* Scrollable content */}
 <div className="flex-1 overflow-y-auto overscroll-contain px-7 py-6">
 {children}
 </div>
 </motion.div>
 </div>
 </>
 )}
 </AnimatePresence>
 );
};

