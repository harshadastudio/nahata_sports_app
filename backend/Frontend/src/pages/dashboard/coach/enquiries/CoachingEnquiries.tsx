import React, { useState, useEffect, useCallback } from 'react';
import {
  MessageSquare, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Eye, X, Filter, Trash2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

type EnquiryStatus = 'Pending' | 'Reviewed' | 'Contacted' | 'Approved' | 'Rejected';

interface CoachingEnquiry {
  id: number;
  name?: string;
  email?: string;
  phone?: string;
  batch?: { id: number; name: string; fees?: number; duration?: string; maxStudents?: number; currentStudents?: number };
  sport?: { id: number; name: string };
  coach?: { id: number; name: string; email: string; phone?: string };
  status: EnquiryStatus;
  createdAt?: string;
  updatedAt?: string;
  message?: string;
  referenceNumber?: string;
  user?: { id: number; name: string; email: string; phone_number?: string };
}

interface EnquiriesResponse {
  success: boolean;
  data: {
    enquiries: CoachingEnquiry[];
    total: number;
    totalPages: number;
    page: number;
  };
}

// ── Status badge ──────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  Pending:   'bg-amber-100 text-amber-700',
  Reviewed:  'bg-blue-100 text-blue-700',
  Contacted: 'bg-purple-100 text-purple-700',
  Approved:  'bg-green-100 text-green-700',
  Rejected:  'bg-red-100 text-red-600',
};

function statusBadge(status: string) {
  const cls = STATUS_STYLES[status] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {status}
    </span>
  );
}

function formatDateTime(d?: string) {
  if (!d) return '—';
  const date = new Date(d);
  return date.toLocaleString('en-IN', { 
    day: '2-digit', 
    month: 'short', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
}

// ── View / Respond Drawer ─────────────────────────────────────────────────────

interface DrawerProps {
  enquiry: CoachingEnquiry;
  onClose: () => void;
  onStatusUpdate: (id: number, status: EnquiryStatus) => Promise<void>;
  onDelete: (id: number) => Promise<void>;
  onApprove: (enquiry: CoachingEnquiry) => Promise<void>;
}

const EnquiryDrawer: React.FC<DrawerProps> = ({ enquiry, onClose, onStatusUpdate, onDelete, onApprove }) => {
  const [updating, setUpdating] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [approving, setApproving] = useState(false);

  const isFull = enquiry.batch?.maxStudents !== undefined && enquiry.batch?.currentStudents !== undefined
    && enquiry.batch.currentStudents >= enquiry.batch.maxStudents;

  const handleApprove = async () => {
    if (!window.confirm(`Approve and enroll "${enquiry.user?.name ?? enquiry.name}" in "${enquiry.batch?.name}"?`)) return;
    setApproving(true);
    try {
      await onApprove(enquiry);
    } finally {
      setApproving(false);
    }
  };

  const name = enquiry.user?.name ?? enquiry.name ?? '—';
  const email = enquiry.user?.email ?? enquiry.email ?? '—';
  const phone = enquiry.user?.phone_number ?? enquiry.phone ?? '—';

  const handleUpdate = async (status: EnquiryStatus) => {
    setUpdating(true);
    try {
      await onStatusUpdate(enquiry.id, status);
    } finally {
      setUpdating(false);
    }
  };

  const handleDelete = async () => {
    if (!window.confirm('Are you sure you want to delete this enquiry? This action cannot be undone.')) {
      return;
    }
    setDeleting(true);
    try {
      await onDelete(enquiry.id);
      onClose();
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white w-full max-w-md h-full overflow-y-auto shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-white z-10">
          <h2 className="text-lg font-bold text-text-dark">Enquiry #{enquiry.id}</h2>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} className="text-slate-500" />
          </button>
        </div>

        <div className="flex-1 p-6 space-y-6">
          {/* Student Info */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Student</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Name</span>
                <span className="font-medium text-text-dark">{name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Email</span>
                <span className="font-medium text-text-dark">{email}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Phone</span>
                <span className="font-medium text-text-dark">{phone}</span>
              </div>
            </div>
          </section>

          {/* Enquiry Details */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Details</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Program</span>
                <span className="font-medium text-text-dark">{enquiry.batch?.name ?? '—'}</span>
              </div>
              {enquiry.sport && (
                <div className="flex justify-between">
                  <span className="text-text-muted">Sport</span>
                  <span className="font-medium text-text-dark">{enquiry.sport.name}</span>
                </div>
              )}
              {enquiry.referenceNumber && (
                <div className="flex justify-between">
                  <span className="text-text-muted">Reference</span>
                  <span className="font-medium text-text-dark">{enquiry.referenceNumber}</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-text-muted">Submitted</span>
                <span className="font-medium text-text-dark">
                  {formatDateTime(enquiry.createdAt)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Last Updated</span>
                <span className="font-medium text-text-dark">
                  {formatDateTime(enquiry.updatedAt)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Status</span>
                {statusBadge(enquiry.status)}
              </div>
            </div>
          </section>

          {/* Message */}
          {enquiry.message && (
            <section>
              <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Message</h3>
              <div className="bg-slate-50 rounded-xl p-4 text-sm text-text-dark">
                {enquiry.message}
              </div>
            </section>
          )}

          {/* Approve & Enroll */}
          {enquiry.status !== 'Approved' && enquiry.status !== 'Rejected' && (
            <section>
              <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Approve &amp; Enroll</h3>
              {enquiry.batch?.maxStudents !== undefined && enquiry.batch?.currentStudents !== undefined && (
                <p className="text-xs text-text-muted mb-2">
                  Batch capacity: {enquiry.batch.currentStudents}/{enquiry.batch.maxStudents} enrolled
                </p>
              )}
              <button
                onClick={handleApprove}
                disabled={approving || isFull}
                title={isFull ? 'Batch is full' : ''}
                className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-emerald-600 text-white rounded-xl font-medium hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {approving ? <Loader2 size={16} className="animate-spin" /> : null}
                {approving ? 'Processing...' : isFull ? 'Batch Full' : 'Approve & Enroll'}
              </button>
              <p className="text-xs text-slate-400 mt-2">
                Enrolling starts the student's fee record as Pending — Admin/Employee still need to
                separately approve it before their gate pass QR unlocks.
              </p>
            </section>
          )}

          {/* Update Status */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Update Status</h3>
            <div className="flex flex-wrap gap-2">
              {(['Reviewed', 'Contacted', 'Rejected'] as EnquiryStatus[]).map((s) => (
                <button
                  key={s}
                  disabled={updating || enquiry.status === s}
                  onClick={() => handleUpdate(s)}
                  className="px-3 py-1.5 text-xs font-medium rounded-lg border border-border hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                >
                  {updating ? <Loader2 size={12} className="animate-spin inline mr-1" /> : null}
                  Mark {s}
                </button>
              ))}
            </div>
          </section>

          {/* Delete */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Danger Zone</h3>
            <button
              onClick={handleDelete}
              disabled={deleting}
              className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-red-50 text-red-600 border border-red-200 rounded-lg hover:bg-red-100 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              {deleting ? <Loader2 size={14} className="animate-spin" /> : <Trash2 size={14} />}
              Delete Enquiry
            </button>
          </section>
        </div>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function CoachingEnquiries() {
  useAuth();

  const [enquiries, setEnquiries] = useState<CoachingEnquiry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedEnquiry, setSelectedEnquiry] = useState<CoachingEnquiry | null>(null);

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

      const res = await fetchWithAuth(`${API_BASE}/coaching-enquiries/coach/my-enquiries?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: EnquiriesResponse = await res.json();

      setEnquiries(data.data.enquiries ?? []);
      setTotal(data.data.total ?? 0);
      setTotalPages(data.data.totalPages ?? 1);
      setPage(p);
    } catch (err) {
      console.error('Failed to load enquiries:', err);
      setError('Failed to load coaching enquiries. Please try again.');
      toast.error('Failed to load enquiries');
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => { load(1); }, [load]);

  const handleStatusUpdate = async (id: number, status: EnquiryStatus) => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/coaching-enquiries/coach/${id}/status`, {
        method: 'PATCH',
        body: JSON.stringify({ status }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      toast.success(`Enquiry marked as ${status}`);
      setEnquiries((prev) =>
        prev.map((e) => (e.id === id ? { ...e, status, updatedAt: new Date().toISOString() } : e))
      );
      if (selectedEnquiry?.id === id) {
        setSelectedEnquiry((prev) => prev ? { ...prev, status, updatedAt: new Date().toISOString() } : prev);
      }
    } catch (err) {
      console.error('Failed to update enquiry status:', err);
      toast.error('Failed to update status');
      throw err;
    }
  };

  const handleApprove = async (enquiry: CoachingEnquiry) => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/coaching-enquiries/${enquiry.id}/approve-and-enroll`, {
        method: 'POST',
      });
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({ message: 'Unknown error' }));
        throw new Error(errorData.message || `HTTP ${res.status}`);
      }
      toast.success('Enquiry approved and student enrolled');
      setEnquiries((prev) =>
        prev.map((e) => (e.id === enquiry.id ? { ...e, status: 'Approved', updatedAt: new Date().toISOString() } : e))
      );
      if (selectedEnquiry?.id === enquiry.id) {
        setSelectedEnquiry((prev) => prev ? { ...prev, status: 'Approved', updatedAt: new Date().toISOString() } : prev);
      }
    } catch (err: any) {
      console.error('Failed to approve enquiry:', err);
      toast.error(err.message || 'Failed to approve enquiry');
    }
  };

  const handleDelete = async (id: number) => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/coaching-enquiries/coach/${id}`, {
        method: 'DELETE',
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      toast.success('Enquiry deleted successfully');
      setEnquiries((prev) => prev.filter((e) => e.id !== id));
      setTotal((prev) => prev - 1);
    } catch (err) {
      console.error('Failed to delete enquiry:', err);
      toast.error('Failed to delete enquiry');
      throw err;
    }
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Coaching Enquiries" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Coaching Enquiries</h1>
            <p className="text-text-muted text-sm mt-1">{total} enquir{total !== 1 ? 'ies' : 'y'} assigned to you</p>
          </div>
          <button
            onClick={() => load(page)}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
          >
            <RefreshCw size={15} /> Refresh
          </button>
        </div>

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
                <option value="Pending">Pending</option>
                <option value="Reviewed">Reviewed</option>
                <option value="Contacted">Contacted</option>
                <option value="Approved">Approved</option>
                <option value="Rejected">Rejected</option>
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
              <p className="text-text-muted text-sm">Loading enquiries…</p>
            </div>
          ) : enquiries.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <MessageSquare size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No enquiries found</p>
              <p className="text-text-muted text-sm">Try adjusting your filters or check back later.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Student Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Email</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Phone</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Program</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Date & Time</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {enquiries.map((e, idx) => {
                    const name = e.user?.name ?? e.name ?? '—';
                    const email = e.user?.email ?? e.email ?? '—';
                    const phone = e.user?.phone_number ?? e.phone ?? '—';
                    return (
                      <tr key={e.id} className="hover:bg-slate-50 transition-colors">
                        <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                        <td className="px-4 py-3 font-medium text-text-dark">{name}</td>
                        <td className="px-4 py-3 text-text-muted">{email}</td>
                        <td className="px-4 py-3 text-text-muted">{phone}</td>
                        <td className="px-4 py-3 text-text-muted">{e.batch?.name ?? '—'}</td>
                        <td className="px-4 py-3">{statusBadge(e.status)}</td>
                        <td className="px-4 py-3 text-text-muted text-xs">
                          {formatDateTime(e.createdAt)}
                        </td>
                        <td className="px-4 py-3">
                          <button
                            onClick={() => setSelectedEnquiry(e)}
                            className="flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-brand-primary border border-brand-primary/30 rounded-lg hover:bg-brand-primary/5 transition-colors"
                          >
                            <Eye size={13} /> View / Manage
                          </button>
                        </td>
                      </tr>
                    );
                  })}
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

      {/* Enquiry Drawer */}
      {selectedEnquiry && (
        <EnquiryDrawer
          enquiry={selectedEnquiry}
          onClose={() => setSelectedEnquiry(null)}
          onStatusUpdate={handleStatusUpdate}
          onDelete={handleDelete}
          onApprove={handleApprove}
        />
      )}
    </UnifiedDashboardLayout>
  );
}
