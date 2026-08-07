import React, { useEffect, useState } from 'react';
import {
  Ticket,
  Calendar,
  IndianRupee,
  X,
  Loader2,
  AlertCircle,
  Clock,
  Send,
  Eye,
  MessageCircle,
  Mail,
  CheckCircle,
  Users,
  UserPlus,
  Phone,
  Pencil,
  Trash2,
  Plus,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { motion, AnimatePresence } from 'motion/react';
import { fetchWithAuth } from '../../lib/fetchWithAuth';
import { getImageUrl } from '../../lib/utils';

// MyEventPass appends /api/... paths itself, so strip /api from base
const _rawEventBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
const API_BASE = _rawEventBase.endsWith('/api') ? _rawEventBase.slice(0, -4) : _rawEventBase;
const API = `${API_BASE}/api`;

interface BookingSlot {
  id: string;
  name: string;
  date: string;
  passType?: string;
  price: number;
  startTime?: string;
  endTime?: string;
}

interface BookingEvent {
  id: string;
  title: string;
  image?: string;
}

interface GroupPass {
  id: string;
  passCode: string;
  qrCode: string;
  maxPersons: number;
  scannedInCount: number;
  scannedOutCount: number;
  scanStatus: 'NotScanned' | 'In' | 'Out';
  scannedInAt?: string;
  scannedOutAt?: string;
  holderName: string;
  holderEmail: string;
  isValid: boolean;
  members?: Member[];
}

interface Member {
  id: string;
  name: string;
  phone: string; // digits only e.g. "919876543210"
  scanStatus: 'NotScanned' | 'In' | 'Out';
  scannedInAt?: string;
  scannedOutAt?: string;
}

interface MyBooking {
  id: string;
  name: string;
  email: string;
  numberOfPasses: number;
  totalAmount: number;
  status: 'Pending' | 'Confirmed' | 'Cancelled';
  qrCode?: string;
  createdAt: string;
  event: BookingEvent;
  slot: BookingSlot;
  individualPasses?: GroupPass[];
}

const STATUS_STYLES: Record<string, { bg: string; text: string; dot: string }> = {
  Confirmed: { bg: 'bg-green-50', text: 'text-green-700', dot: 'bg-green-500' },
  Pending:   { bg: 'bg-amber-50',  text: 'text-amber-700',  dot: 'bg-amber-400' },
  Cancelled: { bg: 'bg-red-50',   text: 'text-red-600',   dot: 'bg-red-400'   },
};

function fmtDate(d?: string) {
  if (!d) return '—';
  const dt = new Date(d + 'T00:00:00');
  return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function fmtTime(t?: string) {
  if (!t) return null;
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  const hour = h % 12 || 12;
  return `${hour}:${String(m).padStart(2, '0')} ${ampm}`;
}

function buildWhatsAppLink(pass: GroupPass, booking: MyBooking): string {
  const eventTitle = booking.event?.title || 'Event';
  const date = fmtDate(booking.slot?.date);
  const passType = booking.slot?.passType || booking.slot?.name || 'Pass';
  const startFmt = fmtTime(booking.slot?.startTime);
  const endFmt = fmtTime(booking.slot?.endTime);
  const timeStr = startFmt ? (endFmt ? `${startFmt} – ${endFmt}` : startFmt) : '';

  const msg = [
    `🎟️ *Your Event Pass — ${eventTitle}*`,
    ``,
    `📅 Date: ${date}`,
    timeStr ? `⏰ Time: ${timeStr}` : '',
    `🎫 Pass Type: ${passType}`,
    pass.maxPersons > 1 ? `👥 Valid for: ${pass.maxPersons} persons` : '',
    ``,
    `*Pass Code:* ${pass.passCode}`,
    ``,
    `📱 Show this QR code at the entry gate:`,
    pass.qrCode,
    ``,
    `_Nahata Sports Complex_`,
  ]
    .filter(Boolean)
    .join('\n');

  return `https://wa.me/?text=${encodeURIComponent(msg)}`;
}

/** Build a WhatsApp link to a SPECIFIC member's number */
function buildMemberWhatsAppLink(member: Member, pass: GroupPass, booking: MyBooking): string {
  const eventTitle = booking.event?.title || 'Event';
  const date = fmtDate(booking.slot?.date);
  const passType = booking.slot?.passType || booking.slot?.name || 'Pass';
  const startFmt = fmtTime(booking.slot?.startTime);
  const endFmt = fmtTime(booking.slot?.endTime);
  const timeStr = startFmt ? (endFmt ? `${startFmt} – ${endFmt}` : startFmt) : '';

  const msg = [
    `🎟️ *Hi ${member.name}! Your Event Pass — ${eventTitle}*`,
    ``,
    `📅 Date: ${date}`,
    timeStr ? `⏰ Time: ${timeStr}` : '',
    `🎫 Pass Type: ${passType}`,
    ``,
    `*Pass Code:* ${pass.passCode}`,
    ``,
    `📱 Show this QR code at the entry gate:`,
    pass.qrCode,
    ``,
    `_Nahata Sports Complex_`,
  ]
    .filter(Boolean)
    .join('\n');

  // wa.me/<phone> sends directly to that number
  return `https://wa.me/${member.phone}?text=${encodeURIComponent(msg)}`;
}

export const MyEventPass: React.FC = () => {
  const [bookings, setBookings] = useState<MyBooking[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // View QR modal
  const [viewPass, setViewPass] = useState<{ pass: GroupPass; booking: MyBooking } | null>(null);

  // Send pass modal
  const [sendPass, setSendPass] = useState<{ pass: GroupPass; booking: MyBooking } | null>(null);
  const [sendEmail, setSendEmail] = useState('');
  const [sendName, setSendName] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [sendSuccess, setSendSuccess] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);

  // Members modal
  const [membersModal, setMembersModal] = useState<{ pass: GroupPass; booking: MyBooking } | null>(null);
  const [memberRows, setMemberRows] = useState<{ name: string; phone: string }[]>([]);
  const [isSavingMembers, setIsSavingMembers] = useState(false);
  const [membersError, setMembersError] = useState<string | null>(null);
  const [membersSaved, setMembersSaved] = useState(false);

  useEffect(() => {
    fetchWithAuth(`${API}/event-passes/bookings/my`)
      .then(async (res) => {
        const json = await res.json();
        if (!res.ok) throw new Error(json.message || 'Failed to load bookings');
        // Only bookings whose payment went through belong on this page. A
        // booking left Pending (checkout cancelled or abandoned) has no pass,
        // so its card would be an empty placeholder. Free events are created
        // as Confirmed, so they are kept.
        const paid = (json.data ?? []).filter((b: MyBooking) => b.status === 'Confirmed');
        setBookings(paid);
      })
      .catch((err) => setError(err.message))
      .finally(() => setIsLoading(false));
  }, []);

  const openSendModal = (pass: GroupPass, booking: MyBooking) => {
    setSendPass({ pass, booking });
    setSendEmail('');
    setSendName('');
    setSendSuccess(false);
    setSendError(null);
  };

  const openMembersModal = (pass: GroupPass, booking: MyBooking) => {
    // Pre-fill with existing members if any
    const existing = (pass.members ?? []).map((m) => ({ name: m.name, phone: m.phone }));
    const rows = existing.length > 0
      ? existing
      : Array.from({ length: pass.maxPersons }, () => ({ name: '', phone: '' }));
    setMemberRows(rows);
    setMembersError(null);
    setMembersSaved(false);
    setMembersModal({ pass, booking });
  };

  const handleSaveMembers = async () => {
    if (!membersModal) return;
    setMembersError(null);

    // Validate all rows filled
    for (let i = 0; i < memberRows.length; i++) {
      if (!memberRows[i].name.trim()) {
        setMembersError(`Please enter a name for member ${i + 1}.`);
        return;
      }
      if (!memberRows[i].phone.trim()) {
        setMembersError(`Please enter a WhatsApp number for ${memberRows[i].name || `member ${i + 1}`}.`);
        return;
      }
    }

    setIsSavingMembers(true);
    try {
      const res = await fetchWithAuth(
        `${API}/event-passes/individual-passes/${membersModal.pass.id}/members`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ members: memberRows }),
        }
      );
      const json = await res.json();
      if (!res.ok) throw new Error(json.message || 'Failed to save members');
      setMembersSaved(true);
      const refreshRes = await fetchWithAuth(`${API}/event-passes/bookings/my`);
      const refreshJson = await refreshRes.json();
      if (refreshJson.success) {
        setBookings((refreshJson.data ?? []).filter((b: MyBooking) => b.status === 'Confirmed'));
      }
    } catch (err: any) {
      setMembersError(err.message);
    } finally {
      setIsSavingMembers(false);
    }
  };

  const updateMemberRow = (index: number, field: 'name' | 'phone', value: string) => {
    setMemberRows((prev) => prev.map((r, i) => i === index ? { ...r, [field]: value } : r));
  };

  const handleSendEmail = async () => {
    if (!sendPass) return;
    if (!sendEmail.trim()) { setSendError('Please enter an email address.'); return; }
    setIsSending(true);
    setSendError(null);
    try {
      const res = await fetchWithAuth(
        `${API}/event-passes/individual-passes/${sendPass.pass.id}/send-email`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            recipientEmail: sendEmail.trim(),
            recipientName: sendName.trim() || sendPass.pass.holderName,
          }),
        }
      );
      const json = await res.json();
      if (!res.ok) throw new Error(json.message || 'Failed to send');
      setSendSuccess(true);
    } catch (err: any) {
      setSendError(err.message);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <UserMainLayout
      breadcrumbs={[{ label: 'Dashboard' }, { label: 'My Event Pass', active: true }]}
    >
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-text-dark">My Event Passes</h1>
          <p className="text-text-muted text-sm mt-1">
            View your pass QR code and share it via WhatsApp or Email.
          </p>
        </div>

        {isLoading && (
          <div className="flex items-center justify-center py-24 text-slate-400">
            <Loader2 size={32} className="animate-spin" />
          </div>
        )}

        {!isLoading && error && (
          <div className="flex items-center gap-3 bg-red-50 border border-red-200 text-red-700 px-5 py-4 rounded-2xl text-sm font-medium">
            <AlertCircle size={18} />
            {error}
          </div>
        )}

        {!isLoading && !error && bookings.length === 0 && (
          <div className="flex flex-col items-center justify-center py-24 text-slate-400 gap-4">
            <div className="w-20 h-20 rounded-2xl bg-brand-secondary flex items-center justify-center">
              <Ticket size={36} className="text-brand-primary opacity-60" />
            </div>
            <div className="text-center">
              <p className="font-semibold text-slate-600">No event passes yet</p>
              <p className="text-sm mt-1">
                Visit the{' '}
                <a href="/events" className="text-primary font-bold hover:underline">Events page</a>{' '}
                to book your first pass.
              </p>
            </div>
          </div>
        )}

        {!isLoading && !error && bookings.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
            {bookings.map((booking, i) => {
              const style = STATUS_STYLES[booking.status] ?? STATUS_STYLES.Pending;
              const startFmt = fmtTime(booking.slot?.startTime);
              const endFmt = fmtTime(booking.slot?.endTime);
              // The single group pass for this booking
              const pass = booking.individualPasses?.[0];

              return (
                <motion.div
                  key={booking.id}
                  initial={{ opacity: 0, y: 16 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.06 }}
                  className="bg-white rounded-2xl border border-border overflow-hidden flex flex-col shadow-sm hover:shadow-md transition-shadow"
                >
                  {/* Event image */}
                  {booking.event?.image && (
                    <div className="h-28 overflow-hidden">
                      <img
                        src={getImageUrl(booking.event.image)}
                        alt={booking.event.title}
                        className="w-full h-full object-cover"
                        onError={(e) => { (e.currentTarget as HTMLImageElement).style.display = 'none'; }}
                      />
                    </div>
                  )}

                  <div className="p-5 flex flex-col gap-4 flex-1">
                    {/* Top row */}
                    <div className="flex items-start justify-between gap-2">
                      <div className="w-10 h-10 bg-brand-secondary rounded-xl flex items-center justify-center shrink-0">
                        <Ticket size={20} className="text-primary" />
                      </div>
                      <span className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold ${style.bg} ${style.text}`}>
                        <span className={`w-1.5 h-1.5 rounded-full ${style.dot}`} />
                        {booking.status}
                      </span>
                    </div>

                    {/* Event title */}
                    <div>
                      <p className="font-bold text-text-dark text-sm leading-snug">
                        {booking.event?.title ?? '—'}
                      </p>
                      {booking.slot?.passType && (
                        <p className="text-[11px] font-semibold text-primary mt-0.5 uppercase tracking-wide">
                          {booking.slot.passType}
                        </p>
                      )}
                    </div>

                    {/* Details */}
                    <div className="space-y-2">
                      <DetailRow icon={<Calendar size={13} />} label="Date" value={fmtDate(booking.slot?.date)} />
                      {startFmt && (
                        <DetailRow
                          icon={<Clock size={13} />}
                          label="Time"
                          value={endFmt ? `${startFmt} – ${endFmt}` : startFmt}
                        />
                      )}
                      <DetailRow
                        icon={<Users size={13} />}
                        label="Persons"
                        value={`${booking.numberOfPasses} person${booking.numberOfPasses > 1 ? 's' : ''}`}
                      />
                      <DetailRow
                        icon={<IndianRupee size={13} />}
                        label="Total"
                        value={Number(booking.totalAmount) > 0 ? `₹${Number(booking.totalAmount).toFixed(2)}` : 'Free'}
                      />
                    </div>

                    {/* Scan progress (if pass exists and has been scanned) */}
                    {pass && pass.scannedInCount > 0 && (
                      <div className="bg-slate-50 rounded-xl px-3 py-2">
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Entry Progress</span>
                          <span className="text-[10px] font-bold text-emerald-600">{pass.scannedInCount}/{pass.maxPersons} in</span>
                        </div>
                        <div className="h-1.5 bg-slate-200 rounded-full overflow-hidden">
                          <div
                            className="h-full bg-emerald-500 rounded-full transition-all"
                            style={{ width: `${(pass.scannedInCount / pass.maxPersons) * 100}%` }}
                          />
                        </div>
                      </div>
                    )}

                    <p className="text-[10px] text-slate-400 font-mono">
                      Pass #{String(booking.id).padStart(6, '0')}
                    </p>

                    {/* View & Send buttons */}
                    {pass ? (
                      <div className="mt-auto space-y-2">
                        {/* Members status */}
                        {pass.maxPersons > 1 && (
                          <div className={`flex items-center justify-between px-3 py-2 rounded-xl text-xs font-bold ${
                            (pass.members?.length ?? 0) === pass.maxPersons
                              ? 'bg-emerald-50 text-emerald-700'
                              : 'bg-amber-50 text-amber-700'
                          }`}>
                            <span className="flex items-center gap-1.5">
                              <Users size={12} />
                              {(pass.members?.length ?? 0) === pass.maxPersons
                                ? `${pass.members!.length} members registered`
                                : `${pass.members?.length ?? 0}/${pass.maxPersons} members added`}
                            </span>
                            <button
                              onClick={() => openMembersModal(pass, booking)}
                              className="flex items-center gap-1 underline underline-offset-2"
                            >
                              <Pencil size={10} />
                              {(pass.members?.length ?? 0) > 0 ? 'Edit' : 'Add'}
                            </button>
                          </div>
                        )}

                        <div className="grid grid-cols-2 gap-2">
                          <button
                            onClick={() => setViewPass({ pass, booking })}
                            className="flex items-center justify-center gap-1.5 py-2.5 rounded-xl border border-primary/20 bg-brand-secondary text-primary text-xs font-bold hover:bg-primary hover:text-white transition-all"
                          >
                            <Eye size={13} />
                            View Pass
                          </button>
                          <button
                            onClick={() => openSendModal(pass, booking)}
                            className="flex items-center justify-center gap-1.5 py-2.5 rounded-xl border border-emerald-200 bg-emerald-50 text-emerald-700 text-xs font-bold hover:bg-emerald-500 hover:text-white transition-all"
                          >
                            <Send size={13} />
                            Send Pass
                          </button>
                        </div>

                        {/* Add Members CTA if not yet added */}
                        {pass.maxPersons > 1 && (pass.members?.length ?? 0) < pass.maxPersons && (
                          <button
                            onClick={() => openMembersModal(pass, booking)}
                            className="w-full flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-amber-500 text-white text-xs font-bold hover:bg-amber-600 transition-all"
                          >
                            <UserPlus size={13} />
                            Add {pass.maxPersons} Members to Send Pass
                          </button>
                        )}
                      </div>
                    ) : (
                      /* Confirmed but the pass row hasn't landed yet — only
                         reachable if issuance failed after a verified payment;
                         re-verifying repairs it. Unpaid bookings never get here,
                         they are filtered out above. */
                      <div className="mt-auto py-2.5 rounded-xl bg-slate-50 text-slate-400 text-xs text-center font-medium">
                        Pass generating…
                      </div>
                    )}
                  </div>
                </motion.div>
              );
            })}
          </div>
        )}
      </div>

      {/* ── View Pass Modal ── */}
      <AnimatePresence>
        {viewPass && (
          <div className="fixed inset-0 z-[200] flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setViewPass(null)}
              className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.92, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.92, y: 20 }}
              className="relative bg-white w-full max-w-sm rounded-4xl shadow-2xl overflow-hidden"
            >
              <button
                onClick={() => setViewPass(null)}
                className="absolute top-5 right-5 text-slate-400 hover:text-slate-600 transition-colors z-10"
              >
                <X size={22} />
              </button>

              {/* Header */}
              <div className="bg-primary px-6 pt-8 pb-6 text-white text-center">
                <div className="w-12 h-12 bg-white/20 rounded-2xl flex items-center justify-center mx-auto mb-3">
                  <Ticket size={24} />
                </div>
                <h2 className="font-display font-extrabold text-xl tracking-tight uppercase leading-tight">
                  Event Pass
                </h2>
                <p className="text-white/70 text-xs mt-1 leading-snug px-4">
                  {viewPass.booking.event?.title}
                </p>
                {viewPass.pass.maxPersons > 1 && (
                  <div className="mt-2 inline-flex items-center gap-1.5 bg-white/20 rounded-full px-3 py-1 text-xs font-bold">
                    <Users size={12} />
                    Valid for {viewPass.pass.maxPersons} persons
                  </div>
                )}
              </div>

              {/* QR + details */}
              <div className="px-8 py-6 flex flex-col items-center gap-5">
                <div className="p-3 bg-white border-2 border-brand-secondary rounded-2xl shadow-inner">
                  <img src={viewPass.pass.qrCode} alt="QR Code" className="w-44 h-44" />
                </div>

                <p className="text-xs font-mono font-bold text-slate-600 tracking-widest text-center">
                  {viewPass.pass.passCode}
                </p>

                <div className="w-full space-y-2 text-sm">
                  <QrDetailRow label="Pass Holder" value={viewPass.pass.holderName} />
                  <QrDetailRow label="Date" value={fmtDate(viewPass.booking.slot?.date)} />
                  <QrDetailRow
                    label="Pass Type"
                    value={viewPass.booking.slot?.passType ?? viewPass.booking.slot?.name ?? '—'}
                  />
                  <QrDetailRow
                    label="Valid For"
                    value={`${viewPass.pass.maxPersons} person${viewPass.pass.maxPersons > 1 ? 's' : ''}`}
                  />
                  {viewPass.pass.scannedInCount > 0 && (
                    <QrDetailRow
                      label="Entered"
                      value={`${viewPass.pass.scannedInCount} / ${viewPass.pass.maxPersons}`}
                    />
                  )}
                </div>

                {/* Share buttons */}
                <div className="w-full grid grid-cols-2 gap-3">
                  <a
                    href={buildWhatsAppLink(viewPass.pass, viewPass.booking)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-center gap-2 py-2.5 rounded-xl bg-green-500 text-white text-xs font-bold hover:bg-green-600 transition-all"
                  >
                    <MessageCircle size={14} />
                    WhatsApp
                  </a>
                  <button
                    onClick={() => { setViewPass(null); openSendModal(viewPass.pass, viewPass.booking); }}
                    className="flex items-center justify-center gap-2 py-2.5 rounded-xl bg-blue-500 text-white text-xs font-bold hover:bg-blue-600 transition-all"
                  >
                    <Mail size={14} />
                    Email
                  </button>
                </div>

                <button
                  onClick={() => setViewPass(null)}
                  className="w-full py-3 rounded-2xl bg-brand-secondary text-primary font-bold text-sm hover:bg-primary hover:text-white transition-all"
                >
                  Close
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* ── Send Pass Modal ── */}
      <AnimatePresence>
        {sendPass && (
          <div className="fixed inset-0 z-[200] flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => { if (!isSending) setSendPass(null); }}
              className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.92, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.92, y: 20 }}
              className="relative bg-white w-full max-w-sm rounded-4xl shadow-2xl overflow-hidden"
            >
              <button
                onClick={() => setSendPass(null)}
                disabled={isSending}
                className="absolute top-5 right-5 text-slate-400 hover:text-slate-600 transition-colors z-10"
              >
                <X size={22} />
              </button>

              <div className="p-8">
                {sendSuccess ? (
                  <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="text-center space-y-4 py-4"
                  >
                    <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto">
                      <CheckCircle size={32} className="text-green-600" />
                    </div>
                    <h3 className="text-xl font-bold text-slate-900">Pass Sent!</h3>
                    <p className="text-sm text-slate-500">
                      Your pass has been sent to{' '}
                      <strong className="text-slate-700">{sendEmail}</strong>
                    </p>
                    <button
                      onClick={() => setSendPass(null)}
                      className="w-full py-3 rounded-2xl bg-primary text-white font-bold text-sm hover:bg-blue-700 transition-all"
                    >
                      Done
                    </button>
                  </motion.div>
                ) : (
                  <>
                    <div className="text-center mb-6">
                      <div className="w-12 h-12 bg-brand-secondary rounded-2xl flex items-center justify-center mx-auto mb-3">
                        <Send size={22} className="text-primary" />
                      </div>
                      <h2 className="text-xl font-bold text-slate-900">Send Pass</h2>
                      <p className="text-sm text-slate-500 mt-1">
                        {sendPass.booking.event?.title}
                        {sendPass.pass.maxPersons > 1 && (
                          <span className="block text-xs text-emerald-600 font-semibold mt-0.5">
                            Valid for {sendPass.pass.maxPersons} persons
                          </span>
                        )}
                      </p>
                    </div>

                    {/* If members are registered — show per-member WhatsApp buttons */}
                    {(sendPass.pass.members?.length ?? 0) > 0 ? (
                      <div className="space-y-3">
                        <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">
                          Send to each member
                        </p>
                        <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
                          {sendPass.pass.members!.map((member) => (
                            <a
                              key={member.id}
                              href={buildMemberWhatsAppLink(member, sendPass.pass, sendPass.booking)}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="flex items-center gap-3 p-3 bg-slate-50 rounded-xl border border-border hover:bg-green-50 hover:border-green-200 transition-all group"
                            >
                              <div className="w-8 h-8 bg-green-100 rounded-xl flex items-center justify-center shrink-0 group-hover:bg-green-500 transition-all">
                                <MessageCircle size={14} className="text-green-600 group-hover:text-white" />
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-xs font-bold text-text-dark truncate">{member.name}</p>
                                <p className="text-[10px] text-slate-400">+{member.phone}</p>
                              </div>
                              <span className="text-[10px] font-bold text-green-600 shrink-0">Send →</span>
                            </a>
                          ))}
                        </div>

                        <div className="flex items-center gap-3 my-2">
                          <div className="h-px bg-slate-200 flex-1" />
                          <span className="text-xs text-slate-400 font-medium">or share generally</span>
                          <div className="h-px bg-slate-200 flex-1" />
                        </div>

                        <a
                          href={buildWhatsAppLink(sendPass.pass, sendPass.booking)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center justify-center gap-2 w-full py-2.5 rounded-xl bg-green-500 text-white text-xs font-bold hover:bg-green-600 transition-all"
                        >
                          <MessageCircle size={14} />
                          Share Pass Link (General)
                        </a>
                      </div>
                    ) : (
                      /* No members — show generic WhatsApp + email */
                      <>
                        <a
                          href={buildWhatsAppLink(sendPass.pass, sendPass.booking)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center justify-center gap-2 w-full py-3 rounded-xl bg-green-500 text-white text-sm font-bold hover:bg-green-600 transition-all mb-4"
                        >
                          <MessageCircle size={16} />
                          Share via WhatsApp
                        </a>

                        {sendPass.pass.maxPersons > 1 && (
                          <div className="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-700 text-xs">
                            <strong>Tip:</strong> Add your {sendPass.pass.maxPersons} members first to send the pass directly to each person's WhatsApp number.
                            <button
                              onClick={() => { setSendPass(null); openMembersModal(sendPass.pass, sendPass.booking); }}
                              className="block mt-1.5 font-bold underline"
                            >
                              Add Members →
                            </button>
                          </div>
                        )}
                      </>
                    )}

                    <div className="flex items-center gap-3 mb-4 mt-2">
                      <div className="h-px bg-slate-200 flex-1" />
                      <span className="text-xs text-slate-400 font-medium">or send by email</span>
                      <div className="h-px bg-slate-200 flex-1" />
                    </div>

                    {sendError && (
                      <div className="mb-3 p-3 bg-red-50 border border-red-200 rounded-xl text-red-600 text-xs">
                        {sendError}
                      </div>
                    )}

                    <div className="space-y-3">
                      <div>
                        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1 ml-1">
                          Recipient Name (optional)
                        </label>
                        <input
                          type="text"
                          value={sendName}
                          onChange={(e) => setSendName(e.target.value)}
                          placeholder={sendPass.pass.holderName}
                          className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                        />
                      </div>
                      <div>
                        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1 ml-1">
                          Recipient Email <span className="text-red-500">*</span>
                        </label>
                        <input
                          type="email"
                          value={sendEmail}
                          onChange={(e) => setSendEmail(e.target.value)}
                          placeholder="friend@example.com"
                          className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                        />
                      </div>
                      <button
                        onClick={handleSendEmail}
                        disabled={isSending || !sendEmail.trim()}
                        className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-primary text-white text-sm font-bold hover:bg-blue-700 disabled:opacity-50 transition-all"
                      >
                        {isSending ? (
                          <><Loader2 size={16} className="animate-spin" /> Sending...</>
                        ) : (
                          <><Mail size={16} /> Send via Email</>
                        )}
                      </button>
                    </div>
                  </>
                )}
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* ── Add Members Modal ── */}
      <AnimatePresence>
        {membersModal && (
          <div className="fixed inset-0 z-[200] flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => { if (!isSavingMembers) setMembersModal(null); }}
              className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="relative bg-white w-full max-w-lg rounded-3xl shadow-2xl overflow-hidden max-h-[90vh] flex flex-col"
            >
              <button
                onClick={() => setMembersModal(null)}
                disabled={isSavingMembers}
                className="absolute top-5 right-5 text-slate-400 hover:text-slate-600 z-10"
              >
                <X size={22} />
              </button>

              {/* Header */}
              <div className="p-6 border-b border-border shrink-0">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-amber-100 rounded-xl flex items-center justify-center">
                    <UserPlus size={20} className="text-amber-600" />
                  </div>
                  <div>
                    <h2 className="text-lg font-black text-text-dark">Add Members</h2>
                    <p className="text-xs text-text-muted mt-0.5">
                      {membersModal.booking.event?.title} · {membersModal.pass.maxPersons} persons
                    </p>
                  </div>
                </div>
                <p className="text-xs text-slate-500 mt-3 bg-blue-50 border border-blue-100 rounded-xl px-3 py-2">
                  Add the name and WhatsApp number for each person. The pass will be sent directly to their WhatsApp. Only these registered members will be valid at the gate.
                </p>
              </div>

              {/* Member rows */}
              <div className="flex-1 overflow-y-auto p-6 space-y-3">
                {membersSaved ? (
                  <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="text-center py-8 space-y-3"
                  >
                    <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto">
                      <CheckCircle size={32} className="text-green-600" />
                    </div>
                    <h3 className="text-lg font-bold text-slate-900">Members Saved!</h3>
                    <p className="text-sm text-slate-500">
                      {memberRows.length} members registered. Use "Send Pass" to send the pass to each member's WhatsApp.
                    </p>
                    <button
                      onClick={() => setMembersModal(null)}
                      className="mt-2 px-6 py-3 rounded-2xl bg-primary text-white font-bold text-sm hover:bg-blue-700 transition-all"
                    >
                      Done
                    </button>
                  </motion.div>
                ) : (
                  <>
                    {membersError && (
                      <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-red-600 text-xs flex items-start gap-2">
                        <AlertCircle size={14} className="shrink-0 mt-0.5" />
                        {membersError}
                      </div>
                    )}

                    {memberRows.map((row, idx) => (
                      <div key={idx} className="flex items-center gap-2">
                        <div className="w-6 h-6 bg-slate-100 rounded-lg flex items-center justify-center text-[10px] font-black text-slate-500 shrink-0">
                          {idx + 1}
                        </div>
                        <input
                          type="text"
                          value={row.name}
                          onChange={(e) => updateMemberRow(idx, 'name', e.target.value)}
                          placeholder="Full name"
                          className="flex-1 bg-slate-50 border border-slate-200 rounded-xl py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                        />
                        <div className="relative flex-1">
                          <Phone size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                          <input
                            type="tel"
                            value={row.phone}
                            onChange={(e) => updateMemberRow(idx, 'phone', e.target.value)}
                            placeholder="WhatsApp no. (with country code)"
                            className="w-full bg-slate-50 border border-slate-200 rounded-xl py-2.5 pl-8 pr-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                          />
                        </div>
                      </div>
                    ))}

                    <p className="text-[10px] text-slate-400 text-center pt-1">
                      Enter WhatsApp numbers with country code, e.g. 919876543210 for India
                    </p>
                  </>
                )}
              </div>

              {/* Footer */}
              {!membersSaved && (
                <div className="p-5 border-t border-border shrink-0 flex gap-3">
                  <button
                    onClick={handleSaveMembers}
                    disabled={isSavingMembers}
                    className="flex-1 flex items-center justify-center gap-2 py-3 rounded-2xl bg-primary text-white font-bold text-sm hover:bg-blue-700 disabled:opacity-50 transition-all"
                  >
                    {isSavingMembers ? (
                      <><Loader2 size={16} className="animate-spin" /> Saving...</>
                    ) : (
                      <><CheckCircle size={16} /> Save Members</>
                    )}
                  </button>
                  <button
                    onClick={() => setMembersModal(null)}
                    disabled={isSavingMembers}
                    className="px-5 py-3 rounded-2xl bg-slate-100 text-slate-600 font-bold text-sm hover:bg-slate-200 transition-all"
                  >
                    Cancel
                  </button>
                </div>
              )}
            </motion.div>
          </div>
        )}
      </AnimatePresence>

    </UserMainLayout>
  );
};

const DetailRow: React.FC<{ icon: React.ReactNode; label: string; value: string }> = ({ icon, label, value }) => (
  <div className="flex items-center gap-2 text-xs">
    <span className="text-slate-400 shrink-0">{icon}</span>
    <span className="text-text-muted font-medium w-14 shrink-0">{label}</span>
    <span className="font-bold text-text-dark truncate">{value}</span>
  </div>
);

const QrDetailRow: React.FC<{ label: string; value: string }> = ({ label, value }) => (
  <div className="flex items-center justify-between py-1.5 border-b border-slate-100 last:border-0">
    <span className="text-text-muted text-xs">{label}</span>
    <span className="font-bold text-text-dark text-xs text-right max-w-[60%] truncate">{value}</span>
  </div>
);

export default MyEventPass;
