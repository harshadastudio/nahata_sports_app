import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ScanLine,
  CheckCircle2,
  XCircle,
  RotateCcw,
  Loader2,
  Trophy,
  Calendar,
  Clock,
  User as UserIcon,
  Phone,
  Droplets,
  GraduationCap,
  UserCheck,
  Repeat,
  Volume2,
  VolumeX,
  Info,
  Keyboard,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../components/dashboard/DashboardNavbar';
import { QrCameraScanner } from '../../../components/scanner/QrCameraScanner';
import { extractPassCode, detectPassKind, getPassKindMeta } from '../../../components/scanner/passCodes';
import { fetchWithAuth } from '../../../lib/fetchWithAuth';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

/** How long a result stays on screen before the camera resumes automatically. */
const RESUME_DELAY_MS = { success: 2600, failure: 4200 };

interface ScanPass {
  passCode: string;
  attendanceState: 'marked' | 'updated' | 'already' | 'verified';
  date: string;
  checkInTime: string | null;
  student: { name: string; phone: string; bloodGroup: string; dob: string; avatar: string | null };
  batchName: string;
  sportName: string;
  sportImage: string | null;
  coachName: string;
  batchDays: string;
  startTime: string;
  endTime: string;
}

interface ScanResult {
  success: boolean;
  message: string;
  data?: ScanPass;
}

function fmtTime(t?: string) {
  if (!t) return null;
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  const hour = h % 12 || 12;
  return `${hour}:${String(m).padStart(2, '0')} ${ampm}`;
}

function fmtDate(d?: string) {
  if (!d) return '—';
  const dt = new Date(d + 'T00:00:00');
  return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

/**
 * StudentPassScanner (SECURITY + COACH) — scan a student's gate pass
 * (GATEPASS-…) at the gate. Verifies the enrollment and marks the student
 * Present in today's attendance.
 *
 * The camera is the primary input: the phone/tablet/webcam reads the QR in
 * front of the coach and submits it automatically. A typed / hardware-gun code
 * remains available as a fallback when no camera is usable.
 */
export default function StudentPassScanner() {
  const [manualCode, setManualCode] = useState('');
  const [isVerifying, setIsVerifying] = useState(false);
  const [result, setResult] = useState<ScanResult | null>(null);
  const [continuous, setContinuous] = useState(true);
  const [sound, setSound] = useState(true);
  const [resetSignal, setResetSignal] = useState(0);
  const [recentScans, setRecentScans] = useState<
    Array<{ passCode: string; name: string; time: string; success: boolean; state?: string }>
  >([]);
  const inputRef = useRef<HTMLInputElement>(null);

  const busyRef = useRef(false);
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

  // ── Scanning ────────────────────────────────────────────────────────────────

  const reset = useCallback(() => {
    clearResumeTimer();
    setResult(null);
    setManualCode('');
    // Let the camera forget the last code so the same pass can be re-scanned.
    setResetSignal((n) => n + 1);
    // Keep the barcode gun armed without scrolling the page to the input.
    inputRef.current?.focus({ preventScroll: true });
  }, [clearResumeTimer]);

  const finish = useCallback((ok: boolean) => {
    playTone(ok);
    buzz(ok);
    if (continuous) {
      clearResumeTimer();
      resumeTimerRef.current = window.setTimeout(() => {
        setResult(null);
        setResetSignal((n) => n + 1);
      }, ok ? RESUME_DELAY_MS.success : RESUME_DELAY_MS.failure);
    }
  }, [continuous, playTone, clearResumeTimer]);

  const handleScan = useCallback(async (raw: string, source: 'camera' | 'manual' = 'manual') => {
    const code = extractPassCode(raw);
    if (!code || busyRef.current) return;

    clearResumeTimer();
    busyRef.current = true;
    setIsVerifying(true);
    setResult(null);

    // A court/visitor/event QR held up at the coaching gate is rejected here
    // instead of being posted to the attendance endpoint.
    const kind = detectPassKind(code);
    if (kind && kind !== 'student') {
      const meta = getPassKindMeta(kind);
      setResult({
        success: false,
        message: `That is a ${meta.label} (${code}). Scan a student gate pass — it starts with GATEPASS-.`,
      });
      toast.error(`Not a student pass — ${meta.label}`);
      busyRef.current = false;
      setIsVerifying(false);
      finish(false);
      return;
    }

    try {
      const res = await fetchWithAuth(`${API_BASE}/fees/scan-pass`, {
        method: 'POST',
        body: JSON.stringify({ passCode: code }),
      });
      const json: ScanResult = await res.json();
      setResult(json);

      if (json.success) {
        const state = json.data?.attendanceState;
        toast.success(
          state === 'verified' ? 'Pass verified' : state === 'already' ? 'Already marked Present' : 'Marked Present'
        );
      } else {
        toast.error(json.message || 'Invalid pass');
      }

      setRecentScans((prev) => [
        {
          passCode: json.data?.passCode || code,
          name: json.data?.student?.name || code,
          time: new Date().toLocaleTimeString('en-IN'),
          success: json.success,
          state: json.data?.attendanceState,
        },
        ...prev.slice(0, 19),
      ]);
      finish(Boolean(json.success));
    } catch {
      setResult({ success: false, message: 'Network error. Please check your connection.' });
      toast.error('Scan failed');
      finish(false);
    } finally {
      busyRef.current = false;
      setIsVerifying(false);
      setManualCode('');
      // Only chase focus for the typed / barcode-gun flow — refocusing during a
      // camera scan would scroll the result card out of view.
      if (source === 'manual') setTimeout(() => inputRef.current?.focus({ preventScroll: true }), 100);
    }
  }, [clearResumeTimer, finish]);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') void handleScan(manualCode);
  };

  const pass = result?.data;
  const alreadyPresent = pass?.attendanceState === 'already';
  const verifiedOnly = pass?.attendanceState === 'verified';
  // Keep the preview alive but stop decoding while a result is on screen.
  const paused = isVerifying || result !== null;

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Student Pass Scanner" />}
    >
      <div className="max-w-[900px] mx-auto pb-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-text-dark">Student Pass Scanner</h1>
          <p className="text-text-muted text-sm mt-1">
            Point the camera at a student's gate pass (GATEPASS-…) — it is read and submitted
            automatically. Coaches marking a scan also mark the student{' '}
            <span className="font-bold">Present</span> in today's attendance; everyone else just
            verifies the pass and sees the student's name.
          </p>
        </div>

        <div className="space-y-5">
          {/* Live camera */}
          <QrCameraScanner
            onDetected={(text) => void handleScan(text, 'camera')}
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
                ? 'The camera resumes automatically after each result — keep scanning the queue.'
                : 'Press "Scan Next" after each result to resume.'}
            </span>
          </div>

          {/* Scan result */}
          <AnimatePresence mode="wait">
            {isVerifying && !result && (
              <motion.div
                key="verifying"
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                className="rounded-2xl border-2 border-slate-200 bg-white px-6 py-5 flex items-center gap-3"
              >
                <Loader2 size={20} className="animate-spin text-brand-primary" />
                <p className="text-sm font-bold text-text-dark">Verifying pass…</p>
              </motion.div>
            )}

            {result && (
              <motion.div
                key={result.success ? 'success' : 'fail'}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                className={`rounded-2xl border-2 overflow-hidden ${
                  result.success ? 'border-emerald-200 bg-emerald-50' : 'border-red-200 bg-red-50'
                }`}
              >
                <div
                  className={`px-6 py-4 flex items-center gap-4 ${
                    result.success
                      ? alreadyPresent
                        ? 'bg-amber-500 text-white'
                        : verifiedOnly
                          ? 'bg-blue-500 text-white'
                          : 'bg-emerald-500 text-white'
                      : 'bg-red-500 text-white'
                  }`}
                >
                  <div className="w-12 h-12 bg-white/20 rounded-xl flex items-center justify-center shrink-0">
                    {result.success ? <CheckCircle2 size={28} /> : <XCircle size={28} />}
                  </div>
                  <div className="flex-1">
                    <p className="font-black text-lg">
                      {result.success
                        ? alreadyPresent
                          ? '✓ Already Present'
                          : verifiedOnly
                            ? '✓ Pass Verified'
                            : '✓ Present Marked'
                        : '✗ Invalid Pass'}
                    </p>
                    <p className="text-white/80 text-sm">{result.message}</p>
                  </div>
                  <button
                    onClick={reset}
                    className="px-3 py-2 bg-white/20 hover:bg-white/30 rounded-xl transition-all inline-flex items-center gap-2 text-xs font-bold shrink-0"
                    title="Scan next"
                  >
                    <RotateCcw size={16} /> Scan Next
                  </button>
                </div>

                {result.success && pass && (
                  <div className="p-5">
                    <div className="flex items-center gap-4 mb-4">
                      <div className="w-16 h-16 rounded-2xl bg-white border border-slate-200 overflow-hidden flex items-center justify-center shrink-0">
                        {pass.student.avatar ? (
                          <img src={pass.student.avatar} alt={pass.student.name} className="w-full h-full object-cover" />
                        ) : (
                          <UserIcon size={28} className="text-slate-300" />
                        )}
                      </div>
                      <div className="min-w-0">
                        <p className="text-lg font-black text-text-dark truncate">{pass.student.name}</p>
                        <p className="text-xs text-slate-500 font-mono">{pass.passCode}</p>
                      </div>
                      <div className="ml-auto text-right shrink-0">
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                          {verifiedOnly ? 'Attendance' : 'Check-In'}
                        </p>
                        <p className={`text-sm font-black ${verifiedOnly ? 'text-blue-600' : 'text-emerald-600'}`}>
                          {verifiedOnly ? 'Not marked' : fmtTime(pass.checkInTime) ?? '—'}
                        </p>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <PassDetail icon={<GraduationCap size={14} />} label="Batch" value={pass.batchName || '—'} />
                      <PassDetail icon={<Trophy size={14} />} label="Sport" value={pass.sportName || '—'} />
                      <PassDetail icon={<UserCheck size={14} />} label="Coach" value={pass.coachName || '—'} />
                      <PassDetail icon={<Calendar size={14} />} label="Date" value={fmtDate(pass.date)} />
                      {(pass.startTime || pass.endTime) && (
                        <PassDetail
                          icon={<Clock size={14} />}
                          label="Timing"
                          value={
                            pass.endTime
                              ? `${fmtTime(pass.startTime)} – ${fmtTime(pass.endTime)}`
                              : fmtTime(pass.startTime) ?? '—'
                          }
                        />
                      )}
                      <PassDetail icon={<Phone size={14} />} label="Phone" value={pass.student.phone || '—'} />
                      <PassDetail icon={<Droplets size={14} />} label="Blood Group" value={pass.student.bloodGroup || '—'} />
                    </div>
                  </div>
                )}
              </motion.div>
            )}
          </AnimatePresence>

          {/* Manual fallback */}
          <div className="bg-white rounded-2xl border border-border p-5">
            <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3 flex items-center gap-2">
              <Keyboard size={13} /> Camera unavailable? Type the code
            </p>
            <div className="flex gap-3">
              <div className="relative flex-1">
                <ScanLine className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input
                  ref={inputRef}
                  type="text"
                  value={manualCode}
                  onChange={(e) => setManualCode(e.target.value)}
                  onKeyDown={handleKeyDown}
                  placeholder="Scan QR or type pass code (e.g. GATEPASS-2026-000042)"
                  className="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-200 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
                />
              </div>
              <button
                onClick={() => void handleScan(manualCode)}
                disabled={isVerifying || !manualCode.trim()}
                className="px-6 py-4 rounded-xl font-black text-sm uppercase tracking-wider transition-all flex items-center gap-2 disabled:opacity-50 bg-emerald-500 hover:bg-emerald-600 text-white shadow-lg shadow-emerald-500/20"
              >
                {isVerifying ? <Loader2 size={18} className="animate-spin" /> : <UserCheck size={18} />}
                {isVerifying ? 'Verifying...' : 'Verify & Mark'}
              </button>
            </div>
            <p className="text-[10px] text-slate-400 mt-2 ml-1">
              Tip: A USB/Bluetooth QR scanner just types the code and auto-submits on Enter.
            </p>
          </div>

          {/* Recent scans log */}
          {recentScans.length > 0 && (
            <div className="bg-white rounded-2xl border border-border p-5">
              <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">
                Recent Scans (this session)
              </p>
              <div className="space-y-2 max-h-64 overflow-y-auto">
                {recentScans.map((scan, i) => (
                  <div
                    key={i}
                    className={`flex items-center gap-3 px-3 py-2 rounded-xl text-xs ${
                      scan.success
                        ? scan.state === 'already'
                          ? 'bg-amber-50 border border-amber-100'
                          : scan.state === 'verified'
                            ? 'bg-blue-50 border border-blue-100'
                            : 'bg-emerald-50 border border-emerald-100'
                        : 'bg-red-50 border border-red-100'
                    }`}
                  >
                    <div
                      className={`w-6 h-6 rounded-lg flex items-center justify-center shrink-0 text-white ${
                        scan.success
                          ? scan.state === 'already'
                            ? 'bg-amber-500'
                            : scan.state === 'verified'
                              ? 'bg-blue-500'
                              : 'bg-emerald-500'
                          : 'bg-red-500'
                      }`}
                    >
                      {scan.success ? <CheckCircle2 size={12} /> : <XCircle size={12} />}
                    </div>
                    <span className="font-bold text-text-dark flex-1 truncate">{scan.name}</span>
                    <span className="font-mono text-slate-400 text-[10px] truncate max-w-[140px]">{scan.passCode}</span>
                    <span className="text-slate-400 shrink-0">{scan.time}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </UnifiedDashboardLayout>
  );
}

const PassDetail: React.FC<{ icon: React.ReactNode; label: string; value: string }> = ({ icon, label, value }) => (
  <div className="flex items-start gap-2">
    <span className="text-slate-400 mt-0.5 shrink-0">{icon}</span>
    <div className="min-w-0">
      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">{label}</p>
      <p className="text-sm font-bold text-text-dark truncate">{value}</p>
    </div>
  </div>
);
