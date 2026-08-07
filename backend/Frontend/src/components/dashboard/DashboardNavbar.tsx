import React from 'react';
import { LogOut, User } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import NotificationBell from '../NotificationBell';
import { cn } from '../../lib/utils';

interface DashboardNavbarProps {
 pageTitle?: string;
}

/**
 * DashboardNavbar - Top navigation bar for the unified dashboard
 * 
 * Features:
 * - Page title display
 * - Notification bell integration
 * - User avatar with initials
 * - User name and role badge
 * - Logout button
 * 
 * Note: Hamburger menu button is handled by UnifiedDashboardLayout
 * 
 * Validates: Requirements 2.2, 15.4
 */
export const DashboardNavbar: React.FC<DashboardNavbarProps> = ({ pageTitle = 'Dashboard' }) => {
 const { user, logout } = useAuth();

 // Generate initials from user name
 const getInitials = (name: string): string => {
 return name
 .split(' ')
 .map(part => part[0])
 .join('')
 .toUpperCase()
 .slice(0, 2);
 };

 // Get role badge color based on role (upgraded with premium colors)
 const getRoleBadgeColor = (role: string): string => {
 switch (role) {
 case 'ADMIN':
 return 'bg-purple-50 text-purple-700 border-purple-200';
 case 'EMPLOYEE':
 return 'bg-blue-50 text-blue-700 border-blue-200';
 case 'COACH':
 return 'bg-amber-50 text-amber-700 border-amber-200';
 case 'SECURITY':
 return 'bg-red-50 text-red-700 border-red-200';
 case 'USER':
 return 'bg-brand-secondary text-brand-primary border-[#E8E6F5]';
 default:
 return 'bg-slate-50 text-slate-700 border-slate-200';
 }
 };

 // Format role for display
 const formatRole = (role: string): string => {
 return role.charAt(0) + role.slice(1).toLowerCase();
 };

 const handleLogout = async () => {
 try {
 await logout();
 } catch (error) {
 console.error('Logout error:', error);
 }
 };

 if (!user) {
 return null;
 }

 return (
 <nav className="bg-white border-b border-[#EAE8F7] sticky top-0 z-30 shadow-[0_1px_3px_rgba(14,11,31,0.04)]">
 <div className="px-4 sm:px-6 lg:px-8">
 <div className="flex items-center justify-between h-16">
 {/* Page Title */}
 <div className="flex-1">
 <h1 className="text-xl sm:text-2xl text-text-dark tracking-tight">
 {pageTitle}
 </h1>
 </div>

 {/* Right side: Notification Bell, User Info, Logout */}
 <div className="flex items-center gap-2 sm:gap-4">
 {/* Notification Bell */}
 <div className="flex items-center">
 <NotificationBell />
 </div>

 {/* User Info - Desktop */}
 <div className="hidden sm:flex items-center gap-3 px-4 py-2 rounded-xl bg-slate-50/80 border border-slate-200/60 hover:bg-slate-100/80 transition-all duration-200">
 {/* User Avatar with gradient background */}
 <div className="flex items-center justify-center w-10 h-10 rounded-full bg-gradient-to-br from-brand-primary to-brand-bright text-white text-sm shadow-sm">
 {getInitials(user.name)}
 </div>

 {/* User Name and Role */}
 <div className="flex flex-col gap-1">
 <span className="text-sm text-text-dark leading-none">
 {user.name}
 </span>
 <span
 className={cn(
 'text-[11px] px-2 py-1 rounded-full border inline-block w-fit leading-none',
 getRoleBadgeColor(user.role)
 )}
 >
 {formatRole(user.role)}
 </span>
 </div>
 </div>

 {/* Mobile User Avatar (shows on small screens) */}
 <div className="sm:hidden flex items-center justify-center w-10 h-10 rounded-full bg-gradient-to-br from-brand-primary to-brand-bright text-white text-sm shadow-sm">
 {getInitials(user.name)}
 </div>

 {/* Logout Button - Premium styling */}
 <button
 onClick={handleLogout}
 className="flex items-center gap-2 px-3 py-2 rounded-xl text-slate-600 hover:text-red-600 hover:bg-red-50 transition-all duration-200 border border-transparent hover:border-red-200 hover:shadow-sm"
 aria-label="Logout"
 title="Logout"
 >
 <LogOut size={18} strokeWidth={2} />
 <span className="hidden md:inline text-sm">Logout</span>
 </button>
 </div>
 </div>
 </div>
 </nav>
 );
};

export default DashboardNavbar;

