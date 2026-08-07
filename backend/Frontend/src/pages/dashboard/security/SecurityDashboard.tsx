import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Shield,
  UserCheck,
  UserX,
  QrCode,
  AlertCircle,
  Users,
  RefreshCw,
  ArrowRight,
  CheckCircle2,
  XCircle,
  Hourglass,
  UserPlus,
  ScanLine,
  List,
  Ticket,
} from 'lucide-react';
import { UnifiedDashboardLayout } from '../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../components/dashboard/DashboardNavbar';
import { useAuth } from '../../../contexts/AuthContext';
import {
  type VisitorPass,
  VisitorPassStatusBadge as StatusBadge,
  normalizePassStatus,
} from '../../../components/security/visitorPass';
import { fetchWithAuth } from '../../../lib/fetchWithAuth';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Helpers ───────────────────────────────────────────────────────────────────

// The API may send a timestamp as ISO OR as an already-localized en-IN string
// (e.g. "28/06/2026, 5:30:00 pm") that `new Date()` cannot parse — handle both,
// otherwise dates render as "Invalid Date" / "NaNd ago".
const parseApiDate = (value?: string | null): Date | null => {
  if (!value) return null;
  const native = new Date(value);
  if (!isNaN(native.getTime())) return native;
  const m = value.match(/(\d{1,2})\/(\d{1,2})\/(\d{4}),?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?/i);
  if (m) {
    let hour = parseInt(m[4], 10);
    const ap = m[7]?.toLowerCase();
    if (ap === 'pm' && hour < 12) hour += 12;
    if (ap === 'am' && hour === 12) hour = 0;
    return new Date(+m[3], +m[2] - 1, +m[1], hour, +m[5], m[6] ? +m[6] : 0);
  }
  return null;
};

const isSameDay = (value: string | null | undefined, ref: Date): boolean => {
  const d = parseApiDate(value);
  return !!d && d.getFullYear() === ref.getFullYear() && d.getMonth() === ref.getMonth() && d.getDate() === ref.getDate();
};

const timeAgo = (dateStr: string): string => {
  const d = parseApiDate(dateStr);
  if (!d) return '—';
  const diff = Date.now() - d.getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min${mins > 1 ? 's' : ''} ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} hr${hrs > 1 ? 's' : ''} ago`;
  return `${Math.floor(hrs / 24)}d ago`;
};

const formatTime = (dateStr: string): string => {
  const d = parseApiDate(dateStr);
  return d ? d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true }) : '—';
};

const formatDate = (dateStr: string): string => {
  const d = parseApiDate(dateStr);
  return d ? d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
};

const initials = (name: string): string =>
  name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');

const AVATAR_COLORS = [
  'bg-red-100 text-red-600',
  'bg-blue-100 text-blue-600',
  'bg-green-100 text-green-600',
  'bg-orange-100 text-orange-600',
  'bg-purple-100 text-purple-600',
  'bg-teal-100 text-teal-600',
];

const avatarColor = (name: string) =>
  AVATAR_COLORS[name.charCodeAt(0) % AVATAR_COLORS.length];

// ── Sub-components ────────────────────────────────────────────────────────────

interface StatCardProps {
  icon: React.ReactNode;
  value: number | string;
  label: string;
  colorClass: string;
  loading?: boolean;
}

const StatCard: React.FC<StatCardProps> = ({ icon, value, label, colorClass, loading }) => (
  <div className="bg-white rounded-xl p-6 border border-border flex items-center gap-4">
    <div className={`${colorClass} p-3 rounded-lg shrink-0`}>{icon}</div>
    <div>
      {loading ? (
        <div className="h-7 w-12 bg-slate-200 animate-pulse rounded mb-1" />
      ) : (
        <p className="text-2xl font-bold text-text-dark">{value}</p>
      )}
      <p className="text-sm text-text-muted">{label}</p>
    </div>
  </div>
);

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * SecurityDashboard - Overview page for the SECURITY role
 *
 * Displays visitor pass stats, recent pass activity, active visitors,
 * and quick action buttons for security operations.
 * Wrapped with UnifiedDashboardLayout using RoleBasedSidebar and DashboardNavbar.
 *
 * Validates: Requirements 6.1, 8.3
 */
export default function SecurityDashboard() {
  const navigate = useNavigate();
  const { user } = useAuth();

  const [passes, setPasses] = useState<VisitorPass[]>([]);
  const [eventScans, setEventScans] = useState<{ total: number; today: number }>({ total: 0, today: 0 });
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastRefreshed, setLastRefreshed] = useState<Date>(new Date());

  // Derived stats
  const totalPasses = passes.length;
  const activePasses = passes.filter((p) => normalizePassStatus(p.status) === 'active').length;
  // "Inside" = checked in at the gate and not checked out yet.
  const insidePasses = passes.filter((p) => normalizePassStatus(p.status) === 'checked_in').length;
  const checkedOutPasses = passes.filter((p) => normalizePassStatus(p.status) === 'checked_out').length;

  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);
  const todayPasses = passes.filter((p) => isSameDay(p.generatedAt, now));
  const recentPasses = [...passes]
    .sort((a, b) => (parseApiDate(b.generatedAt)?.getTime() ?? 0) - (parseApiDate(a.generatedAt)?.getTime() ?? 0))
    .slice(0, 5);
  const visitorsInside = passes
    .filter((p) => normalizePassStatus(p.status) === 'checked_in')
    .slice(0, 5);
  const expiringToday = passes.filter(
    (p) => normalizePassStatus(p.status) === 'active' && p.validUntil?.slice(0, 10) === todayStr
  ).length;

  const fetchData = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    else setRefreshing(true);
    setError(null);
    try {
      const res = await fetchWithAuth(`${API_BASE}/visitor-passes?page=1&limit=100`);
      if (res.ok) {
        const json = await res.json();
        setPasses(Array.isArray(json.data) ? json.data : []);
        setLastRefreshed(new Date());
      } else {
        setError('Failed to load visitor data.');
      }

      // How many event passes THIS guard has scanned (total + today). Non-fatal.
      try {
        const scanRes = await fetchWithAuth(`${API_BASE}/event-passes/my-scan-stats`);
        if (scanRes.ok) {
          const scanJson = await scanRes.json();
          if (scanJson?.data) setEventScans(scanJson.data);
        }
      } catch {
        /* ignore — event scan stat is supplementary */
      }
    } catch (err: any) {
      setError(err.message ?? 'Unable to connect to server.');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
    const interval = setInterval(() => fetchData(true), 60000);
    return () => clearInterval(interval);
  }, [fetchData]);

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Security Dashboard" />}
    >
      <div className="space-y-6">

        {/* Header banner */}
        <div className="bg-gradient-to-r from-red-500 to-red-600 rounded-xl p-8 text-white">
          <div className="flex items-center justify-between flex-wrap gap-4">
            <div>
              <h1 className="text-3xl font-bold mb-1">Security Dashboard</h1>
              <p className="text-red-100 text-sm">
                Welcome back,{' '}
                <span className="font-semibold">{user?.name ?? 'Security Guard'}</span>
                {' · '}Monitor entry/exit, verify passes, and manage visitors
              </p>
            </div>
            <div className="flex items-center gap-3 flex-wrap">
              <button
                onClick={() => fetchData(true)}
                disabled={refreshing}
                className="flex items-center gap-2 bg-white/20 hover:bg-white/30 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-all disabled:opacity-60"
              >
                <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
                {refreshing ? 'Refreshing…' : 'Refresh'}
              </button>
              <button
                onClick={() => navigate('/dashboard/generate-pass')}
                className="flex items-center gap-2 bg-white text-red-600 hover:bg-red-50 px-4 py-2 rounded-lg text-sm font-bold transition-all shadow"
              >
                <UserPlus className="w-4 h-4" />
                Generate Pass
              </button>
              <button
                onClick={() => navigate('/dashboard/verify-pass')}
                className="flex items-center gap-2 bg-white/20 hover:bg-white/30 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-all"
              >
                <ScanLine className="w-4 h-4" />
                Verify Pass
              </button>
            </div>
          </div>
          <p className="text-red-200 text-xs mt-3">
            Last refreshed:{' '}
            {lastRefreshed.toLocaleTimeString('en-IN', {
              hour: '2-digit',
              minute: '2-digit',
              second: '2-digit',
            })}
            {' · '}Auto-refreshes every 60 seconds
          </p>
        </div>

        {/* Error banner */}
        {error && (
          <div className="flex items-center gap-3 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700">
            <AlertCircle className="w-5 h-5 shrink-0" />
            <p className="text-sm font-medium">{error}</p>
            <button
              onClick={() => fetchData()}
              className="ml-auto text-xs font-bold underline hover:no-underline"
            >
              Retry
            </button>
          </div>
        )}

        {/* Stats grid */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard
            icon={<Users className="w-5 h-5" />}
            value={totalPasses}
            label="Total Passes"
            colorClass="bg-slate-100 text-slate-600"
            loading={loading}
          />
          <StatCard
            icon={<CheckCircle2 className="w-5 h-5" />}
            value={activePasses}
            label="Active Passes"
            colorClass="bg-green-100 text-green-600"
            loading={loading}
          />
          <StatCard
            icon={<UserCheck className="w-5 h-5" />}
            value={insidePasses}
            label="Checked In"
            colorClass="bg-blue-100 text-blue-600"
            loading={loading}
          />
          <StatCard
            icon={<XCircle className="w-5 h-5" />}
            value={checkedOutPasses}
            label="Checked Out"
            colorClass="bg-slate-200 text-slate-600"
            loading={loading}
          />
        </div>

        {/* Today summary row */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-white rounded-xl border border-border p-5 flex items-center gap-4">
            <div className="bg-indigo-100 text-indigo-600 p-3 rounded-lg shrink-0">
              <Ticket className="w-5 h-5" />
            </div>
            <div>
              {loading ? (
                <div className="h-6 w-10 bg-slate-200 animate-pulse rounded mb-1" />
              ) : (
                <p className="text-xl font-bold text-text-dark">
                  {eventScans.total}
                  <span className="text-xs font-semibold text-green-600 ml-2">
                    +{eventScans.today} today
                  </span>
                </p>
              )}
              <p className="text-sm text-text-muted">Event Passes Scanned</p>
            </div>
          </div>
          <div className="bg-white rounded-xl border border-border p-5 flex items-center gap-4">
            <div className="bg-orange-100 text-orange-600 p-3 rounded-lg shrink-0">
              <QrCode className="w-5 h-5" />
            </div>
            <div>
              {loading ? (
                <div className="h-6 w-10 bg-slate-200 animate-pulse rounded mb-1" />
              ) : (
                <p className="text-xl font-bold text-text-dark">{todayPasses.length}</p>
              )}
              <p className="text-sm text-text-muted">Passes Generated Today</p>
            </div>
          </div>
          <div className="bg-white rounded-xl border border-border p-5 flex items-center gap-4">
            <div className="bg-purple-100 text-purple-600 p-3 rounded-lg shrink-0">
              <Shield className="w-5 h-5" />
            </div>
            <div>
              {loading ? (
                <div className="h-6 w-10 bg-slate-200 animate-pulse rounded mb-1" />
              ) : (
                <p className="text-xl font-bold text-text-dark">{insidePasses}</p>
              )}
              <p className="text-sm text-text-muted">Currently Inside</p>
            </div>
          </div>
          <div className="bg-white rounded-xl border border-border p-5 flex items-center gap-4">
            <div className="bg-yellow-100 text-yellow-600 p-3 rounded-lg shrink-0">
              <Hourglass className="w-5 h-5" />
            </div>
            <div>
              {loading ? (
                <div className="h-6 w-10 bg-slate-200 animate-pulse rounded mb-1" />
              ) : (
                <p className="text-xl font-bold text-text-dark">{expiringToday}</p>
              )}
              <p className="text-sm text-text-muted">Passes Expiring Today</p>
            </div>
          </div>
        </div>

        {/* Recent passes log + Active visitors */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

          {/* Recent Pass Log */}
          <div className="bg-white rounded-xl border border-border p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-text-dark">Recent Pass Activity</h2>
              <button
                onClick={() => navigate('/dashboard/visitor-list')}
                className="flex items-center gap-1 text-xs text-primary font-semibold hover:underline"
              >
                View All <ArrowRight className="w-3 h-3" />
              </button>
            </div>

            {loading ? (
              <div className="space-y-3">
                {[...Array(4)].map((_, i) => (
                  <div key={i} className="h-16 bg-slate-100 animate-pulse rounded-lg" />
                ))}
              </div>
            ) : recentPasses.length === 0 ? (
              <div className="text-center py-10 text-text-muted">
                <QrCode className="w-10 h-10 mx-auto mb-2 opacity-30" />
                <p className="text-sm">No passes generated yet</p>
              </div>
            ) : (
              <div className="space-y-3">
                {recentPasses.map((pass) => (
                  <div
                    key={pass.id}
                    className="flex items-center justify-between p-4 bg-slate-50 hover:bg-slate-100 rounded-lg transition-colors"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div
                        className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm shrink-0 ${avatarColor(pass.visitorName)}`}
                      >
                        {initials(pass.visitorName)}
                      </div>
                      <div className="min-w-0">
                        <p className="font-semibold text-text-dark text-sm truncate">
                          {pass.visitorName}
                        </p>
                        <p className="text-xs text-text-muted truncate">
                          {pass.visitPurpose} · {pass.passCode}
                        </p>
                      </div>
                    </div>
                    <div className="text-right shrink-0 ml-3">
                      <StatusBadge status={pass.status} />
                      <p className="text-xs text-text-muted mt-1">
                        {timeAgo(pass.generatedAt)}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Active Visitors */}
          <div className="bg-white rounded-xl border border-border p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-text-dark">Visitors Inside</h2>
              <span className="text-xs font-semibold bg-green-100 text-green-700 px-2 py-0.5 rounded-full">
                {insidePasses} inside
              </span>
            </div>

            {loading ? (
              <div className="space-y-3">
                {[...Array(3)].map((_, i) => (
                  <div key={i} className="h-14 bg-slate-100 animate-pulse rounded-lg" />
                ))}
              </div>
            ) : visitorsInside.length === 0 ? (
              <div className="text-center py-10 text-text-muted">
                <UserX className="w-10 h-10 mx-auto mb-2 opacity-30" />
                <p className="text-sm">No visitors inside right now</p>
              </div>
            ) : (
              <div className="space-y-3">
                {visitorsInside.map((pass) => (
                  <div
                    key={pass.id}
                    className="flex items-center justify-between p-3 bg-slate-50 rounded-lg"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div
                        className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm shrink-0 ${avatarColor(pass.visitorName)}`}
                      >
                        {initials(pass.visitorName)}
                      </div>
                      <div className="min-w-0">
                        <p className="font-semibold text-text-dark text-sm truncate">
                          {pass.visitorName}
                        </p>
                        <p className="text-xs text-text-muted">
                          Entry: {formatTime(pass.checkInTime ?? pass.generatedAt)}
                        </p>
                      </div>
                    </div>
                    <div className="text-right shrink-0 ml-3">
                      <span className="px-2 py-0.5 bg-green-100 text-green-700 rounded-full text-xs font-semibold">
                        Inside
                      </span>
                      {pass.phoneNumber && (
                        <p className="text-xs text-text-muted mt-1">{pass.phoneNumber}</p>
                      )}
                    </div>
                  </div>
                ))}
                {insidePasses > 5 && (
                  <button
                    onClick={() => navigate('/dashboard/visitor-list')}
                    className="w-full text-center text-xs text-primary font-semibold hover:underline pt-1"
                  >
                    +{insidePasses - 5} more visitors inside →
                  </button>
                )}
              </div>
            )}
          </div>
        </div>

        {/* All passes table */}
        <div className="bg-white rounded-xl border border-border p-6">
          <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
            <h2 className="text-lg font-bold text-text-dark">All Visitor Passes</h2>
            <div className="flex items-center gap-3">
              <button
                onClick={() => navigate('/dashboard/visitor-list')}
                className="flex items-center gap-2 text-sm text-primary font-semibold hover:underline"
              >
                <List className="w-4 h-4" />
                Full Visitor List
              </button>
              <button
                onClick={() => navigate('/dashboard/generate-pass')}
                className="flex items-center gap-2 bg-primary text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-primary/90 transition-all"
              >
                <UserPlus className="w-4 h-4" />
                New Pass
              </button>
            </div>
          </div>

          {loading ? (
            <div className="space-y-2">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="h-12 bg-slate-100 animate-pulse rounded-lg" />
              ))}
            </div>
          ) : passes.length === 0 ? (
            <div className="text-center py-12 text-text-muted">
              <Shield className="w-12 h-12 mx-auto mb-3 opacity-20" />
              <p className="font-semibold">No visitor passes found</p>
              <p className="text-sm mt-1">Generate a pass to get started</p>
              <button
                onClick={() => navigate('/dashboard/generate-pass')}
                className="mt-4 bg-primary text-white px-5 py-2 rounded-lg text-sm font-semibold hover:bg-primary/90 transition-all"
              >
                Generate First Pass
              </button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-3 px-3 text-xs font-bold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left py-3 px-3 text-xs font-bold text-text-muted uppercase tracking-wider">Visitor</th>
                    <th className="text-left py-3 px-3 text-xs font-bold text-text-muted uppercase tracking-wider">Phone</th>
                    <th className="text-left py-3 px-3 text-xs font-bold text-text-muted uppercase tracking-wider">Purpose</th>
                    <th className="text-left py-3 px-3 text-xs font-bold text-text-muted uppercase tracking-wider">Pass Code</th>
                    <th className="text-left py-3 px-3 text-xs font-bold text-text-muted uppercase tracking-wider">Generated</th>
                    <th className="text-left py-3 px-3 text-xs font-bold text-text-muted uppercase tracking-wider">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {passes.slice(0, 10).map((pass, idx) => (
                    <tr key={pass.id} className="hover:bg-slate-50 transition-colors">
                      <td className="py-3 px-3 text-text-muted">{idx + 1}</td>
                      <td className="py-3 px-3">
                        <div className="flex items-center gap-2">
                          <div
                            className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-xs shrink-0 ${avatarColor(pass.visitorName)}`}
                          >
                            {initials(pass.visitorName)}
                          </div>
                          <span className="font-medium text-text-dark">{pass.visitorName}</span>
                        </div>
                      </td>
                      <td className="py-3 px-3 text-text-muted">{pass.phoneNumber}</td>
                      <td className="py-3 px-3 text-text-muted max-w-[140px] truncate">
                        {pass.visitPurpose}
                      </td>
                      <td className="py-3 px-3">
                        <span className="font-mono text-xs bg-slate-100 px-2 py-0.5 rounded">
                          {pass.passCode}
                        </span>
                      </td>
                      <td className="py-3 px-3 text-text-muted whitespace-nowrap">
                        {formatDate(pass.generatedAt)}
                        <span className="block text-xs opacity-70">
                          {formatTime(pass.generatedAt)}
                        </span>
                      </td>
                      <td className="py-3 px-3">
                        <StatusBadge status={pass.status} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {passes.length > 10 && (
                <div className="text-center pt-4 border-t border-border mt-2">
                  <button
                    onClick={() => navigate('/dashboard/visitor-list')}
                    className="text-sm text-primary font-semibold hover:underline"
                  >
                    View all {passes.length} passes in Visitor List →
                  </button>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Quick actions */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <button
            onClick={() => navigate('/dashboard/generate-pass')}
            className="flex items-center gap-4 p-5 bg-white border border-border rounded-xl hover:border-primary hover:shadow-md transition-all group text-left"
          >
            <div className="bg-red-100 text-red-600 p-3 rounded-lg group-hover:bg-red-600 group-hover:text-white transition-colors">
              <UserPlus className="w-5 h-5" />
            </div>
            <div>
              <p className="font-bold text-text-dark">Generate Visitor Pass</p>
              <p className="text-xs text-text-muted">Create a new entry pass</p>
            </div>
            <ArrowRight className="w-4 h-4 text-text-muted ml-auto group-hover:text-primary transition-colors" />
          </button>

          <button
            onClick={() => navigate('/dashboard/event-scanner')}
            className="flex items-center gap-4 p-5 bg-white border border-border rounded-xl hover:border-primary hover:shadow-md transition-all group text-left"
          >
            <div className="bg-indigo-100 text-indigo-600 p-3 rounded-lg group-hover:bg-indigo-600 group-hover:text-white transition-colors">
              <Ticket className="w-5 h-5" />
            </div>
            <div>
              <p className="font-bold text-text-dark">Event Scanner</p>
              <p className="text-xs text-text-muted">Scan event passes IN / OUT</p>
            </div>
            <ArrowRight className="w-4 h-4 text-text-muted ml-auto group-hover:text-primary transition-colors" />
          </button>

          <button
            onClick={() => navigate('/dashboard/verify-pass')}
            className="flex items-center gap-4 p-5 bg-white border border-border rounded-xl hover:border-primary hover:shadow-md transition-all group text-left"
          >
            <div className="bg-green-100 text-green-600 p-3 rounded-lg group-hover:bg-green-600 group-hover:text-white transition-colors">
              <ScanLine className="w-5 h-5" />
            </div>
            <div>
              <p className="font-bold text-text-dark">Verify Pass</p>
              <p className="text-xs text-text-muted">Scan & validate a pass</p>
            </div>
            <ArrowRight className="w-4 h-4 text-text-muted ml-auto group-hover:text-primary transition-colors" />
          </button>

          <button
            onClick={() => navigate('/dashboard/visitor-list')}
            className="flex items-center gap-4 p-5 bg-white border border-border rounded-xl hover:border-primary hover:shadow-md transition-all group text-left"
          >
            <div className="bg-blue-100 text-blue-600 p-3 rounded-lg group-hover:bg-blue-600 group-hover:text-white transition-colors">
              <List className="w-5 h-5" />
            </div>
            <div>
              <p className="font-bold text-text-dark">Visitor List</p>
              <p className="text-xs text-text-muted">View all visitor records</p>
            </div>
            <ArrowRight className="w-4 h-4 text-text-muted ml-auto group-hover:text-primary transition-colors" />
          </button>
        </div>

      </div>
    </UnifiedDashboardLayout>
  );
}
