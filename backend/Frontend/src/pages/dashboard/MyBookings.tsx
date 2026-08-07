import React, { useState, useEffect, useCallback } from 'react';
import {
  Calendar, Search, MapPin, Trophy, Clock,
  IndianRupee, Loader2, RefreshCw, XCircle, CheckCircle,
  AlertCircle, ChevronLeft, ChevronRight, QrCode, X, Users,
  Download, Share2, MessageCircle, Mail, Send, UserPlus, Pencil, Phone,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { bookingService, MyBooking, BookingMember, formatTime } from '../../services/bookingService';
import { getImageUrl } from '../../lib/utils';

// ── Status helpers ────────────────────────────────────────────────────────────
const BOOKING_STATUS: Record<string, { bg: string; text: string; icon: React.ReactNode }> = {
  Confirmed: { bg: 'bg-green-100',  text: 'text-green-700',  icon: <CheckCircle size={12} /> },
  Completed: { bg: 'bg-slate-100',  text: 'text-slate-600',  icon: <CheckCircle size={12} /> },
  Pending:   { bg: 'bg-blue-100',   text: 'text-blue-700',   icon: <AlertCircle size={12} /> },
  Cancelled: { bg: 'bg-red-100',    text: 'text-red-600',    icon: <XCircle size={12} /> },
};

const PAYMENT_STATUS: Record<string, { bg: string; text: string }> = {
  Paid:     { bg: 'bg-emerald-100', text: 'text-emerald-700' },
  Pending:  { bg: 'bg-amber-100',   text: 'text-amber-700' },
  Failed:   { bg: 'bg-red-100',     text: 'text-red-600' },
  Refunded: { bg: 'bg-purple-100',  text: 'text-purple-700' },
};

const fmt    = (s: string) => BOOKING_STATUS[s] ?? BOOKING_STATUS.Pending;
const fmtPay = (s: string) => PAYMENT_STATUS[s] ?? PAYMENT_STATUS.Pending;

// ── WhatsApp share link ─────────────────────────────────────────────────────
// Builds a wa.me link with the booking-pass details (same style as Event Pass).
function buildBookingWhatsAppLink(b: MyBooking): string {
  const ref = `#NSC-${String(b.id).padStart(6, '0')}`;
  const msg = [
    `🎟️ *Your Booking Pass — ${b.sport?.name || 'Sport'}*`,
    ``,
    `📅 Date: ${b.date}`,
    `⏰ Time: ${formatTime(b.startTime)} – ${formatTime(b.endTime)}`,
    b.court?.name ? `🏟️ Court: ${b.court.name}` : '',
    b.court?.SportComplex?.name ? `📍 Venue: ${b.court.SportComplex.name}` : '',
    b.maxPersons && b.maxPersons > 1 ? `👥 Valid for: ${b.maxPersons} persons` : '',
    ``,
    `*Pass Code:* ${b.passCode}`,
    `*Ref:* ${ref}`,
    ``,
    `📱 Show this QR code at the entry gate:`,
    b.qrCode,
    ``,
    `_Nahata Sports Complex_`,
  ]
    .filter(Boolean)
    .join('\n');

  return `https://wa.me/?text=${encodeURIComponent(msg)}`;
}

/** WhatsApp link to a SPECIFIC member's number, carrying THAT member's own pass/QR. */
function buildMemberWhatsAppLink(m: BookingMember, b: MyBooking): string {
  const ref = `#NSC-${String(b.id).padStart(6, '0')}`;
  const msg = [
    `🎟️ *Hi ${m.name}! Your Booking Pass — ${b.sport?.name || 'Sport'}*`,
    ``,
    `📅 Date: ${b.date}`,
    `⏰ Time: ${formatTime(b.startTime)} – ${formatTime(b.endTime)}`,
    b.court?.name ? `🏟️ Court: ${b.court.name}` : '',
    b.court?.SportComplex?.name ? `📍 Venue: ${b.court.SportComplex.name}` : '',
    ``,
    `*Your Pass Code:* ${m.passCode}`,
    `*Ref:* ${ref}`,
    ``,
    `📱 Show this QR code at the entry gate:`,
    m.qrCode || '',
    ``,
    `_Nahata Sports Complex_`,
  ]
    .filter(Boolean)
    .join('\n');

  return `https://wa.me/${m.phone}?text=${encodeURIComponent(msg)}`;
}

// ── QR Modal ──────────────────────────────────────────────────────────────────
interface QrModalProps {
  booking: MyBooking;
  onClose: () => void;
  onRefresh: () => void;
}

const emptyRow = () => ({ name: '', phone: '', email: '' });

const QrModal: React.FC<QrModalProps> = ({ booking, onClose, onRefresh }) => {
  const ref = `#NSC-${String(booking.id).padStart(6, '0')}`;
  const cap = booking.maxPersons ?? 1;
  // Members get their passes from the booking pass, which only exists once the
  // payment went through — so no pass, no member list.
  const isGroup = cap > 1 && !!booking.qrCode;
  const scannedIn = booking.scannedInCount ?? 0;

  // Email-share sub-flow (booking-level / counter fallback)
  const [emailMode, setEmailMode] = useState(false);
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [sendErr, setSendErr] = useState<string | null>(null);

  // Members (allowed members with individual QR)
  const [members, setMembers] = useState<BookingMember[]>(booking.members ?? []);
  const [membersMode, setMembersMode] = useState(false);
  const [memberRows, setMemberRows] = useState<{ name: string; phone: string; email: string }[]>([]);
  const [savingMembers, setSavingMembers] = useState(false);
  const [membersErr, setMembersErr] = useState<string | null>(null);
  const [memberMsg, setMemberMsg] = useState<{ id: number; text: string; ok: boolean } | null>(null);
  const [memberEmailSending, setMemberEmailSending] = useState<number | null>(null);

  const openMembersEditor = () => {
    const existing = members.map((m) => ({ name: m.name, phone: m.phone, email: m.email || '' }));
    const rows = existing.length > 0 ? existing.slice() : [];
    while (rows.length < cap) rows.push(emptyRow());
    setMemberRows(rows.slice(0, cap));
    setMembersErr(null);
    setMembersMode(true);
  };

  const updateRow = (i: number, field: 'name' | 'phone' | 'email', value: string) => {
    setMemberRows((prev) => prev.map((r, idx) => (idx === i ? { ...r, [field]: value } : r)));
  };

  const handleSaveMembers = async () => {
    setMembersErr(null);
    for (let i = 0; i < memberRows.length; i++) {
      if (!memberRows[i].name.trim()) { setMembersErr(`Enter a name for member ${i + 1}.`); return; }
      if (!memberRows[i].phone.trim()) { setMembersErr(`Enter a WhatsApp number for ${memberRows[i].name || `member ${i + 1}`}.`); return; }
    }
    setSavingMembers(true);
    try {
      const saved = await bookingService.saveMembers(
        booking.id,
        memberRows.map((r) => ({ name: r.name.trim(), phone: r.phone.trim(), email: r.email.trim() || undefined })),
      );
      setMembers(saved);
      setMembersMode(false);
      onRefresh();
    } catch (e: any) {
      setMembersErr(e.message || 'Failed to save members.');
    } finally {
      setSavingMembers(false);
    }
  };

  const handleMemberEmail = async (m: BookingMember) => {
    const target = (m.email && m.email.trim()) || window.prompt(`Email address to send ${m.name}'s pass to:`)?.trim();
    if (!target) return;
    setMemberEmailSending(m.id);
    setMemberMsg(null);
    try {
      await bookingService.sendMemberPassByEmail(booking.id, m.id, target);
      setMemberMsg({ id: m.id, text: `Pass emailed to ${target}`, ok: true });
    } catch (e: any) {
      setMemberMsg({ id: m.id, text: e.message || 'Failed to email pass', ok: false });
    } finally {
      setMemberEmailSending(null);
    }
  };

  const handleSendEmail = async () => {
    if (!email.trim()) { setSendErr('Please enter an email address.'); return; }
    setSending(true);
    setSendErr(null);
    try {
      await bookingService.sendPassByEmail(booking.id, email.trim(), name.trim() || undefined);
      setSent(true);
    } catch (e: any) {
      setSendErr(e.message || 'Failed to send pass email.');
    } finally {
      setSending(false);
    }
  };

  const handleDownload = () => {
    if (!booking.qrCode) return;
    const a = document.createElement('a');
    a.href = booking.qrCode;
    a.download = `${booking.passCode || ref}-qr.png`;
    a.target = '_blank';
    a.click();
  };

  const handleShare = async () => {
    const text = `My Nahata Sports booking pass\nRef: ${ref}\nSport: ${booking.sport?.name}\nDate: ${booking.date} | ${formatTime(booking.startTime)} – ${formatTime(booking.endTime)}\nPass Code: ${booking.passCode}`;
    if (navigator.share) {
      await navigator.share({ title: 'Nahata Sports Booking Pass', text });
    } else {
      await navigator.clipboard.writeText(text);
      alert('Pass details copied to clipboard!');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative bg-white rounded-3xl shadow-2xl w-full max-w-md max-h-[92vh] overflow-y-auto">
        {/* Header */}
        <div className="bg-linear-to-br from-slate-800 to-slate-900 px-6 pt-6 pb-5 text-center">
          <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">
            Nahata Sports
          </p>
          <h2 className="text-white font-black text-lg leading-tight">
            {booking.sport?.name} Booking
          </h2>
          <p className="text-slate-400 text-xs mt-1">{booking.court?.name}</p>
          <span className="inline-block mt-3 bg-green-500 text-white text-[10px] font-black px-3 py-1 rounded-full uppercase tracking-wider">
            ✓ Confirmed Pass
          </span>
        </div>

        {/* Dashed divider */}
        <div className="border-t-2 border-dashed border-slate-200" />

        {/* QR Code */}
        <div className="px-6 py-5 text-center">
          {booking.qrCode ? (
            <>
              <div className="inline-block p-3 bg-white border-2 border-slate-200 rounded-2xl shadow-sm">
                <img
                  src={booking.qrCode}
                  alt="Booking QR Code"
                  className="w-44 h-44 object-contain"
                />
              </div>
              <p className="mt-3 font-mono text-sm font-black text-slate-800 tracking-widest">
                {booking.passCode}
              </p>
              <p className="text-[10px] text-slate-400 mt-1">Booking Pass Code</p>
            </>
          ) : (
            <div className="py-8 text-slate-400 text-sm">
              QR code not available yet. Complete payment to generate your pass.
            </div>
          )}
        </div>

        {/* Booking details */}
        <div className="mx-6 mb-4 bg-slate-50 rounded-2xl p-4 space-y-2 text-xs">
          <div className="flex justify-between">
            <span className="text-slate-500 font-medium">Reference</span>
            <span className="font-mono font-black text-slate-800">{ref}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-500 font-medium">Date</span>
            <span className="font-bold text-slate-800">{booking.date}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-500 font-medium">Time</span>
            <span className="font-bold text-slate-800">
              {formatTime(booking.startTime)} – {formatTime(booking.endTime)}
            </span>
          </div>
          {booking.maxPersons && (
            <div className="flex justify-between">
              <span className="text-slate-500 font-medium flex items-center gap-1">
                <Users size={11} /> Valid For
              </span>
              <span className="font-black text-blue-700">
                {booking.maxPersons} Person{booking.maxPersons > 1 ? 's' : ''}
              </span>
            </div>
          )}
        </div>

        {/* Scan progress */}
        {isGroup && (
          <div className="mx-6 mb-4">
            <div className="flex items-center justify-between mb-1">
              <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Checked In</span>
              <span className="text-[10px] font-black text-emerald-600">{scannedIn}/{cap}</span>
            </div>
            <div className="h-1.5 bg-slate-200 rounded-full overflow-hidden">
              <div className="h-full bg-emerald-500 rounded-full transition-all" style={{ width: `${cap ? (scannedIn / cap) * 100 : 0}%` }} />
            </div>
          </div>
        )}

        {/* Allowed Members — each gets their own QR shared via WhatsApp/Email */}
        {isGroup && (
          <div className="mx-6 mb-4 bg-slate-50 rounded-2xl p-4">
            <div className="flex items-center justify-between mb-3">
              <span className="text-[11px] font-black text-slate-600 uppercase tracking-wide flex items-center gap-1.5">
                <Users size={12} /> Allowed Members
              </span>
              {!membersMode && (
                <button onClick={openMembersEditor} className="text-[11px] font-bold text-primary flex items-center gap-1 hover:underline">
                  <Pencil size={11} /> {members.length > 0 ? 'Edit' : `Add ${cap}`}
                </button>
              )}
            </div>

            {membersMode ? (
              <div className="space-y-2">
                {membersErr && (
                  <div className="p-2 bg-red-50 border border-red-200 rounded-lg text-red-600 text-[11px]">{membersErr}</div>
                )}
                {memberRows.map((row, i) => (
                  <div key={i} className="space-y-1.5 bg-white rounded-xl p-2.5 border border-slate-200">
                    <div className="flex items-center gap-2">
                      <span className="w-5 h-5 bg-slate-100 rounded-md text-[10px] font-black text-slate-500 flex items-center justify-center shrink-0">{i + 1}</span>
                      <input
                        value={row.name}
                        onChange={(e) => updateRow(i, 'name', e.target.value)}
                        placeholder="Full name"
                        className="flex-1 bg-slate-50 border border-slate-200 rounded-lg py-2 px-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div className="relative">
                      <Phone size={12} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
                      <input
                        value={row.phone}
                        onChange={(e) => updateRow(i, 'phone', e.target.value)}
                        placeholder="WhatsApp no. with country code (e.g. 919876543210)"
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 pl-7 pr-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div className="relative">
                      <Mail size={12} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
                      <input
                        value={row.email}
                        onChange={(e) => updateRow(i, 'email', e.target.value)}
                        placeholder="Email (optional)"
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 pl-7 pr-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                  </div>
                ))}
                <p className="text-[10px] text-slate-400">Enter WhatsApp numbers with country code, e.g. 919876543210 for India.</p>
                <div className="grid grid-cols-2 gap-2 pt-1">
                  <button onClick={() => setMembersMode(false)} disabled={savingMembers} className="py-2.5 rounded-xl bg-slate-100 text-slate-600 text-xs font-black hover:bg-slate-200 disabled:opacity-50">
                    Cancel
                  </button>
                  <button onClick={handleSaveMembers} disabled={savingMembers} className="flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-primary text-white text-xs font-black hover:bg-primary/90 disabled:opacity-50">
                    {savingMembers ? <><Loader2 size={13} className="animate-spin" /> Saving…</> : <><CheckCircle size={13} /> Save</>}
                  </button>
                </div>
              </div>
            ) : members.length > 0 ? (
              <div className="space-y-2">
                {members.map((m) => {
                  const isIn = m.scanStatus === 'In';
                  const isOut = m.scanStatus === 'Out';
                  return (
                    <div key={m.id} className="bg-white rounded-xl border border-slate-200 p-2.5">
                      <div className="flex items-center gap-2">
                        <div className="flex-1 min-w-0">
                          <p className="text-xs font-bold text-slate-800 truncate">{m.name}</p>
                          <p className="text-[10px] text-slate-400">+{m.phone}</p>
                        </div>
                        <span className={`text-[9px] font-black px-2 py-0.5 rounded-full shrink-0 ${isIn ? 'bg-emerald-100 text-emerald-700' : isOut ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-500'}`}>
                          {isIn ? 'IN' : isOut ? 'OUT' : 'NOT SCANNED'}
                        </span>
                      </div>
                      <div className="grid grid-cols-2 gap-2 mt-2">
                        <a
                          href={buildMemberWhatsAppLink(m, booking)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center justify-center gap-1.5 py-2 rounded-lg bg-green-500 hover:bg-green-600 text-white text-[11px] font-black"
                        >
                          <MessageCircle size={12} /> WhatsApp
                        </a>
                        <button
                          onClick={() => handleMemberEmail(m)}
                          disabled={memberEmailSending === m.id}
                          className="flex items-center justify-center gap-1.5 py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white text-[11px] font-black disabled:opacity-50"
                        >
                          {memberEmailSending === m.id ? <Loader2 size={12} className="animate-spin" /> : <Mail size={12} />} Email
                        </button>
                      </div>
                      {memberMsg?.id === m.id && (
                        <p className={`text-[10px] mt-1.5 font-semibold ${memberMsg.ok ? 'text-emerald-600' : 'text-red-600'}`}>{memberMsg.text}</p>
                      )}
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-center py-2">
                <p className="text-[11px] text-slate-500 mb-2 leading-relaxed">
                  Add your {cap} members to send each person their own pass on WhatsApp &amp; Email. Only these members will be valid at the gate.
                </p>
                <button onClick={openMembersEditor} className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-amber-500 text-white text-xs font-black hover:bg-amber-600">
                  <UserPlus size={13} /> Add {cap} Members
                </button>
              </div>
            )}
          </div>
        )}

        {/* Actions */}
        {booking.qrCode && (
          <div className="px-6 pb-5 space-y-3">
            {sent ? (
              /* Email sent success */
              <div className="text-center space-y-3 py-2">
                <div className="w-14 h-14 bg-green-100 rounded-full flex items-center justify-center mx-auto">
                  <CheckCircle size={28} className="text-green-600" />
                </div>
                <p className="text-sm font-black text-slate-800">Pass Sent!</p>
                <p className="text-xs text-slate-500">
                  Your booking pass was sent to <strong className="text-slate-700">{email}</strong>
                </p>
                <button
                  onClick={() => { setSent(false); setEmailMode(false); setEmail(''); setName(''); }}
                  className="text-xs font-bold text-primary hover:underline"
                >
                  Send to another email
                </button>
              </div>
            ) : emailMode ? (
              /* Email entry form */
              <div className="space-y-3">
                <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">
                  Send pass by email
                </p>
                {sendErr && (
                  <div className="p-2.5 bg-red-50 border border-red-200 rounded-xl text-red-600 text-xs">
                    {sendErr}
                  </div>
                )}
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Recipient name (optional)"
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="friend@example.com"
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                />
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={() => { setEmailMode(false); setSendErr(null); }}
                    disabled={sending}
                    className="flex items-center justify-center gap-2 bg-slate-100 hover:bg-slate-200 text-slate-600 text-xs font-black py-3 rounded-xl transition-colors disabled:opacity-50"
                  >
                    Back
                  </button>
                  <button
                    onClick={handleSendEmail}
                    disabled={sending || !email.trim()}
                    className="flex items-center justify-center gap-2 bg-primary hover:bg-primary/90 text-white text-xs font-black py-3 rounded-xl transition-colors disabled:opacity-50"
                  >
                    {sending
                      ? <><Loader2 size={14} className="animate-spin" /> Sending…</>
                      : <><Send size={14} /> Send</>}
                  </button>
                </div>
              </div>
            ) : (
              /* Default share actions */
              <>
                <div className="grid grid-cols-2 gap-3">
                  <a
                    href={buildBookingWhatsAppLink(booking)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-center gap-2 bg-green-500 hover:bg-green-600 text-white text-xs font-black py-3 rounded-xl transition-colors"
                  >
                    <MessageCircle size={14} /> WhatsApp
                  </a>
                  <button
                    onClick={() => { setEmailMode(true); setSendErr(null); }}
                    className="flex items-center justify-center gap-2 bg-blue-500 hover:bg-blue-600 text-white text-xs font-black py-3 rounded-xl transition-colors"
                  >
                    <Mail size={14} /> Email
                  </button>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={handleDownload}
                    className="flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700 text-white text-xs font-black py-3 rounded-xl transition-colors"
                  >
                    <Download size={14} /> Download
                  </button>
                  <button
                    onClick={handleShare}
                    className="flex items-center justify-center gap-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-black py-3 rounded-xl transition-colors"
                  >
                    <Share2 size={14} /> Share
                  </button>
                </div>
              </>
            )}
          </div>
        )}

        {/* Close */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-1.5 bg-white/10 hover:bg-white/20 rounded-full text-white transition-colors"
        >
          <X size={16} />
        </button>
      </div>
    </div>
  );
};

// ── Component ─────────────────────────────────────────────────────────────────
export const MyBookings: React.FC = () => {
  const [bookings, setBookings]       = useState<MyBooking[]>([]);
  const [loading, setLoading]         = useState(true);
  const [cancellingId, setCancellingId] = useState<number | null>(null);
  const [search, setSearch]           = useState('');
  const [page, setPage]               = useState(1);
  const [totalPages, setTotalPages]   = useState(1);
  const [totalItems, setTotalItems]   = useState(0);
  const [error, setError]             = useState('');
  const [qrBooking, setQrBooking]     = useState<MyBooking | null>(null);
  const limit = 10;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const res = await bookingService.getMyBookings(p, limit);
      setBookings(res.bookings);
      setTotalPages(res.totalPages);
      setTotalItems(res.totalItems);
      setPage(p);
    } catch {
      setError('Failed to load bookings. Please try again.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(1); }, [load]);

  const handleCancel = async (id: number) => {
    if (!confirm('Cancel this booking?')) return;
    setCancellingId(id);
    try {
      await bookingService.cancelBooking(id);
      await load(page);
    } catch (e: any) {
      alert(e.message || 'Cancel failed');
    } finally {
      setCancellingId(null);
    }
  };

  // Client-side search filter
  const filtered = bookings.filter((b) => {
    const q = search.toLowerCase();
    return (
      b.sport?.name?.toLowerCase().includes(q) ||
      b.court?.name?.toLowerCase().includes(q) ||
      b.court?.SportComplex?.name?.toLowerCase().includes(q) ||
      b.date?.includes(q)
    );
  });

  return (
    <UserMainLayout
      breadcrumbs={[{ label: 'Dashboard' }, { label: 'My Bookings', active: true }]}
    >
      <div className="space-y-6">

        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">My Bookings</h1>
            <p className="text-text-muted text-sm mt-1">
              {totalItems} booking{totalItems !== 1 ? 's' : ''} total
            </p>
          </div>
          <div className="flex items-center gap-3">
            <div className="relative">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                type="text"
                placeholder="Search sport, court, venue…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-9 pr-4 py-2.5 bg-white border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all w-60"
              />
            </div>
            <button
              onClick={() => load(page)}
              className="p-2.5 bg-white border border-border rounded-xl text-slate-400 hover:text-primary hover:border-primary transition-all"
              title="Refresh"
            >
              <RefreshCw size={16} />
            </button>
          </div>
        </div>

        {/* Error */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 text-sm px-4 py-3 rounded-xl flex items-center gap-2">
            <AlertCircle size={16} /> {error}
          </div>
        )}

        {/* Loading */}
        {loading ? (
          <div className="bg-white rounded-2xl border border-border p-16 flex flex-col items-center gap-3">
            <Loader2 size={32} className="animate-spin text-primary" />
            <p className="text-text-muted text-sm">Loading your bookings…</p>
          </div>
        ) : filtered.length === 0 ? (
          <div className="bg-white rounded-2xl border border-border p-16 text-center">
            <Calendar size={40} className="text-slate-300 mx-auto mb-3" />
            <p className="font-semibold text-text-dark mb-1">No bookings found</p>
            <p className="text-text-muted text-sm">
              {search ? 'Try a different search term.' : 'Book a court to get started.'}
            </p>
          </div>
        ) : (
          <>
            {/* Cards */}
            <div className="space-y-3">
              {filtered.map((b) => {
                const bs = fmt(b.bookingStatus);
                const ps = fmtPay(b.paymentStatus);
                const canCancel = b.bookingStatus === 'Confirmed' || b.bookingStatus === 'Pending';
                const hasQr = !!b.qrCode;

                return (
                  <div
                    key={b.id}
                    className="bg-white rounded-2xl border border-border p-5 hover:shadow-md transition-shadow"
                  >
                    <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4">

                      {/* Left — booking info */}
                      <div className="flex items-start gap-4">
                        {/* Sport icon / image */}
                        <div className="w-12 h-12 rounded-xl bg-brand-secondary flex items-center justify-center shrink-0 overflow-hidden">
                          {b.sport?.image
                            ? <img src={getImageUrl(b.sport.image)} alt={b.sport.name} className="w-full h-full object-cover" />
                            : <Trophy size={20} className="text-primary" />
                          }
                        </div>

                        <div className="space-y-1.5">
                          {/* Sport + Court */}
                          <p className="font-bold text-text-dark text-sm leading-tight">
                            {b.sport?.name ?? '—'} &mdash; {b.court?.name ?? '—'}
                          </p>

                          {/* Venue */}
                          {b.court?.SportComplex && (
                            <p className="text-xs text-text-muted flex items-center gap-1">
                              <MapPin size={11} className="text-primary" />
                              {b.court.SportComplex.name}, {b.court.SportComplex.city}
                            </p>
                          )}

                          {/* Date + Time */}
                          <div className="flex flex-wrap items-center gap-3 text-xs text-text-muted">
                            <span className="flex items-center gap-1">
                              <Calendar size={11} /> {b.date}
                            </span>
                            <span className="flex items-center gap-1">
                              <Clock size={11} />
                              {formatTime(b.startTime)} – {formatTime(b.endTime)}
                            </span>
                            <span className="flex items-center gap-1 font-semibold text-text-dark">
                              <IndianRupee size={11} className="text-primary" />
                              {parseFloat(String(b.totalAmount)).toLocaleString('en-IN')}
                            </span>
                          </div>

                          {/* Ref ID + capacity */}
                          <div className="flex items-center gap-3 flex-wrap">
                            <p className="text-[10px] text-text-muted font-mono">
                              Ref: #NSC-{String(b.id).padStart(6, '0')} · {b.bookingSource}
                            </p>
                            {b.maxPersons && (
                              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full">
                                <Users size={9} /> {b.maxPersons} persons
                              </span>
                            )}
                            {b.maxPersons && b.maxPersons > 1 && (b.scannedInCount ?? 0) > 0 && (
                              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full">
                                <CheckCircle size={9} /> {b.scannedInCount}/{b.maxPersons} in
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Right — badges + actions */}
                      <div className="flex sm:flex-col items-start sm:items-end gap-2 shrink-0">
                        {/* Booking status */}
                        <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold ${bs.bg} ${bs.text}`}>
                          {bs.icon} {b.bookingStatus}
                        </span>

                        {/* Payment status */}
                        <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold ${ps.bg} ${ps.text}`}>
                          <IndianRupee size={10} /> {b.paymentStatus}
                        </span>

                        {/* QR button — shown when QR exists */}
                        {hasQr && (
                          <button
                            onClick={() => setQrBooking(b)}
                            className="mt-1 flex items-center gap-1 text-[10px] font-bold text-primary hover:text-primary/80 transition-colors bg-brand-secondary px-2.5 py-1 rounded-full"
                          >
                            <QrCode size={11} /> View Pass
                          </button>
                        )}

                        {/* Cancel button */}
                        {canCancel && (
                          <button
                            onClick={() => handleCancel(b.id)}
                            disabled={cancellingId === b.id}
                            className="flex items-center gap-1 text-[10px] font-bold text-red-500 hover:text-red-700 transition-colors disabled:opacity-50"
                          >
                            {cancellingId === b.id
                              ? <Loader2 size={11} className="animate-spin" />
                              : <XCircle size={11} />
                            }
                            Cancel
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between pt-2">
                <p className="text-xs text-text-muted">
                  Page {page} of {totalPages}
                </p>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => load(page - 1)}
                    disabled={page <= 1}
                    className="p-2 bg-white border border-border rounded-xl text-slate-400 hover:text-primary hover:border-primary transition-all disabled:opacity-40"
                  >
                    <ChevronLeft size={16} />
                  </button>
                  <button
                    onClick={() => load(page + 1)}
                    disabled={page >= totalPages}
                    className="p-2 bg-white border border-border rounded-xl text-slate-400 hover:text-primary hover:border-primary transition-all disabled:opacity-40"
                  >
                    <ChevronRight size={16} />
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* QR Modal */}
      {qrBooking && (
        <QrModal booking={qrBooking} onClose={() => setQrBooking(null)} onRefresh={() => load(page)} />
      )}
    </UserMainLayout>
  );
};

export default MyBookings;
