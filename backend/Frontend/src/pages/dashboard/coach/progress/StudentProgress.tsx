import React, { useState, useEffect, useCallback } from 'react';
import {
  TrendingUp, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Eye, X, Filter, Plus, Save, Pencil, Trash2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface StudentProgressRecord {
  id: number;
  studentId: number;
  sportId: number;
  studentName: string;
  sport: string;
  program: string;
  currentScore: number;
  skillLevel: string;
  previousScore: number | null;
  improvement: string;
  lastUpdated: string;
  notes: string;
}

interface StudentsResponse {
  success: boolean;
  data: {
    progress: StudentProgressRecord[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}

interface Option { id: number; name: string; }

const SKILL_LEVELS = ['Beginner', 'Intermediate', 'Advanced', 'Expert'] as const;

function todayISO() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// ── Progress helpers ──────────────────────────────────────────────────────────

const PROGRESS_STYLES: Record<string, string> = {
  Excellent:          'bg-green-100 text-green-700',
  Good:               'bg-blue-100 text-blue-700',
  Average:            'bg-amber-100 text-amber-700',
  'Needs Improvement':'bg-red-100 text-red-600',
};

function progressBadge(level?: string) {
  const l = level ?? 'Average';
  const cls = PROGRESS_STYLES[l] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {l}
    </span>
  );
}

function formatDate(d?: string) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

/** Tailwind-based progress bar */
function ProgressBar({ value, color = 'bg-brand-primary' }: { value: number; color?: string }) {
  const pct = Math.min(100, Math.max(0, value));
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
        <div
          className={`h-full rounded-full transition-all ${color}`}
          style={{ width: `${pct}%` }}
        />
      </div>
      <span className="text-xs font-medium text-text-dark w-8 text-right">{pct}%</span>
    </div>
  );
}

// ── View Drawer ───────────────────────────────────────────────────────────────

interface DrawerProps {
  student: StudentProgressRecord;
  onClose: () => void;
}

const ProgressDrawer: React.FC<DrawerProps> = ({ student, onClose }) => {
  const getProgressLevel = (score: number): string => {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Average';
    return 'Needs Improvement';
  };

  const level = getProgressLevel(student.currentScore);

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white w-full max-w-md h-full overflow-y-auto shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-white z-10">
          <h2 className="text-lg font-bold text-text-dark">Student Progress</h2>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} className="text-slate-500" />
          </button>
        </div>

        <div className="flex-1 p-6 space-y-6">
          {/* Avatar */}
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-full bg-brand-primary/10 flex items-center justify-center text-brand-primary font-bold text-xl">
              {student.studentName.charAt(0).toUpperCase()}
            </div>
            <div>
              <p className="font-bold text-text-dark text-lg">{student.studentName}</p>
              <p className="text-sm text-text-muted">{student.sport}</p>
            </div>
          </div>

          {/* Program */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Program</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Program</span>
                <span className="font-medium text-text-dark">{student.program}</span>
              </div>
            </div>
          </section>

          {/* Progress Metrics */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Progress Metrics</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-4">
              <div>
                <div className="flex justify-between mb-1">
                  <span className="text-xs text-text-muted">Current Score</span>
                </div>
                <ProgressBar value={student.currentScore} color="bg-brand-primary" />
              </div>
              {student.previousScore !== null && (
                <div>
                  <div className="flex justify-between mb-1">
                    <span className="text-xs text-text-muted">Previous Score</span>
                  </div>
                  <ProgressBar value={student.previousScore} color="bg-slate-400" />
                </div>
              )}
            </div>
          </section>

          {/* Summary */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Summary</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Improvement</span>
                <span className={`font-bold ${student.improvement.startsWith('+') ? 'text-green-600' : student.improvement.startsWith('-') ? 'text-red-600' : 'text-slate-600'}`}>
                  {student.improvement}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Last Updated</span>
                <span className="font-medium text-text-dark">{formatDate(student.lastUpdated)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Progress Level</span>
                {progressBadge(level)}
              </div>
            </div>
          </section>

          {/* Notes */}
          {student.notes && (
            <section>
              <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Notes</h3>
              <div className="bg-slate-50 rounded-xl p-4 text-sm text-text-dark">
                {student.notes}
              </div>
            </section>
          )}
        </div>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function StudentProgress() {
  const { user } = useAuth();

  const [students, setStudents] = useState<StudentProgressRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedStudent, setSelectedStudent] = useState<StudentProgressRecord | null>(null);

  // Filters
  const [sportFilter, setSportFilter] = useState('');

  // Dropdown options (the coach's own students + sports) for filter + record form
  const [studentOpts, setStudentOpts] = useState<Option[]>([]);
  const [sportOpts, setSportOpts] = useState<Option[]>([]);

  // Record / edit progress modal
  const [showRecord, setShowRecord] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const emptyForm = {
    studentId: '', sportId: '', fitnessScore: '', skillLevel: 'Beginner',
    coachNotes: '', assessmentDate: todayISO(),
  };
  const [form, setForm] = useState(emptyForm);

  const limit = 10;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(p),
        limit: String(limit),
      });
      if (sportFilter.trim()) params.set('sportId', sportFilter.trim());

      const res = await fetchWithAuth(`${API_BASE}/coach/dashboard/performance/progress?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: StudentsResponse = await res.json();

      setStudents(data.data?.progress ?? []);
      setTotal(data.data?.total ?? 0);
      setTotalPages(data.data?.totalPages ?? 1);
      setPage(p);
    } catch (err) {
      console.error('Failed to load student progress:', err);
      setError('Failed to load student progress. Please try again.');
      toast.error('Failed to load student progress');
    } finally {
      setLoading(false);
    }
  }, [sportFilter]);

  useEffect(() => { load(1); }, [load]);

  // Load the coach's students + sports for the filter dropdown and record form.
  const loadOptions = useCallback(async () => {
    try {
      const [stuRes, spRes] = await Promise.all([
        fetchWithAuth(`${API_BASE}/coach/dashboard/autocomplete/students`),
        fetchWithAuth(`${API_BASE}/coach/dashboard/autocomplete/sports`),
      ]);
      if (stuRes.ok) setStudentOpts((await stuRes.json()).data ?? []);
      if (spRes.ok) setSportOpts((await spRes.json()).data ?? []);
    } catch {
      /* non-fatal — dropdowns just stay empty */
    }
  }, []);

  useEffect(() => { loadOptions(); }, [loadOptions]);

  const openCreate = () => {
    setEditingId(null);
    setForm(emptyForm);
    setShowRecord(true);
  };

  const openEdit = (r: StudentProgressRecord) => {
    setEditingId(r.id);
    setForm({
      studentId: String(r.studentId),
      sportId: String(r.sportId),
      fitnessScore: String(r.currentScore),
      skillLevel: r.skillLevel || 'Beginner',
      coachNotes: r.notes || '',
      assessmentDate: r.lastUpdated ? String(r.lastUpdated).slice(0, 10) : todayISO(),
    });
    setShowRecord(true);
  };

  const submitRecord = async () => {
    if (!form.studentId || !form.sportId || form.fitnessScore === '') {
      toast.error('Student, sport and fitness score are required');
      return;
    }
    const score = Number(form.fitnessScore);
    if (Number.isNaN(score) || score < 0 || score > 100) {
      toast.error('Fitness score must be between 0 and 100');
      return;
    }
    setSaving(true);
    try {
      const isEdit = editingId != null;
      const res = await fetchWithAuth(
        `${API_BASE}/coach/dashboard/performance/progress${isEdit ? `/${editingId}` : ''}`,
        {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify({
            studentId: Number(form.studentId),
            sportId: Number(form.sportId),
            fitnessScore: score,
            skillLevel: form.skillLevel,
            coachNotes: form.coachNotes || undefined,
            assessmentDate: form.assessmentDate || undefined,
          }),
        },
      );
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.message || 'Failed to save progress');
      toast.success(isEdit ? 'Progress updated' : 'Progress recorded');
      setShowRecord(false);
      setEditingId(null);
      setForm(emptyForm);
      load(page);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to save progress');
    } finally {
      setSaving(false);
    }
  };

  const deleteRecord = async (r: StudentProgressRecord) => {
    if (!window.confirm(`Delete this progress record for ${r.studentName}?`)) return;
    setDeletingId(r.id);
    try {
      const res = await fetchWithAuth(`${API_BASE}/coach/dashboard/performance/progress/${r.id}`, {
        method: 'DELETE',
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.message || 'Failed to delete');
      toast.success('Progress deleted');
      // If we just removed the last row on this page, step back a page.
      const nextPage = students.length === 1 && page > 1 ? page - 1 : page;
      load(nextPage);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to delete');
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Student Progress" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Student Progress</h1>
            <p className="text-text-muted text-sm mt-1">{total} student{total !== 1 ? 's' : ''} tracked</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => load(page)}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
            >
              <RefreshCw size={15} /> Refresh
            </button>
            <button
              onClick={openCreate}
              className="flex items-center gap-2 px-4 py-2 bg-brand-primary text-white rounded-xl text-sm font-medium hover:bg-brand-primary/90 transition-all"
            >
              <Plus size={15} /> Record Progress
            </button>
          </div>
        </div>

        {/* Filters */}
        <div className="bg-white rounded-xl border border-border p-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter size={15} className="text-slate-400" />
            <span className="text-sm font-medium text-text-dark">Filters</span>
          </div>
          <div className="flex gap-3 flex-wrap">
            <div className="min-w-[200px]">
              <label className="block text-xs text-text-muted mb-1">Sport</label>
              <select
                value={sportFilter}
                onChange={(e) => setSportFilter(e.target.value)}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white"
              >
                <option value="">All sports</option>
                {sportOpts.map((s) => (
                  <option key={s.id} value={s.id}>{s.name}</option>
                ))}
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
              onClick={() => setSportFilter('')}
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
              <p className="text-text-muted text-sm">Loading student progress…</p>
            </div>
          ) : students.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <TrendingUp size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No students found</p>
              <p className="text-text-muted text-sm">No students are currently assigned to you.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Student Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Sport</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Program</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Current Score</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Improvement</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Last Updated</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Progress</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {students.map((s, idx) => {
                    const getProgressLevel = (score: number): string => {
                      if (score >= 90) return 'Excellent';
                      if (score >= 75) return 'Good';
                      if (score >= 60) return 'Average';
                      return 'Needs Improvement';
                    };
                    const level = getProgressLevel(s.currentScore);
                    return (
                      <tr key={s.id} className="hover:bg-slate-50 transition-colors">
                        <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                        <td className="px-4 py-3 font-medium text-text-dark">{s.studentName}</td>
                        <td className="px-4 py-3 text-text-muted">{s.sport}</td>
                        <td className="px-4 py-3 text-text-muted">{s.program}</td>
                        <td className="px-4 py-3 min-w-[120px]">
                          <ProgressBar value={s.currentScore} color="bg-brand-primary" />
                        </td>
                        <td className="px-4 py-3">
                          <span className={`font-bold ${s.improvement.startsWith('+') ? 'text-green-600' : s.improvement.startsWith('-') ? 'text-red-600' : 'text-slate-600'}`}>
                            {s.improvement}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-text-muted">{formatDate(s.lastUpdated)}</td>
                        <td className="px-4 py-3">{progressBadge(level)}</td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-1.5">
                            <button
                              onClick={() => setSelectedStudent(s)}
                              title="View"
                              className="flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-brand-primary border border-brand-primary/30 rounded-lg hover:bg-brand-primary/5 transition-colors"
                            >
                              <Eye size={13} /> View
                            </button>
                            <button
                              onClick={() => openEdit(s)}
                              title="Edit"
                              className="p-1.5 text-slate-500 border border-border rounded-lg hover:text-brand-primary hover:border-brand-primary transition-colors"
                            >
                              <Pencil size={13} />
                            </button>
                            <button
                              onClick={() => deleteRecord(s)}
                              disabled={deletingId === s.id}
                              title="Delete"
                              className="p-1.5 text-slate-500 border border-border rounded-lg hover:text-red-600 hover:border-red-300 transition-colors disabled:opacity-50"
                            >
                              {deletingId === s.id ? <Loader2 size={13} className="animate-spin" /> : <Trash2 size={13} />}
                            </button>
                          </div>
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

      {/* Progress Drawer */}
      {selectedStudent && (
        <ProgressDrawer
          student={selectedStudent}
          onClose={() => setSelectedStudent(null)}
        />
      )}

      {/* Record Progress Modal */}
      {showRecord && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/40" onClick={() => !saving && setShowRecord(false)} />
          <div className="relative bg-white w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden">
            <div className="flex items-center justify-between px-6 py-4 border-b border-border">
              <h2 className="text-lg font-bold text-text-dark">{editingId ? 'Edit Student Progress' : 'Record Student Progress'}</h2>
              <button onClick={() => !saving && setShowRecord(false)} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
                <X size={18} className="text-slate-500" />
              </button>
            </div>

            <div className="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-text-muted mb-1">Student *</label>
                  <select
                    value={form.studentId}
                    onChange={(e) => setForm((f) => ({ ...f, studentId: e.target.value }))}
                    disabled={editingId != null}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary disabled:bg-slate-100 disabled:text-slate-500"
                  >
                    <option value="">Select student…</option>
                    {studentOpts.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                  </select>
                  {editingId == null && studentOpts.length === 0 && (
                    <p className="text-[11px] text-amber-600 mt-1">No students assigned to you yet.</p>
                  )}
                </div>
                <div>
                  <label className="block text-xs font-medium text-text-muted mb-1">Sport *</label>
                  <select
                    value={form.sportId}
                    onChange={(e) => setForm((f) => ({ ...f, sportId: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  >
                    <option value="">Select sport…</option>
                    {sportOpts.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-text-muted mb-1">Fitness Score (0–100) *</label>
                  <input
                    type="number" min={0} max={100}
                    value={form.fitnessScore}
                    onChange={(e) => setForm((f) => ({ ...f, fitnessScore: e.target.value }))}
                    placeholder="e.g. 78"
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-text-muted mb-1">Skill Level</label>
                  <select
                    value={form.skillLevel}
                    onChange={(e) => setForm((f) => ({ ...f, skillLevel: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  >
                    {SKILL_LEVELS.map((l) => <option key={l} value={l}>{l}</option>)}
                  </select>
                </div>
                <div className="sm:col-span-2">
                  <label className="block text-xs font-medium text-text-muted mb-1">Assessment Date</label>
                  <input
                    type="date"
                    value={form.assessmentDate}
                    onChange={(e) => setForm((f) => ({ ...f, assessmentDate: e.target.value }))}
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="block text-xs font-medium text-text-muted mb-1">Coach Notes</label>
                  <textarea
                    rows={3}
                    value={form.coachNotes}
                    onChange={(e) => setForm((f) => ({ ...f, coachNotes: e.target.value }))}
                    placeholder="Observations, areas to improve…"
                    className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary resize-none"
                  />
                </div>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 px-6 py-4 border-t border-border bg-slate-50">
              <button
                onClick={() => !saving && setShowRecord(false)}
                className="px-4 py-2 bg-white border border-border rounded-lg text-sm text-slate-600 hover:bg-slate-100 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={submitRecord}
                disabled={saving}
                className="flex items-center gap-2 px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 transition-colors disabled:opacity-50"
              >
                {saving ? <Loader2 size={15} className="animate-spin" /> : <Save size={15} />}
                {saving ? 'Saving…' : editingId ? 'Update' : 'Save Progress'}
              </button>
            </div>
          </div>
        </div>
      )}
    </UnifiedDashboardLayout>
  );
}
