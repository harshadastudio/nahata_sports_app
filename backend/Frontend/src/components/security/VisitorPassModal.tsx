import React, { useEffect, useState } from 'react';
import {
  X,
  User,
  Phone,
  Briefcase,
  Clock,
  Copy,
  Share2,
  MessageCircle,
  Mail,
  Download,
  Printer,
  LogIn,
  LogOut,
  ShieldAlert,
  Loader2,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { fetchWithAuth } from '../../lib/fetchWithAuth';
import {
  type VisitorPass,
  VisitorPassStatusBadge,
  getPassStatusMeta,
  normalizePassStatus,
  isQrLive,
  qrImageUrl,
  formatDateTime,
  shareOnWhatsApp,
  copyPassDetails,
  copyPassCode,
  downloadQr,
  emailPass,
  printPass,
} from './visitorPass';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface VisitorPassModalProps {
  pass: VisitorPass | null;
  onClose: () => void;
  /** Called after a background refresh returns newer data (e.g. status changed). */
  onRefreshed?: (pass: VisitorPass) => void;
}

/**
 * Full view of a single visitor pass — QR, details, check-in/out timeline and
 * the share actions. Opened from any pass list; re-fetches the pass on open so
 * the status shown is current even if the row was loaded minutes ago.
 */
export const VisitorPassModal: React.FC<VisitorPassModalProps> = ({ pass, onClose, onRefreshed }) => {
  const [current, setCurrent] = useState<VisitorPass | null>(pass);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    // Keep the last pass around while the modal animates closed.
    if (!pass) return;
    setCurrent(pass);

    let cancelled = false;
    setRefreshing(true);
    fetchWithAuth(`${API_BASE}/visitor-passes/${pass.id}`)
      .then((res) => (res.ok ? res.json() : null))
      .then((json) => {
        const fresh: VisitorPass | undefined = json?.data ?? json?.pass;
        if (cancelled || !fresh) return;
        setCurrent(fresh);
        onRefreshed?.(fresh);
      })
      .catch(() => {
        /* Keep the row data we already have. */
      })
      .finally(() => {
        if (!cancelled) setRefreshing(false);
      });

    return () => {
      cancelled = true;
    };
    // Refresh every time a pass is opened (the row object identity is stable
    // while the modal is open, so this cannot loop).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pass]);

  // Close on Escape.
  useEffect(() => {
    if (!pass) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [pass, onClose]);

  const p = current;
  const status = normalizePassStatus(p?.status);
  const meta = getPassStatusMeta(p?.status);
  const live = p ? isQrLive(p) : false;

  return (
    <AnimatePresence>
      {pass && p && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 z-[100] bg-slate-900/60 backdrop-blur-sm"
          />

          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 16 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 16 }}
            transition={{ type: 'spring', damping: 28, stiffness: 320 }}
            className="fixed inset-0 z-[101] flex items-center justify-center p-4 pointer-events-none"
          >
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[92vh] overflow-hidden flex flex-col pointer-events-auto">

              {/* Header */}
              <div className={`px-6 py-5 flex items-start gap-4 shrink-0 ${meta.solidCls}`}>
                <div className="bg-white/20 p-2.5 rounded-xl shrink-0">
                  {status === 'checked_in' ? (
                    <LogIn size={22} />
                  ) : status === 'checked_out' ? (
                    <LogOut size={22} />
                  ) : (
                    <User size={22} />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <h2 className="text-lg font-bold leading-tight truncate">{p.visitorName}</h2>
                  <p className="text-white/85 text-xs mt-0.5">{meta.hint}</p>
                </div>
                <button
                  onClick={onClose}
                  className="p-2 -mr-1 -mt-1 rounded-lg hover:bg-white/20 transition-colors shrink-0"
                  aria-label="Close"
                >
                  <X size={18} />
                </button>
              </div>

              <div className="flex-1 overflow-y-auto p-6 space-y-5">

                {/* QR */}
                <div className="flex flex-col items-center gap-3">
                  <div
                    className={`bg-white border-2 rounded-2xl p-3 relative ${
                      live ? 'border-border' : 'border-slate-200'
                    }`}
                  >
                    <img
                      src={qrImageUrl(p)}
                      alt={`QR code for ${p.passCode}`}
                      referrerPolicy="no-referrer"
                      className={`w-44 h-44 object-contain ${live ? '' : 'opacity-25 grayscale'}`}
                    />
                    {!live && (
                      <div className="absolute inset-0 flex items-center justify-center">
                        <span className="px-3 py-1.5 rounded-lg bg-slate-800 text-white text-[11px] font-bold uppercase tracking-wider">
                          No longer valid
                        </span>
                      </div>
                    )}
                  </div>

                  <div className="flex items-center gap-2">
                    <span className="font-mono text-lg font-bold text-text-dark tracking-widest">
                      {p.passCode}
                    </span>
                    <button
                      onClick={() => copyPassCode(p.passCode)}
                      className="p-1.5 bg-white border border-border rounded-lg hover:bg-slate-100 transition-colors"
                      title="Copy pass code"
                    >
                      <Copy size={13} className="text-slate-500" />
                    </button>
                  </div>

                  <div className="flex items-center gap-2">
                    <VisitorPassStatusBadge status={p.status} size="md" />
                    {refreshing && <Loader2 size={13} className="animate-spin text-slate-400" />}
                  </div>
                </div>

                {!live && (
                  <div className="flex items-start gap-2.5 bg-amber-50 border border-amber-200 rounded-xl p-3">
                    <ShieldAlert size={16} className="text-amber-600 shrink-0 mt-0.5" />
                    <p className="text-xs text-amber-800">
                      {status === 'checked_out'
                        ? 'This visitor has already checked out. Scanning this QR at the gate will be rejected — generate a new pass for another visit.'
                        : 'This QR code will be rejected at the gate. Generate a new pass if the visitor needs entry.'}
                    </p>
                  </div>
                )}

                {/* Details */}
                <div className="space-y-3 text-sm">
                  <Row icon={<User size={13} />} label="Name" value={p.visitorName} />
                  {p.phoneNumber && <Row icon={<Phone size={13} />} label="Phone" value={p.phoneNumber} />}
                  <Row icon={<Briefcase size={13} />} label="Purpose" value={p.visitPurpose} />
                  <Row icon={<Clock size={13} />} label="Generated" value={formatDateTime(p.generatedAt)} />
                  {p.validUntil && (
                    <Row icon={<Clock size={13} />} label="Valid Until" value={formatDateTime(p.validUntil)} />
                  )}
                  {p.checkInTime && (
                    <Row
                      icon={<LogIn size={13} className="text-blue-500" />}
                      label="Checked In"
                      value={formatDateTime(p.checkInTime)}
                    />
                  )}
                  {p.checkOutTime && (
                    <Row
                      icon={<LogOut size={13} className="text-slate-500" />}
                      label="Checked Out"
                      value={formatDateTime(p.checkOutTime)}
                    />
                  )}
                </div>

                {/* Share */}
                <div className="border-t border-border pt-4">
                  <p className="flex items-center gap-1.5 text-xs font-semibold text-text-muted mb-3">
                    <Share2 size={13} /> Share Pass
                  </p>
                  <div className="grid grid-cols-2 gap-2">
                    <ShareButton
                      onClick={() => shareOnWhatsApp(p)}
                      icon={<MessageCircle size={15} />}
                      label="WhatsApp"
                      cls="bg-green-50 text-green-700 border-green-200 hover:bg-green-100"
                    />
                    <ShareButton
                      onClick={() => emailPass(p, (path, init) => fetchWithAuth(`${API_BASE}${path}`, init))}
                      icon={<Mail size={15} />}
                      label="Email"
                      cls="bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-100"
                    />
                    <ShareButton
                      onClick={() => copyPassDetails(p)}
                      icon={<Copy size={15} />}
                      label="Copy Details"
                      cls="bg-slate-50 text-slate-700 border-border hover:bg-slate-100"
                    />
                    <ShareButton
                      onClick={() => downloadQr(p)}
                      icon={<Download size={15} />}
                      label="Download QR"
                      cls="bg-slate-50 text-slate-700 border-border hover:bg-slate-100"
                    />
                    <ShareButton
                      onClick={() => printPass(p)}
                      icon={<Printer size={15} />}
                      label="Print Pass"
                      cls="col-span-2 bg-slate-50 text-slate-700 border-border hover:bg-slate-100"
                    />
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

// ── Bits ──────────────────────────────────────────────────────────────────────

const Row: React.FC<{ icon: React.ReactNode; label: string; value: string }> = ({ icon, label, value }) => (
  <div className="flex justify-between gap-4">
    <span className="text-text-muted flex items-center gap-1.5 shrink-0">
      {icon} {label}
    </span>
    <span className="font-semibold text-text-dark text-right break-words">{value}</span>
  </div>
);

const ShareButton: React.FC<{
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  cls: string;
}> = ({ onClick, icon, label, cls }) => (
  <button
    onClick={onClick}
    className={`flex items-center justify-center gap-2 px-3 py-2.5 border rounded-xl text-sm font-semibold transition-colors ${cls}`}
  >
    {icon} {label}
  </button>
);

export default VisitorPassModal;
