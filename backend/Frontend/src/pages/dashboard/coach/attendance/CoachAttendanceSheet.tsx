import React, { useState, useEffect, useCallback } from 'react';
import {
  ClipboardList, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Filter, Plus, X,
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
  date: string;
  studentName: string;
  studentEmail: string;
  batchName: string;
  status: 'Present' | 'Absent' | 'Late';
  markedBy: string;
  markedAt: string;
}

interface AttendanceResponse {
  success: boolean;
  data: {
    records: AttendanceRecord[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}

// ── Status badge ──────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  Present: 'bg-green-100 text-green-700',
  Absent:  'bg-red-100 text-red-600',
  Late:    'bg-amber-100 text-amber-700',
};

function statusBadge(status: string) {
  const cls = STATUS_STYLES[status] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {status}
    </span>
  );
}

function formatDate(d?: string) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

// ── Mark Attendance Modal ─────────────────────────────────────────────────────

interface MarkModalProps {
  coachId: string;
  onClose: () => void;
  onSuccess: () => void;
}

const MarkAttendanceModal: React.FC<MarkModalProps> = ({ coachId, onClose, onSuccess }) => {
  const [studentId, setStudentId] = useState('');
  const [sport, setSport] = useState('');
  const [batch, setBatch] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [status, setStatus] = useState<'Present' | 'Absent' | 'Late'>('Present');
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Dropdown states - Initialize as empty arrays
  const [students, setStudents] = useState<Array<{ id: number; name: string; email: string }>>([]);
  const [sports, setSports] = useState<Array<{ id: number; name: string }>>([]);
  const [batches, setBatches] = useState<Array<{ id: number; name: string }>>([]);
  const [loadingDropdowns, setLoadingDropdowns] = useState(false);

  // Fetch ALL students, sports, and batches on mount
  useEffect(() => {
    const fetchDropdownData = async () => {
      setLoadingDropdowns(true);
      try {
        // Fetch ALL students from database
        console.log('Fetching all students from:', `${API_BASE}/students/coach/all-students`);
        const studentsRes = await fetchWithAuth(`${API_BASE}/students/coach/all-students?limit=1000`);
        console.log('Students response status:', studentsRes.status);
        if (studentsRes.ok) {
          const studentsData = await studentsRes.json();
          console.log('Students data received:', studentsData);
          
          // Handle nested response format: { success: true, data: { students: [...] } }
          if (studentsData.success) {
            const studentsList = studentsData.data?.students || studentsData.data || [];
            if (Array.isArray(studentsList)) {
              // Map to extract user info
              const mappedStudents = studentsList.map((student: any) => ({
                id: student.id,
                name: student.User?.name || student.name || 'Unknown',
                email: student.User?.email || student.email || '',
              }));
              setStudents(mappedStudents);
              console.log('Students set to state:', mappedStudents.length, 'students');
            } else {
              console.warn('Students list is not an array:', studentsList);
              setStudents([]);
            }
          } else {
            console.warn('Students response not successful:', studentsData);
            setStudents([]);
          }
        } else {
          console.error('Failed to fetch students:', studentsRes.status, studentsRes.statusText);
          toast.error('Failed to load students list');
          setStudents([]);
        }

        // Fetch sports
        console.log('Fetching sports from:', `${API_BASE}/coach/dashboard/autocomplete/sports`);
        const sportsRes = await fetchWithAuth(`${API_BASE}/coach/dashboard/autocomplete/sports`);
        console.log('Sports response status:', sportsRes.status);
        if (sportsRes.ok) {
          const sportsData = await sportsRes.json();
          console.log('Sports data received:', sportsData);
          if (sportsData.success && Array.isArray(sportsData.data)) {
            setSports(sportsData.data);
            console.log('Sports set to state:', sportsData.data);
          } else {
            console.warn('Sports data is not an array:', sportsData);
            setSports([]);
          }
        } else {
          console.error('Failed to fetch sports:', sportsRes.status, sportsRes.statusText);
          setSports([]);
        }

        // Fetch batches
        console.log('Fetching batches from:', `${API_BASE}/coach/dashboard/autocomplete/batches`);
        const batchesRes = await fetchWithAuth(`${API_BASE}/coach/dashboard/autocomplete/batches`);
        console.log('Batches response status:', batchesRes.status);
        if (batchesRes.ok) {
          const batchesData = await batchesRes.json();
          console.log('Batches data received:', batchesData);
          if (batchesData.success && Array.isArray(batchesData.data)) {
            setBatches(batchesData.data);
            console.log('Batches set to state:', batchesData.data);
          } else {
            console.warn('Batches data is not an array:', batchesData);
            setBatches([]);
          }
        } else {
          console.error('Failed to fetch batches:', batchesRes.status, batchesRes.statusText);
          setBatches([]);
        }
      } catch (err) {
        console.error('Failed to fetch dropdown data:', err);
        toast.error('Failed to load form data');
        setStudents([]);
        setSports([]);
        setBatches([]);
      } finally {
        setLoadingDropdowns(false);
      }
    };

    fetchDropdownData();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!studentId || !date) {
      toast.error('Student and date are required');
      return;
    }
    if (!batch) {
      toast.error('Batch is required');
      return;
    }
    setSubmitting(true);
    try {
      const payload = {
        studentId: parseInt(studentId),
        batchId: batch ? parseInt(batch) : undefined,
        batchName: batch && isNaN(parseInt(batch)) ? batch : undefined,
        sportId: sport ? parseInt(sport) : undefined,
        date,
        status,
        notes: notes.trim() || undefined,
      };

      console.log('📤 Submitting attendance:', payload);

      const res = await fetchWithAuth(`${API_BASE}/attendance`, {
        method: 'POST',
        body: JSON.stringify(payload),
      });

      console.log('📥 Response status:', res.status);

      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        console.error('❌ Error response:', errorData);
        throw new Error(errorData.message || `HTTP ${res.status}`);
      }

      const result = await res.json();
      console.log('✅ Success response:', result);
      toast.success('Attendance marked successfully');
      onSuccess();
      onClose();
    } catch (err: any) {
      console.error('❌ Failed to mark attendance:', err);
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
          {/* Student Dropdown - Show ALL students */}
          <div>
            <label className="block text-xs font-medium text-text-muted mb-1">
              Student Name * {loadingDropdowns && <span className="text-xs text-slate-400">(Loading...)</span>}
            </label>
            <select
              value={studentId}
              onChange={(e) => setStudentId(e.target.value)}
              required
              disabled={loadingDropdowns}
              className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white disabled:opacity-50"
            >
              <option value="">-- Select Student --</option>
              {!loadingDropdowns && students.length === 0 && (
                <option value="" disabled>No students available</option>
              )}
              {Array.isArray(students) && students.map((student) => (
                <option key={student.id} value={student.id}>
                  {student.name} ({student.email})
                </option>
              ))}
            </select>
            {!loadingDropdowns && students.length > 0 && (
              <p className="text-xs text-slate-500 mt-1">
                {students.length} student{students.length !== 1 ? 's' : ''} available
              </p>
            )}
          </div>

          {/* Sport and Batch Dropdowns */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-text-muted mb-1">
                Sport {loadingDropdowns && <span className="text-xs text-slate-400">(Loading...)</span>}
              </label>
              <select
                value={sport}
                onChange={(e) => setSport(e.target.value)}
                disabled={loadingDropdowns}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white disabled:opacity-50"
              >
                <option value="">Select Sport (Optional)</option>
                {!loadingDropdowns && sports.length === 0 && (
                  <option value="" disabled>No sports available</option>
                )}
                {Array.isArray(sports) && sports.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-text-muted mb-1">
                Batch * {loadingDropdowns && <span className="text-xs text-slate-400">(Loading...)</span>}
              </label>
              <select
                value={batch}
                onChange={(e) => setBatch(e.target.value)}
                required
                disabled={loadingDropdowns}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white disabled:opacity-50"
              >
                <option value="">-- Select Batch --</option>
                {!loadingDropdowns && batches.length === 0 && (
                  <option value="" disabled>No batches available</option>
                )}
                {Array.isArray(batches) && batches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-text-muted mb-1">Date *</label>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                required
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-text-muted mb-1">Status *</label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value as 'Present' | 'Absent' | 'Late')}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white"
              >
                <option value="Present">Present</option>
                <option value="Absent">Absent</option>
                <option value="Late">Late</option>
              </select>
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-text-muted mb-1">Notes</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Optional notes…"
              rows={2}
              className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary resize-none"
            />
          </div>
          <div className="flex gap-3 pt-2">
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 disabled:opacity-60 transition-colors"
            >
              {submitting ? <Loader2 size={14} className="animate-spin" /> : null}
              Mark Attendance
            </button>
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 bg-white border border-border rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function CoachAttendanceSheet() {
  const { user } = useAuth();

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
      const params = new URLSearchParams({
        page: String(p),
        limit: String(limit),
      });
      if (dateFilter) params.set('date', dateFilter);
      if (statusFilter) params.set('status', statusFilter);

      const res = await fetchWithAuth(`${API_BASE}/coach/dashboard/attendance/records?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: AttendanceResponse = await res.json();

      setRecords(data.data?.records ?? []);
      setTotal(data.data?.total ?? 0);
      setTotalPages(data.data?.totalPages ?? 1);
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

  const handleApplyFilters = () => load(1);
  const handleClearFilters = () => {
    setDateFilter('');
    setStatusFilter('');
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Attendance Sheet" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Attendance Sheet</h1>
            <p className="text-text-muted text-sm mt-1">{total} record{total !== 1 ? 's' : ''} total</p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setShowMarkModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-brand-primary text-white rounded-xl text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              <Plus size={15} /> Mark Attendance
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
                <option value="">All</option>
                <option value="Present">Present</option>
                <option value="Absent">Absent</option>
                <option value="Late">Late</option>
              </select>
            </div>
          </div>
          <div className="flex gap-2 mt-3">
            <button
              onClick={handleApplyFilters}
              className="px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              Apply Filters
            </button>
            <button
              onClick={handleClearFilters}
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
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Batch / Email</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Date</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Marked By</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {records.map((r, idx) => (
                    <tr key={r.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-text-dark">{r.studentName}</td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="font-medium text-text-dark">{r.batchName}</p>
                          <p className="text-xs text-text-muted">{r.studentEmail}</p>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-text-muted">{formatDate(r.date)}</td>
                      <td className="px-4 py-3">{statusBadge(r.status)}</td>
                      <td className="px-4 py-3 text-text-muted text-xs">
                        <div>
                          <p>{r.markedBy}</p>
                          <p className="text-[10px] text-slate-400">{formatDate(r.markedAt)}</p>
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

      {/* Mark Attendance Modal */}
      {showMarkModal && user?.id && (
        <MarkAttendanceModal
          coachId={String(user.id)}
          onClose={() => setShowMarkModal(false)}
          onSuccess={() => load(1)}
        />
      )}
    </UnifiedDashboardLayout>
  );
}
