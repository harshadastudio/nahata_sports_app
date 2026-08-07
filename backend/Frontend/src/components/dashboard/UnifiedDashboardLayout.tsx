import React, { useState, useEffect } from 'react';
import { Menu, X } from 'lucide-react';
import { cn } from '../../lib/utils';

interface UnifiedDashboardLayoutProps {
 children: React.ReactNode;
 sidebar: React.ReactNode;
 navbar: React.ReactNode;
}

/**
 * UnifiedDashboardLayout - Main layout component for all operational roles
 * 
 * Provides a responsive layout with:
 * - Sidebar for navigation (role-based menu)
 * - Navbar at the top (user info, notifications)
 * - Content area for page-specific content
 * 
 * Responsive behavior:
 * - Mobile (< 768px): Sidebar hidden by default, overlay when opened
 * - Tablet (768px - 1023px): Condensed sidebar
 * - Desktop (>= 1024px): Full-width sidebar
 * 
 * Validates: Requirements 2.1, 2.2, 2.6, 2.7, 14.1, 14.2, 14.3
 */
export const UnifiedDashboardLayout: React.FC<UnifiedDashboardLayoutProps> = ({
 children,
 sidebar,
 navbar,
}) => {
 const [sidebarOpen, setSidebarOpen] = useState(false);
 const [isMobile, setIsMobile] = useState(false);

 // Detect screen size and update mobile state
 useEffect(() => {
 const checkMobile = () => {
 const mobile = window.innerWidth < 768;
 setIsMobile(mobile);
 // Auto-close sidebar on mobile
 if (mobile) {
 setSidebarOpen(false);
 }
 };

 // Initial check
 checkMobile();

 // Listen for resize events
 window.addEventListener('resize', checkMobile);
 return () => window.removeEventListener('resize', checkMobile);
 }, []);

 // Close sidebar when clicking outside on mobile
 useEffect(() => {
 if (!isMobile || !sidebarOpen) return;

 const handleClickOutside = (e: MouseEvent) => {
 const target = e.target as HTMLElement;
 // Check if click is outside sidebar
 if (!target.closest('[data-sidebar]') && !target.closest('[data-sidebar-toggle]')) {
 setSidebarOpen(false);
 }
 };

 document.addEventListener('mousedown', handleClickOutside);
 return () => document.removeEventListener('mousedown', handleClickOutside);
 }, [isMobile, sidebarOpen]);

 const toggleSidebar = () => {
 setSidebarOpen(!sidebarOpen);
 };

 return (
 <div className="flex bg-bg-main min-h-screen font-sans selection:bg-brand-secondary selection:text-brand-primary">
 {/* Overlay for mobile when sidebar is open */}
 {isMobile && sidebarOpen && (
 <div
 className="fixed inset-0 bg-black/50 z-40 transition-opacity"
 onClick={() => setSidebarOpen(false)}
 aria-hidden="true"
 />
 )}

 {/* Sidebar */}
 <div
 data-sidebar
 className={cn(
 'fixed lg:sticky top-0 h-screen z-50 transition-transform duration-300 ease-in-out',
 // Mobile: slide in from left
 isMobile && !sidebarOpen && '-translate-x-full',
 isMobile && sidebarOpen && 'translate-x-0',
 // Desktop: always visible
 !isMobile && 'translate-x-0'
 )}
 >
 {/* Close button for mobile */}
 {isMobile && sidebarOpen && (
 <button
 onClick={() => setSidebarOpen(false)}
 className="absolute top-4 right-4 z-10 p-2 bg-white rounded-lg shadow-lg hover:bg-slate-50 transition-colors"
 aria-label="Close sidebar"
 >
 <X size={20} className="text-slate-600"/>
 </button>
 )}
 {sidebar}
 </div>

 {/* Main content area */}
 <div className="flex-1 flex flex-col h-screen overflow-hidden">
 {/* Navbar with mobile menu toggle */}
 <div className="relative">
 {/* Mobile menu toggle button */}
 {isMobile && (
 <button
 data-sidebar-toggle
 onClick={toggleSidebar}
 className="absolute left-4 top-1/2 -translate-y-1/2 z-10 p-2 bg-white rounded-lg shadow-sm hover:bg-slate-50 transition-colors border border-slate-200"
 aria-label="Toggle sidebar"
 >
 <Menu size={20} className="text-slate-600"/>
 </button>
 )}
 {/* Navbar component */}
 <div className={cn(isMobile && 'pl-14')}>
 {navbar}
 </div>
 </div>

 {/* Content area */}
 <main className="flex-1 overflow-y-auto overflow-x-hidden scroll-smooth">
 <div className="p-4 sm:p-6 md:p-8 max-w-[1500px] mx-auto">
 {children}
 </div>
 </main>
 </div>
 </div>
 );
};

export default UnifiedDashboardLayout;

