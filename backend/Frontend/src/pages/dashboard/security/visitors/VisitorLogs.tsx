import React, { useState, useEffect, useCallback } from 'react';
import {
  Users,
  RefreshCw,
  Loader2,
  AlertCircle,
  ChevronLeft,
  ChevronRight,
  Eye,
  X,
  Filter,
  Download,
  UserPlus,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { VisitorPassModal } from '../../../../components/security/VisitorPassModal';
import {
  type VisitorPass,
  VisitorPassStatusBadge,
  getPassStatusMeta,
  formatDateTime,
} from '../../../../components/security/visitorPass';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types ─────────────────────────────────────────────────────────────────────

interface VisitorPassesResponse {
  success: boolean;
  data?: VisitorPass[];
  passes?: VisitorPass[];
  total?: number;
  totalPages?: number;
  currentPage?: number;
}

interface GeneratePassForm {
  visitorName: string;
  phoneNumber: string;
  visitPurpose: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
// Status rendering, date parsing and sharing live in components/security/visitorPass.

// ── Generate Pass Modal ───────────────────────────────────────────────────────

interface GenerateModalProps {
  onClose: () => void;
  onSuccess: () => void;
}

const GeneratePassModal: React.FC<GenerateModalProps> = ({ onClose, onSuccess }) => {
  const [form, setForm] = useState<GeneratePassForm>({
    visitorName: '',
    phoneNumber: '',
    visitPurpose: 'Sports Activity',
  });
  const [submitting, setSubmitting] = useState(false);
  const [errors, setErrors] = useState<Partial<GeneratePassForm>>({});

  const validate = (): boolean => {
    const newErrors: Partial<GeneratePassForm> = {};
    if (!form.visitorName.trim()) newErrors.visitorName = 'Visitor name is required';
    if (!form.phoneNumber.trim()) {
      newErrors.phoneNumber = 'Phone number is required';
    } else if (!/^\d{10}$/.test(form.phoneNumber.trim())) {
      newErrors.phoneNumber = 'Phone number must be exactly 10 digits';
    }
    if (!form.visitPurpose) newErrors.visitPurpose = 'Visit purpose is required';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/visitor-passes`, {
        method: 'POST',
        body: JSON.stringify({
          visitorName: form.visitorName.trim(),
          phoneNumber: form.phoneNumber.trim(),
          visitPurpose: form.visitPurpose,
        }),
      });

      if (res.ok) {
        toast.success('Visitor pass generated successfully');
        onSuccess();
        onClose();
      } else {
        const data = await res.json();
        toast.error(data.message || 'Failed to generate pass');
      }
    } catch {
      toast.error('Unable to connect to server');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-md">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border">
          <h2 className="text-lg font-bold text-text-dark">Generate Visitor Pass</h2>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-slate-100 transition-colors"
          >
            <X size={18} className="text-slate-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {/* Visitor Name */}
          <div>
            <label className="block text-sm font-semibold text-text-dark mb-1">
              Visitor Name <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={form.visitorName}
              onChange={(e) => setForm({ ...form, visitorName: e.target.value })}
              placeholder="Enter visitor name"
              className={`w-full px-3 py-2.5 border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all ${errors.visitorName ? 'border-red-400' : 'border-border'}`}
            />
            {errors.visitorName && (
              <p className="text-xs text-red-500 mt-1">{errors.visitorName}</p>
            )}
          </div>

          {/* Phone Number */}
          <div>
            <label className="block text-sm font-semibold text-text-dark mb-1">
              Phone Number <span className="text-red-500">*</span>
            </label>
            <input
              type="tel"
              value={form.phoneNumber}
              onChange={(e) => setForm({ ...form, phoneNumber: e.target.value.replace(/\D/g, '').slice(0, 10) })}
              placeholder="10-digit phone number"
              className={`w-full px-3 py-2.5 border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all ${errors.phoneNumber ? 'border-red-400' : 'border-border'}`}
            />
            {errors.phoneNumber && (
              <p className="text-xs text-red-500 mt-1">{errors.phoneNumber}</p>
            )}
          </div>

          {/* Visit Purpose */}
          <div>
            <label className="block text-sm font-semibold text-text-dark mb-1">
              Visit Purpose <span className="text-red-500">*</span>
            </label>
            <select
              value={form.visitPurpose}
              onChange={(e) => setForm({ ...form, visitPurpose: e.target.value })}
              className="w-full px-3 py-2.5 border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white transition-all"
            >
              <option>Sports Activity</option>
              <option>Meeting</option>
              <option>Event</option>
              <option>Training</option>
              <option>Maintenance</option>
              <option>Other</option>
            </select>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2.5 border border-border rounded-xl text-sm font-semibold text-slate-600 hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-brand-primary text-white rounded-xl text-sm font-semibold hover:bg-brand-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              {submitting ? (
                <Loader2 size={15} className="animate-spin" />
              ) : (
                <UserPlus size={15} />
              )}
              {submitting ? 'Generating…' : 'Generate Pass'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * VisitorLogs - Visitor pass management page for SECURITY role
 *
 * Displays a paginated table of visitor passes with filtering by date and
 * status. Supports viewing full pass details in a drawer, exporting CSV,
 * and generating new passes via a modal.
 *
 * Validates: Requirements 6.4, 8.3, 9.2, 13.1
 */
export default function VisitorLogs() {
  useAuth();

  const [passes, setPasses] = useState<VisitorPass[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedPass, setSelectedPass] = useState<VisitorPass | null>(null);
  const [showGenerateModal, setShowGenerateModal] = useState(false);

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

      const res = await fetchWithAuth(`${API_BASE}/visitor-passes?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: VisitorPassesResponse = await res.json();

      const list = data.data ?? data.passes ?? [];
      setPasses(list);
      setTotal(data.total ?? list.length);
      setTotalPages(data.totalPages ?? 1);
      setPage(p);
    } catch (err) {
      console.error('Failed to load visitor passes:', err);
      setError('Failed to load visitor passes. Please try again.');
      toast.error('Failed to load visitor passes');
    } finally {
      setLoading(false);
    }
  }, [dateFilter, statusFilter]);

  useEffect(() => { load(1); }, [load]);

  // Export CSV
  const handleExportCSV = () => {
    if (passes.length === 0) {
      toast.error('No data to export');
      return;
    }

    const headers = ['#', 'Visitor Name', 'Phone', 'Purpose', 'Pass Code', 'Status', 'Generated At', 'Checked In', 'Checked Out'];
    const rows = passes.map((p, idx) => [
      idx + 1,
      p.visitorName,
      p.phoneNumber ?? '',
      p.visitPurpose,
      p.passCode,
      getPassStatusMeta(p.status).label,
      formatDateTime(p.generatedAt),
      p.checkInTime ? formatDateTime(p.checkInTime) : '',
      p.checkOutTime ? formatDateTime(p.checkOutTime) : '',
    ]);

    const csv = [headers, ...rows]
      .map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      .join('\n');

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `visitor-logs-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    toast.success('CSV exported successfully');
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Visitor Logs" />}
    >
      <div className="space-y-6">

        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Visitor Logs</h1>
            <p className="text-text-muted text-sm mt-1">
              {total} visitor pass{total !== 1 ? 'es' : ''} total
            </p>
          </div>
          <div className="flex items-center gap-3 flex-wrap">
            <button
              onClick={handleExportCSV}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
            >
              <Download size={15} /> Export CSV
            </button>
            <button
              onClick={() => setShowGenerateModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-brand-primary text-white rounded-xl text-sm font-semibold hover:bg-brand-primary/90 transition-all"
            >
              <UserPlus size={15} /> Generate Pass
            </button>
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
                <option value="">All Statuses</option>
                <option value="active">Active</option>
                <option value="checked_in">Checked In</option>
                <option value="checked_out">Checked Out</option>
                <option value="expired">Expired</option>
                <option value="cancelled">Cancelled</option>
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
              <p className="text-text-muted text-sm">Loading visitor logs…</p>
            </div>
          ) : passes.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Users size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No visitor passes found</p>
              <p className="text-text-muted text-sm">Try adjusting your filters or generate a new pass.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Visitor Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Phone</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Purpose</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Pass Code</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Generated At</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Checked In</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Checked Out</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {passes.map((p, idx) => (
                    <tr
                      key={p.id}
                      onClick={() => setSelectedPass(p)}
                      title={`View pass ${p.passCode}`}
                      className="hover:bg-slate-50 cursor-pointer transition-colors"
                    >
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-text-dark">{p.visitorName}</td>
                      <td className="px-4 py-3 text-text-muted">{p.phoneNumber ?? '—'}</td>
                      <td className="px-4 py-3 text-text-muted max-w-[140px] truncate">{p.visitPurpose}</td>
                      <td className="px-4 py-3">
                        <span className="font-mono text-xs bg-slate-100 px-2 py-0.5 rounded">
                          {p.passCode}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <VisitorPassStatusBadge status={p.status} />
                      </td>
                      <td className="px-4 py-3 text-text-muted whitespace-nowrap text-xs">
                        {formatDateTime(p.generatedAt)}
                      </td>
                      <td className="px-4 py-3 text-text-muted whitespace-nowrap text-xs">
                        {p.checkInTime ? formatDateTime(p.checkInTime) : '—'}
                      </td>
                      <td className="px-4 py-3 text-text-muted whitespace-nowrap text-xs">
                        {p.checkOutTime ? formatDateTime(p.checkOutTime) : '—'}
                      </td>
                      <td className="px-4 py-3">
                        <button
                          onClick={(e) => { e.stopPropagation(); setSelectedPass(p); }}
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

      {/* Pass viewer + share */}
      <VisitorPassModal
        pass={selectedPass}
        onClose={() => setSelectedPass(null)}
        onRefreshed={(fresh) =>
          setPasses((prev) =>
            prev.map((p) => (String(p.id) === String(fresh.id) ? { ...p, ...fresh } : p))
          )
        }
      />

      {/* Generate Pass Modal */}
      {showGenerateModal && (
        <GeneratePassModal
          onClose={() => setShowGenerateModal(false)}
          onSuccess={() => load(1)}
        />
      )}
    </UnifiedDashboardLayout>
  );
}
