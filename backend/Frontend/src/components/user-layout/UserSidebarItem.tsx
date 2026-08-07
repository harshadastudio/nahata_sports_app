import { Link, useLocation } from 'react-router-dom';
import { LucideIcon } from 'lucide-react';
import { cn } from '../../lib/utils';

interface UserSidebarItemProps {
 name: string;
 path: string;
 icon: LucideIcon;
 collapsed?: boolean;
}

export const UserSidebarItem: React.FC<UserSidebarItemProps> = ({
 name,
 path,
 icon: Icon,
 collapsed,
}) => {
 const location = useLocation();
 // Active if exact match or child route (but not for /dashboard matching /dashboard/*)
 const isActive =
 path === '/dashboard'
 ? location.pathname === '/dashboard'
 : location.pathname === path || location.pathname.startsWith(path + '/');

 return (
 <Link
 to={path}
 title={collapsed ? name : undefined}
 className={cn(
 'flex items-center gap-3 px-6 py-3 mx-4 rounded-[14px] transition-all duration-300 group relative',
 isActive
 ? 'bg-slate-900 text-white shadow-md shadow-slate-900/10'
 : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900'
 )}
 >
 <Icon
 size={18}
 className={cn(
 'shrink-0 transition-transform duration-300',
 isActive
 ? 'text-brand-bright scale-110'
 : 'text-slate-400 group-hover:text-brand-primary group-hover:scale-110'
 )}
 />
 {!collapsed && (
 <span
 className={cn(
 'text-[13px] tracking-wide transition-all whitespace-nowrap',
 isActive ? 'text-white' : 'text-slate-500 group-hover:text-slate-900'
 )}
 >
 {name}
 </span>
 )}
 {isActive && (
 <div className="absolute -left-4 top-1/2 -translate-y-1/2 w-1.5 h-8 bg-brand-primary rounded-r-full shadow-[0_0_8px_rgba(79,70,229,0.5)]"/>
 )}
 </Link>
 );
};

export default UserSidebarItem;

