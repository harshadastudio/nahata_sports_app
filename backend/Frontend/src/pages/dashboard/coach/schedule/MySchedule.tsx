import React, { useState, useEffect, useCallback } from 'react';
import {
  CalendarDays, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Eye, X, Filter, Clock, Users,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface Batch {
  id: number;
  name: string;
  program: string;
  sport: string;
  schedule: string;
  court: string;
  studentCount: number;
  maxStudents: number;
  status: string;
  startDate: string;
  endDate: string;
}

interface BatchesResponse {
  success: boolean;
  data: {
    batches: Batch[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}

// ── Status badge ──────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  Active:   'bg-green-100 text-green-700',
  Inactive: 'bg-slate-100 text-slate-600',
  Upcoming: 'bg-blue-100 text-blue-700',
  Ended:    'bg-red-100 text-red-600',
};

function statusBadge(status?: string) {
  const s = status ?? 'Active';
  const cls = STATUS_STYLES[s] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {s}
    </span>
  );
}

function formatSchedule(batch: Batch): string {
  return batch.schedule ?? '—';
}

function formatDate(d?: string) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

// ── View Drawer ───────────────────────────────────────────────────────────────

interface DrawerProps {
  batch: Batch;
  onClose: () => void;
}

const BatchDrawer: React.FC<DrawerProps> = ({ batch, onClose }) => {
  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white w-full max-w-md h-full overflow-y-auto shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-white z-10">
          <h2 className="text-lg font-bold text-text-dark">Batch Details</h2>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} className="text-slate-500" />
          </button>
        </div>

        <div className="flex-1 p-6 space-y-6">
          {/* Batch Name */}
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-brand-primary/10 flex items-center justify-center">
              <CalendarDays size={22} className="text-brand-primary" />
            </div>
            <div>
              <p className="font-bold text-text-dark text-lg">{batch.name}</p>
              <p className="text-sm text-text-muted">{batch.sport}</p>
            </div>
          </div>

          {/* Schedule */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Schedule</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Schedule</span>
                <span className="font-medium text-text-dark">{batch.schedule}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Court</span>
                <span className="font-medium text-text-dark">{batch.court}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Program</span>
                <span className="font-medium text-text-dark">{batch.program}</span>
              </div>
            </div>
          </section>

          {/* Stats */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Stats</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Students Enrolled</span>
                <span className="font-bold text-text-dark">{batch.studentCount} / {batch.maxStudents}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Status</span>
                {statusBadge(batch.status)}
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Start Date</span>
                <span className="font-medium text-text-dark">{formatDate(batch.startDate)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">End Date</span>
                <span className="font-medium text-text-dark">{formatDate(batch.endDate)}</span>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};

// ── Upcoming Sessions Calendar View ──────────────────────────────────────────

interface CalendarViewProps {
  batches: Batch[];
}

const UpcomingSessionsView: React.FC<CalendarViewProps> = ({ batches }) => {
  const today = new Date();
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Build next 7 days
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(today);
    d.setDate(today.getDate() + i);
    return d;
  });

  // Simple display - show all batches for each day
  return (
    <div className="bg-white rounded-xl border border-border p-4">
      <h2 className="text-sm font-semibold text-text-dark mb-4 flex items-center gap-2">
        <CalendarDays size={16} className="text-brand-primary" />
        Upcoming Sessions (Next 7 Days)
      </h2>
      <div className="grid grid-cols-7 gap-2">
        {days.map((d) => {
          const isToday = d.toDateString() === today.toDateString();
          return (
            <div
              key={d.toISOString()}
              className={`rounded-xl p-2 text-center min-h-[80px] ${
                isToday ? 'bg-brand-primary/10 border border-brand-primary/30' : 'bg-slate-50'
              }`}
            >
              <p className={`text-xs font-semibold mb-1 ${isToday ? 'text-brand-primary' : 'text-text-muted'}`}>
                {dayNames[d.getDay()]}
              </p>
              <p className={`text-sm font-bold mb-2 ${isToday ? 'text-brand-primary' : 'text-text-dark'}`}>
                {d.getDate()}
              </p>
              {batches.length > 0 && isToday ? (
                <div className="space-y-1">
                  {batches.slice(0, 2).map((s) => (
                    <div
                      key={s.id}
                      className="text-[10px] bg-brand-primary text-white rounded px-1 py-0.5 truncate"
                      title={s.name}
                    >
                      {s.name}
                    </div>
                  ))}
                  {batches.length > 2 && (
                    <p className="text-[10px] text-text-muted">+{batches.length - 2} more</p>
                  )}
                </div>
              ) : (
                <p className="text-[10px] text-slate-300">—</p>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function MySchedule() {
  const { user } = useAuth();

  const [batches, setBatches] = useState<Batch[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedBatch, setSelectedBatch] = useState<Batch | null>(null);

  // Filters
  const [statusFilter, setStatusFilter] = useState('');

  const limit = 10;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(p),
        limit: String(limit),
      });
      if (statusFilter) params.set('status', statusFilter);

      const res = await fetchWithAuth(`${API_BASE}/coach/dashboard/schedule/batches?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: BatchesResponse = await res.json();

      setBatches(data.data?.batches ?? []);
      setTotal(data.data?.total ?? 0);
      setTotalPages(data.data?.totalPages ?? 1);
      setPage(p);
    } catch (err) {
      console.error('Failed to load schedule:', err);
      setError('Failed to load schedule. Please try again.');
      toast.error('Failed to load schedule');
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => { load(1); }, [load]);

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="My Schedule" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">My Schedule</h1>
            <p className="text-text-muted text-sm mt-1">{total} batch{total !== 1 ? 'es' : ''} assigned</p>
          </div>
          <button
            onClick={() => load(page)}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
          >
            <RefreshCw size={15} /> Refresh
          </button>
        </div>

        {/* Calendar View */}
        {!loading && batches.length > 0 && (
          <UpcomingSessionsView batches={batches} />
        )}

        {/* Filters */}
        <div className="bg-white rounded-xl border border-border p-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter size={15} className="text-slate-400" />
            <span className="text-sm font-medium text-text-dark">Filters</span>
          </div>
          <div className="flex gap-3 flex-wrap">
            <div className="min-w-[180px]">
              <label className="block text-xs text-text-muted mb-1">Status</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white"
              >
                <option value="">All</option>
                <option value="Active">Active</option>
                <option value="Inactive">Inactive</option>
                <option value="Upcoming">Upcoming</option>
                <option value="Ended">Ended</option>
              </select>
            </div>
          </div>
          <div className="flex gap-2 mt-3">
            <button
              onClick={() => load(1)}
              className="px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              Apply Filters
            </button>
            <button
              onClick={() => setStatusFilter('')}
              className="px-4 py-2 bg-white border border-border rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors"
            >
              Clear
            </button>
          </div>
        </div>

        {/* Error */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 text-sm px-4 py-3 rounded-xl flex items-center gap-2">
            <AlertCircle size={16} /> {error}
          </div>
        )}

        {/* Table */}
        <div className="bg-white rounded-xl border border-border overflow-hidden">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Loader2 size={32} className="animate-spin text-brand-primary" />
              <p className="text-text-muted text-sm">Loading schedule…</p>
            </div>
          ) : batches.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <CalendarDays size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No batches found</p>
              <p className="text-text-muted text-sm">No batches are currently assigned to you.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Batch Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Sport</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Schedule</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Students</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {batches.map((b, idx) => (
                    <tr key={b.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-text-dark">{b.name}</td>
                      <td className="px-4 py-3 text-text-muted">{b.sport}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1 text-text-muted">
                          <Clock size={13} />
                          <span className="text-xs">{formatSchedule(b)}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1 text-text-dark font-medium">
                          <Users size={13} className="text-slate-400" />
                          {b.studentCount}
                        </div>
                      </td>
                      <td className="px-4 py-3">{statusBadge(b.status)}</td>
                      <td className="px-4 py-3">
                        <button
                          onClick={() => setSelectedBatch(b)}
                          className="flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-brand-primary border border-brand-primary/30 rounded-lg hover:bg-brand-primary/5 transition-colors"
                        >
                          <Eye size={13} /> View
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Pagination */}
        {!loading && totalPages > 1 && (
          <div className="flex items-center justify-between">
            <p className="text-xs text-text-muted">Page {page} of {totalPages}</p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => load(page - 1)}
                disabled={page <= 1}
                className="p-2 bg-white border border-border rounded-xl text-slate-400 hover:text-brand-primary hover:border-brand-primary transition-all disabled:opacity-40"
              >
                <ChevronLeft size={16} />
              </button>
              <button
                onClick={() => load(page + 1)}
                disabled={page >= totalPages}
                className="p-2 bg-white border border-border rounded-xl text-slate-400 hover:text-brand-primary hover:border-brand-primary transition-all disabled:opacity-40"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Batch Drawer */}
      {selectedBatch && (
        <BatchDrawer
          batch={selectedBatch}
          onClose={() => setSelectedBatch(null)}
        />
      )}
    </UnifiedDashboardLayout>
  );
}
