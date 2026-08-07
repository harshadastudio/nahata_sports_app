import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { LogOut, ChevronRight, Home, Menu } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import NotificationBell from '../NotificationBell';

interface Breadcrumb {
 label: string;
 active?: boolean;
}

interface UserNavbarProps {
 breadcrumbs?: Breadcrumb[];
 onMenuClick?: () => void;
}

// Derive a human-readable breadcrumb label from a path segment
function segmentToLabel(segment: string): string {
 if (typeof segment !== 'string' || !segment) return '';
 const map: Record<string, string> = {
 dashboard: 'Dashboard',
 sports: 'View Sports',
 feedback: 'Feedback',
 bookings: 'My Bookings',
 'event-pass': 'My Event Pass',
 'students-parents': 'Students / Parents',
 'entry-pass': 'Entry Pass',
 attendance: 'Attendance Sheet',
 };
 return map[segment] ?? segment.charAt(0).toUpperCase() + segment.slice(1).replace(/-/g, ' ');
}

export const UserNavbar: React.FC<UserNavbarProps> = ({ breadcrumbs, onMenuClick }) => {
 const { user, logout } = useAuth();
 const navigate = useNavigate();
 const location = useLocation();

 const handleLogout = async () => {
 try {
 await logout();
 } catch {
 // logout already handles redirect
 }
 navigate('/');
 };

 // Auto-generate breadcrumbs from pathname if not provided
 const crumbs: Breadcrumb[] = breadcrumbs ?? (() => {
 const segments = location.pathname.split('/').filter(Boolean);
 return segments.map((seg, i) => ({
 label: segmentToLabel(seg),
 active: i === segments.length - 1,
 }));
 })();

 const initials = (typeof user?.name === 'string' && user.name.trim())
 ? user.name
 .trim()
 .split(/\s+/)
 .filter(Boolean)
 .map((w) => w[0] ?? '')
 .join('')
 .toUpperCase()
 .slice(0, 2) || 'U'
 : 'U';

 return (
 <header className="h-[72px] bg-white/80 backdrop-blur-xl border-b border-slate-200 flex items-center justify-between px-4 md:px-8 shrink-0 sticky top-0 z-40 shadow-sm">
 <div className="flex items-center gap-4">
 {/* Mobile Menu Toggle */}
 <button
 onClick={onMenuClick}
 className="md:hidden p-2 text-slate-500 hover:bg-slate-100 rounded-xl transition-colors"
 aria-label="Open Menu"
 >
 <Menu size={24} />
 </button>

 {/* Breadcrumbs */}
 <nav className="flex items-center gap-2 text-sm overflow-x-auto whitespace-nowrap scrollbar-hide flex-1" aria-label="Breadcrumb">
 <Home size={14} className="text-slate-400 shrink-0"/>
 {crumbs.map((crumb, i) => (
 <React.Fragment key={i}>
 <ChevronRight size={14} className="text-slate-300 shrink-0"/>
 <span
 className={
 crumb.active
 ? ' text-slate-900 tracking-wide font-medium'
 : ' text-slate-500 tracking-wide'
 }
 >
 {crumb.label}
 </span>
 </React.Fragment>
 ))}
 </nav>
 </div>

 {/* Right actions */}
 <div className="flex items-center gap-2 sm:gap-4 shrink-0 ml-2">
 {/* Notification bell */}
 <NotificationBell />

 {/* User info */}
 <div className="flex items-center gap-3 px-2 sm:px-3 py-1.5 bg-slate-50 hover:bg-slate-100 rounded-[14px] border border-slate-200 transition-colors cursor-pointer">
 {/* Avatar */}
 <div className="w-8 h-8 rounded-[10px] bg-slate-900 flex items-center justify-center text-white text-[11px] shadow-sm">
 {initials}
 </div>
 <div className="hidden lg:flex flex-col leading-tight pr-2">
 <span className="text-[13px] text-slate-900">{user?.name ?? 'User'}</span>
 <span className="text-[10px] uppercase tracking-widest text-slate-500">
 {typeof user?.role === 'string' ? user.role.toLowerCase() : 'user'}
 </span>
 </div>
 </div>

 {/* Logout */}
 <button
 onClick={handleLogout}
 className="flex items-center justify-center w-10 h-10 rounded-[14px] text-slate-400 hover:text-red-500 hover:bg-red-50 hover:border-red-100 border border-transparent transition-all"
 aria-label="Logout"
 >
 <LogOut size={18} />
 </button>
 </div>
 </header>
 );
};

export default UserNavbar;
