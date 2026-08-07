import React, { useState, useEffect, useCallback } from 'react';
import {
  CheckCircle2, Users, AlertCircle, Eye, RefreshCw, Loader2,
  X as CloseIcon, Check, MessageCircle,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { motion, AnimatePresence } from 'motion/react';
import { cn } from '../../../../lib/utils';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface FeeRecord {
  id: number;
  studentId: number;
  batchId: number;
  enrollmentDate: string;
  paymentStatus: 'Paid' | 'Pending' | 'Partial' | 'Overdue';
  approvalStatus?: 'Pending' | 'Approved' | 'Rejected';
  amountPaid: number;
  paymentMode?: string;
  notes?: string;
  student?: {
    User?: {
      name: string;
      email: string;
      phone_number: string;
    };
  };
  batch?: {
    name: string;
    fees: number;
    sport?: {
      name: string;
    };
  };
}

// Fees a coach recorded, awaiting (or already given) Admin/Employee approval.
// Employees can only Approve/Reject here — recording the fee itself stays with
// the coach; approving is what unlocks the student's gate pass.

export default function EmployeeFeesApproval() {
  const [fees, setFees] = useState<FeeRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedRecord, setSelectedRecord] = useState<FeeRecord | null>(null);
  const [isDetailsOpen, setIsDetailsOpen] = useState(false);
  const [statusFilter, setStatusFilter] = useState<string>('Pending');
  const [stats, setStats] = useState({ total: 0, paid: 0, unpaid: 0, pendingApproval: 0 });
  const [statsLoading, setStatsLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  const pageSize = 10;

  const loadStats = useCallback(async () => {
    setStatsLoading(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/fees/stats`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();
      if (result.success && result.data) {
        setStats({
          total: result.data.total || 0,
          paid: result.data.paid || 0,
          unpaid: result.data.unpaid || 0,
          pendingApproval: result.data.pendingApproval || 0,
        });
      }
    } catch (err) {
      console.error('Failed to load stats:', err);
    } finally {
      setStatsLoading(false);
    }
  }, []);

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(p),
        limit: String(pageSize),
      });
      if (searchTerm.trim()) params.set('search', searchTerm.trim());
      if (statusFilter) params.set('approvalStatus', statusFilter);

      const res = await fetchWithAuth(`${API_BASE}/fees?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();

      let feesData: FeeRecord[] = [];
      let totalRecords = 0;

      if (result.success) {
        if (Array.isArray(result.data)) {
          feesData = result.data;
          totalRecords = result.total || result.data.length;
        } else if (result.data && Array.isArray(result.data.fees)) {
          feesData = result.data.fees;
          totalRecords = result.data.total || result.data.fees.length;
        }
      }

      setFees(feesData);
      setTotal(totalRecords);
      setCurrentPage(p);
    } catch (err) {
      console.error('Failed to load fees:', err);
      setError('Failed to load fee records. Please try again.');
      toast.error('Failed to load fee records');
    } finally {
      setLoading(false);
    }
  }, [searchTerm, statusFilter]);

  useEffect(() => {
    loadStats();
    load(1);
  }, [load, loadStats]);

  const handleApprove = async (record: FeeRecord) => {
    if (!confirm(`Approve fee payment for "${record.student?.User?.name}"? This will unlock their gate pass.`)) return;
    setActionLoading(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/fees/${record.id}/approve`, { method: 'PATCH' });
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({ message: 'Unknown error' }));
        throw new Error(errorData.message || `HTTP ${res.status}`);
      }
      toast.success('Fee payment approved — gate pass unlocked');
      setIsDetailsOpen(false);
      loadStats();
      load(currentPage);
    } catch (err: any) {
      console.error('Failed to approve:', err);
      toast.error(err.message || 'Failed to approve');
    } finally {
      setActionLoading(false);
    }
  };

  const handleReject = async (record: FeeRecord) => {
    if (!confirm(`Reject fee payment for "${record.student?.User?.name}"?`)) return;
    setActionLoading(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/fees/${record.id}/reject`, { method: 'PATCH' });
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({ message: 'Unknown error' }));
        throw new Error(errorData.message || `HTTP ${res.status}`);
      }
      toast.success('Fee payment rejected');
      setIsDetailsOpen(false);
      loadStats();
      load(currentPage);
    } catch (err: any) {
      console.error('Failed to reject:', err);
      toast.error(err.message || 'Failed to reject');
    } finally {
      setActionLoading(false);
    }
  };

  const handleSendToWhatsApp = (record: FeeRecord) => {
    const phoneNumber = record.student?.User?.phone_number;
    if (!phoneNumber) {
      toast.error('Student phone number not available');
      return;
    }

    const cleanPhone = phoneNumber.replace(/\D/g, '');
    const fullPhone = cleanPhone.startsWith('91') ? cleanPhone : `91${cleanPhone}`;
    const passCode = `GATEPASS-${new Date().getFullYear()}-${String(record.id).padStart(6, '0')}`;
    const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(passCode)}&format=png&margin=10`;
    const studentName = record.student?.User?.name || 'Student';
    const batchName = record.batch?.name || 'Batch';
    const amount = Number(record.amountPaid).toLocaleString('en-IN');
    const enrollmentDate = record.enrollmentDate;
    const currentDate = new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });

    const message = `🎓 *Hi ${studentName}! Your Gate Pass — Nahata Sports Academy*

📅 Date: ${currentDate}
🏃 Batch: ${batchName}
💰 Amount Paid: ₹${amount}
📆 Enrollment Date: ${enrollmentDate}

*Pass Code:* ${passCode}

✅ *Status: APPROVED*

🔐 Show this QR code at the entry gate:
${qrCodeUrl}

_Nahata Sports Complex_

Thank you for choosing Nahata Sports Academy! 🏆`;

    const encodedMessage = encodeURIComponent(message);
    const whatsappUrl = `https://wa.me/${fullPhone}?text=${encodedMessage}`;
    window.open(whatsappUrl, '_blank');
    toast.success('Opening WhatsApp...');
  };

  const approvalBadge = (status?: string) => {
    const s = status ?? 'Pending';
    const cls = s === 'Approved' ? 'bg-emerald-50 text-emerald-700'
      : s === 'Rejected' ? 'bg-rose-50 text-rose-700'
      : 'bg-amber-50 text-amber-700';
    return (
      <span className={cn('px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider', cls)}>
        {s}
      </span>
    );
  };

  const statCards = [
    { label: 'Awaiting Approval', value: stats?.pendingApproval ?? '—', icon: AlertCircle, color: 'red' },
    { label: 'Total Paid', value: stats?.paid ?? '—', icon: CheckCircle2, color: 'emerald' },
    { label: 'Total Students', value: stats?.total ?? '—', icon: Users, color: 'blue' },
  ];

  const totalPages = Math.ceil(total / pageSize);

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Fees Approval" />}
    >
      <div className="max-w-[1400px] mx-auto min-h-full pb-10">
        {/* Header */}
        <div className="mb-8 flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-black text-text-dark tracking-tight">Fees Approval</h1>
            <p className="text-sm text-text-muted mt-1">Review coach-recorded fee collections and approve or reject them</p>
          </div>
          <div className="flex items-center gap-3">
            {(stats?.pendingApproval ?? 0) > 0 && (
              <div className="px-4 py-2 bg-red-50 text-red-600 rounded-xl flex items-center gap-2 text-xs font-black uppercase tracking-wider animate-pulse border border-red-100">
                <AlertCircle size={14} />
                {stats?.pendingApproval} Pending
              </div>
            )}
            <select
              value={statusFilter}
              onChange={(e) => { setStatusFilter(e.target.value); setCurrentPage(1); }}
              className="px-4 py-2 border border-border rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
            >
              <option value="">All Records</option>
              <option value="Pending">Awaiting Approval</option>
              <option value="Approved">Approved</option>
              <option value="Rejected">Rejected</option>
            </select>
            <button
              onClick={() => { loadStats(); load(currentPage); }}
              className="p-2.5 bg-white border border-border rounded-xl text-text-muted hover:bg-slate-50"
            >
              <RefreshCw size={16} />
            </button>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
          {statCards.map((s, i) => (
            <motion.div
              key={s.label}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.1 }}
              className={cn(
                'p-8 rounded-[2.5rem] bg-white border-2 flex flex-col items-center justify-center text-center hover:shadow-lg hover:-translate-y-1 transition-all group',
                s.color === 'red' ? 'border-red-100' :
                s.color === 'emerald' ? 'border-emerald-100' : 'border-blue-100'
              )}
            >
              <div className={cn(
                'w-16 h-16 rounded-[1.5rem] flex items-center justify-center mb-4 group-hover:scale-110 transition-transform',
                s.color === 'red' ? 'bg-red-50 text-red-600' :
                s.color === 'emerald' ? 'bg-emerald-50 text-emerald-600' : 'bg-blue-50 text-blue-600'
              )}>
                <s.icon size={28} />
              </div>
              <p className="text-4xl font-black text-text-dark mb-1">{statsLoading ? '…' : s.value}</p>
              <p className="text-xs font-bold text-text-muted uppercase tracking-widest">{s.label}</p>
            </motion.div>
          ))}
        </div>

        {/* Search */}
        <div className="mb-6">
          <input
            type="text"
            placeholder="Search student name..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && load(1)}
            className="w-full px-4 py-3 border border-border rounded-xl text-sm focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
          />
        </div>

        {/* Error */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 text-sm px-4 py-3 rounded-xl flex items-center gap-2 mb-4">
            <AlertCircle size={16} /> {error}
          </div>
        )}

        {/* Table */}
        {loading && fees.length === 0 ? (
          <div className="flex items-center justify-center h-64">
            <Loader2 className="animate-spin text-brand-primary" size={32} />
          </div>
        ) : fees.length === 0 ? (
          <div className="bg-white rounded-2xl border border-border p-16 text-center">
            <CheckCircle2 size={48} className="text-emerald-400 mx-auto mb-4" />
            <p className="text-text-dark font-bold text-lg">All caught up!</p>
            <p className="text-sm text-text-muted mt-1">No fee records found for this filter.</p>
          </div>
        ) : (
          <div className="bg-white rounded-2xl border border-border overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Student Details</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Batch</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Amount</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Mode</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Approval</th>
                    <th className="text-right px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {fees.map((row) => (
                    <tr key={row.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3 py-1">
                          <div className="w-9 h-9 bg-slate-100 rounded-xl flex items-center justify-center text-slate-400 shrink-0 font-black text-sm">
                            {(row.student?.User?.name || 'S')[0].toUpperCase()}
                          </div>
                          <div>
                            <div className="font-bold text-text-dark">{row.student?.User?.name || `Student #${row.studentId}`}</div>
                            <div className="text-[10px] text-text-muted">{row.student?.User?.phone_number || row.student?.User?.email || ''}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div>
                          <div className="font-semibold text-text-dark text-sm">{row.batch?.name || `Batch #${row.batchId}`}</div>
                          {row.batch?.sport && <div className="text-[10px] text-text-muted">{row.batch.sport.name}</div>}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="font-black text-emerald-600 text-base">
                          ₹{Number(row.amountPaid).toLocaleString('en-IN')}
                          {row.batch?.fees && (
                            <span className="text-text-muted font-normal text-xs"> / ₹{Number(row.batch.fees).toLocaleString('en-IN')}</span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-xs text-text-muted font-medium">{row.paymentMode || '—'}</td>
                      <td className="px-4 py-3">{approvalBadge(row.approvalStatus)}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => { setSelectedRecord(row); setIsDetailsOpen(true); }}
                            className="p-2 bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white rounded-lg transition-all"
                            title="View Details"
                          >
                            <Eye size={15} />
                          </button>
                          {row.approvalStatus === 'Approved' ? (
                            <button
                              onClick={() => handleSendToWhatsApp(row)}
                              className="p-2 bg-green-50 text-green-600 hover:bg-green-600 hover:text-white rounded-lg transition-all"
                              title="Send to WhatsApp"
                            >
                              <MessageCircle size={15} />
                            </button>
                          ) : (
                            <>
                              <button
                                onClick={() => handleApprove(row)}
                                disabled={actionLoading}
                                className="p-2 bg-emerald-50 text-emerald-600 hover:bg-emerald-600 hover:text-white rounded-lg transition-all disabled:opacity-50"
                                title="Approve"
                              >
                                <Check size={15} />
                              </button>
                              <button
                                onClick={() => handleReject(row)}
                                disabled={actionLoading}
                                className="p-2 bg-rose-50 text-rose-600 hover:bg-rose-600 hover:text-white rounded-lg transition-all disabled:opacity-50"
                                title="Reject"
                              >
                                <CloseIcon size={15} />
                              </button>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="px-4 py-3 border-t border-border flex items-center justify-between">
                <p className="text-xs text-text-muted">
                  Showing {(currentPage - 1) * pageSize + 1} to {Math.min(currentPage * pageSize, total)} of {total} records
                </p>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => load(currentPage - 1)}
                    disabled={currentPage <= 1}
                    className="px-3 py-1.5 border border-border rounded-lg text-sm disabled:opacity-50 hover:bg-slate-50"
                  >
                    Previous
                  </button>
                  <span className="text-sm text-text-muted">
                    Page {currentPage} of {totalPages}
                  </span>
                  <button
                    onClick={() => load(currentPage + 1)}
                    disabled={currentPage >= totalPages}
                    className="px-3 py-1.5 border border-border rounded-lg text-sm disabled:opacity-50 hover:bg-slate-50"
                  >
                    Next
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Details Modal */}
      <AnimatePresence>
        {isDetailsOpen && selectedRecord && (
          <>
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setIsDetailsOpen(false)}
              className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100]"
            />
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="fixed inset-0 flex items-center justify-center z-[101] p-4 overflow-y-auto"
            >
              <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full my-8 max-h-[90vh] overflow-y-auto">
                <div className="p-8 border-b border-border flex items-center justify-between sticky top-0 bg-white z-10">
                  <div>
                    <h2 className="text-2xl font-black text-text-dark tracking-tight">Fee Details</h2>
                    <p className="text-xs font-bold text-text-muted uppercase tracking-widest mt-1">
                      Record #{selectedRecord.id}
                    </p>
                  </div>
                  <button onClick={() => setIsDetailsOpen(false)} className="p-2 hover:bg-slate-100 rounded-xl text-slate-400">
                    <CloseIcon size={22} />
                  </button>
                </div>

                <div className="p-8 space-y-5">
                  <div className="grid grid-cols-2 gap-5">
                    <div>
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-1">Student</label>
                      <p className="font-bold text-text-dark">{selectedRecord.student?.User?.name || '—'}</p>
                      <p className="text-xs text-text-muted">{selectedRecord.student?.User?.phone_number || ''}</p>
                    </div>
                    <div>
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-1">Batch</label>
                      <p className="font-bold text-text-dark">{selectedRecord.batch?.name || '—'}</p>
                      <p className="text-xs text-text-muted">{selectedRecord.batch?.sport?.name || ''}</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-5">
                    <div>
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-1">Amount Collected</label>
                      <p className="font-black text-emerald-600 text-lg">₹{Number(selectedRecord.amountPaid).toLocaleString('en-IN')}</p>
                    </div>
                    <div>
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-1">Batch Fee</label>
                      <p className="font-bold text-text-dark">₹{Number(selectedRecord.batch?.fees || 0).toLocaleString('en-IN')}</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-5">
                    <div>
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-1">Payment Mode</label>
                      <p className="font-medium text-text-dark text-sm">{selectedRecord.paymentMode || '—'}</p>
                    </div>
                    <div>
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-1">Enrolled On</label>
                      <p className="font-medium text-text-dark text-sm">{selectedRecord.enrollmentDate}</p>
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-2 border-t border-border">
                    <span className="text-xs font-bold text-text-muted uppercase tracking-widest">Approval Status</span>
                    {approvalBadge(selectedRecord.approvalStatus)}
                  </div>

                  {selectedRecord.notes && (
                    <div>
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-1">Notes</label>
                      <p className="text-sm text-text-dark bg-slate-50 rounded-xl p-3">{selectedRecord.notes}</p>
                    </div>
                  )}

                  {/* Gate Pass Preview - Only show if approved */}
                  {selectedRecord.approvalStatus === 'Approved' && (
                    <div className="border-t border-border pt-5">
                      <label className="text-xs font-bold text-text-muted uppercase tracking-widest block mb-3">Gate Pass Preview</label>
                      <div className="bg-white rounded-2xl p-6 border-2 border-slate-200 shadow-lg">
                        <div className="flex flex-col items-center justify-center py-6 bg-slate-50 rounded-xl mb-4">
                          <div className="w-40 h-40 bg-white border-4 border-slate-300 rounded-lg flex items-center justify-center mb-3 overflow-hidden">
                            <img
                              src={`https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(`GATEPASS-${new Date().getFullYear()}-${String(selectedRecord.id).padStart(6, '0')}`)}&format=png&margin=10`}
                              alt="Gate Pass QR Code"
                              className="w-full h-full object-contain"
                            />
                          </div>
                          <p className="text-xs text-slate-600 font-semibold">Scan at entrance for verification</p>
                          <p className="text-[10px] text-slate-400 mt-1">Pass Code: GATEPASS-{new Date().getFullYear()}-{String(selectedRecord.id).padStart(6, '0')}</p>
                        </div>
                      </div>
                    </div>
                  )}
                </div>

                <div className="p-8 bg-slate-50 border-t border-border flex flex-col gap-3">
                  {selectedRecord.approvalStatus === 'Approved' ? (
                    <button
                      onClick={() => handleSendToWhatsApp(selectedRecord)}
                      className="w-full bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-xl text-sm font-bold flex items-center justify-center gap-2 transition-all"
                    >
                      <MessageCircle size={15} />
                      Send Gate Pass to WhatsApp
                    </button>
                  ) : (
                    <div className="flex gap-3">
                      <button
                        onClick={() => handleApprove(selectedRecord)}
                        disabled={actionLoading}
                        className="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white px-6 py-3 rounded-xl text-sm font-bold flex items-center justify-center gap-2 disabled:opacity-50 transition-all"
                      >
                        {actionLoading ? <Loader2 size={15} className="animate-spin" /> : <Check size={15} />}
                        Approve
                      </button>
                      <button
                        onClick={() => handleReject(selectedRecord)}
                        disabled={actionLoading}
                        className="flex-1 bg-rose-600 hover:bg-rose-700 text-white px-6 py-3 rounded-xl text-sm font-bold flex items-center justify-center gap-2 disabled:opacity-50 transition-all"
                      >
                        <CloseIcon size={15} /> Reject
                      </button>
                    </div>
                  )}
                  <button
                    onClick={() => setIsDetailsOpen(false)}
                    className="w-full px-6 py-3 bg-white border border-border text-text-muted rounded-xl text-sm font-bold hover:bg-slate-50"
                  >
                    Close
                  </button>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </UnifiedDashboardLayout>
  );
}
