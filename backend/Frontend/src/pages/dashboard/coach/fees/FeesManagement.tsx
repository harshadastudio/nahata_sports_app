import React, { useState, useEffect, useCallback } from 'react';
import {
  Wallet, Search, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Eye, X, Filter, IndianRupee, Edit, Save, Plus, User, Calendar,
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
  /** Date this student's enrollment is valid up to. null = no expiry. */
  validTill?: string | null;
  paymentStatus: 'Paid' | 'Pending' | 'Partial' | 'Overdue';
  approvalStatus?: 'Pending' | 'Approved' | 'Rejected';
  amountPaid: number;
  paymentMode?: 'Cash' | 'UPI' | 'Card' | 'BankTransfer' | 'Cheque' | 'Other';
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

interface FeesResponse {
  success: boolean;
  data: FeeRecord[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  stats?: {
    total: number;
    paid: number;
    unpaid: number;
    overdue: number;
    totalCollected: number;
    totalPending: number;
  };
}

// ── Status badge ──────────────────────────────────────────────────────────────

const PAYMENT_STATUS_STYLES: Record<string, string> = {
  Paid:     'bg-emerald-50 text-emerald-700',
  Pending:  'bg-amber-50 text-amber-700',
  Partial:  'bg-blue-50 text-blue-700',
  Overdue:  'bg-rose-50 text-rose-700',
};

function paymentStatusBadge(status?: string) {
  const s = status ?? 'Pending';
  const cls = PAYMENT_STATUS_STYLES[s] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {s}
    </span>
  );
}

const APPROVAL_STATUS_STYLES: Record<string, string> = {
  Approved: 'bg-emerald-50 text-emerald-700',
  Pending:  'bg-amber-50 text-amber-700',
  Rejected: 'bg-rose-50 text-rose-700',
};

function approvalStatusBadge(status?: string) {
  const s = status ?? 'Pending';
  const cls = APPROVAL_STATUS_STYLES[s] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {s === 'Pending' ? 'Awaiting approval' : s}
    </span>
  );
}

const PAYMENT_MODES = ['Cash', 'UPI', 'Card', 'BankTransfer', 'Cheque', 'Other'] as const;

function formatDate(d?: string) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function formatCurrency(amount: number) {
  return `₹${amount.toLocaleString('en-IN')}`;
}

// ── View/Edit Drawer ──────────────────────────────────────────────────────────

interface DrawerProps {
  fee: FeeRecord;
  onClose: () => void;
  onUpdate: () => void;
}

const FeeDrawer: React.FC<DrawerProps> = ({ fee, onClose, onUpdate }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({
    studentName: fee.student?.User?.name || '',
    batchName: fee.batch?.name || '',
    enrollmentDate: fee.enrollmentDate,
    validTill: fee.validTill || '',
    paymentStatus: fee.paymentStatus,
    amountPaid: String(fee.amountPaid),
    paymentMode: fee.paymentMode || 'Cash',
    notes: fee.notes || '',
  });
  const [updating, setUpdating] = useState(false);

  const handleUpdate = async () => {
    setUpdating(true);
    try {
      // Coach can mark this Paid directly — but the backend always re-queues
      // approvalStatus to Pending, so the gate pass QR only unlocks once
      // Admin/Employee separately approves it.
      const res = await fetchWithAuth(`${API_BASE}/fees/${fee.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          studentName: formData.studentName,
          batchName: formData.batchName,
          enrollmentDate: formData.enrollmentDate,
          validTill: formData.validTill || null,
          paymentStatus: formData.paymentStatus,
          amountPaid: parseFloat(formData.amountPaid) || 0,
          paymentMode: formData.paymentMode,
          notes: formData.notes || undefined,
        }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      toast.success('Fee record updated successfully');
      setIsEditing(false);
      onUpdate();
      onClose();
    } catch (err) {
      console.error('Failed to update fee:', err);
      toast.error('Failed to update fee record');
    } finally {
      setUpdating(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white w-full max-w-md h-full overflow-y-auto shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-white z-10">
          <h2 className="text-lg font-bold text-text-dark">
            {isEditing ? 'Edit Fee Record' : 'Fee Details'}
          </h2>
          <div className="flex items-center gap-2">
            {!isEditing && (
              <button
                onClick={() => setIsEditing(true)}
                className="p-2 rounded-lg hover:bg-slate-100 transition-colors text-blue-600"
              >
                <Edit size={18} />
              </button>
            )}
            <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
              <X size={18} className="text-slate-500" />
            </button>
          </div>
        </div>

        <div className="flex-1 p-6 space-y-6">
          {!isEditing ? (
            <>
              {/* Student Info */}
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-full bg-brand-primary/10 flex items-center justify-center text-brand-primary font-bold text-xl">
                  {fee.student?.User?.name?.charAt(0).toUpperCase()}
                </div>
                <div>
                  <p className="font-bold text-text-dark text-lg">{fee.student?.User?.name}</p>
                  <p className="text-sm text-text-muted">{fee.student?.User?.email}</p>
                </div>
              </div>

              {/* Contact */}
              <section>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Contact</h3>
                <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-text-muted">Phone</span>
                    <span className="font-medium text-text-dark">{fee.student?.User?.phone_number}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted">Email</span>
                    <span className="font-medium text-text-dark">{fee.student?.User?.email}</span>
                  </div>
                </div>
              </section>

              {/* Batch Details */}
              <section>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Batch</h3>
                <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-text-muted">Batch</span>
                    <span className="font-medium text-text-dark">{fee.batch?.name}</span>
                  </div>
                  {fee.batch?.sport && (
                    <div className="flex justify-between">
                      <span className="text-text-muted">Sport</span>
                      <span className="font-medium text-text-dark">{fee.batch.sport.name}</span>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <span className="text-text-muted">Enrollment Date</span>
                    <span className="font-medium text-text-dark">{formatDate(fee.enrollmentDate)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted">Enrollment Valid Till</span>
                    <span className="font-medium text-text-dark">
                      {fee.validTill ? formatDate(fee.validTill) : 'No expiry'}
                    </span>
                  </div>
                </div>
              </section>

              {/* Fee Details */}
              <section>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Fee Details</h3>
                <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-text-muted">Batch Fee</span>
                    <span className="font-bold text-text-dark">{formatCurrency(fee.batch?.fees || 0)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted">Amount Paid</span>
                    <span className="font-bold text-green-600">{formatCurrency(fee.amountPaid)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted">Amount Due</span>
                    <span className="font-bold text-red-600">
                      {formatCurrency((fee.batch?.fees || 0) - fee.amountPaid)}
                    </span>
                  </div>
                  {fee.paymentMode && (
                    <div className="flex justify-between">
                      <span className="text-text-muted">Payment Mode</span>
                      <span className="font-medium text-text-dark">{fee.paymentMode}</span>
                    </div>
                  )}
                  <div className="flex justify-between pt-2 border-t border-border">
                    <span className="text-text-muted">Payment Status</span>
                    {paymentStatusBadge(fee.paymentStatus)}
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted">Approval</span>
                    {approvalStatusBadge(fee.approvalStatus)}
                  </div>
                </div>
              </section>

              {/* Notes */}
              {fee.notes && (
                <section>
                  <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Notes</h3>
                  <div className="bg-slate-50 rounded-xl p-4 text-sm text-text-dark">
                    {fee.notes}
                  </div>
                </section>
              )}
            </>
          ) : (
            <>
              {/* Edit Form */}
              <div className="space-y-4">
                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Student Name
                  </label>
                  <input
                    type="text"
                    value={formData.studentName}
                    onChange={(e) => setFormData(p => ({ ...p, studentName: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                </div>

                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Batch Name
                  </label>
                  <input
                    type="text"
                    value={formData.batchName}
                    onChange={(e) => setFormData(p => ({ ...p, batchName: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                </div>

                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Enrollment Date
                  </label>
                  <input
                    type="date"
                    value={formData.enrollmentDate}
                    onChange={(e) => setFormData(p => ({ ...p, enrollmentDate: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                </div>

                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Enrollment Valid Till
                  </label>
                  <input
                    type="date"
                    value={formData.validTill}
                    min={formData.enrollmentDate || undefined}
                    onChange={(e) => setFormData(p => ({ ...p, validTill: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                  <p className="text-[11px] text-text-muted mt-1">
                    Shown to the student under Students / Parents. Leave empty for no expiry.
                  </p>
                </div>

                <div className="bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 text-xs text-amber-700">
                  Marking this Paid confirms you collected the fee — Admin/Employee still need to
                  separately approve it before the student's gate pass QR unlocks.
                </div>

                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Payment Status
                  </label>
                  <select
                    value={formData.paymentStatus}
                    onChange={(e) => setFormData(p => ({ ...p, paymentStatus: e.target.value as any }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  >
                    <option value="Pending">Pending</option>
                    <option value="Paid">Paid</option>
                    <option value="Partial">Partial</option>
                    <option value="Overdue">Overdue</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Amount Paid (₹)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formData.amountPaid}
                    onChange={(e) => setFormData(p => ({ ...p, amountPaid: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                </div>

                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Payment Mode
                  </label>
                  <select
                    value={formData.paymentMode}
                    onChange={(e) => setFormData(p => ({ ...p, paymentMode: e.target.value as any }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  >
                    {PAYMENT_MODES.map(m => <option key={m} value={m}>{m}</option>)}
                  </select>
                </div>

                <div>
                  <label className="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">
                    Notes
                  </label>
                  <textarea
                    value={formData.notes}
                    onChange={(e) => setFormData(p => ({ ...p, notes: e.target.value }))}
                    rows={3}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary resize-none"
                  />
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex gap-3 pt-4">
                <button
                  onClick={handleUpdate}
                  disabled={updating}
                  className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-brand-primary text-white rounded-xl font-medium hover:bg-brand-primary/90 transition-colors disabled:opacity-50"
                >
                  {updating ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
                  {updating ? 'Updating...' : 'Update Record'}
                </button>
                <button
                  onClick={() => setIsEditing(false)}
                  className="flex-1 px-4 py-3 bg-white border border-border rounded-xl font-medium hover:bg-slate-50 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function FeesManagement() {
  const [fees, setFees] = useState<FeeRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedFee, setSelectedFee] = useState<FeeRecord | null>(null);
  const [search, setSearch] = useState('');
  const [paymentFilter, setPaymentFilter] = useState('');
  const [stats, setStats] = useState({ total: 0, paid: 0, unpaid: 0, overdue: 0, totalCollected: 0, totalPending: 0 });
  const [showAddForm, setShowAddForm] = useState(false);
  const [students, setStudents] = useState<any[]>([]);
  const [programs, setPrograms] = useState<any[]>([]);
  const [loadingStudents, setLoadingStudents] = useState(false);
  const [loadingPrograms, setLoadingPrograms] = useState(false);
  const [retentionStats, setRetentionStats] = useState<any>(null);

  const [formData, setFormData] = useState({
    studentId: '',
    batchId: '',
    enrollmentDate: new Date().toISOString().split('T')[0],
    validTill: '',
    paymentStatus: 'Pending',
    amountPaid: '',
    paymentMode: 'Cash',
    notes: '',
  });

  const limit = 20;

  const loadStats = useCallback(async () => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/fees/stats`);
      if (!res.ok) {
        console.error('Failed to load stats - HTTP', res.status);
        return;
      }
      const result = await res.json();
      console.log('Stats API Response:', result);
      
      if (result.success && result.data) {
        setStats({
          total: result.data.total || 0,
          paid: result.data.paid || 0,
          unpaid: result.data.unpaid || 0,
          overdue: result.data.overdue || 0,
          totalCollected: result.data.totalCollected || 0,
          totalPending: result.data.totalPending || 0,
        });
      }
    } catch (err) {
      console.error('Failed to load stats:', err);
    }
  }, []);

  const loadRetentionStats = useCallback(async () => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/fees/retention-stats`);
      if (!res.ok) {
        console.error('Failed to load retention stats - HTTP', res.status);
        return;
      }
      const result = await res.json();
      console.log('Retention Stats API Response:', result);
      
      if (result.success && result.data) {
        setRetentionStats(result.data);
      }
    } catch (err) {
      console.error('Failed to load retention stats:', err);
    }
  }, []);

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(p),
        limit: String(limit),
      });
      if (search.trim()) params.set('search', search.trim());
      if (paymentFilter) params.set('paymentStatus', paymentFilter);

      // Fetch fees for coach's assigned students
      const res = await fetchWithAuth(`${API_BASE}/fees?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();

      console.log('Fees API Response:', result); // Debug log

      // Handle different response structures
      let feesData: FeeRecord[] = [];
      let totalRecords = 0;
      let statsData = { total: 0, paid: 0, unpaid: 0, overdue: 0, totalCollected: 0, totalPending: 0 };

      if (result.success) {
        // Check if data is directly an array or nested
        if (Array.isArray(result.data)) {
          feesData = result.data;
          totalRecords = result.total || result.data.length;
        } else if (result.data && Array.isArray(result.data.fees)) {
          feesData = result.data.fees;
          totalRecords = result.data.total || result.data.fees.length;
        } else if (result.data && result.data.data && Array.isArray(result.data.data)) {
          feesData = result.data.data;
          totalRecords = result.data.total || result.data.data.length;
        }

        // Extract stats if available
        if (result.stats) {
          statsData = { ...statsData, ...result.stats };
        } else if (result.data && result.data.stats) {
          statsData = { ...statsData, ...result.data.stats };
        }
      }

      setFees(feesData);
      setTotal(totalRecords);
      setTotalPages(Math.ceil(totalRecords / limit));
      setPage(p);
      setStats(statsData);
    } catch (err) {
      console.error('Failed to load fees:', err);
      setError('Failed to load fee records. Please try again.');
      toast.error('Failed to load fee records');
    } finally {
      setLoading(false);
    }
  }, [search, paymentFilter]);

  useEffect(() => { 
    loadStats();
    loadRetentionStats();
    load(1); 
  }, [load, loadStats, loadRetentionStats]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    load(1);
  };

  const handleUpdate = () => {
    loadStats();
    loadRetentionStats();
    load(page);
  };

  const loadStudents = async () => {
    setLoadingStudents(true);
    try {
      // Fetch ALL students from database using coach-accessible endpoint
      const res = await fetchWithAuth(`${API_BASE}/students/coach/all-students?page=1&limit=1000`);
      if (!res.ok) {
        const errorText = await res.text();
        console.error('Failed to load students - HTTP', res.status, errorText);
        throw new Error(`HTTP ${res.status}`);
      }
      const data = await res.json();
      console.log('Students API Response:', data);
      
      // Handle different response structures
      let studentsList: any[] = [];
      if (data.success && data.data) {
        // Check if data.data is an array or has a students property
        if (Array.isArray(data.data)) {
          studentsList = data.data;
        } else if (data.data.students && Array.isArray(data.data.students)) {
          studentsList = data.data.students;
        } else if (data.data.data && Array.isArray(data.data.data)) {
          studentsList = data.data.data;
        }
      }
      
      console.log('Students array:', studentsList);
      console.log('Setting students:', studentsList.length, 'students');
      setStudents(studentsList);
      
      if (studentsList.length === 0) {
        toast.info('No students found in the database.');
      }
    } catch (err) {
      console.error('Failed to load students:', err);
      toast.error('Failed to load students');
    } finally {
      setLoadingStudents(false);
    }
  };

  const loadPrograms = async () => {
    setLoadingPrograms(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/batches?page=1&limit=100`);
      if (!res.ok) {
        const errorText = await res.text();
        console.error('Failed to load programs - HTTP', res.status, errorText);
        throw new Error(`HTTP ${res.status}`);
      }
      const data = await res.json();
      console.log('Batches API Response:', data);
      const programsList = data.data?.batches || [];
      console.log('Setting batches:', programsList.length, 'batches');
      setPrograms(programsList);
      
      if (programsList.length === 0) {
        toast.info('No programs found in the system.');
      }
    } catch (err) {
      console.error('Failed to load programs:', err);
      toast.error('Failed to load programs');
    } finally {
      setLoadingPrograms(false);
    }
  };

  const handleOpenAddForm = () => {
    setFormData({
      studentId: '',
      batchId: '',
      enrollmentDate: new Date().toISOString().split('T')[0],
      validTill: '',
      paymentStatus: 'Pending',
      amountPaid: '',
      paymentMode: 'Cash',
      notes: '',
    });
    loadStudents();
    loadPrograms();
    setShowAddForm(true);
  };

  const handleAddFee = async () => {
    if (!formData.studentId || !formData.batchId) {
      toast.error('Student and program are required');
      return;
    }

    setLoading(true);
    try {
      // Coach can mark this Paid immediately if collected in person — the
      // backend always creates it with approvalStatus Pending regardless,
      // so the gate pass QR still needs a separate Admin/Employee approval.
      const res = await fetchWithAuth(`${API_BASE}/fees`, {
        method: 'POST',
        body: JSON.stringify({
          studentId: parseInt(formData.studentId),
          batchId: parseInt(formData.batchId),
          enrollmentDate: formData.enrollmentDate,
          validTill: formData.validTill || null,
          paymentStatus: formData.paymentStatus,
          amountPaid: formData.amountPaid ? parseFloat(formData.amountPaid) : 0,
          paymentMode: formData.paymentMode,
          notes: formData.notes || undefined,
        }),
      });

      if (!res.ok) {
        const errorData = await res.json().catch(() => ({ message: 'Unknown error' }));
        console.error('API Error Response:', errorData);
        throw new Error(errorData.message || `HTTP ${res.status}`);
      }

      const result = await res.json();
      console.log('Fee record created:', result);

      toast.success('Fee record created — sent to Admin/Employee for gate pass approval');
      setShowAddForm(false);
      setFormData({
        studentId: '',
        batchId: '',
        enrollmentDate: new Date().toISOString().split('T')[0],
        validTill: '',
        paymentStatus: 'Pending',
        amountPaid: '',
        paymentMode: 'Cash',
        notes: '',
      });
      loadStats();
      loadRetentionStats();
      load(page);
    } catch (err: any) {
      console.error('Failed to create fee:', err);
      toast.error(err.message || 'Failed to create fee record');
    } finally {
      setLoading(false);
    }
  };

  const handleTogglePayment = async (record: FeeRecord) => {
    const newStatus = record.paymentStatus === 'Paid' ? 'Pending' : 'Paid';
    try {
      const res = await fetchWithAuth(`${API_BASE}/fees/${record.id}/payment`, {
        method: 'PATCH',
        body: JSON.stringify({ paymentStatus: newStatus }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      toast.success(`Marked as ${newStatus}`);
      loadStats();
      loadRetentionStats();
      load(page);
    } catch (err) {
      console.error('Failed to update payment status:', err);
      toast.error('Failed to update payment status');
    }
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Fees Management" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Fees Management</h1>
            <p className="text-text-muted text-sm mt-1">View and manage fees for assigned students</p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={handleOpenAddForm}
              className="flex items-center gap-2 px-4 py-2 bg-brand-primary text-white rounded-xl text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              <Plus size={15} /> Add Fee Record
            </button>
            <button
              onClick={() => { loadStats(); loadRetentionStats(); load(page); }}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
            >
              <RefreshCw size={15} /> Refresh
            </button>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white rounded-xl border border-border p-5 text-center"
          >
            <p className="text-2xl font-bold text-text-dark mb-1">{stats.total}</p>
            <p className="text-xs font-semibold text-text-muted uppercase tracking-wider">Total Records</p>
          </motion.div>
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.07 }}
            className="bg-white rounded-xl border border-border p-5 text-center"
          >
            <p className="text-2xl font-bold text-emerald-600 mb-1">{stats.paid}</p>
            <p className="text-xs font-semibold text-text-muted uppercase tracking-wider">Paid</p>
          </motion.div>
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.14 }}
            className="bg-white rounded-xl border border-border p-5 text-center"
          >
            <p className="text-2xl font-bold text-amber-600 mb-1">{stats.unpaid}</p>
            <p className="text-xs font-semibold text-text-muted uppercase tracking-wider">Pending</p>
          </motion.div>
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.21 }}
            className="bg-white rounded-xl border border-border p-5 text-center"
          >
            <p className="text-2xl font-bold text-rose-600 mb-1">{stats.overdue}</p>
            <p className="text-xs font-semibold text-text-muted uppercase tracking-wider">Overdue</p>
          </motion.div>
        </div>

        {/* Retention Ratio by Sport */}
        {retentionStats && Object.keys(retentionStats).length > 0 ? (
          <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl border border-blue-200 p-6 shadow-lg">
            <h3 className="text-sm font-black text-text-dark uppercase tracking-widest mb-4 flex items-center gap-2">
              <AlertCircle size={18} className="text-blue-600" />
              Retention Ratio by Sport
              <span className="ml-auto text-[10px] font-normal text-blue-600 bg-blue-100 px-3 py-1 rounded-full">
                Month-over-Month Tracking
              </span>
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {Object.entries(retentionStats).map(([sport, data]: [string, any]) => {
                const rate = data.retentionRate;
                const getColor = () => {
                  if (rate >= 80) return 'from-green-500 to-emerald-600';
                  if (rate >= 70) return 'from-blue-500 to-blue-600';
                  if (rate >= 60) return 'from-yellow-500 to-orange-500';
                  return 'from-red-500 to-rose-600';
                };
                
                const getTextColor = () => {
                  if (rate >= 80) return 'text-green-600';
                  if (rate >= 70) return 'text-blue-600';
                  if (rate >= 60) return 'text-yellow-600';
                  return 'text-red-600';
                };
                
                return (
                  <div key={sport} className="bg-white rounded-xl p-5 border border-blue-100 shadow-sm hover:shadow-md transition-shadow">
                    <p className="text-xs font-bold text-text-muted uppercase tracking-wider mb-2">{sport}</p>
                    <div className="flex items-baseline gap-2 mb-3">
                      <p className={`text-3xl font-black ${getTextColor()}`}>{data.retentionRate}%</p>
                      <div className={`w-2 h-2 rounded-full bg-gradient-to-r ${getColor()}`}></div>
                    </div>
                    <div className="space-y-1">
                      <div className="flex justify-between text-[11px]">
                        <span className="text-text-muted">Continued:</span>
                        <span className="font-bold text-text-dark">{data.continuedThisMonth}</span>
                      </div>
                      <div className="flex justify-between text-[11px]">
                        <span className="text-text-muted">Enrolled Last Month:</span>
                        <span className="font-bold text-text-dark">{data.enrolledLastMonth}</span>
                      </div>
                    </div>
                    <div className="mt-3 pt-3 border-t border-slate-100">
                      <div className="w-full bg-slate-200 rounded-full h-2 overflow-hidden">
                        <div 
                          className={`h-full bg-gradient-to-r ${getColor()} transition-all duration-500`}
                          style={{ width: `${data.retentionRate}%` }}
                        ></div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="mt-4 text-center bg-white/50 rounded-lg py-2 px-4">
              <p className="text-xs text-slate-600">
                <span className="font-bold text-slate-700">Formula:</span> Retention Ratio = (Students Continued This Month ÷ Students Enrolled Last Month) × 100
              </p>
            </div>
          </div>
        ) : (
          <div className="bg-gradient-to-br from-slate-50 to-slate-100 rounded-2xl border border-slate-200 p-6">
            <h3 className="text-sm font-black text-text-dark uppercase tracking-widest mb-4 flex items-center gap-2">
              <AlertCircle size={16} className="text-slate-400" />
              Retention Ratio by Sport
            </h3>
            <div className="text-center py-8">
              <div className="text-slate-400 mb-2">
                <svg className="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
              <p className="text-sm font-bold text-slate-600 mb-1">No Retention Data Available</p>
              <p className="text-xs text-slate-500">
                Retention data will appear when students are enrolled and tracked month-over-month.
              </p>
              <div className="mt-4 text-xs text-slate-400 bg-white rounded-lg p-3 inline-block">
                <p className="font-semibold mb-1">Formula:</p>
                <p>Retention Ratio = (Students Continued This Month ÷ Students Enrolled Last Month) × 100</p>
              </div>
            </div>
          </div>
        )}

        {/* Search & Filter */}
        <form onSubmit={handleSearch} className="bg-white rounded-xl border border-border p-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter size={15} className="text-slate-400" />
            <span className="text-sm font-medium text-text-dark">Search & Filter</span>
          </div>
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                type="text"
                placeholder="Search by student name…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full pl-9 pr-4 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
              />
            </div>
            <select
              value={paymentFilter}
              onChange={(e) => setPaymentFilter(e.target.value)}
              className="px-4 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
            >
              <option value="">All Status</option>
              <option value="Paid">Paid</option>
              <option value="Pending">Pending</option>
              <option value="Partial">Partial</option>
              <option value="Overdue">Overdue</option>
            </select>
            <button
              type="submit"
              className="px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              Search
            </button>
            {(search || paymentFilter) && (
              <button
                type="button"
                onClick={() => { setSearch(''); setPaymentFilter(''); }}
                className="px-4 py-2 bg-white border border-border rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors"
              >
                Clear
              </button>
            )}
          </div>
        </form>

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
              <p className="text-text-muted text-sm">Loading fee records…</p>
            </div>
          ) : fees.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Wallet size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No fee records found</p>
              <p className="text-text-muted text-sm">No fee records are available for your students.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Student</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Batch / Sport</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Amount</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Enrolled</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Approval</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {fees.map((f, idx) => (
                    <tr key={f.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="font-medium text-text-dark">{f.student?.User?.name || `Student #${f.studentId}`}</p>
                          <p className="text-xs text-text-muted">{f.student?.User?.phone_number}</p>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="font-medium text-text-dark">{f.batch?.name || `Batch #${f.batchId}`}</p>
                          {f.batch?.sport && (
                            <p className="text-xs text-text-muted">{f.batch.sport.name}</p>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="font-bold text-text-dark">{formatCurrency(f.amountPaid)}</p>
                          {f.batch?.fees && (
                            <p className="text-xs text-text-muted">of {formatCurrency(f.batch.fees)}</p>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-text-muted text-xs">{formatDate(f.enrollmentDate)}</td>
                      <td className="px-4 py-3">{paymentStatusBadge(f.paymentStatus)}</td>
                      <td className="px-4 py-3">{approvalStatusBadge(f.approvalStatus)}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => setSelectedFee(f)}
                            className="p-1.5 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-all"
                            title="View / Edit Details"
                          >
                            <Eye size={14} />
                          </button>
                          <button
                            onClick={() => handleTogglePayment(f)}
                            disabled={loading}
                            className={cn(
                              'px-3 py-1.5 rounded-lg text-[9px] font-black uppercase tracking-widest transition-all active:scale-95 disabled:opacity-50',
                              f.paymentStatus === 'Paid'
                                ? 'bg-amber-500 text-white shadow-lg shadow-amber-500/20 hover:bg-amber-600'
                                : 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/20 hover:bg-emerald-700'
                            )}
                          >
                            {f.paymentStatus === 'Paid' ? 'Mark Unpaid' : 'Mark Paid'}
                          </button>
                        </div>
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

      {/* Fee Drawer */}
      {selectedFee && (
        <FeeDrawer
          fee={selectedFee}
          onClose={() => setSelectedFee(null)}
          onUpdate={handleUpdate}
        />
      )}

      {/* Add Fee Record Modal */}
      <AnimatePresence>
        {showAddForm && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowAddForm(false)}
              className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100]"
            />
            <motion.div
              initial={{ x: '100%' }}
              animate={{ x: 0 }}
              exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="fixed right-0 top-0 h-full w-full max-w-lg bg-white shadow-2xl z-[101] flex flex-col"
            >
              <div className="p-8 border-b border-border flex items-center justify-between shrink-0">
                <div>
                  <h2 className="text-2xl font-black text-text-dark tracking-tight">
                    Add Fee Record
                  </h2>
                  <p className="text-xs font-bold text-text-muted uppercase tracking-widest mt-1">
                    Register a student enrollment & payment
                  </p>
                </div>
                <button
                  onClick={() => setShowAddForm(false)}
                  className="p-2 hover:bg-slate-100 rounded-xl text-slate-400"
                >
                  <X size={22} />
                </button>
              </div>

              <div className="flex-1 overflow-y-auto p-8 space-y-6">
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Student *
                  </label>
                  <div className="relative">
                    <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <select
                      value={formData.studentId}
                      onChange={(e) => setFormData(p => ({ ...p, studentId: e.target.value }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                      disabled={loadingStudents}
                    >
                      <option value="">
                        {loadingStudents ? 'Loading students...' : students.length === 0 ? 'No students available' : 'Select a student'}
                      </option>
                      {students.map((student: any) => (
                        <option key={student.id} value={student.id}>
                          {student.name || student.User?.name || `Student #${student.id}`}
                          {student.email && ` (${student.email})`}
                          {student.User?.email && ` (${student.User.email})`}
                        </option>
                      ))}
                    </select>
                  </div>
                  {students.length === 0 && !loadingStudents && (
                    <p className="text-xs text-amber-600 mt-1">
                      No students found. Make sure you have students assigned to your programs.
                    </p>
                  )}
                </div>

                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Batch *
                  </label>
                  <select
                    value={formData.batchId}
                    onChange={(e) => setFormData(p => ({ ...p, batchId: e.target.value }))}
                    className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                    disabled={loadingPrograms}
                  >
                    <option value="">
                      {loadingPrograms ? 'Loading batches...' : programs.length === 0 ? 'No batches available' : 'Select a batch'}
                    </option>
                    {programs.map((program: any) => (
                      <option key={program.id} value={program.id}>
                        {program.name} {program.sport?.name ? `(${program.sport.name})` : ''}
                      </option>
                    ))}
                  </select>
                  {programs.length === 0 && !loadingPrograms && (
                    <p className="text-xs text-amber-600 mt-1">
                      No batches found. Please contact admin to create batches.
                    </p>
                  )}
                </div>

                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Enrollment Date
                  </label>
                  <div className="relative">
                    <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="date"
                      value={formData.enrollmentDate}
                      onChange={(e) => setFormData(p => ({ ...p, enrollmentDate: e.target.value }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Enrollment Valid Till
                  </label>
                  <div className="relative">
                    <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="date"
                      value={formData.validTill}
                      min={formData.enrollmentDate || undefined}
                      onChange={(e) => setFormData(p => ({ ...p, validTill: e.target.value }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                    />
                  </div>
                  <p className="text-[11px] text-text-muted">
                    Shown to the student under Students / Parents. Leave empty for no expiry.
                  </p>
                </div>

                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Payment Status
                  </label>
                  <select
                    value={formData.paymentStatus}
                    onChange={(e) => setFormData(p => ({ ...p, paymentStatus: e.target.value }))}
                    className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  >
                    <option value="Pending">Pending</option>
                    <option value="Paid">Paid</option>
                    <option value="Partial">Partial</option>
                    <option value="Overdue">Overdue</option>
                  </select>
                </div>

                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Amount Paid (₹)
                  </label>
                  <div className="relative">
                    <IndianRupee className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="number"
                      min="0"
                      value={formData.amountPaid}
                      onChange={(e) => setFormData(p => ({ ...p, amountPaid: e.target.value }))}
                      placeholder="0"
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Payment Mode
                  </label>
                  <select
                    value={formData.paymentMode}
                    onChange={(e) => setFormData(p => ({ ...p, paymentMode: e.target.value }))}
                    className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  >
                    {PAYMENT_MODES.map(m => <option key={m} value={m}>{m}</option>)}
                  </select>
                </div>

                <div className="bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 text-xs text-amber-700">
                  Admin/Employee still need to separately approve this before the student's gate pass QR unlocks.
                </div>

                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">
                    Notes
                  </label>
                  <textarea
                    value={formData.notes}
                    onChange={(e) => setFormData(p => ({ ...p, notes: e.target.value }))}
                    rows={3}
                    placeholder="Optional notes..."
                    className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary resize-none"
                  />
                </div>
              </div>

              <div className="p-8 bg-slate-50 border-t border-border flex gap-4 shrink-0">
                <button
                  onClick={handleAddFee}
                  disabled={loading}
                  className="flex-1 bg-brand-primary hover:bg-brand-primary/90 text-white px-6 py-3.5 rounded-2xl text-[11px] font-black uppercase tracking-widest shadow-xl shadow-brand-primary/20 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  {loading ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
                  {loading ? 'Saving...' : 'Save Record'}
                </button>
                <button
                  onClick={() => setShowAddForm(false)}
                  className="flex-1 bg-white border border-border text-text-muted px-6 py-3.5 rounded-2xl text-[11px] font-black uppercase tracking-widest hover:bg-slate-50"
                >
                  Cancel
                </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </UnifiedDashboardLayout>
  );
}
