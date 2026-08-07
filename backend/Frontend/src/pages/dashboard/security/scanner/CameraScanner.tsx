import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ScanLine,
  CheckCircle2,
  XCircle,
  RotateCcw,
  Loader2,
  LogIn,
  LogOut,
  Volume2,
  VolumeX,
  Repeat,
  Search,
  QrCode,
  Ticket,
  Trophy,
  GraduationCap,
  ShieldCheck,
  Sparkles,
  Info,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { QrCameraScanner } from '../../../../components/scanner/QrCameraScanner';
import {
  PASS_KINDS,
  detectPassKind,
  extractPassCode,
  getPassKindMeta,
  type PassKind,
} from '../../../../components/scanner/passCodes';
import { getPassStatusMeta } from '../../../../components/security/visitorPass';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types ─────────────────────────────────────────────────────────────────────

type ScanMode = 'auto' | PassKind;
type Direction = 'In' | 'Out';

interface Detail {
  label: string;
  value: string;
}

interface UnifiedResult {
  success: boolean;
  /** null when the code matched no known pass prefix. */
  kind: PassKind | null;
  code: string;
  title: string;
  message: string;
  subject: string;
  details: Detail[];
  members?: Array<{ id: string; name: string; scanStatus: string }>;
}

interface LogEntry {
  code: string;
  kind: PassKind | null;
  subject: string;
  success: boolean;
  time: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const KIND_ICON: Record<PassKind, React.ElementType> = {
  entry: ShieldCheck,
  event: Ticket,
  court: Trophy,
  student: GraduationCap,
};

const KIND_ACCENT: Record<PassKind, string> = {
  entry: 'bg-indigo-100 text-indigo-700',
  event: 'bg-pink-100 text-pink-700',
  court: 'bg-emerald-100 text-emerald-700',
  student: 'bg-amber-100 text-amber-700',
};

/** How long a result stays on screen before the camera resumes automatically. */
const RESUME_DELAY_MS = { success: 2600, failure: 4200 };

function fmtTime(t?: string | null) {
  if (!t) return null;
  const [h, m] = t.split(':').map(Number);
  if (Number.isNaN(h)) return t;
  const ampm = h >= 12 ? 'PM' : 'AM';
  return `${h % 12 || 12}:${String(m ?? 0).padStart(2, '0')} ${ampm}`;
}

function fmtDate(d?: string | null) {
  if (!d) return '—';
  const dt = new Date(d.length <= 10 ? `${d}T00:00:00` : d);
  if (Number.isNaN(dt.getTime())) return d;
  return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * CameraScanner (SECURITY) — a real camera-based QR scanner for the gate.
 *
 * Unlike the existing per-pass scanner screens (which only accept a typed code
 * or a hardware barcode gun), this one opens the phone/tablet/webcam camera and
 * reads the QR in front of the guard. Every pass type carries its own prefix, so
 * a single scan routes itself to the right endpoint:
 *
 *   VP-…       → POST /visitor-passes/verify  (IN / OUT)
 *   EVTPASS-…  → POST /event-passes/scan     (IN / OUT)
 *   BOOK-…     → POST /courts/bookings/scan  (IN / OUT)
 *   GATEPASS-… → POST /fees/scan-pass
 *
 * The guard can also pin the scanner to one pass type, which then rejects codes
 * of any other type instead of guessing.
 */
export default function CameraScanner() {
  const [mode, setMode] = useState<ScanMode>('auto');
  const [direction, setDirection] = useState<Direction>('In');
  const [continuous, setContinuous] = useState(true);
  const [sound, setSound] = useState(true);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<UnifiedResult | null>(null);
  const [log, setLog] = useState<LogEntry[]>([]);
  const [manualCode, setManualCode] = useState('');
  const [resetSignal, setResetSignal] = useState(0);

  const busyRef = useRef(false);
  const lastSubmittedRef = useRef('');
  const allowRepeatRef = useRef(false);
  const resumeTimerRef = useRef<number | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const soundRef = useRef(sound);
  useEffect(() => { soundRef.current = sound; }, [sound]);

  const clearResumeTimer = useCallback(() => {
    if (resumeTimerRef.current !== null) {
      window.clearTimeout(resumeTimerRef.current);
      resumeTimerRef.current = null;
    }
  }, []);

  useEffect(() => () => {
    clearResumeTimer();
    void audioCtxRef.current?.close().catch(() => {});
  }, [clearResumeTimer]);

  // ── Feedback (tone + haptics) ───────────────────────────────────────────────

  const playTone = useCallback((ok: boolean) => {
    if (!soundRef.current) return;
    try {
      const Ctx = window.AudioContext || (window as any).webkitAudioContext;
      if (!Ctx) return;
      if (!audioCtxRef.current) audioCtxRef.current = new Ctx();
      const ctx = audioCtxRef.current;
      if (ctx.state === 'suspended') void ctx.resume();

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.type = ok ? 'sine' : 'square';
      osc.frequency.value = ok ? 880 : 200;

      const duration = ok ? 0.18 : 0.4;
      gain.gain.setValueAtTime(0.0001, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.22, ctx.currentTime + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + duration);
      osc.start();
      osc.stop(ctx.currentTime + duration + 0.02);
    } catch {
      // Audio is a nicety — never let it break a scan.
    }
  }, []);

  const buzz = (ok: boolean) => {
    try {
      navigator.vibrate?.(ok ? 60 : [70, 60, 70]);
    } catch {
      /* unsupported */
    }
  };

  // ── Verification per pass type ──────────────────────────────────────────────

  const verifyEntry = async (code: string, dir: Direction): Promise<UnifiedResult> => {
    const res = await fetchWithAuth(`${API_BASE}/visitor-passes/verify`, {
      method: 'POST',
      body: JSON.stringify({ passCode: code, scanType: dir }),
    });
    const data = await res.json();
    const pass = data?.data ?? data?.pass;
    const ok = res.ok && Boolean(data?.success || data?.valid);

    return {
      success: ok,
      kind: 'entry',
      code,
      title: ok ? (dir === 'In' ? 'Checked In' : 'Checked Out') : 'Access Denied',
      message:
        data?.message ||
        (ok ? 'Visitor pass verified' : 'Invalid or expired visitor pass'),
      subject: pass?.visitorName || code,
      details: pass
        ? [
            { label: 'Visitor', value: pass.visitorName ?? '—' },
            ...(pass.phoneNumber ? [{ label: 'Phone', value: pass.phoneNumber }] : []),
            { label: 'Purpose', value: pass.visitPurpose ?? '—' },
            { label: 'Pass Status', value: getPassStatusMeta(pass.status).label },
          ]
        : [],
    };
  };

  const verifyEvent = async (code: string, dir: Direction): Promise<UnifiedResult> => {
    const res = await fetchWithAuth(`${API_BASE}/event-passes/scan`, {
      method: 'POST',
      body: JSON.stringify({ passCode: code, scanType: dir }),
    });
    const data = await res.json();
    const pass = data?.data ?? data?.pass;
    const ok = res.ok && Boolean(data?.success);

    return {
      success: ok,
      kind: 'event',
      code,
      title: ok ? (dir === 'In' ? 'Entry Recorded' : 'Exit Recorded') : 'Access Denied',
      message: data?.message || (ok ? 'Event pass scanned' : 'Invalid or expired event pass'),
      subject: pass?.event?.title || 'Event Pass',
      details: pass
        ? [
            { label: 'Event', value: pass.event?.title ?? '—' },
            ...(pass.slot?.name ? [{ label: 'Slot', value: pass.slot.name }] : []),
            { label: 'Date', value: fmtDate(pass.slot?.date) },
            ...(pass.slot?.startTime
              ? [{
                  label: 'Time',
                  value: pass.slot.endTime
                    ? `${fmtTime(pass.slot.startTime)} – ${fmtTime(pass.slot.endTime)}`
                    : fmtTime(pass.slot.startTime) ?? '—',
                }]
              : []),
            {
              label: 'Inside',
              value: `${Math.max(0, (pass.scannedInCount ?? 0) - (pass.scannedOutCount ?? 0))} / ${pass.maxPersons ?? 1}`,
            },
          ]
        : [],
    };
  };

  const verifyCourt = async (code: string, dir: Direction): Promise<UnifiedResult> => {
    const res = await fetchWithAuth(`${API_BASE}/courts/bookings/scan`, {
      method: 'POST',
      body: JSON.stringify({ passCode: code, scanType: dir }),
    });
    const data = await res.json();
    const booking = data?.booking ?? data?.data;
    const ok = res.ok && Boolean(data?.success);

    return {
      success: ok,
      kind: 'court',
      code,
      title: ok ? (dir === 'In' ? 'Entry Recorded' : 'Exit Recorded') : 'Access Denied',
      message: data?.message || (ok ? 'Court pass scanned' : 'Invalid court booking pass'),
      subject: booking?.sport?.name
        ? `${booking.sport.name}${booking.court?.name ? ` · ${booking.court.name}` : ''}`
        : 'Court Booking',
      details: booking
        ? [
            { label: 'Sport', value: booking.sport?.name ?? '—' },
            { label: 'Court', value: booking.court?.name ?? '—' },
            { label: 'Date', value: fmtDate(booking.date) },
            ...(booking.startTime
              ? [{
                  label: 'Time',
                  value: booking.endTime
                    ? `${fmtTime(booking.startTime)} – ${fmtTime(booking.endTime)}`
                    : fmtTime(booking.startTime) ?? '—',
                }]
              : []),
            { label: 'Entered', value: `${booking.scannedInCount ?? 0} / ${booking.maxPersons ?? 1}` },
          ]
        : [],
      members: Array.isArray(booking?.members)
        ? booking.members.map((m: any) => ({
            id: String(m.id),
            name: m.name,
            scanStatus: m.scanStatus ?? 'NotScanned',
          }))
        : undefined,
    };
  };

  const verifyStudent = async (code: string): Promise<UnifiedResult> => {
    const res = await fetchWithAuth(`${API_BASE}/fees/scan-pass`, {
      method: 'POST',
      body: JSON.stringify({ passCode: code }),
    });
    const data = await res.json();
    const pass = data?.data;
    const ok = res.ok && Boolean(data?.success);

    return {
      success: ok,
      kind: 'student',
      code,
      title: ok ? 'Student Verified' : 'Access Denied',
      message: data?.message || (ok ? 'Attendance marked' : 'Invalid student gate pass'),
      subject: pass?.student?.name || 'Student Pass',
      details: pass
        ? [
            { label: 'Student', value: pass.student?.name ?? '—' },
            ...(pass.student?.phone ? [{ label: 'Phone', value: pass.student.phone }] : []),
            { label: 'Sport', value: pass.sportName ?? '—' },
            { label: 'Batch', value: pass.batchName ?? '—' },
            ...(pass.startTime
              ? [{
                  label: 'Batch Time',
                  value: pass.endTime
                    ? `${fmtTime(pass.startTime)} – ${fmtTime(pass.endTime)}`
                    : fmtTime(pass.startTime) ?? '—',
                }]
              : []),
            { label: 'Attendance', value: String(pass.attendanceState ?? '—') },
          ]
        : [],
    };
  };

  // ── Scan handling ───────────────────────────────────────────────────────────

  const submit = useCallback(
    async (code: string) => {
      clearResumeTimer();
      busyRef.current = true;
      setBusy(true);
      setResult(null);

      const kind = mode === 'auto' ? detectPassKind(code) : mode;

      // Unrecognised code, or the guard pinned a type that does not match.
      if (!kind || (mode !== 'auto' && detectPassKind(code) !== mode)) {
        const failure: UnifiedResult = {
          success: false,
          kind: null,
          code,
          title: 'Not Recognised',
          message:
            mode === 'auto'
              ? 'This QR code does not belong to any Nahata Sports pass.'
              : `This is not a ${getPassKindMeta(mode as PassKind).label}. Switch to Auto Detect or scan the correct pass.`,
          subject: code,
          details: [],
        };
        setResult(failure);
        playTone(false);
        buzz(false);
        toast.error(failure.message);
        busyRef.current = false;
        setBusy(false);
        return failure;
      }

      let outcome: UnifiedResult;
      try {
        if (kind === 'entry') outcome = await verifyEntry(code, direction);
        else if (kind === 'event') outcome = await verifyEvent(code, direction);
        else if (kind === 'court') outcome = await verifyCourt(code, direction);
        else outcome = await verifyStudent(code);
      } catch {
        outcome = {
          success: false,
          kind,
          code,
          title: 'Scan Failed',
          message: 'Unable to reach the server. Check the connection and try again.',
          subject: code,
          details: [],
        };
      }

      setResult(outcome);
      playTone(outcome.success);
      buzz(outcome.success);
      if (outcome.success) toast.success(`${outcome.title} — ${outcome.subject}`);
      else toast.error(outcome.message);

      setLog((prev) => [
        {
          code,
          kind: outcome.kind,
          subject: outcome.subject,
          success: outcome.success,
          time: new Date().toLocaleTimeString('en-IN'),
        },
        ...prev.slice(0, 24),
      ]);

      busyRef.current = false;
      setBusy(false);
      return outcome;
    },
    [mode, direction, clearResumeTimer, playTone]
  );

  /**
   * Schedule the camera to resume after a result. The just-scanned code stays
   * blocked (see `lastSubmittedRef`) so holding the same QR in frame cannot
   * re-trigger it — only a different code, or "Scan Next", starts a new scan.
   */
  const scheduleResume = useCallback(
    (ok: boolean) => {
      clearResumeTimer();
      resumeTimerRef.current = window.setTimeout(
        () => {
          setResult(null);
          resumeTimerRef.current = null;
        },
        ok ? RESUME_DELAY_MS.success : RESUME_DELAY_MS.failure
      );
    },
    [clearResumeTimer]
  );

  const handleDetected = useCallback(
    (text: string) => {
      if (busyRef.current) return;
      const code = extractPassCode(text);
      if (!code) return;
      if (code === lastSubmittedRef.current && !allowRepeatRef.current) return;

      allowRepeatRef.current = false;
      lastSubmittedRef.current = code;

      void submit(code).then((outcome) => {
        if (continuous) scheduleResume(outcome.success);
      });
    },
    [submit, continuous, scheduleResume]
  );

  const handleManualVerify = () => {
    const code = extractPassCode(manualCode);
    if (!code) {
      toast.error('Enter a pass code first');
      return;
    }
    // Remember it so the camera does not immediately re-scan the same pass,
    // but do NOT unlock a repeat — typing the code again always works.
    lastSubmittedRef.current = code;
    void submit(code).then((outcome) => {
      setManualCode('');
      if (continuous) scheduleResume(outcome.success);
    });
  };

  const handleScanNext = () => {
    clearResumeTimer();
    setResult(null);
    // Let the guard re-scan the very same pass on purpose (e.g. IN then OUT).
    allowRepeatRef.current = true;
    setResetSignal((n) => n + 1);
  };

  const activeMeta = mode === 'auto' ? null : getPassKindMeta(mode);
  const directionApplies = mode === 'auto' || activeMeta?.directional;
  const paused = busy || result !== null;

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Camera Scanner" />}
    >
      <div className="max-w-[1400px] mx-auto pb-10">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-text-dark">Camera Scanner</h1>
          <p className="text-text-muted text-sm mt-1">
            Point the device camera at a QR code — visitor, event, court and student passes are
            detected and verified automatically.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* ── Left: camera + controls ── */}
          <div className="lg:col-span-2 space-y-5">
            {/* Pass type */}
            <div className="bg-white rounded-2xl border border-border p-5">
              <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">
                Pass Type
              </p>
              <div className="flex flex-wrap gap-2">
                <button
                  onClick={() => setMode('auto')}
                  className={`inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold transition-all ${
                    mode === 'auto'
                      ? 'bg-brand-primary text-white shadow-lg shadow-brand-primary/20'
                      : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                  }`}
                >
                  <Sparkles size={14} /> Auto Detect
                </button>
                {PASS_KINDS.map((meta) => {
                  const Icon = KIND_ICON[meta.kind];
                  const active = mode === meta.kind;
                  return (
                    <button
                      key={meta.kind}
                      onClick={() => setMode(meta.kind)}
                      className={`inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold transition-all ${
                        active
                          ? 'bg-brand-primary text-white shadow-lg shadow-brand-primary/20'
                          : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                      }`}
                    >
                      <Icon size={14} /> {meta.label}
                    </button>
                  );
                })}
              </div>
              <p className="text-[10px] text-slate-400 mt-3">
                {mode === 'auto'
                  ? 'Auto Detect reads the pass prefix (VP-, EVTPASS-, BOOK-, GATEPASS-) and picks the right check.'
                  : `Only ${activeMeta?.label} codes are accepted — e.g. ${activeMeta?.example}`}
              </p>
            </div>

            {/* Direction */}
            <div className="bg-white rounded-2xl border border-border p-5">
              <div className="flex items-center justify-between mb-3">
                <p className="text-[10px] font-black text-text-muted uppercase tracking-widest">
                  Scan Direction
                </p>
                {!directionApplies && (
                  <span className="text-[10px] text-slate-400">
                    Not used for {activeMeta?.label}
                  </span>
                )}
              </div>
              <div className="grid grid-cols-2 gap-3">
                <button
                  onClick={() => setDirection('In')}
                  disabled={!directionApplies}
                  className={`flex items-center justify-center gap-2 py-3.5 rounded-xl font-black text-sm uppercase tracking-wider transition-all disabled:opacity-40 ${
                    direction === 'In'
                      ? 'bg-emerald-500 text-white shadow-lg shadow-emerald-500/20'
                      : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                  }`}
                >
                  <LogIn size={18} /> Scan IN
                </button>
                <button
                  onClick={() => setDirection('Out')}
                  disabled={!directionApplies}
                  className={`flex items-center justify-center gap-2 py-3.5 rounded-xl font-black text-sm uppercase tracking-wider transition-all disabled:opacity-40 ${
                    direction === 'Out'
                      ? 'bg-blue-500 text-white shadow-lg shadow-blue-500/20'
                      : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                  }`}
                >
                  <LogOut size={18} /> Scan OUT
                </button>
              </div>
              <p className="text-[10px] text-slate-400 mt-3">
                Direction applies to visitor, event and court passes. A visitor pass is closed by
                the OUT scan — after that its QR code stops working. Student passes are simple
                verifications.
              </p>
            </div>

            {/* Camera */}
            <QrCameraScanner
              onDetected={handleDetected}
              paused={paused}
              resetSignal={resetSignal}
              dedupeMs={3000}
            />

            {/* Scanner options */}
            <div className="bg-white rounded-2xl border border-border p-5 flex flex-wrap items-center gap-3">
              <button
                onClick={() => setContinuous((v) => !v)}
                className={`inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all ${
                  continuous ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'
                }`}
              >
                <Repeat size={14} /> Continuous {continuous ? 'On' : 'Off'}
              </button>
              <button
                onClick={() => setSound((v) => !v)}
                className={`inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all ${
                  sound ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-500'
                }`}
              >
                {sound ? <Volume2 size={14} /> : <VolumeX size={14} />} Beep {sound ? 'On' : 'Off'}
              </button>
              <span className="text-[10px] text-slate-400 flex items-center gap-1.5">
                <Info size={12} />
                {continuous
                  ? 'The camera resumes automatically after each result.'
                  : 'Press "Scan Next" after each result to resume.'}
              </span>
            </div>

            {/* Manual fallback */}
            <div className="bg-white rounded-2xl border border-border p-5">
              <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">
                Camera unavailable? Type the code
              </p>
              <div className="flex gap-3">
                <div className="relative flex-1">
                  <ScanLine className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input
                    type="text"
                    value={manualCode}
                    onChange={(e) => setManualCode(e.target.value)}
                    onKeyDown={(e) => { if (e.key === 'Enter') handleManualVerify(); }}
                    placeholder="e.g. VP-20260731-A3F9 / BOOK-2026-000042-M01"
                    className="w-full pl-12 pr-4 py-3.5 bg-slate-50 border border-slate-200 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
                  />
                </div>
                <button
                  onClick={handleManualVerify}
                  disabled={busy || !manualCode.trim()}
                  className="px-6 py-3.5 rounded-xl bg-brand-primary text-white font-black text-sm uppercase tracking-wider hover:bg-brand-primary/90 disabled:opacity-50 transition-all inline-flex items-center gap-2"
                >
                  {busy ? <Loader2 size={16} className="animate-spin" /> : <Search size={16} />}
                  {busy ? 'Checking' : 'Verify'}
                </button>
              </div>
            </div>
          </div>

          {/* ── Right: result + session log ── */}
          <div className="space-y-5">
            <AnimatePresence mode="wait">
              {busy && !result && (
                <motion.div
                  key="busy"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="bg-white rounded-2xl border border-border p-8 flex flex-col items-center gap-3"
                >
                  <Loader2 size={28} className="animate-spin text-brand-primary" />
                  <p className="text-sm font-semibold text-text-dark">Verifying pass…</p>
                </motion.div>
              )}

              {result && (
                <motion.div
                  key={`${result.code}-${result.success}`}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -12 }}
                  className={`rounded-2xl border-2 overflow-hidden ${
                    result.success ? 'border-emerald-300 bg-emerald-50' : 'border-red-300 bg-red-50'
                  }`}
                >
                  <div
                    className={`px-5 py-4 flex items-center gap-3 ${
                      result.success ? 'bg-emerald-500' : 'bg-red-500'
                    } text-white`}
                  >
                    <div className="w-11 h-11 bg-white/20 rounded-xl flex items-center justify-center shrink-0">
                      {result.success ? <CheckCircle2 size={26} /> : <XCircle size={26} />}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="font-black text-lg leading-tight">{result.title}</p>
                      <p className="text-white/85 text-xs truncate">{result.message}</p>
                    </div>
                  </div>

                  <div className="p-5 space-y-3">
                    <div className="flex items-center gap-2">
                      <span
                        className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider ${
                          result.kind ? KIND_ACCENT[result.kind] : 'bg-slate-100 text-slate-600'
                        }`}
                      >
                        {React.createElement(result.kind ? KIND_ICON[result.kind] : QrCode, { size: 12 })}
                        {result.kind ? getPassKindMeta(result.kind).label : 'Unknown QR Code'}
                      </span>
                    </div>

                    <p className="text-lg font-black text-text-dark leading-tight">{result.subject}</p>
                    <p className="font-mono text-[11px] text-slate-500 break-all">{result.code}</p>

                    {result.details.length > 0 && (
                      <div className="grid grid-cols-2 gap-3 pt-2 border-t border-black/5">
                        {result.details.map((d) => (
                          <div key={d.label} className="min-w-0">
                            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                              {d.label}
                            </p>
                            <p className="text-sm font-bold text-text-dark capitalize break-words">
                              {d.value}
                            </p>
                          </div>
                        ))}
                      </div>
                    )}

                    {result.members && result.members.length > 0 && (
                      <div className="pt-2 border-t border-black/5">
                        <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">
                          Allowed Members
                        </p>
                        <div className="space-y-1.5 max-h-44 overflow-y-auto">
                          {result.members.map((m) => (
                            <div
                              key={m.id}
                              className="flex items-center gap-2 px-3 py-2 rounded-xl bg-white/70 border border-black/5"
                            >
                              <span className="text-xs font-bold text-text-dark truncate flex-1">
                                {m.name}
                              </span>
                              <span
                                className={`text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 ${
                                  m.scanStatus === 'In'
                                    ? 'bg-emerald-100 text-emerald-700'
                                    : m.scanStatus === 'Out'
                                      ? 'bg-blue-100 text-blue-700'
                                      : 'bg-slate-100 text-slate-500'
                                }`}
                              >
                                {m.scanStatus === 'In' ? 'IN' : m.scanStatus === 'Out' ? 'OUT' : 'Not Scanned'}
                              </span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    <button
                      onClick={handleScanNext}
                      className="w-full inline-flex items-center justify-center gap-2 py-3 rounded-xl bg-white border border-border text-sm font-bold text-slate-600 hover:border-brand-primary hover:text-brand-primary transition-all"
                    >
                      <RotateCcw size={15} /> Scan Next
                    </button>
                  </div>
                </motion.div>
              )}

              {!busy && !result && (
                <motion.div
                  key="idle"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="bg-slate-50 rounded-2xl border border-border p-8 text-center text-slate-400"
                >
                  <QrCode size={34} className="mx-auto mb-2 opacity-40" />
                  <p className="text-sm font-medium">
                    Waiting for a QR code — hold the pass inside the camera frame.
                  </p>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Session log */}
            <div className="bg-white rounded-2xl border border-border p-5">
              <div className="flex items-center justify-between mb-3">
                <p className="text-[10px] font-black text-text-muted uppercase tracking-widest">
                  Scans (this session)
                </p>
                {log.length > 0 && (
                  <button
                    onClick={() => setLog([])}
                    className="text-[10px] font-bold text-slate-400 hover:text-red-500 transition-colors"
                  >
                    Clear
                  </button>
                )}
              </div>

              {log.length === 0 ? (
                <p className="text-xs text-slate-400">No scans yet.</p>
              ) : (
                <div className="space-y-2 max-h-80 overflow-y-auto">
                  {log.map((entry, i) => {
                    const Icon = entry.kind ? KIND_ICON[entry.kind] : QrCode;
                    return (
                      <div
                        key={`${entry.code}-${i}`}
                        className={`flex items-center gap-2.5 px-3 py-2 rounded-xl border text-xs ${
                          entry.success
                            ? 'bg-emerald-50 border-emerald-100'
                            : 'bg-red-50 border-red-100'
                        }`}
                      >
                        <span
                          className={`w-6 h-6 rounded-lg flex items-center justify-center shrink-0 text-white ${
                            entry.success ? 'bg-emerald-500' : 'bg-red-500'
                          }`}
                        >
                          <Icon size={12} />
                        </span>
                        <span className="font-bold text-text-dark flex-1 truncate">{entry.subject}</span>
                        <span className="text-slate-400 shrink-0">{entry.time}</span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </UnifiedDashboardLayout>
  );
}
