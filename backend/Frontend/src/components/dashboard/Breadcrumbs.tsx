import React, { useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { ChevronRight, Home } from 'lucide-react';
import { cn } from '../../lib/utils';

interface BreadcrumbItem {
 label: string;
 path: string;
 isActive: boolean;
}

/**
 * Breadcrumbs - Navigation breadcrumb trail component
 * 
 * Features:
 * - Automatically generates breadcrumb trail from current route
 * - Clickable navigation for breadcrumb items
 * - Active breadcrumb highlighting
 * - Updates browser document title based on current page
 * - Home icon for dashboard root
 * 
 * Route mapping examples:
 * - /dashboard → Dashboard
 * - /dashboard/employee/bookings → Dashboard > Employee > Bookings
 * - /dashboard/coach/students → Dashboard > Coach > Students
 * 
 * Validates: Requirements 15.1, 15.2, 15.3, 15.5
 */
export const Breadcrumbs: React.FC = () => {
 const location = useLocation();

 // Generate breadcrumb items from current path
 const generateBreadcrumbs = (): BreadcrumbItem[] => {
 const pathSegments = location.pathname.split('/').filter(Boolean);
 
 // If not in dashboard, return empty
 if (pathSegments[0] !== 'dashboard') {
 return [];
 }

 const breadcrumbs: BreadcrumbItem[] = [];

 // Add dashboard root
 breadcrumbs.push({
 label: 'Dashboard',
 path: '/dashboard',
 isActive: pathSegments.length === 1,
 });

 // Build breadcrumbs from path segments
 let currentPath = '/dashboard';
 for (let i = 1; i < pathSegments.length; i++) {
 const segment = pathSegments[i];
 currentPath += `/${segment}`;
 
 breadcrumbs.push({
 label: formatSegmentLabel(segment),
 path: currentPath,
 isActive: i === pathSegments.length - 1,
 });
 }

 return breadcrumbs;
 };

 // Format path segment into readable label
 const formatSegmentLabel = (segment: string): string => {
 // Handle special cases
 const specialCases: Record<string, string> = {
 'bookings': 'Bookings',
 'users': 'Users',
 'payments': 'Payments',
 'attendance': 'Attendance',
 'coaches': 'Coaches',
 'notifications': 'Notifications',
 'students': 'Students',
 'coaching-enquiries': 'Coaching Enquiries',
 'schedule': 'Schedule',
 'performance': 'Student Progress',
 'scanner': 'Entry Scanner',
 'camera-scanner': 'Camera Scanner',
 'visitor-list': 'Visitor Logs',
 'verify-pass': 'Verify Pass',
 'generate-pass': 'Generate Pass',
 'sports': 'Sports',
 'feedback': 'Feedback',
 'event-pass': 'Event Pass',
 'entry-pass': 'Entry Pass',
 'employee': 'Employee',
 'coach': 'Coach',
 'security': 'Security',
 'user': 'User',
 };

 if (specialCases[segment]) {
 return specialCases[segment];
 }

 // Default: capitalize first letter of each word, replace hyphens/underscores with spaces
 return segment
 .split(/[-_]/)
 .map(word => word.charAt(0).toUpperCase() + word.slice(1))
 .join(' ');
 };

 const breadcrumbs = generateBreadcrumbs();

 // Update document title based on current page
 useEffect(() => {
 if (breadcrumbs.length === 0) return;

 const activeItem = breadcrumbs.find(item => item.isActive);
 if (activeItem) {
 // Set document title:"Page Name - Dashboard - Nahata Sports"
 const titleParts = breadcrumbs.map(item => item.label);
 document.title = `${titleParts.join(' - ')} - Nahata Sports`;
 }
 }, [location.pathname]);

 // Don't render if not in dashboard
 if (breadcrumbs.length === 0) {
 return null;
 }

 return (
 <nav aria-label="Breadcrumb"className="mb-4">
 <ol className="flex items-center gap-2 text-sm">
 {breadcrumbs.map((item, index) => (
 <li key={item.path} className="flex items-center gap-2">
 {/* Separator (except for first item) */}
 {index > 0 && (
 <ChevronRight 
 size={16} 
 className="text-slate-400"
 aria-hidden="true"
 />
 )}

 {/* Breadcrumb item */}
 {item.isActive ? (
 // Active breadcrumb (current page) - not clickable
 <span
 className="flex items-center gap-1.5 text-brand-primary"
 aria-current="page"
 >
 {index === 0 && <Home size={16} aria-hidden="true"/>}
 {item.label}
 </span>
 ) : (
 // Clickable breadcrumb
 <Link
 to={item.path}
 className={cn(
 'flex items-center gap-1.5 text-slate-600 hover:text-brand-primary transition-colors',
 'hover:underline focus:outline-none focus:ring-2 focus:ring-brand-primary focus:ring-offset-2 rounded px-1'
 )}
 >
 {index === 0 && <Home size={16} aria-hidden="true"/>}
 {item.label}
 </Link>
 )}
 </li>
 ))}
 </ol>
 </nav>
 );
};

export default Breadcrumbs;

