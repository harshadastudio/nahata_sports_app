import React, { useState } from 'react';
import { NavLink, Link, useLocation } from 'react-router-dom';
import { LogOut } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { useUserPermissions } from '../../hooks/useUserPermissions';
import { getMenuForRole, filterMenuByPermissions } from '../../config/roleMenuConfig';
import { cn } from '../../lib/utils';

interface RoleBasedSidebarProps {
 /** Controls visibility on mobile (overlay mode). Ignored on tablet/desktop. */
 isOpen?: boolean;
 /** Called when the user requests to close the sidebar (mobile overlay). */
 onClose?: () => void;
}

/**
 * RoleBasedSidebar - Role-aware navigation sidebar for the unified dashboard
 *
 * Behaviour by breakpoint:
 * - Mobile (< 768px) : Full-width (280px) overlay, shown/hidden via `isOpen`
 * - Tablet (768–1023px): Condensed (64px), icons only with tooltips
 * - Desktop (≥ 1024px) : Full sidebar (240px), icons + labels
 *
 * Menu items are:
 * 1. Sourced from `roleMenuConfig` based on the authenticated user's role
 * 2. Filtered by the permissions returned from `useUserPermissions`
 * 3. Highlighted when their path matches the current location
 *
 * Logout items (path === '/logout') call `AuthContext.logout()` instead of
 * navigating, so the auth flow is handled correctly.
 *
 * Validates: Requirements 2.1, 2.3, 2.4, 2.5, 9.6, 14.1, 14.2, 14.3
 */
export const RoleBasedSidebar: React.FC<RoleBasedSidebarProps> = ({
 isOpen = false,
 onClose,
}) => {
 const { user, logout } = useAuth();
 const { permissions, hasPermission, isLoading: permissionsLoading } = useUserPermissions();
 const location = useLocation();

 // Tooltip state for condensed (tablet) mode
 const [tooltip, setTooltip] = useState<{ id: string; label: string } | null>(null);

 // ── Derive menu ──────────────────────────────────────────────────────────────
 const role = user?.role;

 const menuSections = React.useMemo(() => {
 if (!role || role === 'ADMIN') return [];

 const sections = getMenuForRole(role as 'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY');
 
 // Filter menu items based on user's actual permissions from the backend
 // Always include logout permission
 const userPermissions = [...permissions, `${role.toLowerCase()}_logout`];
 
 return filterMenuByPermissions(sections, userPermissions);
 }, [role, permissions]);

 // ── Helpers ──────────────────────────────────────────────────────────────────
 const isActive = (path: string): boolean => {
 if (path === '/dashboard') {
 return location.pathname === '/dashboard';
 }
 return location.pathname.startsWith(path);
 };

 const handleLogout = async () => {
 try {
 await logout();
 } catch (err) {
 console.error('Logout error:', err);
 }
 };

 const handleItemClick = (path: string) => {
 if (path === '/logout') {
 handleLogout();
 return;
 }
 // Close mobile overlay after navigation
 onClose?.();
 };

 // ── Role label ───────────────────────────────────────────────────────────────
 const roleLabel = role
 ? role.charAt(0) + role.slice(1).toLowerCase()
 : '';

 const roleBadgeColor: Record<string, string> = {
 ADMIN: 'bg-purple-100 text-purple-700',
 EMPLOYEE: 'bg-blue-100 text-blue-700',
 COACH: 'bg-green-100 text-green-700',
 SECURITY: 'bg-orange-100 text-orange-700',
 USER: 'bg-slate-100 text-slate-600',
 };

 // ── Render ───────────────────────────────────────────────────────────────────
 return (
 <>
 {/*
 * The sidebar uses CSS classes to handle three breakpoints:
 * - Default (mobile): w-[280px], shown/hidden via `isOpen` prop (controlled by parent)
 * - md (tablet): w-16 (64px), icons only
 * - lg (desktop): w-60 (240px), icons + labels
 *
 * The parent (UnifiedDashboardLayout) is responsible for the overlay backdrop
 * and the translate-x animation on mobile.
 */}
 <aside
 aria-label="Dashboard navigation"
 className={cn(
 // Base styles
 'flex flex-col h-full bg-white border-r border-slate-200 overflow-hidden',
 // Width per breakpoint
 'w-[280px] md:w-16 lg:w-60',
 // Ensure full height
 'min-h-screen'
 )}
 >
 {/* ── Logo / App name ─────────────────────────────────────────────── */}
 <Link
 to="/"
 aria-label="Go to Nahata Sports website"
 className={cn(
 'flex items-center gap-3 px-4 py-5 border-b border-slate-100 shrink-0 hover:opacity-80 transition-opacity',
 // On tablet: center the logo
 'md:justify-center lg:justify-start'
 )}
 >
 {/* Logo mark */}
  <img 
  src="/nahata_logo.png" 
  alt="Nahata Sports" 
  className="w-18 h-18 object-contain shrink-0"
  />

 {/* App name — hidden on tablet, visible on mobile & desktop */}
 <div className="md:hidden lg:flex flex-col leading-tight">
 <span className="text-text-dark text-base">
 Nahata Sports
 </span>
 {role && (
 <span
 className={cn(
 'text-xs px-1.5 py-0.5 rounded-full w-fit mt-0.5',
 roleBadgeColor[role] ?? 'bg-slate-100 text-slate-600'
 )}
 >
 {roleLabel}
 </span>
 )}
 </div>
 </Link>

 {/* ── Navigation menu ─────────────────────────────────────────────── */}
 <nav className="flex-1 overflow-y-auto overflow-x-hidden py-3 px-2">
 {permissionsLoading ? (
 // Skeleton loader while permissions are being fetched
 <div className="space-y-2 px-2">
 {[...Array(5)].map((_, i) => (
 <div
 key={i}
 className="h-10 rounded-lg bg-slate-100 animate-pulse"
 />
 ))}
 </div>
 ) : menuSections.length === 0 ? (
 <p className="text-xs text-slate-400 px-3 py-4 md:hidden lg:block">
 No menu items available.
 </p>
 ) : (
 menuSections.map((section) => (
 <div key={section.section} className="mb-4">
 {/* Section label — hidden on tablet */}
 <p
 className={cn(
 'text-[10px] uppercase tracking-widest text-slate-400 px-3 mb-1',
 'md:hidden lg:block'
 )}
 >
 {section.section}
 </p>

 <ul className="space-y-0.5"role="list">
 {section.items.map((item) => {
 const Icon = item.icon;
 const active = isActive(item.path);
 const isLogout = item.path === '/logout';

 if (isLogout) {
 // Logout rendered as a button, not a NavLink
 return (
 <li key={item.path}>
 <button
 onClick={() => handleItemClick(item.path)}
 onMouseEnter={() =>
 setTooltip({ id: item.path, label: item.name })
 }
 onMouseLeave={() => setTooltip(null)}
 className={cn(
 'relative w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors',
 'text-slate-500 hover:text-red-600 hover:bg-red-50',
 // Tablet: center icon
 'md:justify-center lg:justify-start'
 )}
 aria-label={item.name}
 >
 <Icon
 size={20}
 className="shrink-0"
 aria-hidden="true"
 />
 {/* Label — hidden on tablet */}
 <span className="md:hidden lg:inline truncate">
 {item.name}
 </span>

 {/* Tooltip for tablet mode */}
 {tooltip?.id === item.path && (
 <span
 role="tooltip"
 className={cn(
 'absolute left-full ml-2 z-50 px-2 py-1 text-xs ',
 'bg-slate-800 text-white rounded shadow-lg whitespace-nowrap',
 'hidden md:block lg:hidden'
 )}
 >
 {item.name}
 </span>
 )}
 </button>
 </li>
 );
 }

 return (
 <li key={item.path}>
 <NavLink
 to={item.path}
 onClick={() => handleItemClick(item.path)}
 onMouseEnter={() =>
 setTooltip({ id: item.path, label: item.name })
 }
 onMouseLeave={() => setTooltip(null)}
 className={cn(
 'relative flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all duration-200',
 // Tablet: center icon
 'md:justify-center lg:justify-start',
 active
 ? 'text-white'
 : 'text-slate-600 hover:text-text-dark hover:bg-slate-50'
 )}
 aria-current={active ? 'page' : undefined}
 aria-label={item.name}
 >
 {/* Active indicator - brand gradient background */}
 {active && (
 <span
 className="absolute inset-0 gradient-brand rounded-lg"
 aria-hidden="true"
 />
 )}

 <Icon
 size={20}
 className="shrink-0 relative z-10"
 aria-hidden="true"
 />

 {/* Label — hidden on tablet */}
 <span className="md:hidden lg:inline truncate relative z-10">
 {item.name}
 </span>

 {/* Tooltip for tablet mode */}
 {tooltip?.id === item.path && (
 <span
 role="tooltip"
 className={cn(
 'absolute left-full ml-2 z-50 px-2 py-1 text-xs ',
 'bg-slate-800 text-white rounded shadow-lg whitespace-nowrap',
 'hidden md:block lg:hidden'
 )}
 >
 {item.name}
 </span>
 )}
 </NavLink>
 </li>
 );
 })}
 </ul>
 </div>
 ))
 )}
 </nav>

 {/* ── Footer: user info ────────────────────────────────────────────── */}
 {user && (
 <div
 className={cn(
 'shrink-0 border-t border-slate-100 px-3 py-3',
 'md:flex md:justify-center lg:block'
 )}
 >
 <div className="flex items-center gap-3 md:justify-center lg:justify-start">
 {/* Avatar */}
 <div className="flex items-center justify-center w-8 h-8 rounded-full bg-brand-primary text-white text-xs shrink-0 select-none">
 {user.name
 .split(' ')
 .map((p) => p[0])
 .join('')
 .toUpperCase()
 .slice(0, 2)}
 </div>

 {/* Name + email — hidden on tablet */}
 <div className="md:hidden lg:flex flex-col min-w-0">
 <span className="text-sm text-text-dark truncate leading-tight">
 {user.name}
 </span>
 <span className="text-xs text-slate-400 truncate leading-tight">
 {user.email}
 </span>
 </div>
 </div>
 </div>
 )}
 </aside>
 </>
 );
};

export default RoleBasedSidebar;

