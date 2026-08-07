import React, { useState, useEffect, useCallback } from 'react';
import {
  Bell, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Plus, X, Send,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface Notification {
  id: number;
  title: string;
  message: string;
  type?: string;
  targetRole?: string;
  status?: string;
  isRead?: boolean;
  sentAt?: string;
  createdAt: string;
}

interface NotificationsResponse {
  success: boolean;
  notifications: Notification[];
  total?: number;
  totalPages?: number;
  currentPage?: number;
}

// ── Type / Status helpers ─────────────────────────────────────────────────────

const TYPE_STYLES: Record<string, string> = {
  System:    'bg-blue-100 text-blue-700',
  Booking:   'bg-purple-100 text-purple-700',
  Payment:   'bg-green-100 text-green-700',
  Alert:     'bg-red-100 text-red-600',
  Promotion: 'bg-amber-100 text-amber-700',
  Feedback:  'bg-slate-100 text-slate-600',
};

function typeBadge(type?: string) {
  const t = type ?? 'System';
  const cls = TYPE_STYLES[t] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium capitalize ${cls}`}>
      {t}
    </span>
  );
}

function statusBadge(notification: Notification) {
  const status = notification.status ?? (notification.isRead ? 'Read' : 'Sent');
  const cls = status === 'Read' ? 'bg-slate-100 text-slate-500' : 'bg-green-100 text-green-700';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {status}
    </span>
  );
}

function formatDate(dateStr?: string) {
  if (!dateStr) return '—';
  try {
    return new Date(dateStr).toLocaleDateString('en-IN', {
      day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
    });
  } catch {
    return dateStr;
  }
}

// ── Create Notification Modal ─────────────────────────────────────────────────

interface CreateModalProps {
  onClose: () => void;
  onSuccess: () => void;
}

const CreateNotificationModal: React.FC<CreateModalProps> = ({ onClose, onSuccess }) => {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [type, setType] = useState('System');
  const [submitting, setSubmitting] = useState(false);

  // Targeting mirrors the admin broadcast, but the audience is capped to this
  // employee's own sports complex. The API enforces the same ceiling, so the
  // pickers can never offer a recipient that the send would reject.
  const [recipient, setRecipient] = useState<'all' | 'selected' | 'coaches'>('all');
  const [coaches, setCoaches] = useState<{ id: number; name: string; email?: string }[]>([]);
  const [people, setPeople] = useState<{ id: number; name: string; email?: string }[]>([]);
  const [selectedCoachIds, setSelectedCoachIds] = useState<number[]>([]);
  const [selectedUserIds, setSelectedUserIds] = useState<number[]>([]);
  const [coachSearch, setCoachSearch] = useState('');
  const [userSearch, setUserSearch] = useState('');
  const [loadingAudience, setLoadingAudience] = useState(true);

  useEffect(() => {
    fetchWithAuth(`${API_BASE}/notifications/audience`)
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => {
        const d = j?.data;
        const coachList = Array.isArray(d?.coaches) ? d.coaches : [];
        setCoaches(coachList);
        // Coaches receive messages too, so they appear in the people list as well.
        const students = Array.isArray(d?.students) ? d.students : [];
        const coachUsers = coachList
          .filter((c: any) => c.userId != null)
          .map((c: any) => ({ id: c.userId, name: c.name, email: c.email }));
        const byId = new Map<number, { id: number; name: string; email?: string }>();
        [...coachUsers, ...students].forEach((u: any) => byId.set(u.id, u));
        setPeople([...byId.values()]);
      })
      .catch(() => { setCoaches([]); setPeople([]); })
      .finally(() => setLoadingAudience(false));
  }, []);

  const filteredCoaches = coaches.filter((c) => {
    const q = coachSearch.trim().toLowerCase();
    return !q || (c.name ?? '').toLowerCase().includes(q) || (c.email ?? '').toLowerCase().includes(q);
  });
  const filteredPeople = people.filter((u) => {
    const q = userSearch.trim().toLowerCase();
    return !q || (u.name ?? '').toLowerCase().includes(q) || (u.email ?? '').toLowerCase().includes(q);
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) {
      toast.error('Title and message are required');
      return;
    }
    if (recipient === 'coaches' && selectedCoachIds.length === 0) {
      toast.error('Please select at least one coach');
      return;
    }
    if (recipient === 'selected' && selectedUserIds.length === 0) {
      toast.error('Please select at least one recipient');
      return;
    }

    setSubmitting(true);
    try {
      const payload: Record<string, any> = { title, message, type, recipient };
      if (recipient === 'coaches') payload.coachIds = selectedCoachIds;
      if (recipient === 'selected') payload.userIds = selectedUserIds;

      const res = await fetchWithAuth(`${API_BASE}/notifications/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const result = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(result.message || `HTTP ${res.status}`);
      toast.success(result.message || 'Notification sent successfully');
      onSuccess();
      onClose();
    } catch (err: any) {
      console.error('Failed to send notification:', err);
      toast.error(err.message || 'Failed to send notification');
    } finally {
      setSubmitting(false);
    }
  };

  const radioCls = (active: boolean) =>
    `flex items-start gap-3 p-3.5 rounded-xl border-2 cursor-pointer transition-colors ${
      active ? 'border-brand-primary bg-brand-primary/5' : 'border-slate-200 bg-slate-50 hover:bg-slate-100'
    }`;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[92vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
          <div>
            <h2 className="text-lg font-bold text-text-dark">New Notification</h2>
            <p className="text-[11px] text-text-muted uppercase tracking-wider mt-0.5">
              Broadcast to your sports complex
            </p>
          </div>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} className="text-slate-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5 overflow-y-auto">
          {/* Recipient targeting */}
          <div className="space-y-3">
            <p className="text-[11px] font-black text-brand-primary uppercase tracking-widest">Recipient Targeting</p>

            <label className={radioCls(recipient === 'all')}>
              <input
                type="radio"
                name="emp-recipient"
                checked={recipient === 'all'}
                onChange={() => { setRecipient('all'); setSelectedCoachIds([]); setSelectedUserIds([]); }}
                className="mt-0.5 w-4 h-4 accent-brand-primary"
              />
              <div>
                <div className="font-bold text-sm text-text-dark">Everyone in My Complex</div>
                <div className="text-xs text-text-muted">
                  All coaches and students at your complex
                  {loadingAudience ? '' : ` (${people.length} people)`}
                </div>
              </div>
            </label>

            <label className={radioCls(recipient === 'selected')}>
              <input
                type="radio"
                name="emp-recipient"
                checked={recipient === 'selected'}
                onChange={() => { setRecipient('selected'); setSelectedCoachIds([]); }}
                className="mt-0.5 w-4 h-4 accent-brand-primary"
              />
              <div>
                <div className="font-bold text-sm text-text-dark">Select People</div>
                <div className="text-xs text-text-muted">Choose specific coaches or students</div>
              </div>
            </label>

            <label className={radioCls(recipient === 'coaches')}>
              <input
                type="radio"
                name="emp-recipient"
                checked={recipient === 'coaches'}
                onChange={() => { setRecipient('coaches'); setSelectedUserIds([]); }}
                className="mt-0.5 w-4 h-4 accent-brand-primary"
              />
              <div>
                <div className="font-bold text-sm text-text-dark">Coach-wise Students</div>
                <div className="text-xs text-text-muted">
                  Pick coaches, and the message reaches each coach and every student in their batches
                </div>
              </div>
            </label>
          </div>

          {/* Coach picker */}
          {recipient === 'coaches' && (
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-[11px] font-bold text-text-muted uppercase tracking-wider">
                  Select Coaches ({selectedCoachIds.length})
                </label>
                <div className="flex gap-2 text-[10px] font-bold uppercase tracking-wider">
                  <button type="button" onClick={() => setSelectedCoachIds(filteredCoaches.map((c) => c.id))} className="text-brand-primary hover:underline">All</button>
                  <span className="text-slate-300">|</span>
                  <button type="button" onClick={() => setSelectedCoachIds([])} className="text-slate-500 hover:underline">Clear</button>
                </div>
              </div>
              <input
                type="text"
                value={coachSearch}
                onChange={(e) => setCoachSearch(e.target.value)}
                placeholder="Search coaches..."
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20"
              />
              <div className="max-h-48 overflow-y-auto border border-border rounded-xl divide-y divide-slate-100">
                {filteredCoaches.length === 0 ? (
                  <p className="text-xs text-slate-400 text-center py-6">
                    {loadingAudience ? 'Loading...' : 'No coaches in your complex.'}
                  </p>
                ) : filteredCoaches.map((c) => (
                  <label key={c.id} className="flex items-center gap-3 px-3 py-2.5 hover:bg-slate-50 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={selectedCoachIds.includes(c.id)}
                      onChange={(ev) => setSelectedCoachIds((prev) => ev.target.checked ? [...prev, c.id] : prev.filter((id) => id !== c.id))}
                      className="w-4 h-4 accent-brand-primary"
                    />
                    <div className="min-w-0">
                      <p className="text-sm font-bold text-text-dark truncate">{c.name}</p>
                      <p className="text-[11px] text-slate-500 truncate">{c.email ?? '-'}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>
          )}

          {/* People picker */}
          {recipient === 'selected' && (
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-[11px] font-bold text-text-muted uppercase tracking-wider">
                  Select People ({selectedUserIds.length})
                </label>
                <div className="flex gap-2 text-[10px] font-bold uppercase tracking-wider">
                  <button type="button" onClick={() => setSelectedUserIds(filteredPeople.map((u) => u.id))} className="text-brand-primary hover:underline">All</button>
                  <span className="text-slate-300">|</span>
                  <button type="button" onClick={() => setSelectedUserIds([])} className="text-slate-500 hover:underline">Clear</button>
                </div>
              </div>
              <input
                type="text"
                value={userSearch}
                onChange={(e) => setUserSearch(e.target.value)}
                placeholder="Search coaches and students..."
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20"
              />
              <div className="max-h-48 overflow-y-auto border border-border rounded-xl divide-y divide-slate-100">
                {filteredPeople.length === 0 ? (
                  <p className="text-xs text-slate-400 text-center py-6">
                    {loadingAudience ? 'Loading...' : 'No coaches or students in your complex.'}
                  </p>
                ) : filteredPeople.map((u) => (
                  <label key={u.id} className="flex items-center gap-3 px-3 py-2.5 hover:bg-slate-50 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={selectedUserIds.includes(u.id)}
                      onChange={(ev) => setSelectedUserIds((prev) => ev.target.checked ? [...prev, u.id] : prev.filter((id) => id !== u.id))}
                      className="w-4 h-4 accent-brand-primary"
                    />
                    <div className="min-w-0">
                      <p className="text-sm font-bold text-text-dark truncate">{u.name}</p>
                      <p className="text-[11px] text-slate-500 truncate">{u.email ?? '-'}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>
          )}

          {/* Message payload */}
          <div className="space-y-4 pt-1">
            <p className="text-[11px] font-black text-brand-primary uppercase tracking-widest">Message Payload</p>
            <div>
              <label className="block text-sm font-medium text-text-dark mb-1">
                Title <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Notification title"
                required
                maxLength={200}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-text-dark mb-1">
                Message <span className="text-red-500">*</span>
              </label>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Notification message..."
                required
                rows={4}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary resize-none"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-text-dark mb-1">Type</label>
              <select
                value={type}
                onChange={(e) => setType(e.target.value)}
                className="w-full px-3 py-2 border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white"
              >
                <option value="System">System</option>
                <option value="Booking">Booking</option>
                <option value="Payment">Payment</option>
                <option value="Alert">Alert</option>
                <option value="Promotion">Promotion</option>
                <option value="Feedback">Feedback</option>
              </select>
            </div>
          </div>

          <div className="flex gap-3 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 border border-border rounded-xl text-sm font-medium text-slate-600 hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 py-2.5 bg-brand-primary text-white rounded-xl text-sm font-medium hover:bg-brand-primary/90 disabled:opacity-60 transition-colors flex items-center justify-center gap-2"
            >
              {submitting ? <Loader2 size={15} className="animate-spin" /> : <Send size={15} />}
              Send Notification
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function NotificationsManagement() {
  useAuth();

  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [showCreateModal, setShowCreateModal] = useState(false);

  const limit = 10;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ page: String(p), limit: String(limit) });
      const res = await fetchWithAuth(`${API_BASE}/notifications?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();

      setNotifications(result.data ?? []);
      setTotal(result.pagination?.totalItems ?? 0);
      setTotalPages(result.pagination?.totalPages ?? 1);
      setPage(result.pagination?.currentPage ?? p);
    } catch (err) {
      console.error('Failed to load notifications:', err);
      setError('Failed to load notifications. Please try again.');
      toast.error('Failed to load notifications');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(1); }, [load]);

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Notifications" />}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Notifications</h1>
            <p className="text-text-muted text-sm mt-1">{total} notification{total !== 1 ? 's' : ''} total</p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setShowCreateModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-brand-primary text-white rounded-xl text-sm font-medium hover:bg-brand-primary/90 transition-colors"
            >
              <Plus size={15} /> New Notification
            </button>
            <button
              onClick={() => load(page)}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
            >
              <RefreshCw size={15} /> Refresh
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
              <p className="text-text-muted text-sm">Loading notifications…</p>
            </div>
          ) : notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Bell size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No notifications found</p>
              <p className="text-text-muted text-sm">Create a new notification to get started.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Title</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Message</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Type</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Target Role</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Sent At</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {notifications.map((n, idx) => (
                    <tr key={n.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted">{(page - 1) * limit + idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-text-dark max-w-[180px]">
                        <p className="truncate">{n.title}</p>
                      </td>
                      <td className="px-4 py-3 text-text-muted max-w-[240px]">
                        <p className="truncate">{n.message}</p>
                      </td>
                      <td className="px-4 py-3">{typeBadge(n.type)}</td>
                      <td className="px-4 py-3 text-text-muted">{n.targetRole ?? 'All'}</td>
                      <td className="px-4 py-3 text-text-muted text-xs">
                        {formatDate(n.sentAt ?? n.createdAt)}
                      </td>
                      <td className="px-4 py-3">{statusBadge(n)}</td>
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

      {/* Create Notification Modal */}
      {showCreateModal && (
        <CreateNotificationModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={() => load(1)}
        />
      )}
    </UnifiedDashboardLayout>
  );
}
