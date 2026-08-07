import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  CalendarRange, Search, RefreshCw, Loader2, AlertCircle, Users,
  ChevronLeft, ChevronRight, ChevronDown, GraduationCap, Trophy,
  Clock, IndianRupee, X, UserPlus, Repeat, CalendarClock, Download,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface EnrolledStudent {
  enrollmentId: number;
  id: number;
  name: string;
  email: string;
  phone: string;
  enrollmentDate: string;
  /** Effective validity — the student's own valid-till, else the batch end date. */
  validTill: string | null;
  validTillSource: 'enrollment' | 'batch' | null;
  /** Joined during the selected month (vs. carried over from an earlier one). */
  isNew: boolean;
  /** Validity runs out inside the selected month — renewal due. */
  expiring: boolean;
  status: string;
  paymentStatus: string;
  approvalStatus: string;
  amountPaid: number;
  feesPaid: boolean;
}

interface BatchGroup {
  id: number;
  name: string;
  sport: string;
  schedule: string;
  days: string;
  startTime: string | null;
  endTime: string | null;
  batchStatus: string;
  fees: number | null;
  maxStudents: number | null;
  count: number;
  newCount: number;
  students: EnrolledStudent[];
}

interface Summary {
  totalStudents: number;
  totalBatches: number;
  newThisMonth: number;
  continuing: number;
  expiring: number;
  active: number;
  paid: number;
  pending: number;
}

interface MonthOption {
  month: string;
  label: string;
  count: number;
}

interface EnrollmentsResponse {
  success: boolean;
  data: {
    month: string;
    label: string;
    months: MonthOption[];
    summary: Summary;
    batches: BatchGroup[];
  };
}

const EMPTY_SUMMARY: Summary = {
  totalStudents: 0, totalBatches: 0, newThisMonth: 0,
  continuing: 0, expiring: 0, active: 0, paid: 0, pending: 0,
};

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  Active:      'bg-green-100 text-green-700',
  Completed:   'bg-blue-100 text-blue-700',
  Dropped:     'bg-red-100 text-red-700',
  Transferred: 'bg-purple-100 text-purple-700',
  Suspended:   'bg-amber-100 text-amber-700',
};

const PAYMENT_STYLES: Record<string, string> = {
  Paid:    'bg-emerald-100 text-emerald-700',
  Pending: 'bg-amber-100 text-amber-700',
  Partial: 'bg-orange-100 text-orange-700',
  Overdue: 'bg-red-100 text-red-700',
};

function badge(value: string | undefined, styles: Record<string, string>) {
  const v = value || '—';
  const cls = styles[v] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {v}
    </span>
  );
}

function formatDate(d?: string | null) {
  if (!d) return '—';
  const dt = new Date(d.length <= 10 ? `${d}T00:00:00` : d);
  if (Number.isNaN(dt.getTime())) return d;
  return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function formatTime(t?: string | null) {
  if (!t) return null;
  const [h, m] = t.split(':').map(Number);
  if (Number.isNaN(h)) return t;
  return `${h % 12 || 12}:${String(m ?? 0).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
}

/** YYYY-MM for "now", used as the default month before the API answers. */
function thisMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/** Step a YYYY-MM key by ±n months. */
function shiftMonth(key: string, delta: number) {
  const [y, m] = key.split('-').map(Number);
  const dt = new Date(y, (m - 1) + delta, 1);
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}`;
}

function monthLabel(key: string) {
  if (!/^\d{4}-\d{2}$/.test(key)) return key;
  const [y, m] = key.split('-').map(Number);
  return new Date(y, m - 1, 1).toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

const Stat: React.FC<{ icon: React.ReactNode; label: string; value: React.ReactNode; accent: string }> = ({
  icon, label, value, accent,
}) => (
  <div className="bg-white rounded-xl border border-border p-4 flex items-center gap-3">
    <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${accent}`}>{icon}</div>
    <div className="min-w-0">
      <p className="text-[10px] font-semibold uppercase tracking-wider text-slate-400">{label}</p>
      <p className="text-xl font-bold text-text-dark leading-tight">{value}</p>
    </div>
  </div>
);

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * StudentEnrollments (COACH) — month-wise view of who is enrolled in which batch.
 *
 * My Students answers "who is in my batches right now"; this screen answers
 * "who was enrolled during <month>", grouped batch-wise. A student shows up in
 * every month their enrollment is live — flagged New in the month they joined
 * and Continuing afterwards — so a coach can see both intake and the standing
 * roster per month, and export it as CSV.
 */
export default function StudentEnrollments() {
  /** Month the API was asked for; null means "pick the newest month with data". */
  const [monthParam, setMonthParam] = useState<string | null>(null);
  /** Month currently on screen — display only, so echoing it back never refetches. */
  const [month, setMonth] = useState<string>(thisMonth());
  const [months, setMonths] = useState<MonthOption[]>([]);
  const [batches, setBatches] = useState<BatchGroup[]>([]);
  const [summary, setSummary] = useState<Summary>(EMPTY_SUMMARY);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [appliedSearch, setAppliedSearch] = useState('');
  const [collapsed, setCollapsed] = useState<Record<number, boolean>>({});

  const load = useCallback(async (targetMonth: string | null, searchTerm: string) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      if (targetMonth) params.set('month', targetMonth);
      if (searchTerm.trim()) params.set('search', searchTerm.trim());

      const res = await fetchWithAuth(`${API_BASE}/coach/dashboard/students/enrollments-by-month?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json: EnrollmentsResponse = await res.json();

      setMonths(json.data?.months ?? []);
      setBatches(json.data?.batches ?? []);
      setSummary(json.data?.summary ?? EMPTY_SUMMARY);
      if (json.data?.month) setMonth(json.data.month);
    } catch (err) {
      console.error('Failed to load enrollments:', err);
      setError('Failed to load student enrollments. Please try again.');
      toast.error('Failed to load enrollments');
    } finally {
      setLoading(false);
    }
  }, []);

  // First load (monthParam === null) lets the API pick the newest month that
  // actually has enrollments; every later load asks for an explicit month.
  useEffect(() => {
    load(monthParam, appliedSearch);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [monthParam, appliedSearch]);

  const pickMonth = (key: string) => {
    setMonth(key);
    setMonthParam(key);
  };

  const goMonth = (delta: number) => pickMonth(shiftMonth(month, delta));

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setAppliedSearch(search);
  };

  const clearSearch = () => {
    setSearch('');
    setAppliedSearch('');
  };

  const toggleBatch = (id: number) =>
    setCollapsed((prev) => ({ ...prev, [id]: !prev[id] }));

  /**
   * Export the month on screen as one flat CSV row per student, batch columns
   * repeated, so it opens straight into Excel/Sheets and pivots cleanly.
   */
  const handleExportCSV = () => {
    if (batches.length === 0) {
      toast.error('No enrollments to export');
      return;
    }

    const headers = [
      '#', 'Batch', 'Sport', 'Days', 'Timing', 'Batch Fees',
      'Student', 'Email', 'Phone', 'Enrolled On', 'Valid Till', 'Validity Source',
      'Type', 'Expiring This Month', 'Status', 'Payment', 'Amount Paid', 'Approval',
    ];

    let n = 0;
    const rows = batches.flatMap((b) =>
      b.students.map((s) => {
        n += 1;
        return [
          n,
          b.name,
          b.sport,
          b.days || '',
          b.startTime ? `${formatTime(b.startTime)}${b.endTime ? ` - ${formatTime(b.endTime)}` : ''}` : b.schedule || '',
          b.fees ?? '',
          s.name,
          s.email || '',
          s.phone || '',
          formatDate(s.enrollmentDate),
          s.validTill ? formatDate(s.validTill) : 'Ongoing',
          s.validTillSource === 'batch' ? 'Batch end date' : s.validTillSource === 'enrollment' ? 'Student' : '',
          s.isNew ? 'New' : 'Continuing',
          s.expiring ? 'Yes' : 'No',
          s.status,
          s.paymentStatus,
          s.amountPaid,
          s.approvalStatus,
        ];
      })
    );

    const csv = [headers, ...rows]
      .map((row) => row.map((cell) => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
      .join('\n');

    // The BOM keeps Excel from mangling names with non-ASCII characters.
    const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `student-enrollments-${month}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    toast.success(`Exported ${rows.length} student${rows.length !== 1 ? 's' : ''}`);
  };

  /** Month strip: months that have data, newest first, capped for width. */
  const monthChips = useMemo(() => months.slice(0, 12), [months]);

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Student Enrollments" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Student Enrollments</h1>
            <p className="text-text-muted text-sm mt-1">
              Students active in your batches during <span className="font-semibold">{monthLabel(month)}</span>, grouped
              batch-wise — new joiners plus everyone whose enrollment is still valid that month.
            </p>
          </div>
          <div className="flex items-center gap-3 flex-wrap">
            <button
              onClick={handleExportCSV}
              disabled={loading || batches.length === 0}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all disabled:opacity-50 disabled:hover:text-slate-600 disabled:hover:border-border"
              title={`Export ${monthLabel(month)} as CSV`}
            >
              <Download size={15} /> Export CSV
            </button>
            <button
              onClick={() => load(month, appliedSearch)}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
            >
              <RefreshCw size={15} /> Refresh
            </button>
          </div>
        </div>

        {/* Month picker */}
        <div className="bg-white rounded-xl border border-border p-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex items-center gap-2">
              <CalendarRange size={16} className="text-brand-primary" />
              <span className="text-sm font-medium text-text-dark">Month</span>
            </div>

            <div className="flex items-center gap-1">
              <button
                onClick={() => goMonth(-1)}
                className="p-2 bg-white border border-border rounded-lg text-slate-400 hover:text-brand-primary hover:border-brand-primary transition-all"
                title="Previous month"
              >
                <ChevronLeft size={16} />
              </button>
              <input
                type="month"
                value={month}
                onChange={(e) => e.target.value && pickMonth(e.target.value)}
                className="px-3 py-2 border border-border rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
              />
              <button
                onClick={() => goMonth(1)}
                className="p-2 bg-white border border-border rounded-lg text-slate-400 hover:text-brand-primary hover:border-brand-primary transition-all"
                title="Next month"
              >
                <ChevronRight size={16} />
              </button>
            </div>

            <button
              onClick={() => pickMonth(thisMonth())}
              className="px-3 py-2 bg-slate-50 border border-border rounded-lg text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors"
            >
              This Month
            </button>

            {/* Search */}
            <form onSubmit={handleSearch} className="flex gap-2 ml-auto">
              <div className="relative">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  placeholder="Search name, email or phone…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="w-full sm:w-64 pl-9 pr-4 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                />
              </div>
              <button
                type="submit"
                className="px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 transition-colors"
              >
                Search
              </button>
              {appliedSearch && (
                <button
                  type="button"
                  onClick={clearSearch}
                  className="px-3 py-2 bg-white border border-border rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors"
                  title="Clear search"
                >
                  <X size={15} />
                </button>
              )}
            </form>
          </div>

          {/* Months that actually have enrollments */}
          {monthChips.length > 0 && (
            <div className="flex items-center gap-2 overflow-x-auto pb-1">
              <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400 shrink-0 pr-1">
                Months with students
              </span>
              {monthChips.map((m) => (
                <button
                  key={m.month}
                  onClick={() => pickMonth(m.month)}
                  className={`shrink-0 px-3 py-1.5 rounded-full text-xs font-semibold border transition-all ${
                    m.month === month
                      ? 'bg-brand-primary text-white border-brand-primary'
                      : 'bg-white text-slate-600 border-border hover:border-brand-primary hover:text-brand-primary'
                  }`}
                >
                  {m.label}
                  <span
                    className={`ml-2 px-1.5 py-0.5 rounded-full text-[10px] ${
                      m.month === month ? 'bg-white/25' : 'bg-slate-100 text-slate-500'
                    }`}
                  >
                    {m.count}
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Summary */}
        <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
          <Stat
            icon={<Users size={18} className="text-brand-primary" />}
            label="Students"
            value={summary.totalStudents}
            accent="bg-brand-primary/10"
          />
          <Stat
            icon={<UserPlus size={18} className="text-emerald-600" />}
            label="New This Month"
            value={summary.newThisMonth}
            accent="bg-emerald-100"
          />
          <Stat
            icon={<Repeat size={18} className="text-indigo-600" />}
            label="Continuing"
            value={summary.continuing}
            accent="bg-indigo-100"
          />
          <Stat
            icon={<CalendarClock size={18} className="text-rose-600" />}
            label="Expiring"
            value={summary.expiring}
            accent="bg-rose-100"
          />
          <Stat
            icon={<IndianRupee size={18} className="text-amber-600" />}
            label="Fees Pending"
            value={summary.pending}
            accent="bg-amber-100"
          />
        </div>

        {/* Error */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 text-sm px-4 py-3 rounded-xl flex items-center gap-2">
            <AlertCircle size={16} /> {error}
          </div>
        )}

        {/* Batch groups */}
        {loading ? (
          <div className="bg-white rounded-xl border border-border flex flex-col items-center justify-center py-20 gap-3">
            <Loader2 size={32} className="animate-spin text-brand-primary" />
            <p className="text-text-muted text-sm">Loading enrollments…</p>
          </div>
        ) : batches.length === 0 ? (
          <div className="bg-white rounded-xl border border-border flex flex-col items-center justify-center py-20 gap-3">
            <CalendarRange size={40} className="text-slate-300" />
            <p className="font-semibold text-text-dark">No active enrollments in {monthLabel(month)}</p>
            <p className="text-text-muted text-sm">
              {appliedSearch
                ? 'No student matches your search in this month.'
                : 'Nobody joined and nobody’s enrollment is still valid this month. Pick another month above.'}
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {batches.map((batch) => {
              const isCollapsed = collapsed[batch.id];
              const timing = batch.startTime
                ? `${formatTime(batch.startTime)}${batch.endTime ? ` – ${formatTime(batch.endTime)}` : ''}`
                : batch.schedule || '';

              return (
                <div key={batch.id} className="bg-white rounded-xl border border-border overflow-hidden">
                  {/* Batch header */}
                  <button
                    onClick={() => toggleBatch(batch.id)}
                    className="w-full flex items-center gap-3 px-4 py-4 hover:bg-slate-50 transition-colors text-left"
                  >
                    <div className="w-10 h-10 rounded-xl bg-brand-primary/10 flex items-center justify-center shrink-0">
                      <GraduationCap size={18} className="text-brand-primary" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-text-dark truncate">{batch.name}</p>
                      <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-text-muted mt-0.5">
                        <span className="inline-flex items-center gap-1">
                          <Trophy size={12} /> {batch.sport}
                        </span>
                        {batch.days && <span>{batch.days}</span>}
                        {timing && (
                          <span className="inline-flex items-center gap-1">
                            <Clock size={12} /> {timing}
                          </span>
                        )}
                        {batch.fees != null && (
                          <span className="inline-flex items-center gap-1">
                            <IndianRupee size={12} /> {batch.fees}
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="shrink-0 flex items-center gap-2">
                      {batch.newCount > 0 && (
                        <span className="px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700 text-xs font-bold">
                          +{batch.newCount} new
                        </span>
                      )}
                      <span className="px-2.5 py-1 rounded-full bg-brand-primary/10 text-brand-primary text-xs font-bold">
                        {batch.count} student{batch.count !== 1 ? 's' : ''}
                      </span>
                    </div>
                    <ChevronDown
                      size={18}
                      className={`shrink-0 text-slate-400 transition-transform ${isCollapsed ? '-rotate-90' : ''}`}
                    />
                  </button>

                  {/* Students */}
                  {!isCollapsed && (
                    <div className="overflow-x-auto border-t border-border">
                      <table className="w-full text-sm">
                        <thead>
                          <tr className="bg-slate-50 border-b border-border">
                            <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                            <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Student</th>
                            <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Phone</th>
                            <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Enrolled On</th>
                            <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Valid Till</th>
                            <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                            <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Payment</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                          {batch.students.map((s, idx) => (
                            <tr key={s.enrollmentId} className="hover:bg-slate-50 transition-colors">
                              <td className="px-4 py-3 text-text-muted">{idx + 1}</td>
                              <td className="px-4 py-3">
                                <div className="flex items-center gap-2">
                                  <p className="font-medium text-text-dark">{s.name}</p>
                                  {s.isNew ? (
                                    <span className="inline-flex items-center px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 text-[10px] font-bold uppercase tracking-wider">
                                      New
                                    </span>
                                  ) : (
                                    <span className="inline-flex items-center px-2 py-0.5 rounded-full bg-slate-100 text-slate-500 text-[10px] font-bold uppercase tracking-wider">
                                      Continuing
                                    </span>
                                  )}
                                </div>
                                {s.email && <p className="text-xs text-text-muted">{s.email}</p>}
                              </td>
                              <td className="px-4 py-3 text-text-muted">{s.phone || '—'}</td>
                              <td className="px-4 py-3 text-text-muted">{formatDate(s.enrollmentDate)}</td>
                              <td className="px-4 py-3">
                                {s.validTill ? (
                                  <div className={s.expiring ? 'text-rose-600 font-semibold' : 'text-text-muted'}>
                                    {formatDate(s.validTill)}
                                    {s.expiring && (
                                      <p className="text-[10px] font-bold uppercase tracking-wider">Expires this month</p>
                                    )}
                                    {s.validTillSource === 'batch' && !s.expiring && (
                                      <p className="text-[10px] text-slate-400">from batch end date</p>
                                    )}
                                  </div>
                                ) : (
                                  <span className="text-text-muted">Ongoing</span>
                                )}
                              </td>
                              <td className="px-4 py-3">{badge(s.status, STATUS_STYLES)}</td>
                              <td className="px-4 py-3">{badge(s.paymentStatus, PAYMENT_STYLES)}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </UnifiedDashboardLayout>
  );
}
