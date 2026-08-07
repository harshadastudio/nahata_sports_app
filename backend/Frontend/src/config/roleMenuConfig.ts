import {
 LayoutDashboard,
 Trophy,
 Calendar,
 CalendarDays,
 CalendarRange,
 Ticket,
 MessageSquare,
 Users,
 CreditCard,
 ClipboardList,
 UserCheck,
 Bell,
 HelpCircle,
 TrendingUp,
 ScanLine,
 ShieldCheck,
 QrCode,
 Camera,
 LogOut,
 Wallet,
 CheckCircle,
 UserCircle,
 Ban,
 MapPin,
 Clock,
 IndianRupee,
 type LucideIcon,
} from 'lucide-react';

/**
 * Menu item configuration for role-based navigation
 */
export interface MenuItem {
 name: string;
 path: string;
 icon: LucideIcon;
 permissionId: string;
 /** When true, the item is always shown regardless of permissions
  *  (e.g. the user's own Profile, available to every role). */
 alwaysShow?: boolean;
}

/**
 * Menu section grouping related items
 */
export interface MenuSection {
 section: string;
 items: MenuItem[];
}

/**
 * Role-based menu configuration type
 */
export type RoleMenuConfig = Record<
 'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY',
 MenuSection[]
>;

/**
 * Complete role-based menu configuration
 *
 * Each role has a specific set of menu sections and items.
 * Menu items are filtered by user permissions at runtime.
 *
 * Validates: Requirements 2.1, 2.3, 4.1, 5.1, 6.1, 7.1
 */
export const roleMenuConfig: RoleMenuConfig = {
 USER: [
 {
 section: 'MAIN',
 items: [
 {
 name: 'Dashboard Overview',
 path: '/dashboard',
 icon: LayoutDashboard,
 permissionId: 'user_dashboard',
 },
 {
 name: 'View Sports',
 path: '/dashboard/sports',
 icon: Trophy,
 permissionId: 'user_view_sports',
 },
 {
 name: 'My Bookings',
 path: '/dashboard/bookings',
 icon: Calendar,
 permissionId: 'user_my_bookings',
 },
 {
 name: 'My Event Pass',
 path: '/dashboard/event-pass',
 icon: Ticket,
 permissionId: 'user_my_event_pass',
 },
 {
 name: 'Feedback',
 path: '/dashboard/feedback',
 icon: MessageSquare,
 permissionId: 'user_feedback',
 },
 {
 name: 'Students/Parents',
 path: '/dashboard/students-parents',
 icon: Users,
 permissionId: 'user_students_parents',
 },
 {
 name: 'Entry Pass',
 path: '/dashboard/entry-pass',
 icon: QrCode,
 permissionId: 'user_entry_pass',
 },
 {
 name: 'Attendance Sheet',
 path: '/dashboard/attendance-sheet',
 icon: ClipboardList,
 permissionId: 'user_attendance_sheet',
 },
 {
 name: 'Coaching Enquiries',
 path: '/dashboard/coaching-enquiries',
 icon: HelpCircle,
 permissionId: 'user_coaching_enquiries',
 },
 {
 name: 'My Profile',
 path: '/dashboard/profile',
 icon: UserCircle,
 permissionId: 'profile',
 alwaysShow: true,
 },
 {
 name: 'Logout',
 path: '/logout',
 icon: LogOut,
 permissionId: 'user_logout',
 },
 ],
 },
 ],

 EMPLOYEE: [
 {
 section: 'OPERATIONS',
 items: [
 {
 name: 'Dashboard Overview',
 path: '/dashboard',
 icon: LayoutDashboard,
 permissionId: 'employee_dashboard',
 },
 {
 name: 'Bookings Management',
 path: '/dashboard/bookings',
 icon: Calendar,
 permissionId: 'employee_bookings',
 },
 {
 name: 'Payments Management',
 path: '/dashboard/payments',
 icon: CreditCard,
 permissionId: 'employee_payments',
 },
 {
 name: 'Attendance Management',
 path: '/dashboard/attendance',
 icon: ClipboardList,
 permissionId: 'employee_attendance',
 },
 {
 name: 'Coaches Management',
 path: '/dashboard/coaches',
 icon: UserCheck,
 permissionId: 'employee_coaches',
 },
 {
 name: 'Coaching Enquiries',
 path: '/dashboard/coaching-enquiries',
 icon: HelpCircle,
 permissionId: 'employee_coaching_enquiries',
 },
 {
 name: 'Fees Approval',
 path: '/dashboard/fees-approval',
 icon: CheckCircle,
 permissionId: 'employee_fees_approval',
 },
 {
 name: 'Users Management',
 path: '/dashboard/users',
 icon: Users,
 permissionId: 'employee_users',
 },
 {
 name: 'Notifications',
 path: '/dashboard/notifications',
 icon: Bell,
 permissionId: 'employee_notifications',
 },
 // ── Complex-scoped operations modules. Each shows only the employee's own
 //    sports complex; the API enforces that, not the UI. ──────────────────
 {
 name: 'Blocked Slots',
 path: '/dashboard/blocked-slots',
 icon: Ban,
 permissionId: 'employee_blocked_slots',
 },
 {
 name: 'Fees Management',
 path: '/dashboard/fees-management',
 icon: IndianRupee,
 permissionId: 'employee_fees_management',
 },
 {
 name: 'Sports',
 path: '/dashboard/sports-master',
 icon: Trophy,
 permissionId: 'employee_sports',
 },
 {
 name: 'Court',
 path: '/dashboard/courts',
 icon: MapPin,
 permissionId: 'employee_courts',
 },
 {
 name: 'Slot',
 path: '/dashboard/slots',
 icon: Clock,
 permissionId: 'employee_slots',
 },
 {
 name: 'Batch',
 path: '/dashboard/batches',
 icon: CalendarDays,
 permissionId: 'employee_batches',
 },
 {
 name: 'My Profile',
 path: '/dashboard/profile',
 icon: UserCircle,
 permissionId: 'profile',
 alwaysShow: true,
 },
 {
 name: 'Logout',
 path: '/logout',
 icon: LogOut,
 permissionId: 'employee_logout',
 },
 ],
 },
 ],

 COACH: [
 {
 section: 'COACHING',
 items: [
 {
 name: 'Dashboard Overview',
 path: '/dashboard',
 icon: LayoutDashboard,
 permissionId: 'coach_dashboard',
 },
 {
 name: 'My Students',
 path: '/dashboard/students',
 icon: Users,
 permissionId: 'coach_students',
 },
 {
 name: 'Student Enrollments',
 path: '/dashboard/student-enrollments',
 icon: CalendarRange,
 permissionId: 'coach_students',
 },
 {
 name: 'Attendance Sheet',
 path: '/dashboard/attendance',
 icon: ClipboardList,
 permissionId: 'coach_attendance',
 },
 {
 name: 'Student Pass Scanner',
 path: '/dashboard/student-pass-scanner',
 icon: ScanLine,
 permissionId: 'coach_attendance',
 },
 {
 name: 'Coaching Enquiries',
 path: '/dashboard/coaching-enquiries',
 icon: HelpCircle,
 permissionId: 'coach_coaching_enquiries',
 },
 {
 name: 'My Schedule',
 path: '/dashboard/schedule',
 icon: CalendarDays,
 permissionId: 'coach_schedule',
 },
 {
 name: 'Student Progress',
 path: '/dashboard/performance',
 icon: TrendingUp,
 permissionId: 'coach_performance',
 },
 {
 name: 'Fees Management',
 path: '/dashboard/fees-management',
 icon: Wallet,
 permissionId: 'coach_fees_management',
 },
 {
 name: 'Fees Approval',
 path: '/dashboard/fees-approval',
 icon: CheckCircle,
 permissionId: 'coach_fees_approval',
 },
 {
 name: 'Notifications',
 path: '/dashboard/notifications',
 icon: Bell,
 permissionId: 'coach_notifications',
 },
 {
 name: 'My Profile',
 path: '/dashboard/profile',
 icon: UserCircle,
 permissionId: 'profile',
 alwaysShow: true,
 },
 {
 name: 'Logout',
 path: '/logout',
 icon: LogOut,
 permissionId: 'coach_logout',
 },
 ],
 },
 ],

 SECURITY: [
 {
 section: 'SECURITY',
 items: [
 {
 name: 'Dashboard Overview',
 path: '/dashboard',
 icon: LayoutDashboard,
 permissionId: 'security_dashboard',
 },
 {
 // Live camera QR scanner — auto-detects visitor / event / court / student
 // passes from the code prefix. Reuses the event-pass scanner permission so
 // no new (unseeded) permission id is required.
 name: 'Camera Scanner',
 path: '/dashboard/camera-scanner',
 icon: Camera,
 permissionId: 'security_event_pass_scanner',
 },
 {
 name: 'Entry Scanner',
 path: '/dashboard/scanner',
 icon: ScanLine,
 permissionId: 'security_event_pass_scanner',
 },
 {
 name: 'Event Scanner',
 path: '/dashboard/event-scanner',
 icon: Ticket,
 permissionId: 'security_event_pass_scanner',
 },
 {
 name: 'Court Pass Scanner',
 path: '/dashboard/court-scanner',
 icon: Trophy,
 permissionId: 'security_court_pass_scanner',
 },
 {
 name: 'Student Pass Scanner',
 path: '/dashboard/student-pass-scanner',
 icon: ScanLine,
 permissionId: 'security_court_pass_scanner',
 },
 {
 name: 'Scan Log',
 path: '/dashboard/student-scan-log',
 icon: ClipboardList,
 permissionId: 'security_court_pass_scanner',
 },
 {
 name: 'Verify Pass',
 path: '/dashboard/verify-pass',
 icon: ShieldCheck,
 permissionId: 'security_verify_pass',
 },
 {
 name: 'Generate Pass',
 path: '/dashboard/generate-pass',
 icon: QrCode,
 permissionId: 'security_generate_pass',
 },
 {
 name: 'Visitor List',
 path: '/dashboard/visitor-list',
 icon: ClipboardList,
 permissionId: 'security_visitor_list',
 },
 {
 name: 'My Profile',
 path: '/dashboard/profile',
 icon: UserCircle,
 permissionId: 'profile',
 alwaysShow: true,
 },
 {
 name: 'Logout',
 path: '/logout',
 icon: LogOut,
 permissionId: 'security_logout',
 },
 ],
 },
 ],
};

/**
 * Get menu configuration for a specific role
 * @param role - User role (USER, EMPLOYEE, COACH, SECURITY)
 * @returns Menu sections for the specified role
 */
export function getMenuForRole(
 role: 'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY'
): MenuSection[] {
 return roleMenuConfig[role] || [];
}

/**
 * Filter menu items based on user permissions
 * @param menuSections - Menu sections to filter
 * @param permissions - User's permission IDs
 * @returns Filtered menu sections containing only permitted items
 */
export function filterMenuByPermissions(
 menuSections: MenuSection[],
 permissions: string[]
): MenuSection[] {
 return menuSections
 .map((section) => ({
 ...section,
 items: section.items.filter((item) =>
 item.alwaysShow || permissions.includes(item.permissionId)
 ),
 }))
 .filter((section) => section.items.length > 0);
}

