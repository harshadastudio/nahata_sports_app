import React, { useState, useEffect, useCallback } from 'react';
import {
  Bell, RefreshCw, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, Plus, X, Send, Users,
  Pencil, Trash2, CheckCircle2, Slash, Type, AlignLeft,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { motion, AnimatePresence } from 'framer-motion';
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
  recipientCount?: number;
}

interface NotificationsResponse {
  success: boolean;
  notifications: Notification[];
  total?: number;
  totalPages?: number;
  currentPage?: number;
}

interface User {
  id: number;
  name: string;
  email: string;
  role?: string;
}

// ── Type / Status helpers ─────────────────────────────────────────────────────

const TYPE_STYLES: Record<string, string> = {
  System:       'bg-blue-100 text-blue-700',
  Training:     'bg-purple-100 text-purple-700',
  Attendance:   'bg-green-100 text-green-700',
  Performance:  'bg-amber-100 text-amber-700',
  Alert:        'bg-red-100 text-red-600',
  General:      'bg-slate-100 text-slate-600',
};

function typeBadge(type?: string) {
  const t = type ?? 'General';
  const cls = TYPE_STYLES[t] ?? 'bg-slate-100 text-slate-600';
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium capitalize ${cls}`}>
      {t}
    </span>
  );
}

function statusBadge(notification: Notification) {
  const status = notification.status ?? 'Sent';
  const cls = status === 'Sent' ? 'bg-green-100 text-green-700' : 'bg-slate-100 text-slate-500';
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

// ── Create/Edit Notification Slide-over ──────────────────────────────────────

interface FormProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  editingNotification: Notification | null;
}

const NotificationForm: React.FC<FormProps> = ({ isOpen, onClose, onSuccess, editingNotification }) => {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [type, setType] = useState('System');
  const [recipient, setRecipient] = useState<'all' | 'selected'>('all');
  const [selectedUserIds, setSelectedUserIds] = useState<number[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  // Load form data when editing
  useEffect(() => {
    if (editingNotification) {
      setTitle(editingNotification.title);
      setMessage(editingNotification.message);
      setType(editingNotification.type || 'System');
      setRecipient('selected');
      setSelectedUserIds([]);
    } else {
      resetForm();
    }
  }, [editingNotification]);

  // Load all users when modal opens
  useEffect(() => {
    if (isOpen) {
      loadUsers();
    }
  }, [isOpen]);

  const loadUsers = async () => {
    setLoadingUsers(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/notifications/users`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setUsers(data.data ?? []);
    } catch (err) {
      console.error('Failed to load users:', err);
      toast.error('Failed to load users list');
    } finally {
      setLoadingUsers(false);
    }
  };

  const resetForm = () => {
    setTitle('');
    setMessage('');
    setType('System');
    setRecipient('all');
    setSelectedUserIds([]);
    setSearchTerm('');
  };

  const handleUserToggle = (userId: number) => {
    setSelectedUserIds(prev =>
      prev.includes(userId)
        ? prev.filter(id => id !== userId)
        : [...prev, userId]
    );
  };

  const handleSelectAll = () => {
    if (selectedUserIds.length === filteredUsers.length) {
      setSelectedUserIds([]);
    } else {
      setSelectedUserIds(filteredUsers.map(u => u.id));
    }
  };

  const filteredUsers = users.filter(user =>
    user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleSubmit = async () => {
    if (!title.trim() || !message.trim()) {
      toast.error('Title and message are required');
      return;
    }

    if (recipient === 'selected' && selectedUserIds.length === 0) {
      toast.error('Please select at least one user');
      return;
    }

    setSubmitting(true);
    try {
      const payload: Record<string, any> = {
        title,
        message,
        type,
        recipient,
      };

      if (recipient === 'selected') {
        payload.userIds = selectedUserIds;
      }

      const url = editingNotification
        ? `${API_BASE}/notifications/${editingNotification.id}`
        : `${API_BASE}/notifications/send`;
      
      const method = editingNotification ? 'PATCH' : 'POST';

      const res = await fetchWithAuth(url, {
        method,
        body: JSON.stringify(payload),
      });
      
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();
      
      toast.success(result.message || (editingNotification ? 'Notification updated successfully' : 'Notification sent successfully'));
      onSuccess();
      onClose();
      resetForm();
    } catch (err) {
      console.error('Failed to send notification:', err);
      toast.error('Failed to send notification');
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={onClose}
        className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100]"
      />
      <motion.div
        initial={{ x: '100%' }}
        animate={{ x: 0 }}
        exit={{ x: '100%' }}
        transition={{ type: 'spring', damping: 25, stiffness: 200 }}
        className="fixed right-0 top-0 h-full w-full max-w-2xl bg-white shadow-2xl z-[101] flex flex-col"
      >
        {/* Header */}
        <div className="p-8 border-b border-border flex items-center justify-between shrink-0">
          <div>
            <h2 className="text-2xl font-black text-text-dark tracking-tight">
              {editingNotification ? 'Edit Notification' : 'New Notification'}
            </h2>
            <p className="text-xs font-bold text-text-muted uppercase tracking-widest mt-1">
              Send updates to students and parents
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-slate-100 rounded-xl text-slate-400 transition-colors"
          >
            <X size={22} />
          </button>
        </div>

        {/* Form Content */}
        <div className="flex-1 overflow-y-auto p-8 space-y-10">
          {/* Recipient Targeting Section */}
          <div className="space-y-6">
            <div className="flex items-center gap-4">
              <h3 className="text-[11px] font-black text-brand-primary uppercase tracking-[0.2em] shrink-0">
                Recipient Targeting
              </h3>
              <div className="h-px bg-slate-100 flex-1" />
            </div>

            {/* Send To Options */}
            <div className="space-y-4">
              <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block italic">
                Send To *
              </label>

              {/* Radio Buttons */}
              <div className="space-y-3">
                <label className="flex items-center gap-3 p-4 bg-slate-50 border-2 border-slate-200 rounded-xl cursor-pointer hover:bg-slate-100 transition-colors">
                  <input
                    type="radio"
                    name="recipient"
                    value="all"
                    checked={recipient === 'all'}
                    onChange={() => {
                      setRecipient('all');
                      setSelectedUserIds([]);
                    }}
                    className="w-4 h-4 text-brand-primary"
                  />
                  <div className="flex-1">
                    <div className="font-bold text-sm">All Users</div>
                    <div className="text-xs text-slate-500">Send to all active users ({users.length} users)</div>
                  </div>
                </label>

                <label className="flex items-center gap-3 p-4 bg-slate-50 border-2 border-slate-200 rounded-xl cursor-pointer hover:bg-slate-100 transition-colors">
                  <input
                    type="radio"
                    name="recipient"
                    value="selected"
                    checked={recipient === 'selected'}
                    onChange={() => setRecipient('selected')}
                    className="w-4 h-4 text-brand-primary"
                  />
                  <div className="flex-1">
                    <div className="font-bold text-sm">Select Users</div>
                    <div className="text-xs text-slate-500">Choose specific users to notify</div>
                  </div>
                </label>
              </div>

              {/* User Selection List */}
              {recipient === 'selected' && (
                <div className="space-y-2 mt-4">
                  <div className="flex items-center justify-between mb-2">
                    <label className="text-[11px] font-black text-text-muted uppercase tracking-widest italic">
                      Select Users ({selectedUserIds.length} selected)
                    </label>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={handleSelectAll}
                        className="text-xs text-brand-primary hover:underline font-bold"
                      >
                        {selectedUserIds.length === filteredUsers.length ? 'Clear All' : 'Select All'}
                      </button>
                    </div>
                  </div>

                  <input
                    type="text"
                    placeholder="Search users..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-2xl focus:ring-2 focus:ring-brand-primary/20 focus:bg-white focus:border-brand-primary transition-all text-sm font-medium mb-2"
                  />

                  <div className="max-h-64 overflow-y-auto border border-slate-200 rounded-2xl">
                    {loadingUsers && (
                      <div className="px-4 py-8 text-center text-slate-400 text-sm">
                        Loading users...
                      </div>
                    )}
                    {!loadingUsers && filteredUsers.length === 0 && (
                      <div className="px-4 py-8 text-center text-slate-400 text-sm">
                        {users.length === 0 ? 'No users found in database' : 'No users match your search'}
                      </div>
                    )}
                    {!loadingUsers && filteredUsers.length > 0 && filteredUsers.map((user) => (
                      <label
                        key={user.id}
                        className={`flex items-center gap-3 px-4 py-3 hover:bg-slate-50 transition-colors border-b border-slate-100 last:border-0 cursor-pointer ${
                          selectedUserIds.includes(user.id) ? 'bg-brand-primary/5' : ''
                        }`}
                      >
                        <input
                          type="checkbox"
                          checked={selectedUserIds.includes(user.id)}
                          onChange={() => handleUserToggle(user.id)}
                          className="w-4 h-4 text-brand-primary rounded"
                        />
                        <div className="flex items-center justify-between flex-1">
                          <div>
                            <div className="font-bold text-sm">{user.name}</div>
                            <div className="text-xs text-slate-500">{user.email}</div>
                          </div>
                          {user.role && (
                            <span className={`px-2 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider ml-2 shrink-0 ${
                              user.role === 'ADMIN' ? 'bg-purple-100 text-purple-700' :
                              user.role === 'EMPLOYEE' ? 'bg-blue-100 text-blue-700' :
                              user.role === 'COACH' ? 'bg-green-100 text-green-700' :
                              user.role === 'SECURITY' ? 'bg-orange-100 text-orange-700' :
                              'bg-gray-100 text-gray-700'
                            }`}>
                              {user.role}
                            </span>
                          )}
                        </div>
                      </label>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Message Content Section */}
          <div className="space-y-6">
            <div className="flex items-center gap-4">
              <h3 className="text-[11px] font-black text-brand-primary uppercase tracking-[0.2em] shrink-0">
                Message Payload
              </h3>
              <div className="h-px bg-slate-100 flex-1" />
            </div>

            <div className="space-y-6">
              <div className="space-y-2">
                <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block italic">
                  Title *
                </label>
                <div className="relative">
                  <Type className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                  <input
                    type="text"
                    placeholder="Notification heading"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full pl-12 pr-4 py-3.5 bg-slate-50 border border-slate-100 rounded-2xl focus:ring-2 focus:ring-brand-primary/20 focus:bg-white focus:border-brand-primary transition-all text-sm font-medium"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block italic">
                  Body *
                </label>
                <div className="relative">
                  <AlignLeft className="absolute left-4 top-6 text-slate-400" size={16} />
                  <textarea
                    rows={4}
                    placeholder="Write your message content here..."
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    className="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-100 rounded-[2rem] focus:ring-2 focus:ring-brand-primary/20 focus:bg-white focus:border-brand-primary transition-all text-sm font-medium resize-none leading-relaxed"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block italic">
                  Type
                </label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value)}
                  className="w-full px-4 py-3.5 bg-slate-50 border border-slate-100 rounded-2xl focus:ring-2 focus:ring-brand-primary/20 focus:bg-white focus:border-brand-primary transition-all text-sm font-medium"
                >
                  <option value="System">System</option>
                  <option value="Training">Training</option>
                  <option value="Attendance">Attendance</option>
                  <option value="Performance">Performance</option>
                  <option value="Alert">Alert</option>
                  <option value="General">General</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-8 bg-slate-50 border-t border-border flex items-center gap-4 shrink-0">
          <button
            onClick={handleSubmit}
            disabled={submitting}
            className="flex-1 bg-brand-primary hover:bg-brand-primary/90 text-white px-6 py-4 rounded-[2rem] text-[11px] font-black uppercase tracking-[0.2em] shadow-xl shadow-brand-primary/20 transition-all flex items-center justify-center gap-2 active:scale-95 leading-none disabled:opacity-50"
          >
            <Send size={18} />
            {submitting ? 'Sending...' : editingNotification ? 'Update Notification' : 'Send Notification'}
          </button>
          <button
            onClick={() => {
              resetForm();
              onClose();
            }}
            className="flex-1 bg-white border border-border text-text-muted px-6 py-4 rounded-[2rem] text-[11px] font-black uppercase tracking-[0.2em] transition-all hover:bg-slate-50 flex items-center justify-center gap-2 active:scale-95 leading-none"
          >
            <X size={18} />
            Cancel
          </button>
        </div>
      </motion.div>
    </AnimatePresence>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export default function CoachNotifications() {
  useAuth();

  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingNotification, setEditingNotification] = useState<Notification | null>(null);

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

  const handleEdit = (notification: Notification) => {
    setEditingNotification(notification);
    setIsFormOpen(true);
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this notification?')) return;

    try {
      const res = await fetchWithAuth(`${API_BASE}/notifications/${id}`, {
        method: 'DELETE',
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      toast.success('Notification deleted successfully');
      load(page);
    } catch (err) {
      console.error('Failed to delete notification:', err);
      toast.error('Failed to delete notification');
    }
  };

  const handleToggleStatus = async (notification: Notification) => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/notifications/${notification.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ isRead: !notification.isRead }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      toast.success(`Notification marked as ${!notification.isRead ? 'read' : 'unread'}`);
      load(page);
    } catch (err) {
      console.error('Failed to update status:', err);
      toast.error('Failed to update status');
    }
  };

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
            <p className="text-text-muted text-sm mt-1">Send updates to students and parents</p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => {
                setEditingNotification(null);
                setIsFormOpen(true);
              }}
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
              <p className="font-semibold text-text-dark">No notifications sent yet</p>
              <p className="text-text-muted text-sm">Create a new notification to send updates to your students.</p>
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
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Recipients</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Sent At</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-right px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Actions</th>
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
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1 text-text-muted">
                          <Users size={14} />
                          <span>{n.recipientCount ?? 0}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-text-muted text-xs">
                        {formatDate(n.sentAt ?? n.createdAt)}
                      </td>
                      <td className="px-4 py-3">{statusBadge(n)}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => handleToggleStatus(n)}
                            className="p-1.5 bg-white border border-slate-200 text-slate-400 hover:text-emerald-600 hover:border-emerald-600 rounded-lg transition-all shadow-sm active:scale-95"
                            title={n.isRead ? 'Mark as unread' : 'Mark as read'}
                          >
                            {n.isRead ? <Slash size={14} /> : <CheckCircle2 size={14} />}
                          </button>
                          <button
                            onClick={() => handleEdit(n)}
                            className="p-1.5 bg-white border border-slate-200 text-slate-400 hover:text-brand-primary hover:border-brand-primary rounded-lg transition-all shadow-sm active:scale-95"
                            title="Edit notification"
                          >
                            <Pencil size={14} />
                          </button>
                          <button
                            onClick={() => handleDelete(n.id)}
                            className="p-1.5 bg-white border border-slate-200 text-slate-400 hover:text-rose-600 hover:border-rose-600 rounded-lg transition-all shadow-sm active:scale-95"
                            title="Delete notification"
                          >
                            <Trash2 size={14} />
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

      {/* Notification Form Slide-over */}
      <NotificationForm
        isOpen={isFormOpen}
        onClose={() => {
          setIsFormOpen(false);
          setEditingNotification(null);
        }}
        onSuccess={() => load(1)}
        editingNotification={editingNotification}
      />
    </UnifiedDashboardLayout>
  );
}
