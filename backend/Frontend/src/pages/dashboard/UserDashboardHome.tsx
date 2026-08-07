import React, { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import {
  Calendar, Trophy, Bell, RefreshCw, Loader2,
  CheckCircle, XCircle, AlertCircle, Clock,
  MapPin, ChevronRight, MessageSquare, LogIn,
  IndianRupee, User,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { useAuth } from '../../contexts/AuthContext';
import { bookingService, MyBooking, formatTime } from '../../services/bookingService';
import { fetchWithAuth } from '../../lib/fetchWithAuth';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// Bookings are pulled a page at a time. The "My Bookings" tile uses the
// server's totalItems (always exact); "Sports Enrolled" counts distinct sports
// across the rows in this page.
const STATS_PAGE_SIZE = 100;

// ── Types ─────────────────────────────────────────────────────────────────────
interface Notification {
  id: number;
  title: string;
  message: string;
  type: string;
  isRead: boolean;
  createdAt: string;
}

interface CoachingEnquiry {
  id: number;
  status: string;
  sport?: { name: string };
  batch?: { name: string };
  createdAt: string;
}

interface GatePass {
  id: number;
  passCode: string;
  batchName: string;
  sportName: string;
  approvalStatus: string;
  enrollmentDate: string;
}

// ── Status helpers ────────────────────────────────────────────────────────────
const BOOKING_STATUS: Record<string, { bg: string; text: string; icon: React.ReactNode }> = {
  Confirmed: { bg: 'bg-green-100',  text: 'text-green-700',  icon: <CheckCircle size={11} /> },
  Completed: { bg: 'bg-slate-100',  text: 'text-slate-600',  icon: <CheckCircle size={11} /> },
  Pending:   { bg: 'bg-blue-100',   text: 'text-blue-700',   icon: <AlertCircle size={11} /> },
  Cancelled: { bg: 'bg-red-100',    text: 'text-red-600',    icon: <XCircle size={11} /> },
};

const ENQUIRY_STATUS: Record<string, { bg: string; text: string }> = {
  Pending:   { bg: 'bg-amber-100',  text: 'text-amber-700'  },
  Approved:  { bg: 'bg-green-100',  text: 'text-green-700'  },
  Rejected:  { bg: 'bg-red-100',    text: 'text-red-600'    },
  Contacted: { bg: 'bg-blue-100',   text: 'text-blue-700'   },
};

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1)  return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24)  return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

// ── Main Component ────────────────────────────────────────────────────────────
export const UserDashboardHome: React.FC = () => {
  const { user } = useAuth();
  const firstName = (typeof user?.name === 'string' && user.name.trim())
    ? user.name.trim().split(' ')[0]
    : 'User';

  // Data states
  const [bookings,    setBookings]    = useState<MyBooking[]>([]);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [enquiries,   setEnquiries]   = useState<CoachingEnquiry[]>([]);
  const [gatePasses,  setGatePasses]  = useState<GatePass[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);

  // Stat counters. These are kept separate from the lists above because the
  // lists are trimmed to the few rows shown on the cards — counting the trimmed
  // list is what made the tiles report a capped (wrong) number.
  const [bookingsTotal,   setBookingsTotal]   = useState(0);
  const [sportsCount,     setSportsCount]     = useState(0);
  const [notificationsTotal, setNotificationsTotal] = useState(0);

  // Loading states
  const [loadingBookings,  setLoadingBookings]  = useState(true);
  const [loadingNotifs,    setLoadingNotifs]    = useState(true);
  const [loadingEnquiries, setLoadingEnquiries] = useState(true);
  const [loadingPasses,    setLoadingPasses]    = useState(true);

  // ── Fetch all data in parallel ──────────────────────────────────────────────
  const fetchAll = useCallback(async () => {
    setLoadingBookings(true);
    setLoadingNotifs(true);
    setLoadingEnquiries(true);
    setLoadingPasses(true);

    // Bookings — fetch a full page for the stats, show only the newest 5.
    bookingService.getMyBookings(1, STATS_PAGE_SIZE)
      .then((res) => {
        const list = Array.isArray(res.bookings) ? res.bookings : [];
        setBookings(list.slice(0, 5));
        setBookingsTotal(res.totalItems ?? list.length);
        setSportsCount(new Set(list.map(b => b.sport?.id).filter(Boolean)).size);
      })
      .catch(() => { setBookings([]); setBookingsTotal(0); setSportsCount(0); })
      .finally(() => setLoadingBookings(false));

    // Notifications — total for the tile, unread for the badge.
    Promise.all([
      fetchWithAuth(`${API_BASE}/notifications?limit=5`).then(r => r.json()),
      fetchWithAuth(`${API_BASE}/notifications/unread-count`).then(r => r.json()),
    ])
      .then(([notifJson, countJson]) => {
        const list = Array.isArray(notifJson.data) ? notifJson.data : [];
        setNotifications(list);
        setNotificationsTotal(notifJson.pagination?.totalItems ?? list.length);
        setUnreadCount(typeof countJson.count === 'number' ? countJson.count : 0);
      })
      .catch(() => { setNotifications([]); setNotificationsTotal(0); setUnreadCount(0); })
      .finally(() => setLoadingNotifs(false));

    // Coaching enquiries
    fetchWithAuth(`${API_BASE}/coaching-enquiries/my-enquiries?limit=5`)
      .then(r => r.json())
      .then(json => setEnquiries(Array.isArray(json.data) ? json.data : []))
      .catch(() => setEnquiries([]))
      .finally(() => setLoadingEnquiries(false));

    // Gate passes (approved fees)
    fetchWithAuth(`${API_BASE}/fees/my`)
      .then(r => r.json())
      .then(json => setGatePasses(Array.isArray(json.data) ? json.data : []))
      .catch(() => setGatePasses([]))
      .finally(() => setLoadingPasses(false));
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  // ── Derived stats ───────────────────────────────────────────────────────────
  const approvedPasses   = gatePasses.filter(p => p.approvalStatus === 'Approved').length;
  // Any in-flight request keeps the refresh button spinning.
  const isLoading        = loadingBookings || loadingNotifs || loadingEnquiries || loadingPasses;

  return (
    <UserMainLayout breadcrumbs={[{ label: 'Dashboard', active: true }]}>
      <div className="space-y-6">

        {/* Welcome banner */}
        <div className="relative overflow-hidden bg-gradient-to-r from-primary to-indigo-500 rounded-2xl p-8 text-white">
          <div className="relative z-10">
            <h1 className="text-3xl font-bold mb-1">Welcome back, {firstName}!</h1>
            <p className="text-white/80 text-sm">
              Manage your bookings and explore sports activities.
            </p>
          </div>
          <div className="absolute -right-8 -top-8 w-40 h-40 bg-white/10 rounded-full" />
          <div className="absolute -right-4 -bottom-10 w-28 h-28 bg-white/5 rounded-full" />
          {/* Refresh */}
          <button
            onClick={fetchAll}
            disabled={isLoading}
            className="absolute top-4 right-4 p-2 bg-white/10 hover:bg-white/20 rounded-xl transition-colors"
            title="Refresh"
          >
            <RefreshCw size={15} className={isLoading ? 'animate-spin' : ''} />
          </button>
        </div>

        {/* Quick stats */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            icon={<Calendar size={20} />}
            iconBg="bg-blue-100 text-blue-600"
            value={loadingBookings ? '…' : String(bookingsTotal)}
            label="My Bookings"
            href="/dashboard/bookings"
          />
          <StatCard
            icon={<Trophy size={20} />}
            iconBg="bg-green-100 text-green-600"
            value={loadingBookings ? '…' : String(sportsCount)}
            label="Sports Enrolled"
            href="/dashboard/sports"
          />
          <StatCard
            icon={<User size={20} />}
            iconBg="bg-orange-100 text-orange-600"
            value={user?.status || 'Active'}
            label="Account Status"
          />
          <StatCard
            icon={<Bell size={20} />}
            iconBg="bg-purple-100 text-purple-600"
            value={loadingNotifs ? '…' : String(notificationsTotal)}
            label="Notifications"
            badge={unreadCount > 0 ? unreadCount : undefined}
          />
        </div>

        {/* Main grid — bookings + notifications */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

          {/* Recent Bookings — 2/3 width */}
          <div className="lg:col-span-2 bg-white rounded-2xl border border-border p-6">
            <SectionHeader
              title="Recent Bookings"
              href="/dashboard/bookings"
              loading={loadingBookings}
            />
            {loadingBookings ? (
              <LoadingSkeleton rows={3} />
            ) : bookings.length === 0 ? (
              <EmptyState icon={<Calendar size={24} />} message="No bookings yet. Book a court to get started." />
            ) : (
              <div className="space-y-3 mt-4">
                {bookings.map((b) => {
                  const st = BOOKING_STATUS[b.bookingStatus] ?? BOOKING_STATUS.Pending;
                  return (
                    <div key={b.id} className="flex items-center justify-between p-4 bg-slate-50 rounded-xl hover:bg-slate-100 transition-colors">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="w-9 h-9 bg-primary/10 rounded-xl flex items-center justify-center shrink-0">
                          <Trophy size={16} className="text-primary" />
                        </div>
                        <div className="min-w-0">
                          <p className="font-semibold text-text-dark text-sm truncate">
                            {b.sport?.name ?? '—'}{b.court?.name ? ` — ${b.court.name}` : ''}
                          </p>
                          <p className="text-xs text-text-muted mt-0.5 flex items-center gap-1">
                            <Calendar size={10} /> {b.date}
                            <span className="mx-1">·</span>
                            <Clock size={10} /> {formatTime(b.startTime)} – {formatTime(b.endTime)}
                          </p>
                          {b.court?.SportComplex && (
                            <p className="text-[10px] text-text-muted flex items-center gap-1 mt-0.5">
                              <MapPin size={9} className="text-primary" />
                              {b.court.SportComplex.name}
                            </p>
                          )}
                        </div>
                      </div>
                      <div className="flex flex-col items-end gap-1 shrink-0 ml-3">
                        <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold ${st.bg} ${st.text}`}>
                          {st.icon} {b.bookingStatus}
                        </span>
                        <span className="text-[10px] text-text-muted font-semibold">
                          ₹{Number(b.totalAmount).toLocaleString('en-IN')}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* Notifications — 1/3 width */}
          <div className="bg-white rounded-2xl border border-border p-6">
            {/* No "View all" link: /dashboard/notifications is an EMPLOYEE/COACH
                route, so a USER lands back on the dashboard. The navbar bell is
                the user-facing notifications surface. */}
            <SectionHeader
              title="Notifications"
              loading={loadingNotifs}
              badge={unreadCount > 0 ? unreadCount : undefined}
            />
            {loadingNotifs ? (
              <LoadingSkeleton rows={4} />
            ) : notifications.length === 0 ? (
              <EmptyState icon={<Bell size={24} />} message="No notifications yet." />
            ) : (
              <div className="space-y-3 mt-4">
                {notifications.map((n) => (
                  <div key={n.id} className={`p-3 rounded-xl border transition-colors ${n.isRead ? 'bg-slate-50 border-transparent' : 'bg-blue-50 border-blue-100'}`}>
                    <div className="flex items-start justify-between gap-2">
                      <p className={`text-xs font-bold leading-snug ${n.isRead ? 'text-text-dark' : 'text-blue-800'}`}>
                        {n.title}
                      </p>
                      {!n.isRead && (
                        <span className="w-2 h-2 rounded-full bg-blue-500 shrink-0 mt-1" />
                      )}
                    </div>
                    <p className="text-[10px] text-text-muted mt-1 line-clamp-2">{n.message}</p>
                    <p className="text-[10px] text-slate-400 mt-1">{timeAgo(n.createdAt)}</p>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Second row — coaching enquiries + gate passes */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

          {/* Coaching Enquiries */}
          <div className="bg-white rounded-2xl border border-border p-6">
            <SectionHeader
              title="Coaching Enquiries"
              href="/dashboard/coaching-enquiries"
              loading={loadingEnquiries}
            />
            {loadingEnquiries ? (
              <LoadingSkeleton rows={3} />
            ) : enquiries.length === 0 ? (
              <EmptyState icon={<MessageSquare size={24} />} message="No coaching enquiries yet." />
            ) : (
              <div className="space-y-3 mt-4">
                {enquiries.slice(0, 4).map((e) => {
                  const es = ENQUIRY_STATUS[e.status] ?? ENQUIRY_STATUS.Pending;
                  return (
                    <div key={e.id} className="flex items-center justify-between p-3 bg-slate-50 rounded-xl">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="w-8 h-8 bg-primary/10 rounded-xl flex items-center justify-center shrink-0">
                          <MessageSquare size={14} className="text-primary" />
                        </div>
                        <div className="min-w-0">
                          <p className="text-xs font-bold text-text-dark truncate">
                            {e.batch?.name ?? e.sport?.name ?? `Enquiry #${e.id}`}
                          </p>
                          <p className="text-[10px] text-text-muted">{timeAgo(e.createdAt)}</p>
                        </div>
                      </div>
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold shrink-0 ml-2 ${es.bg} ${es.text}`}>
                        {e.status}
                      </span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* Gate Passes */}
          <div className="bg-white rounded-2xl border border-border p-6">
            <SectionHeader
              title="Entry Passes"
              href="/dashboard/entry-pass"
              loading={loadingPasses}
            />
            {loadingPasses ? (
              <LoadingSkeleton rows={3} />
            ) : gatePasses.length === 0 ? (
              <EmptyState icon={<LogIn size={24} />} message="No gate passes yet. Passes are issued after fee approval." />
            ) : (
              <div className="space-y-3 mt-4">
                {gatePasses.slice(0, 4).map((p) => (
                  <div key={p.id} className="flex items-center justify-between p-3 bg-slate-50 rounded-xl">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-8 h-8 bg-green-100 rounded-xl flex items-center justify-center shrink-0">
                        <LogIn size={14} className="text-green-600" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs font-bold text-text-dark truncate">{p.batchName}</p>
                        {p.sportName && (
                          <p className="text-[10px] text-text-muted">{p.sportName}</p>
                        )}
                        <p className="text-[10px] font-mono text-slate-400">{p.passCode}</p>
                      </div>
                    </div>
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-green-100 text-green-700 shrink-0 ml-2">
                      <CheckCircle size={9} /> Approved
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Quick links */}
        <div className="bg-white rounded-2xl border border-border p-6">
          <h3 className="text-sm font-bold text-text-dark mb-4">Quick Actions</h3>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { label: 'Book a Court',       href: '/book',                            icon: <Calendar size={18} />,     bg: 'bg-blue-50',   text: 'text-blue-600'   },
              { label: 'View Sports',        href: '/dashboard/sports',                 icon: <Trophy size={18} />,       bg: 'bg-green-50',  text: 'text-green-600'  },
              { label: 'My Event Pass',      href: '/dashboard/event-pass',             icon: <IndianRupee size={18} />,  bg: 'bg-purple-50', text: 'text-purple-600' },
              { label: 'Coaching Enquiry',   href: '/dashboard/coaching-enquiries',     icon: <MessageSquare size={18} />, bg: 'bg-orange-50', text: 'text-orange-600' },
            ].map((q) => (
              <Link
                key={q.label}
                to={q.href}
                className={`flex flex-col items-center gap-2 p-4 rounded-xl ${q.bg} hover:opacity-80 transition-opacity text-center`}
              >
                <span className={q.text}>{q.icon}</span>
                <span className={`text-xs font-bold ${q.text}`}>{q.label}</span>
              </Link>
            ))}
          </div>
        </div>

      </div>
    </UserMainLayout>
  );
};

// ── Sub-components ────────────────────────────────────────────────────────────

interface StatCardProps {
  icon: React.ReactNode;
  iconBg: string;
  value: string;
  label: string;
  href?: string;
  badge?: number;
}

const StatCard: React.FC<StatCardProps> = ({ icon, iconBg, value, label, href, badge }) => {
  const inner = (
    <div className="bg-white rounded-2xl p-5 border border-border hover:shadow-md transition-shadow relative">
      <div className="flex items-center gap-3">
        <div className={`p-3 rounded-xl ${iconBg} relative`}>
          {icon}
          {badge !== undefined && badge > 0 && (
            <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white text-[9px] font-black rounded-full flex items-center justify-center">
              {badge > 9 ? '9+' : badge}
            </span>
          )}
        </div>
        <div>
          <p className="text-2xl font-bold text-text-dark leading-none">{value}</p>
          <p className="text-xs text-text-muted mt-1">{label}</p>
        </div>
      </div>
      {href && (
        <ChevronRight size={14} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-300" />
      )}
    </div>
  );
  return href ? <Link to={href}>{inner}</Link> : inner;
};

interface SectionHeaderProps {
  title: string;
  href?: string;
  loading?: boolean;
  badge?: number;
}

const SectionHeader: React.FC<SectionHeaderProps> = ({ title, href, loading, badge }) => (
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-2">
      <h2 className="text-sm font-bold text-text-dark">{title}</h2>
      {badge !== undefined && badge > 0 && (
        <span className="px-1.5 py-0.5 bg-red-500 text-white text-[9px] font-black rounded-full">
          {badge}
        </span>
      )}
    </div>
    <div className="flex items-center gap-2">
      {loading && <Loader2 size={13} className="animate-spin text-slate-400" />}
      {href && (
        <Link to={href} className="text-[10px] font-bold text-primary hover:underline flex items-center gap-0.5">
          View all <ChevronRight size={11} />
        </Link>
      )}
    </div>
  </div>
);

const LoadingSkeleton: React.FC<{ rows: number }> = ({ rows }) => (
  <div className="space-y-3 mt-4">
    {Array.from({ length: rows }).map((_, i) => (
      <div key={i} className="h-14 bg-slate-100 rounded-xl animate-pulse" />
    ))}
  </div>
);

const EmptyState: React.FC<{ icon: React.ReactNode; message: string }> = ({ icon, message }) => (
  <div className="flex flex-col items-center justify-center py-8 text-slate-400 gap-2">
    <div className="w-10 h-10 bg-slate-100 rounded-xl flex items-center justify-center">
      {icon}
    </div>
    <p className="text-xs text-center text-text-muted max-w-[180px]">{message}</p>
  </div>
);

export default UserDashboardHome;
