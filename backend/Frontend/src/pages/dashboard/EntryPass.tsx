import React, { useState, useEffect, useCallback } from 'react';
import {
  LogIn, QrCode, RefreshCw, Loader2, AlertCircle,
  Calendar, Clock, X, Download, Share2, Users,
  CheckCircle, IndianRupee, Trophy, GraduationCap,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { fetchWithAuth } from '../../lib/fetchWithAuth';
import { getImageUrl } from '../../lib/utils';

// ── Types ─────────────────────────────────────────────────────────────────────
interface GatePass {
  id: number;
  passCode: string;
  qrCode: string;
  studentName: string;
  studentPhone: string;
  bloodGroup: string;
  dob: string;
  batchId: number;
  batchName: string;
  sportName: string;
  sportImage: string | null;
  coachName: string;
  amountPaid: number;
  batchFee: number;
  paymentStatus: 'Pending' | 'Paid' | 'Partial' | 'Overdue';
  approvalStatus: 'Approved';
  enrollmentDate: string;
  approvedAt: string | null;
  status: string;
  notes: string | null;
  batchDays: string;
  startTime: string;
  endTime: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

function fmtTime(t?: string) {
  if (!t) return null;
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  const hour = h % 12 || 12;
  return `${hour}:${String(m).padStart(2, '0')} ${ampm}`;
}

function fmtDate(d?: string | null) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
  });
}

const PAYMENT_STYLES: Record<string, { bg: string; text: string }> = {
  Paid:    { bg: 'bg-green-100',  text: 'text-green-700'  },
  Partial: { bg: 'bg-blue-100',   text: 'text-blue-700'   },
  Pending: { bg: 'bg-amber-100',  text: 'text-amber-700'  },
  Overdue: { bg: 'bg-red-100',    text: 'text-red-600'    },
};

// ── QR / Gate Pass Modal ──────────────────────────────────────────────────────
interface PassModalProps {
  pass: GatePass;
  onClose: () => void;
}

const PassModal: React.FC<PassModalProps> = ({ pass, onClose }) => {
  const startFmt = fmtTime(pass.startTime);
  const endFmt   = fmtTime(pass.endTime);
  const payStyle = PAYMENT_STYLES[pass.paymentStatus] ?? PAYMENT_STYLES.Pending;

  const handleDownload = () => {
    const a = document.createElement('a');
    a.href = pass.qrCode;
    a.download = `${pass.passCode}-qr.png`;
    a.target = '_blank';
    a.click();
  };

  const handleShare = async () => {
    const currentDate = new Date().toLocaleDateString('en-GB', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
    const text = [
      `🎟️ Hi ${pass.studentName}! Your Gate Pass — Nahata Sports Academy`,
      ``,
      `📅 Date: ${currentDate}`,
      `🏃 Batch: ${pass.batchName}`,
      pass.sportName ? `🏆 Sport: ${pass.sportName}` : '',
      `💰 Amount Paid: ₹${Number(pass.amountPaid).toLocaleString('en-IN')}`,
      `📆 Enrollment Date: ${pass.enrollmentDate}`,
      ``,
      `*Pass Code:* ${pass.passCode}`,
      ``,
      `✅ Status: APPROVED`,
      ``,
      `🔐 Show this QR code at the entry gate:`,
      pass.qrCode,
      ``,
      `_Nahata Sports Complex_`,
    ]
      .filter((l) => l !== null && l !== undefined)
      .join('\n');

    if (navigator.share) {
      await navigator.share({ title: 'Nahata Sports Gate Pass', text });
    } else {
      await navigator.clipboard.writeText(text);
      alert('Pass details copied to clipboard!');
    }
  };

  const handleWhatsApp = () => {
    const phone = pass.studentPhone?.replace(/\D/g, '');
    if (!phone) return;
    const fullPhone = phone.startsWith('91') ? phone : `91${phone}`;
    const currentDate = new Date().toLocaleDateString('en-GB', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
    const msg = encodeURIComponent(
      `🎟️ Hi ${pass.studentName}! Your Gate Pass — Nahata Sports Academy\n\n` +
      `📅 Date: ${currentDate}\n` +
      `🏃 Batch: ${pass.batchName}\n` +
      `💰 Amount Paid: ₹${Number(pass.amountPaid).toLocaleString('en-IN')}\n` +
      `📆 Enrollment: ${pass.enrollmentDate}\n\n` +
      `*Pass Code:* ${pass.passCode}\n\n` +
      `✅ Status: APPROVED\n\n` +
      `🔐 QR Code: ${pass.qrCode}\n\n` +
      `_Nahata Sports Complex_`
    );
    window.open(`https://wa.me/${fullPhone}?text=${msg}`, '_blank');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm" onClick={onClose} />

      <div className="relative bg-white rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="bg-gradient-to-br from-slate-800 to-slate-900 px-6 pt-6 pb-5 text-center shrink-0">
          <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">
            Nahata Sports Academy
          </p>
          <h2 className="text-white font-black text-lg leading-tight">Gate Pass</h2>
          <p className="text-slate-300 text-xs mt-1 font-semibold">{pass.batchName}</p>
          {pass.sportName && (
            <p className="text-slate-400 text-[10px] mt-0.5">{pass.sportName}</p>
          )}
          <span className="inline-flex items-center gap-1 mt-3 bg-green-500/20 text-green-400 text-[10px] font-black px-3 py-1 rounded-full uppercase tracking-wider border border-green-500/30">
            <CheckCircle size={10} /> Approved
          </span>
        </div>

        <div className="border-t-2 border-dashed border-slate-200" />

        {/* Scrollable content */}
        <div className="overflow-y-auto flex-1 px-6 py-5 space-y-4">
          {/* QR Code */}
          <div className="text-center">
            <div className="inline-block p-3 bg-white border-2 border-slate-200 rounded-2xl shadow-sm">
              <img src={pass.qrCode} alt="Gate Pass QR" className="w-40 h-40 object-contain" />
            </div>
            <p className="mt-2 font-mono text-xs font-black text-slate-700 tracking-widest">
              {pass.passCode}
            </p>
            <p className="text-[10px] text-slate-400 mt-0.5">Show this QR at the entry gate</p>
          </div>

          {/* Student info */}
          <div className="bg-slate-50 rounded-2xl p-4 space-y-2 text-xs">
            <div className="flex justify-between">
              <span className="text-slate-500 font-medium">Student</span>
              <span className="font-bold text-slate-800">{pass.studentName}</span>
            </div>
            {pass.dob && (
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">DOB</span>
                <span className="font-medium text-slate-700">{pass.dob}</span>
              </div>
            )}
            {pass.bloodGroup && (
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Blood Group</span>
                <span className="font-bold text-red-600">{pass.bloodGroup}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span className="text-slate-500 font-medium">Program</span>
              <span className="font-bold text-slate-800 text-right max-w-[60%]">{pass.batchName}</span>
            </div>
            {pass.coachName && (
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Coach</span>
                <span className="font-medium text-slate-700">{pass.coachName}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span className="text-slate-500 font-medium">Enrolled On</span>
              <span className="font-medium text-slate-700">{pass.enrollmentDate}</span>
            </div>
            {startFmt && (
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Batch Time</span>
                <span className="font-medium text-slate-700">
                  {startFmt}{endFmt ? ` – ${endFmt}` : ''}
                </span>
              </div>
            )}
            {pass.batchDays && (
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Days</span>
                <span className="font-medium text-slate-700">{pass.batchDays}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span className="text-slate-500 font-medium">Amount Paid</span>
              <span className="font-black text-green-600">
                ₹{Number(pass.amountPaid).toLocaleString('en-IN')}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-slate-500 font-medium">Payment</span>
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${payStyle.bg} ${payStyle.text}`}>
                {pass.paymentStatus}
              </span>
            </div>
            {pass.approvedAt && (
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Approved On</span>
                <span className="font-medium text-slate-700">{fmtDate(pass.approvedAt)}</span>
              </div>
            )}
          </div>

          {/* Status badges */}
          <div className="flex gap-2 justify-center flex-wrap">
            <span className="px-3 py-1.5 bg-green-100 text-green-700 rounded-lg text-[10px] font-bold">
              ✓ Approved by Admin
            </span>
            <span className="px-3 py-1.5 bg-blue-100 text-blue-700 rounded-lg text-[10px] font-bold">
              Gate Pass Issued
            </span>
          </div>
        </div>

        {/* Actions */}
        <div className="px-6 pb-5 pt-3 border-t border-border shrink-0 space-y-2">
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={handleDownload}
              className="flex items-center justify-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-white text-xs font-black py-2.5 rounded-xl transition-colors"
            >
              <Download size={13} /> Download QR
            </button>
            <button
              onClick={handleShare}
              className="flex items-center justify-center gap-1.5 bg-primary hover:bg-primary/90 text-white text-xs font-black py-2.5 rounded-xl transition-colors"
            >
              <Share2 size={13} /> Share
            </button>
          </div>
          {pass.studentPhone && (
            <button
              onClick={handleWhatsApp}
              className="w-full flex items-center justify-center gap-1.5 bg-green-500 hover:bg-green-600 text-white text-xs font-black py-2.5 rounded-xl transition-colors"
            >
              <svg viewBox="0 0 24 24" className="w-3.5 h-3.5 fill-current"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
              Send via WhatsApp
            </button>
          )}
        </div>

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

// ── Main Component ────────────────────────────────────────────────────────────
export const EntryPass: React.FC = () => {
  const [passes, setPasses]       = useState<GatePass[]>([]);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState<string | null>(null);
  const [selected, setSelected]   = useState<GatePass | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res  = await fetchWithAuth(`${API_BASE}/fees/my`);
      const json = await res.json();
      if (!res.ok) throw new Error(json.message || `Error ${res.status}`);
      setPasses(Array.isArray(json.data) ? json.data : []);
    } catch (err: any) {
      setError(err.message || 'Failed to load gate passes');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <UserMainLayout
      breadcrumbs={[
        { label: 'Dashboard' },
        { label: 'Entry Pass', active: true },
      ]}
    >
      <div className="space-y-6">

        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Entry Pass</h1>
            <p className="text-text-muted text-sm mt-1">
              Your approved gate passes for coaching programs.
            </p>
          </div>
          <button
            onClick={load}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm font-semibold text-text-muted hover:bg-slate-50 transition-colors disabled:opacity-50"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            Refresh
          </button>
        </div>

        {/* Error */}
        {error && (
          <div className="flex items-center gap-3 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">
            <AlertCircle size={16} className="shrink-0" />
            {error}
          </div>
        )}

        {loading ? (
          <div className="flex items-center justify-center py-24 text-slate-400">
            <Loader2 size={32} className="animate-spin" />
          </div>
        ) : passes.length === 0 ? (
          /* Empty state */
          <div className="bg-white rounded-2xl border border-border p-16 text-center">
            <div className="w-16 h-16 bg-brand-secondary rounded-2xl flex items-center justify-center mx-auto mb-4">
              <LogIn size={28} className="text-primary opacity-60" />
            </div>
            <p className="font-semibold text-text-dark mb-1">No gate passes yet</p>
            <p className="text-text-muted text-sm">
              Gate passes are issued after your fee payment is approved by the admin.
            </p>
          </div>
        ) : (
          <>
            {/* Summary */}
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
              {[
                { label: 'Total Passes',  value: passes.length,                                                    color: 'text-text-dark' },
                { label: 'Paid',          value: passes.filter(p => p.paymentStatus === 'Paid').length,            color: 'text-green-600' },
                { label: 'Pending',       value: passes.filter(p => p.paymentStatus !== 'Paid').length,            color: 'text-amber-600' },
              ].map((s) => (
                <div key={s.label} className="bg-white rounded-2xl border border-border p-5 text-center">
                  <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
                  <p className="text-xs text-text-muted mt-1">{s.label}</p>
                </div>
              ))}
            </div>

            {/* Pass cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {passes.map((pass) => {
                const payStyle = PAYMENT_STYLES[pass.paymentStatus] ?? PAYMENT_STYLES.Pending;
                const startFmt = fmtTime(pass.startTime);
                const endFmt   = fmtTime(pass.endTime);

                return (
                  <div
                    key={pass.id}
                    className="bg-white rounded-2xl border border-border overflow-hidden hover:shadow-md transition-shadow"
                  >
                    {/* Sport image strip */}
                    {pass.sportImage && (
                      <div className="h-20 overflow-hidden">
                        <img
                          src={getImageUrl(pass.sportImage)}
                          alt={pass.sportName}
                          className="w-full h-full object-cover"
                          onError={(e) => { (e.currentTarget as HTMLImageElement).style.display = 'none'; }}
                        />
                      </div>
                    )}

                    <div className="p-5 flex flex-col gap-3">
                      {/* Top row */}
                      <div className="flex items-start justify-between gap-2">
                        <div className="w-10 h-10 bg-brand-secondary rounded-xl flex items-center justify-center shrink-0">
                          <LogIn size={18} className="text-primary" />
                        </div>
                        <div className="flex flex-col items-end gap-1">
                          {/* Approved badge */}
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-green-100 text-green-700">
                            <CheckCircle size={9} /> Approved
                          </span>
                          {/* Payment badge */}
                          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${payStyle.bg} ${payStyle.text}`}>
                            {pass.paymentStatus}
                          </span>
                        </div>
                      </div>

                      {/* Info */}
                      <div className="space-y-1">
                        <p className="font-bold text-text-dark text-sm leading-snug">{pass.batchName}</p>
                        {pass.sportName && (
                          <p className="text-xs text-text-muted flex items-center gap-1">
                            <Trophy size={11} className="text-primary" />
                            {pass.sportName}
                          </p>
                        )}
                        {pass.coachName && (
                          <p className="text-xs text-text-muted flex items-center gap-1">
                            <GraduationCap size={11} className="text-primary" />
                            {pass.coachName}
                          </p>
                        )}
                        <p className="text-xs text-text-muted flex items-center gap-1">
                          <Calendar size={11} />
                          Enrolled: {pass.enrollmentDate}
                        </p>
                        {startFmt && (
                          <p className="text-xs text-text-muted flex items-center gap-1">
                            <Clock size={11} />
                            {startFmt}{endFmt ? ` – ${endFmt}` : ''}
                            {pass.batchDays ? ` · ${pass.batchDays}` : ''}
                          </p>
                        )}
                        <p className="text-xs text-green-600 font-bold flex items-center gap-1">
                          <IndianRupee size={11} />
                          ₹{Number(pass.amountPaid).toLocaleString('en-IN')} paid
                          {pass.batchFee ? ` / ₹${Number(pass.batchFee).toLocaleString('en-IN')}` : ''}
                        </p>
                        <p className="text-[10px] text-slate-400 font-mono mt-1">{pass.passCode}</p>
                      </div>

                      {/* View pass button */}
                      <button
                        onClick={() => setSelected(pass)}
                        className="flex items-center gap-2 text-xs font-bold text-primary hover:text-primary/80 transition-colors mt-auto pt-1 border-t border-border"
                      >
                        <QrCode size={13} />
                        View Gate Pass &amp; QR Code
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </div>

      {/* Gate Pass Modal */}
      {selected && (
        <PassModal pass={selected} onClose={() => setSelected(null)} />
      )}
    </UserMainLayout>
  );
};

export default EntryPass;
