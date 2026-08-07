import React, { useState, useEffect } from 'react';
import {
  Send, MessageSquare, Loader2, AlertCircle,
  CheckCircle, Bell, BellOff, Clock,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { useAuth } from '../../contexts/AuthContext';
import { fetchWithAuth } from '../../lib/fetchWithAuth';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface FeedbackNotification {
  id: number;
  title: string;
  message: string;
  isRead: boolean;
  sentAt: string | null;
  createdAt: string;
}

interface ThreadMessage {
  id: string;
  senderType: 'user' | 'admin';
  senderName: string;
  message: string;
  createdAt: string;
}

interface MyFeedback {
  id: string;
  subject: string;
  message: string;
  rating: number | null;
  status: 'new' | 'in_progress' | 'resolved' | 'closed';
  referenceNumber: string;
  createdAt: string;
  messages: ThreadMessage[];
}

const STATUS_META: Record<MyFeedback['status'], { label: string; cls: string }> = {
  new:         { label: 'New',         cls: 'bg-blue-100 text-blue-700' },
  in_progress: { label: 'In Progress', cls: 'bg-amber-100 text-amber-700' },
  resolved:    { label: 'Resolved',    cls: 'bg-green-100 text-green-700' },
  closed:      { label: 'Closed',      cls: 'bg-slate-100 text-slate-500' },
};

export const Feedback: React.FC = () => {
  const { user } = useAuth();
  // ── Received feedback (from admin) ────────────────────────────────────────
  const [received, setReceived] = useState<FeedbackNotification[]>([]);
  const [loadingReceived, setLoadingReceived] = useState(true);
  const [receivedError, setReceivedError] = useState<string | null>(null);

  // ── Send feedback (to admin) ──────────────────────────────────────────────
  const [form, setForm] = useState({ subject: '', message: '', rating: '5' });
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);

  // ── My feedback threads ───────────────────────────────────────────────────
  const [myFeedback, setMyFeedback] = useState<MyFeedback[]>([]);
  const [loadingMine, setLoadingMine] = useState(true);
  const [replyText, setReplyText] = useState<Record<string, string>>({});
  const [replyingId, setReplyingId] = useState<string | null>(null);

  // ── Active tab ────────────────────────────────────────────────────────────
  const [tab, setTab] = useState<'received' | 'send'>('received');

  // ── Fetch received feedback ───────────────────────────────────────────────
  const fetchFeedback = async () => {
    setLoadingReceived(true);
    setReceivedError(null);
    try {
      const res = await fetchWithAuth(`${API_BASE_URL}/students/feedback`);
      if (!res.ok) throw new Error('Failed to load feedback.');
      const data = await res.json();
      setReceived(data.data ?? []);

      // Mark all as read
      if ((data.data ?? []).some((n: FeedbackNotification) => !n.isRead)) {
        await fetchWithAuth(`${API_BASE_URL}/students/feedback/read`, { method: 'POST' });
      }
    } catch (err) {
      setReceivedError(err instanceof Error ? err.message : 'Something went wrong.');
    } finally {
      setLoadingReceived(false);
    }
  };

  // ── Fetch my feedback threads ─────────────────────────────────────────────
  const fetchMyFeedback = async () => {
    setLoadingMine(true);
    try {
      const res = await fetchWithAuth(`${API_BASE_URL}/user-feedback/mine`);
      if (!res.ok) throw new Error('Failed to load your feedback.');
      const data = await res.json();
      setMyFeedback(data.data?.feedbacks ?? []);
    } catch {
      // Non-blocking: the form still works even if history fails to load.
    } finally {
      setLoadingMine(false);
    }
  };

  useEffect(() => {
    fetchFeedback();
    fetchMyFeedback();
  }, []);

  // ── Reply on one of my threads ────────────────────────────────────────────
  const handleReply = async (id: string) => {
    const text = (replyText[id] ?? '').trim();
    if (!text) return;
    setReplyingId(id);
    try {
      const res = await fetchWithAuth(`${API_BASE_URL}/user-feedback/${id}/reply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: text }),
      });
      const d = await res.json();
      if (!res.ok) throw new Error(d.message || 'Failed to send reply.');
      setReplyText((prev) => ({ ...prev, [id]: '' }));
      await fetchMyFeedback();
    } catch (err) {
      setSendError(err instanceof Error ? err.message : 'Failed to send reply.');
    } finally {
      setReplyingId(null);
    }
  };

  // ── Send feedback to admin ────────────────────────────────────────────────
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSending(true);
    setSendError(null);
    try {
      const res = await fetchWithAuth(`${API_BASE_URL}/user-feedback`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subject: form.subject,
          rating:  form.rating,
          message: form.message,
        }),
      });
      const d = await res.json();
      if (!res.ok) throw new Error(d.message || 'Failed to send feedback.');
      setSubmitted(true);
      setForm({ subject: '', message: '', rating: '5' });
      fetchMyFeedback();
    } catch (err) {
      setSendError(err instanceof Error ? err.message : 'Something went wrong.');
    } finally {
      setSending(false);
    }
  };

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('en-IN', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  };

  const unreadCount = received.filter((n) => !n.isRead).length;

  return (
    <UserMainLayout
      breadcrumbs={[
        { label: 'Dashboard' },
        { label: 'Feedback', active: true },
      ]}
    >
      <div className="space-y-6 max-w-2xl">
        <div>
          <h1 className="text-2xl font-bold text-text-dark">Feedback</h1>
          <p className="text-text-muted text-sm mt-1">
            View messages from admin and share your experience.
          </p>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 bg-slate-100 p-1 rounded-xl w-fit">
          <button
            onClick={() => setTab('received')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              tab === 'received'
                ? 'bg-white text-primary shadow-sm'
                : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            <Bell size={15} />
            From Admin
            {unreadCount > 0 && (
              <span className="bg-red-500 text-white text-[10px] font-black rounded-full w-4 h-4 flex items-center justify-center">
                {unreadCount}
              </span>
            )}
          </button>
          <button
            onClick={() => setTab('send')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              tab === 'send'
                ? 'bg-white text-primary shadow-sm'
                : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            <Send size={15} />
            Send Feedback
          </button>
        </div>

        {/* ── RECEIVED TAB ─────────────────────────────────────────────────── */}
        {tab === 'received' && (
          <div className="space-y-3">
            {loadingReceived && (
              <div className="flex items-center justify-center py-16 gap-3 text-slate-400">
                <Loader2 size={22} className="animate-spin" />
                <span className="text-sm">Loading feedback...</span>
              </div>
            )}

            {!loadingReceived && receivedError && (
              <div className="flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 rounded-xl p-4 text-sm">
                <AlertCircle size={18} className="shrink-0 mt-0.5" />
                <span>{receivedError}</span>
              </div>
            )}

            {!loadingReceived && !receivedError && received.length === 0 && (
              <div className="bg-white rounded-2xl border border-border p-12 text-center">
                <BellOff size={32} className="text-slate-300 mx-auto mb-3" />
                <p className="font-semibold text-text-dark mb-1">No feedback yet</p>
                <p className="text-text-muted text-sm">
                  When an admin sends you feedback, it will appear here.
                </p>
              </div>
            )}

            {!loadingReceived && received.map((item) => (
              <div
                key={item.id}
                className={`bg-white rounded-2xl border p-5 transition-all ${
                  !item.isRead ? 'border-primary/30 shadow-sm shadow-primary/10' : 'border-border'
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                      !item.isRead ? 'bg-primary text-white' : 'bg-slate-100 text-slate-400'
                    }`}>
                      <MessageSquare size={16} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <p className="font-bold text-text-dark text-sm">{item.title}</p>
                        {!item.isRead && (
                          <span className="px-2 py-0.5 bg-primary/10 text-primary text-[10px] font-black rounded-full uppercase tracking-wider">
                            New
                          </span>
                        )}
                      </div>
                      <p className="text-sm text-slate-600 mt-1 leading-relaxed">{item.message}</p>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-1 mt-3 ml-12 text-[11px] text-text-muted">
                  <Clock size={11} />
                  <span>{formatDate(item.sentAt ?? item.createdAt)}</span>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── SEND TAB ─────────────────────────────────────────────────────── */}
        {tab === 'send' && (
          <div className="space-y-6">
            {submitted ? (
              <div className="bg-green-50 border border-green-200 rounded-2xl p-8 text-center">
                <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <CheckCircle size={22} className="text-green-600" />
                </div>
                <h2 className="font-bold text-text-dark mb-1">Thank you!</h2>
                <p className="text-sm text-text-muted">Your feedback has been submitted to the admin.</p>
                <button
                  onClick={() => setSubmitted(false)}
                  className="mt-4 text-sm font-semibold text-primary hover:underline"
                >
                  Submit another
                </button>
              </div>
            ) : (
              <form
                onSubmit={handleSubmit}
                className="bg-white rounded-2xl border border-border p-6 space-y-4"
              >
                {sendError && (
                  <div className="flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 rounded-xl p-4 text-sm">
                    <AlertCircle size={18} className="shrink-0 mt-0.5" />
                    <span>{sendError}</span>
                  </div>
                )}

                <div className="space-y-1">
                  <label className="text-xs font-bold text-text-muted uppercase tracking-widest">
                    Subject
                  </label>
                  <input
                    type="text"
                    required
                    value={form.subject}
                    onChange={(e) => setForm({ ...form, subject: e.target.value })}
                    placeholder="e.g. Court booking experience"
                    className="w-full bg-slate-50 border border-border rounded-xl py-3 px-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-bold text-text-muted uppercase tracking-widest">
                    Rating
                  </label>
                  <select
                    value={form.rating}
                    onChange={(e) => setForm({ ...form, rating: e.target.value })}
                    className="w-full bg-slate-50 border border-border rounded-xl py-3 px-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                  >
                    {[5, 4, 3, 2, 1].map((r) => (
                      <option key={r} value={r}>{'⭐'.repeat(r)} ({r}/5)</option>
                    ))}
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-bold text-text-muted uppercase tracking-widest">
                    Message
                  </label>
                  <textarea
                    required
                    rows={5}
                    value={form.message}
                    onChange={(e) => setForm({ ...form, message: e.target.value })}
                    placeholder="Tell us about your experience..."
                    className="w-full bg-slate-50 border border-border rounded-xl py-3 px-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all resize-none"
                  />
                </div>

                <button
                  type="submit"
                  disabled={sending}
                  className="flex items-center gap-2 px-6 py-3 bg-primary text-white rounded-xl text-sm font-bold hover:bg-primary/90 transition-colors disabled:opacity-60"
                >
                  {sending ? (
                    <><Loader2 size={14} className="animate-spin" /> Sending...</>
                  ) : (
                    <><Send size={14} /> Submit Feedback</>
                  )}
                </button>
              </form>
            )}

            {/* ── My feedback threads ──────────────────────────────────────── */}
            {!loadingMine && myFeedback.length > 0 && (
              <div className="space-y-3">
                <h2 className="text-sm font-bold text-text-dark flex items-center gap-2">
                  <MessageSquare size={15} /> Your previous feedback
                </h2>

                {myFeedback.map((fb) => {
                  const meta = STATUS_META[fb.status];
                  const isClosed = fb.status === 'closed';
                  return (
                    <div key={fb.id} className="bg-white rounded-2xl border border-border p-5">
                      {/* Header */}
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="font-bold text-text-dark text-sm">{fb.subject}</p>
                          <p className="text-[11px] text-text-muted mt-0.5">
                            #{fb.referenceNumber} · {formatDate(fb.createdAt)}
                          </p>
                        </div>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider shrink-0 ${meta.cls}`}>
                          {meta.label}
                        </span>
                      </div>

                      {/* Conversation */}
                      <div className="mt-4 space-y-2">
                        {/* Original message (always from the user) */}
                        <div className="flex justify-end">
                          <div className="max-w-[80%] bg-primary text-white rounded-2xl rounded-br-sm px-4 py-2">
                            <p className="text-sm leading-relaxed">{fb.message}</p>
                            <p className="text-[10px] text-white/60 mt-1">You · {formatDate(fb.createdAt)}</p>
                          </div>
                        </div>

                        {fb.messages.map((m) => (
                          <div key={m.id} className={`flex ${m.senderType === 'admin' ? 'justify-start' : 'justify-end'}`}>
                            <div
                              className={`max-w-[80%] rounded-2xl px-4 py-2 ${
                                m.senderType === 'admin'
                                  ? 'bg-slate-100 text-slate-700 rounded-bl-sm'
                                  : 'bg-primary text-white rounded-br-sm'
                              }`}
                            >
                              <p className="text-sm leading-relaxed">{m.message}</p>
                              <p className={`text-[10px] mt-1 ${m.senderType === 'admin' ? 'text-slate-400' : 'text-white/60'}`}>
                                {m.senderType === 'admin' ? m.senderName : 'You'} · {formatDate(m.createdAt)}
                              </p>
                            </div>
                          </div>
                        ))}
                      </div>

                      {/* Reply box */}
                      {isClosed ? (
                        <p className="mt-3 text-[11px] text-text-muted italic">This thread is closed.</p>
                      ) : (
                        <div className="mt-3 flex items-end gap-2">
                          <textarea
                            rows={1}
                            value={replyText[fb.id] ?? ''}
                            onChange={(e) => setReplyText((prev) => ({ ...prev, [fb.id]: e.target.value }))}
                            placeholder="Write a reply..."
                            className="flex-1 bg-slate-50 border border-border rounded-xl py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all resize-none"
                          />
                          <button
                            onClick={() => handleReply(fb.id)}
                            disabled={replyingId === fb.id || !(replyText[fb.id] ?? '').trim()}
                            className="flex items-center gap-1.5 px-4 py-2.5 bg-primary text-white rounded-xl text-sm font-bold hover:bg-primary/90 transition-colors disabled:opacity-50"
                          >
                            {replyingId === fb.id ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
                          </button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </div>
    </UserMainLayout>
  );
};

export default Feedback;
