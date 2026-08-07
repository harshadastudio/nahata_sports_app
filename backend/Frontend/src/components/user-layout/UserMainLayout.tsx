import React from 'react';
import { UserSidebar } from './UserSidebar';
import { UserNavbar } from './UserNavbar';
import { cn } from '../../lib/utils';

interface Breadcrumb {
 label: string;
 active?: boolean;
}

interface UserMainLayoutProps {
 children: React.ReactNode;
 breadcrumbs?: Breadcrumb[];
 className?: string;
}

/**
 * Full-viewport layout for the User Dashboard.
 * Renders UserSidebar + UserNavbar — the public Navbar/Footer are NOT rendered here.
 */
export const UserMainLayout: React.FC<UserMainLayoutProps> = ({
 children,
 breadcrumbs,
 className,
}) => {
 const [isMobileMenuOpen, setIsMobileMenuOpen] = React.useState(false);

 return (
 <div className="flex bg-slate-50 min-h-screen font-sans selection:bg-brand-primary/20 selection:text-brand-primary">
 <UserSidebar isMobileOpen={isMobileMenuOpen} onClose={() => setIsMobileMenuOpen(false)} />
 <div className="flex-1 flex flex-col h-screen overflow-hidden">
 <UserNavbar breadcrumbs={breadcrumbs} onMenuClick={() => setIsMobileMenuOpen(true)} />
 <main
 className={cn(
 'flex-1 overflow-y-auto overflow-x-hidden scroll-smooth',
 className
 )}
 >
 <div className="p-4 md:p-8 max-w-[1500px] mx-auto">
 {children}
 </div>
 </main>
 </div>
 </div>
 );
};

export default UserMainLayout;
