/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { lazy, Suspense, useState, useEffect, type ComponentType } from 'react';
import { Routes, Route, useLocation, Navigate, useNavigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { motion, AnimatePresence } from 'motion/react';
import { MessageCircle } from 'lucide-react';

import { Navbar, Footer } from './components/Navigation';
import { Seo } from './components/Seo';
// The landing page stays in the entry chunk: it is the LCP route, so an extra
// network round-trip for it would directly delay first paint.
import { HomePage } from './pages/Home';
import {
  homePageSchemas,
  coachingPageSchemas,
  aboutPageSchemas,
  eventsPageSchemas,
  blogsPageSchemas,
  contactPageSchemas,
} from './services/structuredData';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { ProtectedUserRoute } from './components/ProtectedUserRoute';
import { PermissionGuard } from './components/PermissionGuard';
import { useUserPermissions } from './hooks/useUserPermissions';

// ── Lazy-loaded routes ────────────────────────────────────────────────────────
/**
 * Everything below is split into its own chunk so an anonymous visitor landing
 * on the public site never downloads the dashboard (all four role trees, the QR
 * scanners, the management tables, …). React.lazy needs a default export, so
 * lazyNamed() adapts the modules that only export a named component.
 */
const lazyNamed = (loader: () => Promise<any>, name: string) =>
  lazy(async () => ({ default: (await loader())[name] as ComponentType<any> }));

// Public pages
const CoachingPage = lazyNamed(() => import('./pages/Coaching'), 'CoachingPage');
const AboutPage = lazyNamed(() => import('./pages/About'), 'AboutPage');
const ContactPage = lazyNamed(() => import('./pages/Contact'), 'ContactPage');
const BlogsPage = lazyNamed(() => import('./pages/Blogs'), 'BlogsPage');
const BlogDetailPage = lazyNamed(() => import('./pages/BlogDetail'), 'BlogDetailPage');
const EventsPage = lazyNamed(() => import('./pages/Events'), 'EventsPage');
const BookFacilityPage = lazyNamed(() => import('./pages/BookFacility'), 'BookFacilityPage');
const LegalPage = lazyNamed(() => import('./pages/LegalPage'), 'LegalPage');
const ResetPasswordPage = lazyNamed(() => import('./pages/ResetPassword'), 'ResetPasswordPage');

// Modals — only mounted once the visitor opens them
const AuthModal = lazyNamed(() => import('./components/AuthModal'), 'AuthModal');
const StudentRegisterModal = lazyNamed(
  () => import('./components/StudentRegisterModal'),
  'StudentRegisterModal',
);

// User Dashboard pages
const UserDashboardHome = lazyNamed(() => import('./pages/dashboard/UserDashboardHome'), 'UserDashboardHome');
const ViewSports = lazyNamed(() => import('./pages/dashboard/ViewSports'), 'ViewSports');
const Feedback = lazyNamed(() => import('./pages/dashboard/Feedback'), 'Feedback');
const MyBookings = lazyNamed(() => import('./pages/dashboard/MyBookings'), 'MyBookings');
const MyEventPass = lazyNamed(() => import('./pages/dashboard/MyEventPass'), 'MyEventPass');
const StudentsParents = lazyNamed(() => import('./pages/dashboard/StudentsParents'), 'StudentsParents');
const EntryPass = lazyNamed(() => import('./pages/dashboard/EntryPass'), 'EntryPass');
const AttendanceSheet = lazyNamed(() => import('./pages/dashboard/AttendanceSheet'), 'AttendanceSheet');
const MyCoachingEnquiries = lazyNamed(() => import('./pages/dashboard/MyCoachingEnquiries'), 'MyCoachingEnquiries');
const Profile = lazyNamed(() => import('./pages/dashboard/Profile'), 'Profile');

// Employee Dashboard pages
const EmployeeDashboard = lazy(() => import('./pages/dashboard/employee/EmployeeDashboard'));
const BookingsManagement = lazy(() => import('./pages/dashboard/employee/bookings/BookingsManagement'));
const UsersManagement = lazy(() => import('./pages/dashboard/employee/users/UsersManagement'));
const PaymentsManagement = lazy(() => import('./pages/dashboard/employee/payments/PaymentsManagement'));
const AttendanceManagement = lazy(() => import('./pages/dashboard/employee/attendance/AttendanceManagement'));
const CoachesManagement = lazy(() => import('./pages/dashboard/employee/coaches/CoachesManagement'));
const NotificationsManagement = lazy(() => import('./pages/dashboard/employee/notifications/NotificationsManagement'));
const EmployeeFeesApproval = lazy(() => import('./pages/dashboard/employee/fees/FeesApproval'));
const EmployeeCoachingEnquiries = lazy(() => import('./pages/dashboard/employee/enquiries/CoachingEnquiries'));
// Employee complex-scoped operations modules
const EmployeeSportsMaster = lazy(() => import('./pages/dashboard/employee/master/SportsMaster'));
const EmployeeCourtsMaster = lazy(() => import('./pages/dashboard/employee/master/CourtsMaster'));
const EmployeeSlotsMaster = lazy(() => import('./pages/dashboard/employee/master/SlotsMaster'));
const EmployeeBatchesMaster = lazy(() => import('./pages/dashboard/employee/master/BatchesMaster'));
const EmployeeBlockedSlots = lazy(() => import('./pages/dashboard/employee/master/BlockedSlotsPage'));
const EmployeeFeesManagement = lazy(() => import('./pages/dashboard/employee/master/FeesManagementPage'));

// Coach Dashboard pages
const CoachDashboard = lazy(() => import('./pages/dashboard/coach/CoachDashboard'));
const MyStudents = lazy(() => import('./pages/dashboard/coach/students/MyStudents'));
const StudentEnrollments = lazy(() => import('./pages/dashboard/coach/students/StudentEnrollments'));
const CoachAttendanceSheet = lazy(() => import('./pages/dashboard/coach/attendance/CoachAttendanceSheet'));
const CoachingEnquiries = lazy(() => import('./pages/dashboard/coach/enquiries/CoachingEnquiries'));
const MySchedule = lazy(() => import('./pages/dashboard/coach/schedule/MySchedule'));
const StudentProgress = lazy(() => import('./pages/dashboard/coach/progress/StudentProgress'));
const FeesManagement = lazy(() => import('./pages/dashboard/coach/fees/FeesManagement'));
const FeesApproval = lazy(() => import('./pages/dashboard/coach/fees/FeesApproval'));
const CoachNotifications = lazy(() => import('./pages/dashboard/coach/notifications/CoachNotifications'));

// Security Dashboard pages
const SecurityDashboard = lazy(() => import('./pages/dashboard/security/SecurityDashboard'));
const CameraScanner = lazy(() => import('./pages/dashboard/security/scanner/CameraScanner'));
const EntryScanner = lazy(() => import('./pages/dashboard/security/scanner/EntryScanner'));
const EventScanner = lazy(() => import('./pages/dashboard/security/scanner/EventScanner'));
const CourtPassScanner = lazy(() => import('./pages/dashboard/security/scanner/CourtPassScanner'));
const StudentPassScanner = lazy(() => import('./pages/dashboard/shared/StudentPassScanner'));
const StudentPassScanLog = lazy(() => import('./pages/dashboard/security/scanner/StudentPassScanLog'));
const VisitorLogs = lazy(() => import('./pages/dashboard/security/visitors/VisitorLogs'));
const EntryPassVerification = lazy(() => import('./pages/dashboard/security/verification/EntryPassVerification'));
const GeneratePass = lazy(() => import('./pages/dashboard/security/pass-generation/GeneratePass'));

// ── Route fallback ────────────────────────────────────────────────────────────
/** Shown while a lazy route chunk is being fetched. */
function RouteFallback() {
 return (
 <div className="min-h-screen flex items-center justify-center bg-bg-main">
 <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin"/>
 </div>
 );
}

// ── Logout page ───────────────────────────────────────────────────────────────
function LogoutPage() {
 const { logout } = useAuth();
 const navigate = useNavigate();
 useEffect(() => {
 logout().finally(() => navigate('/', { replace: true }));
 }, []);
 return (
 <div className="min-h-screen flex items-center justify-center bg-bg-main">
 <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin"/>
 </div>
 );
}

// ── Role-based Dashboard Home ─────────────────────────────────────────────────
/**
 * DashboardHome - Smart component that renders the correct dashboard based on user role
 * - USER → UserDashboardHome
 * - EMPLOYEE → EmployeeDashboard
 * - COACH → CoachDashboard
 * - SECURITY → SecurityDashboard
 */
function DashboardHome() {
 const { user } = useAuth();
 
 if (!user) {
 return (
 <div className="min-h-screen flex items-center justify-center bg-bg-main">
 <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin"/>
 </div>
 );
 }

 switch (user.role) {
 case 'EMPLOYEE':
 return <EmployeeDashboard />;
 case 'COACH':
 return <CoachDashboard />;
 case 'SECURITY':
 return <SecurityDashboard />;
 case 'USER':
 default:
 return <UserDashboardHome />;
 }
}

// ── App ───────────────────────────────────────────────────────────────────────
export default function App() {
 const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
 const [isRegisterModalOpen, setIsRegisterModalOpen] = useState(false);
 const { pathname } = useLocation();

 // Hide public Navbar/Footer for all /dashboard/* routes
 const isDashboard = pathname.startsWith('/dashboard');

 useEffect(() => {
 if (!isDashboard) window.scrollTo(0, 0);
 }, [pathname, isDashboard]);

 // Listen for open-auth-modal event dispatched from CoachingPage
 useEffect(() => {
 const handler = () => setIsAuthModalOpen(true);
 window.addEventListener('open-auth-modal', handler);
 return () => window.removeEventListener('open-auth-modal', handler);
 }, []);

 return (
 <AuthProvider>
 <Toaster
 position="top-right"
 toastOptions={{
 duration: 4000,
 style: { borderRadius: '12px', fontWeight: 600, fontSize: '13px' },
 }}
 />
 {/* Global WhatsApp-verification popup: reminds unverified users (post-login)
     and enforces verification for new signups. Covers public + dashboard. */}
 {isDashboard ? (
 // ── Dashboard routes (no public Navbar/Footer) ────────────────────
 <Suspense fallback={<RouteFallback />}>
 <Routes>
 <Route element={<ProtectedUserRoute />}>

 {/* ── Dashboard Home (role-based) ──────────────────────────────── */}
 <Route path="/dashboard"element={<DashboardHome />} />

 <Route path="/dashboard/sports"element={
 <PermissionGuard permissionId="user_view_sports"><ViewSports /></PermissionGuard>
 } />

 <Route path="/dashboard/feedback"element={
 <PermissionGuard permissionId="user_feedback"><Feedback /></PermissionGuard>
 } />

 <Route path="/dashboard/event-pass"element={
 <PermissionGuard permissionId="user_my_event_pass"><MyEventPass /></PermissionGuard>
 } />

 <Route path="/dashboard/students-parents"element={
 <PermissionGuard permissionId="user_students_parents"><StudentsParents /></PermissionGuard>
 } />

 <Route path="/dashboard/entry-pass"element={
 <PermissionGuard permissionId="user_entry_pass"><EntryPass /></PermissionGuard>
 } />

 {/* USER attendance — path matches roleMenuConfig: /dashboard/attendance-sheet */}
 <Route path="/dashboard/attendance-sheet" element={
 <PermissionGuard permissionId="user_attendance_sheet"><AttendanceSheet /></PermissionGuard>
 } />

 <Route path="/dashboard/coaching-enquiries"element={
 <CoachingEnquiriesRoute />
 } />

 {/*
 * /dashboard/bookings — shared path between USER and EMPLOYEE.
 * PermissionGuard redirects to /dashboard when neither permission is
 * present. The RoleBasedSidebar already shows the correct label per
 * role, so we render the USER component when the user has
 * user_my_bookings, and the EMPLOYEE placeholder when they have
 * employee_bookings. A MultiPermissionRoute pattern is used here:
 * try USER permission first; if missing, try EMPLOYEE permission.
 */}
 <Route path="/dashboard/bookings"element={
 <BookingsRoute />
 } />

 {/*
 * /dashboard/attendance — shared path between EMPLOYEE and COACH.
 * EMPLOYEE uses employee_attendance; COACH uses coach_attendance.
 */}
 <Route path="/dashboard/attendance"element={
 <AttendanceRoute />
 } />

 {/* ── EMPLOYEE routes ──────────────────────────────────────────── */}
 <Route path="/dashboard/users"element={
 <PermissionGuard permissionId="employee_users">
 <UsersManagement />
 </PermissionGuard>
 } />

 <Route path="/dashboard/payments"element={
 <PermissionGuard permissionId="employee_payments">
 <PaymentsManagement />
 </PermissionGuard>
 } />

 <Route path="/dashboard/coaches"element={
 <PermissionGuard permissionId="employee_coaches">
 <CoachesManagement />
 </PermissionGuard>
 } />

 {/*
 * /dashboard/notifications — shared path between EMPLOYEE and COACH.
 * EMPLOYEE uses employee_notifications; COACH uses coach_notifications.
 */}
 <Route path="/dashboard/notifications"element={
 <NotificationsRoute />
 } />

 {/* ── COACH routes ─────────────────────────────────────────────── */}
 <Route path="/dashboard/students"element={
 <PermissionGuard permissionId="coach_students">
 <MyStudents />
 </PermissionGuard>
 } />

 {/* Month-wise enrollment list of the coach's batches */}
 <Route path="/dashboard/student-enrollments"element={
 <PermissionGuard permissionId="coach_students">
 <StudentEnrollments />
 </PermissionGuard>
 } />

 <Route path="/dashboard/schedule"element={
 <PermissionGuard permissionId="coach_schedule">
 <MySchedule />
 </PermissionGuard>
 } />

 <Route path="/dashboard/performance"element={
 <PermissionGuard permissionId="coach_performance">
 <StudentProgress />
 </PermissionGuard>
 } />

 {/*
 * /dashboard/fees-management — shared path between COACH
 * (coach_fees_management) and EMPLOYEE (employee_fees_management).
 */}
 <Route path="/dashboard/fees-management"element={
 <FeesManagementRoute />
 } />

 {/* ── EMPLOYEE complex-scoped operations modules ──────────────────
  * Each is limited to the employee's own sports complex by the API
  * (EMPLOYEE is a COMPLEX_SCOPED_ROLE), and each is gated on the
  * permission the admin grants in Roles Management. */}
 <Route path="/dashboard/blocked-slots"element={
 <PermissionGuard permissionId="employee_blocked_slots">
 <EmployeeBlockedSlots />
 </PermissionGuard>
 } />
 <Route path="/dashboard/sports-master"element={
 <PermissionGuard permissionId="employee_sports">
 <EmployeeSportsMaster />
 </PermissionGuard>
 } />
 <Route path="/dashboard/courts"element={
 <PermissionGuard permissionId="employee_courts">
 <EmployeeCourtsMaster />
 </PermissionGuard>
 } />
 <Route path="/dashboard/slots"element={
 <PermissionGuard permissionId="employee_slots">
 <EmployeeSlotsMaster />
 </PermissionGuard>
 } />
 <Route path="/dashboard/batches"element={
 <PermissionGuard permissionId="employee_batches">
 <EmployeeBatchesMaster />
 </PermissionGuard>
 } />

 {/*
 * /dashboard/fees-approval — shared path between EMPLOYEE (approves) and
 * COACH (read-only view of their own submissions' approval status).
 * EMPLOYEE uses employee_fees_approval; COACH uses coach_fees_approval.
 */}
 <Route path="/dashboard/fees-approval"element={
 <FeesApprovalRoute />
 } />

 {/* ── SECURITY routes ──────────────────────────────────────────── */}
 {/* Live camera QR scanner — routes each scan to the matching pass check */}
 <Route path="/dashboard/camera-scanner"element={
 <PermissionGuard permissionId="security_event_pass_scanner">
 <CameraScanner />
 </PermissionGuard>
 } />

 <Route path="/dashboard/scanner"element={
 <PermissionGuard permissionId="security_event_pass_scanner">
 <EntryScanner />
 </PermissionGuard>
 } />

 <Route path="/dashboard/event-scanner"element={
 <PermissionGuard permissionId="security_event_pass_scanner">
 <EventScanner />
 </PermissionGuard>
 } />

 <Route path="/dashboard/court-scanner"element={
 <PermissionGuard permissionId="security_court_pass_scanner">
 <CourtPassScanner />
 </PermissionGuard>
 } />

 {/* Student gate-pass scanner — shared by SECURITY + COACH */}
 <Route path="/dashboard/student-pass-scanner"element={
 <PermissionGuard anyOf={['security_court_pass_scanner', 'coach_attendance']}>
 <StudentPassScanner />
 </PermissionGuard>
 } />

 <Route path="/dashboard/student-scan-log"element={
 <PermissionGuard permissionId="security_court_pass_scanner">
 <StudentPassScanLog />
 </PermissionGuard>
 } />

 <Route path="/dashboard/visitor-list"element={
 <PermissionGuard permissionId="security_visitor_list">
 <VisitorLogs />
 </PermissionGuard>
 } />

 <Route path="/dashboard/verify-pass"element={
 <PermissionGuard permissionId="security_verify_pass">
 <EntryPassVerification />
 </PermissionGuard>
 } />

 <Route path="/dashboard/generate-pass"element={
 <PermissionGuard permissionId="security_generate_pass">
 <GeneratePass />
 </PermissionGuard>
 } />

 {/* ── Shared / utility routes ──────────────────────────────────── */}
 {/* Profile — available to every authenticated role (own profile) */}
 <Route path="/dashboard/profile"element={<Profile />} />

 <Route path="/dashboard/logout"element={<LogoutPage />} />

 {/* Catch-all inside dashboard → redirect to /dashboard */}
 <Route path="/dashboard/*"element={<Navigate to="/dashboard"replace />} />

 </Route>
 </Routes>
 </Suspense>
 ) : (
 // ── Public site routes (with Navbar/Footer) ──────────────────────────
 <div className="min-h-screen font-sans">
 <Navbar
 onOpenAuth={() => setIsAuthModalOpen(true)}
 onOpenRegister={() => setIsRegisterModalOpen(true)}
 />

 <Suspense
 fallback={
 <div className="min-h-[70vh] flex items-center justify-center bg-bg-main">
 <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin"/>
 </div>
 }
 >
 <Routes>
 <Route path="/"element={<><Seo pageKey="home" structuredData={homePageSchemas()} /><HomePage /></>} />
 <Route path="/coaching"element={<><Seo pageKey="coaching" structuredData={coachingPageSchemas()} /><CoachingPage /></>} />
 <Route path="/about"element={<><Seo pageKey="about" structuredData={aboutPageSchemas()} /><AboutPage /></>} />
 <Route path="/contacts"element={<><Seo pageKey="contact" structuredData={contactPageSchemas()} /><ContactPage /></>} />
 <Route path="/blogs"element={<><Seo pageKey="blogs" structuredData={blogsPageSchemas()} /><BlogsPage /></>} />
 <Route path="/blogs/:slug"element={<BlogDetailPage />} />
 <Route path="/events"element={<><Seo pageKey="events" structuredData={eventsPageSchemas()} /><EventsPage /></>} />
 <Route path="/book"element={<><Seo pageKey="book"/><BookFacilityPage /></>} />
 <Route path="/privacy-policy"element={<LegalPage type="privacy"/>} />
 <Route path="/cancellation-policy"element={<LegalPage type="cancellation"/>} />
 <Route path="/disclaimer"element={<LegalPage type="disclaimer"/>} />
 <Route path="/terms-and-conditions"element={<LegalPage type="terms"/>} />
 <Route path="/holidays"element={<LegalPage type="holidays"/>} />
 <Route path="/equipment-rental"element={<LegalPage type="equipment"/>} />
 <Route path="/reset-password"element={<ResetPasswordPage />} />
 </Routes>
 </Suspense>

 <Footer />

 {/* Floating WhatsApp Button */}
 <motion.a
 href="https://wa.me/yournumber"
 target="_blank"
 rel="noopener noreferrer"
 initial={{ scale: 0, opacity: 0 }}
 animate={{ scale: 1, opacity: 1 }}
 whileHover={{ scale: 1.1 }}
  className="fixed bottom-4 right-4 sm:bottom-8 sm:right-8 z-50 bg-[#25D366] text-white p-3 sm:p-4 rounded-full shadow-2xl flex items-center justify-center hover:bg-[#128C7E] transition-colors"
  >
 <MessageCircle size={32} />
 </motion.a>

 <Suspense fallback={null}>
 <AnimatePresence>
 {isAuthModalOpen && (
 <AuthModal
 isOpen={isAuthModalOpen}
 onClose={() => setIsAuthModalOpen(false)}
 initialMode="login"
 />
 )}
 {isRegisterModalOpen && (
 <StudentRegisterModal
 isOpen={isRegisterModalOpen}
 onClose={() => setIsRegisterModalOpen(false)}
 />
 )}
 </AnimatePresence>
 </Suspense>
 </div>
 )}
 </AuthProvider>
 );
}

// ── Shared-path route helpers ─────────────────────────────────────────────────

/**
 * BookingsRoute — handles /dashboard/bookings which is shared between USER
 * (user_my_bookings) and EMPLOYEE (employee_bookings).
 *
 * Renders the USER MyBookings component when the user has user_my_bookings,
 * otherwise falls back to the EMPLOYEE placeholder guarded by employee_bookings.
 * If neither permission is present, PermissionGuard redirects to /dashboard.
 */
function BookingsRoute() {
 const { hasPermission } = useUserPermissions();

 if (hasPermission('user_my_bookings')) {
 return (
 <PermissionGuard permissionId="user_my_bookings">
 <MyBookings />
 </PermissionGuard>
 );
 }

 return (
 <PermissionGuard permissionId="employee_bookings">
 <BookingsManagement />
 </PermissionGuard>
 );
}

/**
 * AttendanceRoute — handles /dashboard/attendance which is shared between
 * EMPLOYEE (employee_attendance) and COACH (coach_attendance).
 *
 * Renders the EMPLOYEE placeholder when the user has employee_attendance,
 * otherwise falls back to the COACH placeholder guarded by coach_attendance.
 * If neither permission is present, PermissionGuard redirects to /dashboard.
 */
function AttendanceRoute() {
 const { hasPermission } = useUserPermissions();

 if (hasPermission('employee_attendance')) {
 return (
 <PermissionGuard permissionId="employee_attendance">
 <AttendanceManagement />
 </PermissionGuard>
 );
 }

 return (
 <PermissionGuard permissionId="coach_attendance">
 <CoachAttendanceSheet />
 </PermissionGuard>
 );
}

/**
 * FeesApprovalRoute — handles /dashboard/fees-approval which is shared between
 * EMPLOYEE (employee_fees_approval — can Approve/Reject) and COACH
 * (coach_fees_approval — read-only view of their own submissions).
 *
 * Renders the EMPLOYEE approval component when the user has
 * employee_fees_approval, otherwise falls back to the COACH read-only view
 * guarded by coach_fees_approval.
 */
/**
 * FeesManagementRoute — handles /dashboard/fees-management, shared between
 * COACH (coach_fees_management, records fees for their own batches) and
 * EMPLOYEE (employee_fees_management, manages fees across their complex).
 * If neither permission is present, PermissionGuard redirects to /dashboard.
 */
function FeesManagementRoute() {
 const { hasPermission } = useUserPermissions();

 if (hasPermission('employee_fees_management')) {
 return (
 <PermissionGuard permissionId="employee_fees_management">
 <EmployeeFeesManagement />
 </PermissionGuard>
 );
 }

 return (
 <PermissionGuard permissionId="coach_fees_management">
 <FeesManagement />
 </PermissionGuard>
 );
}

function FeesApprovalRoute() {
 const { hasPermission } = useUserPermissions();

 if (hasPermission('employee_fees_approval')) {
 return (
 <PermissionGuard permissionId="employee_fees_approval">
 <EmployeeFeesApproval />
 </PermissionGuard>
 );
 }

 return (
 <PermissionGuard permissionId="coach_fees_approval">
 <FeesApproval />
 </PermissionGuard>
 );
}

/**
 * CoachingEnquiriesRoute — handles /dashboard/coaching-enquiries which is
 * shared between USER (user_coaching_enquiries), EMPLOYEE
 * (employee_coaching_enquiries — can Approve & Enroll across the complex) and
 * COACH (coach_coaching_enquiries — can Approve & Enroll their own assigned
 * enquiries).
 *
 * Renders the USER MyCoachingEnquiries component when the user has
 * user_coaching_enquiries, then the EMPLOYEE approval view when they have
 * employee_coaching_enquiries, otherwise falls back to the COACH
 * CoachingEnquiries component guarded by coach_coaching_enquiries.
 * If none of these permissions is present, PermissionGuard redirects to /dashboard.
 */
function CoachingEnquiriesRoute() {
 const { hasPermission } = useUserPermissions();

 if (hasPermission('user_coaching_enquiries')) {
 return (
 <PermissionGuard permissionId="user_coaching_enquiries">
 <MyCoachingEnquiries />
 </PermissionGuard>
 );
 }

 if (hasPermission('employee_coaching_enquiries')) {
 return (
 <PermissionGuard permissionId="employee_coaching_enquiries">
 <EmployeeCoachingEnquiries />
 </PermissionGuard>
 );
 }

 return (
 <PermissionGuard permissionId="coach_coaching_enquiries">
 <CoachingEnquiries />
 </PermissionGuard>
 );
}

/**
 * NotificationsRoute — handles /dashboard/notifications which is shared between
 * EMPLOYEE (employee_notifications) and COACH (coach_notifications).
 *
 * Renders the EMPLOYEE NotificationsManagement component when the user has
 * employee_notifications, otherwise falls back to the COACH CoachNotifications
 * component guarded by coach_notifications.
 * If neither permission is present, PermissionGuard redirects to /dashboard.
 */
function NotificationsRoute() {
 const { hasPermission } = useUserPermissions();

 if (hasPermission('employee_notifications')) {
 return (
 <PermissionGuard permissionId="employee_notifications">
 <NotificationsManagement />
 </PermissionGuard>
 );
 }

 return (
 <PermissionGuard permissionId="coach_notifications">
 <CoachNotifications />
 </PermissionGuard>
 );
}

// ss