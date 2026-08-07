import React, { useState, useEffect, useCallback } from 'react';
import {
  ClipboardList, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Filter, CheckCircle, XCircle, Clock,
  Plus, X,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface AttendanceRecord {
  id: number;
  studentId?: number;
  userId?: number;
  batchId?: number;
  date: string;
  status: 'Present' | 'Absent' | 'Late';
  markedBy?: string;
  notes?: string;
  student?: { id: number; name?: string; User?: { id: number; name: string } };
  user?: { id: number; name: string };
  marker?: { id: number; name: string; role: string };
  batch?: { id: number; name: string; sport?: { name: string } };
  sport?: { name: string };
  createdAt?: string;
}

interface AttendanceResponse {
  success: boolean;
  // Direct shape (legacy)
  attendance?: AttendanceRecord[];
  total?: number;
  totalPages?: number;
  currentPage?: number;
  // Nested shape returned by attendanceController
  data?: {
    attendance: AttendanceRecord[];
    total?: number;
    totalPages?: number;
    page?: number;
    limit?: number;
  };
}

// ── Status helpers ────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, { cls: string; icon: React.ReactNode }> = {
  Present: { cls: 'bg-green-100 text-green-700', icon: <CheckCircle size={12} /> },
  Absent:  { cls: 'bg-red-100 text-red-600',    icon: <XCircle size={12} /> },
  Late:    { cls: 'bg-amber-100 text-amber-700', icon: <Clock size={12} /> },
};

function statusBadge(status: string) {
  const s = STATUS_STYLES[status] ?? { cls: 'bg-slate-100 text-slate-600', icon: null };
  return (
    <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium ${s.cls}`}>
      {s.icon} {status}
    </span>
  );
}

function formatDate(dateStr: string) {
  try {
    return new Date(dateStr).toLocaleDateString('en-IN', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
  } catch {
    return dateStr;
  }
}

// ── Mark Attendance Modal ─────────────────────────────────────────────────────

interface MarkModalProps {
  onClose: () => void;
  onSuccess: () => void;
}

const MarkAttendanceModal: React.FC<MarkModalProps> = ({ onClose, onSuccess }) => {
  const [studentId, setStudentId] = useState('');
  const [batchId, setBatchId] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [status, setStatus] = useState<'Present' | 'Absent' | 'Late'>('Present');
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [batches, setBatches] = useState<{ id: number; name: string; sport?: { name: string } }[]>([]);
  const [batchesLoading, setBatchesLoading] = useState(true);

  // Fetch batches for the dropdown on mount
  useEffect(() => {
    const fetchBatches = async () => {
      try {
        const res = await fetchWithAuth(`${API_BASE}/batches?limit=200`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        // Handle both { batches: [] } and { data: { batches: [] } } shapes
        const list = data.batches ?? data.data?.batches ?? data.data ?? [];
        setBatches(Array.isArray(list) ? list : []);
      } catch (err) {
        console.error('Failed to load batches:', err);
        toast.error('Could not load batches');
      } finally {
        setBatchesLoading(false);
      }
    };
    fetchBatches();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!studentId || !batchId || !date) {
      toast.error('Please fill in all required fields');
      return;
    }
    setSubmitting(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/attendance`, {
        method: 'POST',
        body: JSON.stringify({
          studentId: parseInt(studentId),
          batchId: parseInt(batchId),
          date,
          status,
          notes: notes || undefined,
        }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json?.message || `HTTP ${res.status}`);
      toast.success('Attendance marked successfully');
      onSuccess();
      onClose();
    } catch (err: any) {
      console.error('Failed to mark attendance:', err);
      toast.error(err.message || 'Failed to mark attendance');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-4 border-b border-border">
          <h2 className="text-lg font-bold text-text-dark">Mark Attendance</h2>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} className="text-slate-500" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-text-dark mb-1">
              Student ID <span className="text-red-500">*</span>
            </label>
            <input
              type="number"
              value={studentId}
              onChange={(e) => setStudentId(e.target.value)}
              placeholder="Enter student ID"
              required
              className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-text-dark mb-1">
              Batch <span className="text-red-500">*</span>
            </label>
            {batchesLoading ? (
              <div className="flex items-center gap-2 px-3 py-2 border border-border rounded-lg text-sm text-text-muted">
                <Loader2 size={14} className="animate-spin" /> Loading batches…
              </div>
            ) : (
              <select
                value={batchId}
                onChange={(e) => setBatchId(e.target.value)}
                required
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white"
              >
                <option value="">Select a batch</option>
                {batches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}{b.sport?.name ? ` — ${b.sport.name}` : ''}
                  </option>
                ))}
              </select>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-text-dark mb-1">
              Date <span className="text-red-500">*</span>
            </label>
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              required
              className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-text-dark mb-1">Status</label>
            <div className="flex gap-2">
              {(['Present', 'Absent', 'Late'] as const).map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setStatus(s)}
                  className={`flex-1 py-2 rounded-lg text-sm font-medium border transition-colors ${
                    status === s
                      ? 'bg-brand-primary text-white border-brand-primary'
                      : 'bg-white border-border text-slate-600 hover:bg-slate-50'
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-text-dark mb-1">Notes (optional)</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Any additional notes…"
              rows={2}
              className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary resize-none"
            />
          </div>
          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 border border-border rounded-xl text-sm font-medium text-slate-600 hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting || batchesLoading}
              className="flex-1 py-2.5 bg-brand-primary text-white rounded-xl text-sm font-medium hover:bg-brand-primary/90 disabled:opacity-60 transition-colors flex items-center justify-center gap-2"
            >
              {submitting ? <Loader2 size={15} className="animate-spin" /> : null}
              Mark Attendance
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function AttendanceManagement() {
  useAuth();

  const [records, setRecords] = useState<AttendanceRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [showMarkModal, setShowMarkModal] = useState(false);

  // Filters
  const [dateFilter, setDateFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const limit = 10;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ page: String(p), limit: String(limit) });
      if (dateFilter) params.set('date', dateFilter);
      if (statusFilter) params.set('status', statusFilter);

      const res = await fetchWithAuth(`${API_BASE}/attendance?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: AttendanceResponse = await res.json();

      // Handle both response shapes:
      // Shape A (attendanceController): { success, data: { attendance, total, totalPages, page } }
      // Shape B (legacy): { success, attendance, total, totalPages }
      const nested = data.data;
      const recordsList = nested?.attendance ?? data.attendance ?? [];
      const totalCount  = nested?.total ?? data.total ?? recordsList.length;
      const pages       = nested?.totalPages ?? data.totalPages ?? 1;

      setRecords(recordsList);
      setTotal(totalCount);
      setTotalPages(pages);
      setPage(p);
    } catch (err) {
      console.error('Failed to load attendance:', err);
      setError('Failed to load attendance records. Please try again.');
      toast.error('Failed to load attendance');
    } finally {
      setLoading(false);
    }
  }, [dateFilter, statusFilter]);

  useEffect(() => { load(1); }, [load]);

  const getStudentName = (r: AttendanceRecord) =>
    r.student?.User?.name ?? r.student?.name ?? r.user?.name ?? '—';

  const getMarkedBy = (r: AttendanceRecord) =>
    r.marker?.name ?? (typeof r.markedBy === 'string' ? r.markedBy : '—');

  const getSportBatch = (r: AttendanceRecord) => {
    const sport = r.batch?.sport?.name ?? r.sport?.name ?? '—';
    const batch = r.batch?.name;
    return batch ? `${sport} / ${batch}` : sport;
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Attendance Management" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Attendance Management</h1>
            <p className="text-text-muted text-sm mt-1">{total} record{total !== 1 ? 's' : ''} total</p>
          </div>
          {/* Attendance is marked by coaches (and at the gate on scan), so the
              employee view is read-only — the Mark Attendance action is not
              offered here. */}
          <div className="flex gap-2">
            <button
              onClick={() => load(page)}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
            >
              <RefreshCw size={15} /> Refresh
            </button>
          </div>
        </div>

        {/* Filters */}
        <div className="bg-white rounded-xl border border-border p-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter size={15} className="text-slate-400" />
            <span className="text-sm font-medium text-text-dark">Filters</span>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs text-text-muted mb-1">Date</label>
              <input
                type="date"
                value={dateFilter}
                onChange={(e) => setDateFilter(e.target.value)}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
              />
            </div>
            <div>
              <label className="block text-xs text-text-muted mb-1">Status</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white"
              >
                <option value="">All</option>
                <option value="Present">Present</option>
                <option value="Absent">Absent</option>
                <option value="Late">Late</option>
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
              onClick={() => { setDateFilter(''); setStatusFilter(''); }}
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
              <p className="text-text-muted text-sm">Loading attendance records…</p>
            </div>
          ) : records.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <ClipboardList size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No attendance records found</p>
              <p className="text-text-muted text-sm">Try adjusting your filters or mark new attendance.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Student Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Sport / Batch</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Date</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Marked By</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {records.map((r, idx) => (
                    <tr key={r.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-text-dark">{getStudentName(r)}</td>
                      <td className="px-4 py-3 text-text-muted">{getSportBatch(r)}</td>
                      <td className="px-4 py-3 text-text-muted">{formatDate(r.date)}</td>
                      <td className="px-4 py-3">{statusBadge(r.status)}</td>
                      <td className="px-4 py-3 text-text-muted">{getMarkedBy(r)}</td>
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

      {/* Mark Attendance Modal */}
      {showMarkModal && (
        <MarkAttendanceModal
          onClose={() => setShowMarkModal(false)}
          onSuccess={() => load(1)}
        />
      )}
    </UnifiedDashboardLayout>
  );
}
