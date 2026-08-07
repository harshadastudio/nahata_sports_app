import React, { useState, useEffect, useCallback } from 'react';
import {
  UserCheck, Search, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Eye, X,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface Coach {
  id: number;
  name: string;
  email: string;
  phone?: string;
  phone_number?: string;
  status?: string;
  isActive?: boolean;
  bio?: string;
  experience?: string | number;
  sports?: Array<{ id: number; name: string }> | string[];
  user?: { id: number; name: string; email: string; phone_number?: string };
  createdAt?: string;
}

interface CoachesResponse {
  success: boolean;
  // Direct shape (legacy)
  coaches?: Coach[];
  total?: number;
  totalPages?: number;
  currentPage?: number;
  // Nested shape returned by coachController → coachService
  data?: {
    coaches: Coach[];
    totalItems?: number;
    total?: number;
    totalPages?: number;
    currentPage?: number;
  };
}

// ── Status helpers ────────────────────────────────────────────────────────────

function getCoachStatus(coach: Coach): string {
  if (coach.status) return coach.status;
  if (typeof coach.isActive === 'boolean') return coach.isActive ? 'Active' : 'Inactive';
  return 'Active';
}

function statusBadge(status: string) {
  const cls =
    status === 'Active' || status === 'active'
      ? 'bg-green-100 text-green-700'
      : 'bg-slate-100 text-slate-500';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {status}
    </span>
  );
}

function getSportsDisplay(coach: Coach): string {
  if (!coach.sports || coach.sports.length === 0) return '—';
  return coach.sports
    .map((s) => (typeof s === 'string' ? s : s.name))
    .join(', ');
}

function formatDate(dateStr?: string) {
  if (!dateStr) return '—';
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
  coach: Coach;
  onClose: () => void;
}

const CoachDrawer: React.FC<DrawerProps> = ({ coach, onClose }) => {
  const displayName = coach.user?.name ?? coach.name;
  const displayEmail = coach.user?.email ?? coach.email;
  const displayPhone = coach.user?.phone_number ?? coach.phone ?? coach.phone_number;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white w-full max-w-md h-full overflow-y-auto shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-white z-10">
          <h2 className="text-lg font-bold text-text-dark">Coach Details</h2>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} className="text-slate-500" />
          </button>
        </div>

        <div className="flex-1 p-6 space-y-6">
          {/* Avatar */}
          <div className="flex items-center gap-4">
            <div className="flex items-center justify-center w-16 h-16 rounded-full bg-green-100 text-green-700 text-xl font-bold select-none">
              {displayName.split(' ').map((p: string) => p[0]).join('').toUpperCase().slice(0, 2)}
            </div>
            <div>
              <p className="text-lg font-bold text-text-dark">{displayName}</p>
              {statusBadge(getCoachStatus(coach))}
            </div>
          </div>

          {/* Contact */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Contact Information</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Email</span>
                <span className="font-medium text-text-dark">{displayEmail}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-muted">Phone</span>
                <span className="font-medium text-text-dark">{displayPhone ?? '—'}</span>
              </div>
            </div>
          </section>

          {/* Professional */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Professional Details</h3>
            <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-text-muted">Sports</span>
                <span className="font-medium text-text-dark text-right max-w-[200px]">{getSportsDisplay(coach)}</span>
              </div>
              {coach.experience !== undefined && (
                <div className="flex justify-between">
                  <span className="text-text-muted">Experience</span>
                  <span className="font-medium text-text-dark">{coach.experience} years</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-text-muted">Status</span>
                {statusBadge(getCoachStatus(coach))}
              </div>
              {coach.createdAt && (
                <div className="flex justify-between">
                  <span className="text-text-muted">Joined</span>
                  <span className="font-medium text-text-dark">{formatDate(coach.createdAt)}</span>
                </div>
              )}
            </div>
          </section>

          {/* Bio */}
          {coach.bio && (
            <section>
              <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">Bio</h3>
              <div className="bg-slate-50 rounded-xl p-4">
                <p className="text-sm text-text-muted leading-relaxed">{coach.bio}</p>
              </div>
            </section>
          )}
        </div>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function CoachesManagement() {
  useAuth();

  const [coaches, setCoaches] = useState<Coach[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedCoach, setSelectedCoach] = useState<Coach | null>(null);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');


  const limit = 10;




  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ page: String(p), limit: String(limit) });
      if (search) params.set('search', search);

      const res = await fetchWithAuth(`${API_BASE}/coaches?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: CoachesResponse = await res.json();

      // Handle both response shapes:
      // Shape A (coachController): { success, data: { coaches, totalItems, totalPages, currentPage } }
      // Shape B (legacy): { success, coaches, total, totalPages, currentPage }
      const nested = data.data;
      const coachesList = nested?.coaches ?? data.coaches ?? [];
      const totalCount  = nested?.totalItems ?? nested?.total ?? data.total ?? coachesList.length;
      const pages       = nested?.totalPages ?? data.totalPages ?? 1;

      setCoaches(coachesList);
      setTotal(totalCount);
      setTotalPages(pages);
      setPage(p);
    } catch (err) {
      console.error('Failed to load coaches:', err);
      setError('Failed to load coaches. Please try again.');
      toast.error('Failed to load coaches');
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => { load(1); }, [load]);

  const handleSearch = () => setSearch(searchInput);
  const handleClearSearch = () => { setSearchInput(''); setSearch(''); };
  const handleKeyDown = (e: React.KeyboardEvent) => { if (e.key === 'Enter') handleSearch(); };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Coaches Management" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Coaches Management</h1>
            <p className="text-text-muted text-sm mt-1">{total} coach{total !== 1 ? 'es' : ''} total</p>
          </div>
          <button
            onClick={() => load(page)}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
          >
            <RefreshCw size={15} /> Refresh
          </button>
        </div>

        {/* Search */}
        <div className="bg-white rounded-xl border border-border p-4">
          <div className="flex items-center gap-2 mb-3">
            <Search size={15} className="text-slate-400" />
            <span className="text-sm font-medium text-text-dark">Search by Name</span>
          </div>
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                type="text"
                placeholder="Search coaches by name…"
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
                onKeyDown={handleKeyDown}
                className="w-full pl-9 pr-4 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
              />
            </div>
            <button
              onClick={handleSearch}
              className="px-4 py-2 bg-brand-primary text-white rounded-lg text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              Search
            </button>
            {search && (
              <button
                onClick={handleClearSearch}
                className="px-4 py-2 bg-white border border-border rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors"
              >
                Clear
              </button>
            )}
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
              <p className="text-text-muted text-sm">Loading coaches…</p>
            </div>
          ) : coaches.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <UserCheck size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No coaches found</p>
              <p className="text-text-muted text-sm">
                {search ? 'Try a different search term.' : 'No coaches available.'}
              </p>
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
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Sports</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {coaches.map((c, idx) => {
                    const displayName = c.user?.name ?? c.name;
                    const displayEmail = c.user?.email ?? c.email;
                    const displayPhone = c.user?.phone_number ?? c.phone ?? c.phone_number;
                    return (
                      <tr key={c.id} className="hover:bg-slate-50 transition-colors">
                        <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                        <td className="px-4 py-3 font-medium text-text-dark">{displayName}</td>
                        <td className="px-4 py-3 text-text-muted">{displayEmail}</td>
                        <td className="px-4 py-3 text-text-muted">{displayPhone ?? '—'}</td>
                        <td className="px-4 py-3 text-text-muted max-w-[160px] truncate">{getSportsDisplay(c)}</td>
                        <td className="px-4 py-3">{statusBadge(getCoachStatus(c))}</td>
                        <td className="px-4 py-3">
                          <button
                            onClick={() => setSelectedCoach(c)}
                            className="flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-brand-primary border border-brand-primary/30 rounded-lg hover:bg-brand-primary/5 transition-colors"
                          >
                            <Eye size={13} /> View
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

      {/* Coach Drawer */}
      {selectedCoach && (
        <CoachDrawer coach={selectedCoach} onClose={() => setSelectedCoach(null)} />
      )}


    </UnifiedDashboardLayout>
  );
}

