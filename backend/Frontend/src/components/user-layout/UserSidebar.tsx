import React, { useEffect, useRef, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
 LayoutDashboard,
 Trophy,
 MessageSquare,
 Calendar,
 Ticket,
 Users,
 LogIn,
 ClipboardList,
 UserCircle,
 LogOut,
 ChevronLeft,
 ChevronRight,
 GraduationCap,
 Activity,
 X
} from 'lucide-react';
import { UserSidebarItem } from './UserSidebarItem';
import { useUserPermissions } from '../../hooks/useUserPermissions';
import { cn } from '../../lib/utils';
import { motion, AnimatePresence } from 'motion/react';
import { useAuth } from '../../contexts/AuthContext';

interface MenuItem {
 name: string;
 path: string;
 icon: React.ComponentType<{ size?: number; className?: string }>;
 permissionId: string;
 /** When true, the item is always shown regardless of permissions
  *  (e.g. the user's own Profile, available to every role). */
 alwaysShow?: boolean;
}

interface MenuSection {
 section: string;
 items: MenuItem[];
}

const MENU_CONFIG: MenuSection[] = [
 {
 section: 'MAIN',
 items: [
 { name: 'Dashboard', path: '/dashboard', icon: LayoutDashboard, permissionId: 'user_dashboard' },
 ],
 },
 {
 section: 'USER PANEL',
 items: [
 { name: 'View Sports', path: '/dashboard/sports', icon: Trophy, permissionId: 'user_view_sports' },
 { name: 'Feedback', path: '/dashboard/feedback', icon: MessageSquare, permissionId: 'user_feedback' },
 { name: 'My Bookings', path: '/dashboard/bookings', icon: Calendar, permissionId: 'user_my_bookings' },
 { name: 'My Event Pass', path: '/dashboard/event-pass', icon: Ticket, permissionId: 'user_my_event_pass' },
 { name: 'Coaching Enquiries', path: '/dashboard/coaching-enquiries', icon: GraduationCap, permissionId: 'user_coaching_enquiries' },
 { name: 'Students / Parents', path: '/dashboard/students-parents', icon: Users, permissionId: 'user_students_parents' },
 { name: 'Entry Pass', path: '/dashboard/entry-pass', icon: LogIn, permissionId: 'user_entry_pass' },
 { name: 'Attendance Sheet', path: '/dashboard/attendance-sheet', icon: ClipboardList, permissionId: 'user_attendance_sheet' },
 ],
 },
 {
 section: 'ACCOUNT',
 items: [
 { name: 'My Profile', path: '/dashboard/profile', icon: UserCircle, permissionId: 'user_profile', alwaysShow: true },
 { name: 'Logout', path: '/dashboard/logout', icon: LogOut, permissionId: 'user_logout' },
 ],
 },
];

interface UserSidebarProps {
 isMobileOpen?: boolean;
 onClose?: () => void;
}

export const UserSidebar: React.FC<UserSidebarProps> = ({ isMobileOpen, onClose }) => {
 const [collapsed, setCollapsed] = useState(() => window.innerWidth < 1024);
 const location = useLocation();
 const navigate = useNavigate();
 const navRef = useRef<HTMLElement>(null);
 const { hasPermission } = useUserPermissions();
 const { logout } = useAuth();

 // Auto-collapse on medium screens, hide on small
 useEffect(() => {
 const handleResize = () => {
 if (window.innerWidth < 1024) setCollapsed(true);
 else setCollapsed(false);
 };
 window.addEventListener('resize', handleResize);
 return () => window.removeEventListener('resize', handleResize);
 }, []);

 // Close mobile sidebar on route change
 useEffect(() => {
 if (isMobileOpen && onClose) onClose();
 }, [location.pathname]);

 const handleLogout = async () => {
   try {
     await logout();
   } finally {
     navigate('/', { replace: true });
   }
 };

 const sidebarContent = (
 <aside
 className={cn(
 'flex flex-col bg-white border-r border-slate-200 transition-all duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] h-full shrink-0 overflow-x-hidden shadow-[4px_0_24px_rgba(15,23,42,0.02)] z-50',
 collapsed ? 'w-[88px]' : 'w-[280px]',
 'md:h-screen md:sticky md:top-0'
 )}
 >
 {/* Logo Area */}
 <div className="flex items-center justify-between p-6 pb-2 shrink-0 bg-white">
 {!collapsed ? (
 <Link to="/" title="Go to website" className="flex items-center gap-3">
  <img
  src="/nahata_logo.png"
  alt="Nahata Sports"
  className="w-20 h-20 object-contain"
  />
 <div className="flex flex-col">
 <span className="tracking-tight text-slate-900 text-[19px] leading-none uppercase">
 Nahata
 </span>
 <span className="tracking-[0.25em] text-brand-primary text-[9px] uppercase mt-0.5">
 Sports User
 </span>
 </div>
 </Link>
 ) : (
  <Link to="/" title="Go to website" className="mx-auto">
  <img
  src="/nahata_logo.png"
  alt="Nahata Sports"
  className="w-20 h-20 object-contain"
  />
  </Link>
 )}
 
 {/* Mobile Close Button */}
 <button onClick={onClose} className="md:hidden p-2 text-slate-400 hover:text-slate-600">
 <X size={20} />
 </button>
 </div>

 {/* Collapse toggle - Hidden on Mobile */}
 <div className="px-5 mb-4 mt-4 hidden md:block">
 <button
 onClick={() => setCollapsed(!collapsed)}
 className="w-full flex items-center justify-center py-2.5 bg-slate-50 hover:bg-slate-100 text-slate-400 rounded-xl transition-all border border-slate-200 hover:border-slate-300"
 aria-label={collapsed ? 'Expand menu' : 'Collapse menu'}
 >
 {collapsed ? (
 <ChevronRight size={16} />
 ) : (
 <div className="flex items-center gap-2 text-[10px] uppercase tracking-widest text-slate-500">
 <ChevronLeft size={14} /> Collapse Menu
 </div>
 )}
 </button>
 </div>

 {/* Nav items */}
 <nav
 ref={navRef}
 className="flex-1 py-4 space-y-6 overflow-y-auto overflow-x-hidden scrollbar-hide"
 >
 {MENU_CONFIG.map((section) => {
 const visibleItems = section.items.filter((item) =>
 item.alwaysShow || hasPermission(item.permissionId)
 );
 if (visibleItems.length === 0) return null;
 return (
 <div key={section.section} className="space-y-1">
 {!collapsed && (
 <h3 className="px-8 mb-2 text-[10px] tracking-[0.2em] text-slate-400 uppercase">
 {section.section}
 </h3>
 )}
 <div className="space-y-1">
 {visibleItems.map((item) => (
 item.path === '/dashboard/logout' ? (
   <button
     key={item.path}
     type="button"
     title={collapsed ? item.name : undefined}
     onClick={handleLogout}
     className={cn(
       'flex items-center gap-3 px-6 py-3 mx-4 rounded-[14px] transition-all duration-300 group relative text-slate-500 hover:bg-slate-50 hover:text-slate-900 w-[calc(100%-2rem)]'
     )}
   >
     <item.icon
       size={18}
       className={cn(
         'shrink-0 transition-transform duration-300 text-slate-400 group-hover:text-brand-primary group-hover:scale-110'
       )}
     />
     {!collapsed && (
       <span className="text-[13px] tracking-wide transition-all whitespace-nowrap text-slate-500 group-hover:text-slate-900">
         {item.name}
       </span>
     )}
   </button>
 ) : (
   <UserSidebarItem
     key={item.path}
     name={item.name}
     path={item.path}
     icon={item.icon as any}
     collapsed={collapsed}
   />
 )
 ))}
 </div>
 </div>
 );
 })}
 </nav>

 {/* Support card - Only when expanded */}
 {!collapsed && (
 <div className="p-5 m-5 bg-slate-900 rounded-[24px] shadow-xl relative overflow-hidden group shrink-0">
 <div className="absolute top-0 right-0 w-24 h-24 bg-brand-primary/40 rounded-full blur-2xl pointer-events-none transition-colors group-hover:bg-brand-primary/50"/>
 <div className="relative z-10 flex flex-col gap-4">
 <div className="flex items-center gap-3">
 <div className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center backdrop-blur-md border border-white/10">
 <Activity size={18} className="text-brand-bright"/>
 </div>
 <div>
 <p className="text-[13px] text-white font-medium">Support</p>
 <p className="text-[10px] text-white/50 uppercase tracking-wider">Help Center</p>
 </div>
 </div>
 <button className="w-full py-2.5 bg-white border border-transparent rounded-xl text-[11px] uppercase tracking-wider font-semibold text-slate-900 hover:bg-slate-100 transition-colors shadow-lg">
 Get Help
 </button>
 </div>
 </div>
 )}
 </aside>
 );

 return (
 <>
 {/* Desktop Sidebar */}
 <div className="hidden md:block h-screen sticky top-0 shrink-0">
 {sidebarContent}
 </div>

 {/* Mobile Sidebar Drawer */}
 <AnimatePresence>
 {isMobileOpen && (
 <div className="fixed inset-0 z-50 md:hidden">
 {/* Backdrop */}
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onClick={onClose}
 className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
 />
 
 {/* Sidebar Drawer */}
 <motion.div
 initial={{ x: '-100%' }}
 animate={{ x: 0 }}
 exit={{ x: '-100%' }}
 transition={{ type: 'spring', damping: 25, stiffness: 200 }}
 className="absolute top-0 left-0 bottom-0 w-[280px] h-full"
 >
 {React.cloneElement(sidebarContent as React.ReactElement, { className: cn((sidebarContent as React.ReactElement).props.className, 'w-full h-full') })}
 </motion.div>
 </div>
 )}
 </AnimatePresence>
 </>
 );
};

export default UserSidebar;
