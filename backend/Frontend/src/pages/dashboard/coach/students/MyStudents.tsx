import React, { useState, useEffect, useCallback } from 'react';
import {
  Users, Search, RefreshCw, Loader2, AlertCircle,
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

interface Student {
  id: number;
  name: string;
  email: string;
  phone: string;
  program: string;
  batch: string;
  enrollmentDate: string;
  status: string;
  attendance: string;
  performance: string;
}

interface StudentsResponse {
  success: boolean;
  data: {
    students: Student[];
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
  Pending:  'bg-amber-100 text-amber-700',
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

function formatDate(d?: string) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

// ── View Drawer ───────────────────────────────────────────────────────────────

interface DrawerProps {
  student: Student;
  onClose: () => void;
}

const StudentDrawer: React.FC<DrawerProps> = ({ student, onClose }) => {
  const name = student.name ?? '—';
  const email = student.email ?? '—';
  const phone = student.phone ?? '—';
  const program = student.program ?? '—';
  const batch = student.batch ?? '—';

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white w-full max-w-md h-full overflow-y-auto shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-white z-10">
          <h2 className="text-lg font-bold text-text-dark">Student Details</h2>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} className="text-slate-500" />
          </button>
        </div>

        <div className="flex-1 p-6 space-y-6">
          {/* Avatar */}
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-full bg-brand-primary/10 flex items-center justify-center text-brand-primary font-bold text-xl">
              {name.charAt(0).toUpperCase()}
            </div>
            <div>
              <p className="font-bold text-text-dark text-lg">{name}</p>
              <p className="text-sm text-text-muted">{email}</p>
            </div>
          </div>

          {/* Contact */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Contact</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Phone</span>
                <span className="font-medium text-text-dark">{phone}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Email</span>
                <span className="font-medium text-text-dark">{email}</span>
              </div>
            </div>
          </section>

          {/* Enrollment */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Enrollment</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Program</span>
                <span className="font-medium text-text-dark">{program}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Batch</span>
                <span className="font-medium text-text-dark">{batch}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Enrollment Date</span>
                <span className="font-medium text-text-dark">
                  {formatDate(student.enrollmentDate)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Status</span>
                {statusBadge(student.status)}
              </div>
            </div>
          </section>

          {/* Performance */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Performance</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Attendance</span>
                <span className="font-bold text-text-dark">{student.attendance}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Performance</span>
                <span className="font-bold text-text-dark">{student.performance}</span>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function MyStudents() {
  const { user } = useAuth();

  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedStudent, setSelectedStudent] = useState<Student | null>(null);
  const [search, setSearch] = useState('');

  const limit = 10;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(p),
        limit: String(limit),
      });
      if (search.trim()) params.set('search', search.trim());

      const res = await fetchWithAuth(`${API_BASE}/coach/dashboard/students/my-students?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: StudentsResponse = await res.json();

      setStudents(data.data?.students ?? []);
      setTotal(data.data?.total ?? 0);
      setTotalPages(data.data?.totalPages ?? 1);
      setPage(p);
    } catch (err) {
      console.error('Failed to load students:', err);
      setError('Failed to load students. Please try again.');
      toast.error('Failed to load students');
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => { load(1); }, [load]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    load(1);
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="My Students" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">My Students</h1>
            <p className="text-text-muted text-sm mt-1">{total} student{total !== 1 ? 's' : ''} assigned to you</p>
          </div>
          <button
            onClick={() => load(page)}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
          >
            <RefreshCw size={15} /> Refresh
          </button>
        </div>

        {/* Search */}
        <form onSubmit={handleSearch} className="bg-white rounded-xl border border-border p-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter size={15} className="text-slate-400" />
            <span className="text-sm font-medium text-text-dark">Search</span>
          </div>
          <div className="flex gap-3">
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
            <button
              type="submit"
              className="px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              Search
            </button>
            {search && (
              <button
                type="button"
                onClick={() => { setSearch(''); }}
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
              <p className="text-text-muted text-sm">Loading students…</p>
            </div>
          ) : students.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Users size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No students found</p>
              <p className="text-text-muted text-sm">No students are currently assigned to you.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Email</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Phone</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Program / Batch</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Enrollment Date</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {students.map((s, idx) => (
                    <tr key={s.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-text-dark">{s.name}</td>
                      <td className="px-4 py-3 text-text-muted">{s.email}</td>
                      <td className="px-4 py-3 text-text-muted">{s.phone}</td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="font-medium text-text-dark">{s.program}</p>
                          <p className="text-xs text-text-muted">{s.batch}</p>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-text-muted">
                        {formatDate(s.enrollmentDate)}
                      </td>
                      <td className="px-4 py-3">{statusBadge(s.status)}</td>
                      <td className="px-4 py-3">
                        <button
                          onClick={() => setSelectedStudent(s)}
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

      {/* Student Drawer */}
      {selectedStudent && (
        <StudentDrawer
          student={selectedStudent}
          onClose={() => setSelectedStudent(null)}
        />
      )}
    </UnifiedDashboardLayout>
  );
}
