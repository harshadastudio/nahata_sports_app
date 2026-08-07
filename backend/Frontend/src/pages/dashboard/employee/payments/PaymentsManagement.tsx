import React, { useState, useEffect, useCallback } from 'react';
import {
  CreditCard, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Eye, X, Filter,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface Payment {
  id: string;
  sourceId: number;
  type: string;
  typeLabel: string;
  transactionId?: string;
  razorpayPaymentId?: string;
  razorpayOrderId?: string;
  userName: string;
  userEmail: string;
  userPhone: string;
  amount: number;
  paymentMode: string;
  status: string;
  description: string;
  venue: string;
  createdAt: string;
  date: string;
}

interface PaymentsResponse {
  success: boolean;
  data: Payment[];
  stats?: {
    totalRevenue: number;
    successCount: number;
    pendingCount: number;
    failedCount: number;
    totalCount: number;
  };
  pagination?: {
    currentPage: number;
    totalPages: number;
    totalCount: number;
    limit: number;
  };
}

// ── Status helpers ────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  Paid:     'bg-emerald-100 text-emerald-700',
  Pending:  'bg-amber-100 text-amber-700',
  Failed:   'bg-red-100 text-red-600',
  Refunded: 'bg-purple-100 text-purple-700',
};

function statusBadge(status: string) {
  const cls = STATUS_STYLES[status] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {status}
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

// ── View Drawer ───────────────────────────────────────────────────────────────

interface DrawerProps {
  payment: Payment;
  onClose: () => void;
}

const PaymentDrawer: React.FC<DrawerProps> = ({ payment, onClose }) => (
  <div className="fixed inset-0 z-50 flex justify-end">
    <div className="absolute inset-0 bg-black/40" onClick={onClose} />
    <div className="relative bg-white w-full max-w-md h-full overflow-y-auto shadow-2xl flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-white z-10">
        <h2 className="text-lg font-bold text-text-dark">Payment #{payment.id}</h2>
        <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
          <X size={18} className="text-slate-500" />
        </button>
      </div>

      <div className="flex-1 p-6 space-y-6">
        {/* User Info */}
        <section>
          <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">User</h3>
          <div className="bg-slate-50 rounded-xl p-4 space-y-1">
            <p className="font-semibold text-text-dark">{payment.userName ?? '—'}</p>
            <p className="text-sm text-text-muted">{payment.userEmail ?? '—'}</p>
            {payment.userPhone && <p className="text-sm text-text-muted">{payment.userPhone}</p>}
          </div>
        </section>

        {/* Payment Details */}
        <section>
          <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Payment Details</h3>
          <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-text-muted">Amount</span>
              <span className="font-bold text-text-dark">
                ₹{parseFloat(String(payment.amount)).toLocaleString('en-IN')}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-text-muted">Method</span>
              <span className="font-medium text-text-dark">{payment.paymentMode ?? '—'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-text-muted">Type</span>
              <span className="font-medium text-text-dark">{payment.typeLabel ?? '—'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-text-muted">Status</span>
              {statusBadge(payment.status)}
            </div>
            {payment.transactionId && (
              <div className="flex justify-between">
                <span className="text-text-muted">Transaction ID</span>
                <span className="font-mono text-xs font-medium text-text-dark break-all">{payment.transactionId}</span>
              </div>
            )}
            {payment.razorpayOrderId && (
              <div className="flex justify-between">
                <span className="text-text-muted">Order ID</span>
                <span className="font-mono text-xs font-medium text-text-dark break-all">{payment.razorpayOrderId}</span>
              </div>
            )}
            {payment.description && (
              <div className="flex justify-between">
                <span className="text-text-muted">Description</span>
                <span className="text-xs text-text-dark">{payment.description}</span>
              </div>
            )}
            {payment.venue && (
              <div className="flex justify-between">
                <span className="text-text-muted">Venue</span>
                <span className="text-xs text-text-dark">{payment.venue}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span className="text-text-muted">Date</span>
              <span className="font-medium text-text-dark">{formatDate(payment.createdAt)}</span>
            </div>
          </div>
        </section>
      </div>
    </div>
  </div>
);

// ── Main Component ────────────────────────────────────────────────────────────

export default function PaymentsManagement() {
  useAuth();

  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedPayment, setSelectedPayment] = useState<Payment | null>(null);
  const [statusFilter, setStatusFilter] = useState('');

  const limit = 10;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ page: String(p), limit: String(limit) });
      if (statusFilter) params.set('status', statusFilter);

      const res = await fetchWithAuth(`${API_BASE}/payments/all?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: PaymentsResponse = await res.json();

      setPayments(data.data ?? []);
      setTotal(data.pagination?.totalCount ?? 0);
      setTotalPages(data.pagination?.totalPages ?? 1);
      setPage(p);
    } catch (err) {
      console.error('Failed to load payments:', err);
      setError('Failed to load payments. Please try again.');
      toast.error('Failed to load payments');
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => { load(1); }, [load]);

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Payments Management" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Payments Management</h1>
            <p className="text-text-muted text-sm mt-1">{total} payment{total !== 1 ? 's' : ''} total</p>
          </div>
          <button
            onClick={() => load(page)}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
          >
            <RefreshCw size={15} /> Refresh
          </button>
        </div>

        {/* Filter */}
        <div className="bg-white rounded-xl border border-border p-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter size={15} className="text-slate-400" />
            <span className="text-sm font-medium text-text-dark">Filter by Status</span>
          </div>
          <div className="flex gap-2 flex-wrap">
            {['', 'Paid', 'Pending', 'Failed', 'Refunded'].map((s) => (
              <button
                key={s || 'all'}
                onClick={() => setStatusFilter(s)}
                className={`px-4 py-2 rounded-lg text-sm font-medium border transition-colors ${
                  statusFilter === s
                    ? 'bg-brand-primary text-white border-brand-primary'
                    : 'bg-white border-border text-slate-600 hover:bg-slate-50'
                }`}
              >
                {s || 'All'}
              </button>
            ))}
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
              <p className="text-text-muted text-sm">Loading payments…</p>
            </div>
          ) : payments.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <CreditCard size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No payments found</p>
              <p className="text-text-muted text-sm">Try adjusting your filters.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">User</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Amount</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Payment Method</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Transaction ID</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Date</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {payments.map((p, idx) => (
                    <tr key={p.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="font-medium text-text-dark">{p.userName ?? '—'}</p>
                          <p className="text-xs text-text-muted">{p.userEmail ?? '—'}</p>
                        </div>
                      </td>
                      <td className="px-4 py-3 font-semibold text-text-dark">
                        ₹{parseFloat(String(p.amount)).toLocaleString('en-IN')}
                      </td>
                      <td className="px-4 py-3 text-text-muted">{p.paymentMode ?? '—'}</td>
                      <td className="px-4 py-3">{statusBadge(p.status)}</td>
                      <td className="px-4 py-3 font-mono text-xs text-text-muted max-w-[140px] truncate">
                        {p.transactionId ?? '—'}
                      </td>
                      <td className="px-4 py-3 text-text-muted">{formatDate(p.createdAt)}</td>
                      <td className="px-4 py-3">
                        <button
                          onClick={() => setSelectedPayment(p)}
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

      {/* Payment Drawer */}
      {selectedPayment && (
        <PaymentDrawer payment={selectedPayment} onClose={() => setSelectedPayment(null)} />
      )}
    </UnifiedDashboardLayout>
  );
}
