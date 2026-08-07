import React, { useState, useRef, useEffect } from 'react';
import {
  ScanLine,
  QrCode,
  CheckCircle2,
  XCircle,
  RotateCcw,
  LogIn,
  LogOut,
  Loader2,
  Trophy,
  Calendar,
  Clock,
  User,
  Users,
  MapPin,
  BarChart3,
  AlertCircle,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types ─────────────────────────────────────────────────────────────────────

interface ScanMember {
  id: string;
  name: string;
  phone: string;
  passCode?: string;
  scanStatus: 'NotScanned' | 'In' | 'Out';
  scannedInAt?: string;
  scannedOutAt?: string;
}

interface ScanBooking {
  id: string;
  passCode: string;
  maxPersons?: number;
  scannedInCount: number;
  scannedOutCount: number;
  scanStatus: 'NotScanned' | 'In' | 'Out';
  date?: string;
  startTime?: string;
  endTime?: string;
  court?: { id: string; name: string; SportComplex?: { name: string } };
  sport?: { id: string; name: string };
  members?: ScanMember[];
}

interface ScanResult {
  success: boolean;
  message: string;
  booking?: ScanBooking;
  data?: ScanBooking;
}

interface ScanStats {
  totalPasses: number;
  totalPersons: number;
  in: number;
  out: number;
  notScanned: number;
  currentlyInside: number;
}

interface CourtOption {
  id: string;
  name: string;
  complex?: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * CourtPassScanner (SECURITY role) — scan a member QR (or the booking QR) at the
 * gate to mark people IN or OUT for a court booking. Mirrors the admin scanner
 * but runs in the security dashboard layout with token-based auth + toasts.
 */
export default function CourtPassScanner() {
  const [scanType, setScanType] = useState<'In' | 'Out'>('In');
  const [manualCode, setManualCode] = useState('');
  const [isVerifying, setIsVerifying] = useState(false);
  const [result, setResult] = useState<ScanResult | null>(null);

  // Member-level scan state
  const [memberScanLoading, setMemberScanLoading] = useState<string | null>(null);
  const [memberScanResult, setMemberScanResult] = useState<{ memberId: string; success: boolean; message: string } | null>(null);

  // Stats — by court + date
  const [courts, setCourts] = useState<CourtOption[]>([]);
  const [selectedCourtId, setSelectedCourtId] = useState('');
  const [statsDate, setStatsDate] = useState(todayStr());
  const [stats, setStats] = useState<ScanStats | null>(null);
  const [isLoadingStats, setIsLoadingStats] = useState(false);

  // Recent scans log (this session)
  const [recentScans, setRecentScans] = useState<
    Array<{ passCode: string; name: string; type: 'In' | 'Out'; time: string; success: boolean }>
  >([]);

  const inputRef = useRef<HTMLInputElement>(null);

  // Load courts for the stats dropdown
  useEffect(() => {
    fetchWithAuth(`${API_BASE}/courts?status=Active&limit=100`)
      .then((r) => r.json())
      .then((json) => {
        const list = Array.isArray(json.data) ? json.data : [];
        setCourts(list.map((c: any) => ({ id: String(c.id), name: c.name, complex: c.SportComplex?.name })));
      })
      .catch(() => {});
  }, []);

  const loadStats = () => {
    if (!selectedCourtId) { setStats(null); return; }
    setIsLoadingStats(true);
    const qs = new URLSearchParams({ courtId: selectedCourtId, date: statsDate }).toString();
    fetchWithAuth(`${API_BASE}/courts/bookings/scan-stats?${qs}`)
      .then((r) => r.json())
      .then((json) => { if (json.success) setStats(json.data); })
      .catch(() => {})
      .finally(() => setIsLoadingStats(false));
  };

  useEffect(() => {
    loadStats();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedCourtId, statsDate]);

  const handleScan = async (code: string) => {
    const trimmed = code.trim();
    if (!trimmed) return;

    setIsVerifying(true);
    setResult(null);
    setMemberScanResult(null);

    try {
      const res = await fetchWithAuth(`${API_BASE}/courts/bookings/scan`, {
        method: 'POST',
        body: JSON.stringify({ passCode: trimmed, scanType }),
      });
      const json = await res.json();
      const normalized: ScanResult = { ...json, booking: json.booking || json.data };
      setResult(normalized);

      if (json.success) {
        toast.success(scanType === 'In' ? 'Entry recorded' : 'Exit recorded');
      } else {
        toast.error(json.message || 'Scan denied');
      }

      setRecentScans((prev) => [
        {
          passCode: trimmed,
          name: normalized.booking?.sport?.name
            ? `${normalized.booking.sport.name} — ${normalized.booking.court?.name ?? ''}`
            : trimmed,
          type: scanType,
          time: new Date().toLocaleTimeString('en-IN'),
          success: json.success,
        },
        ...prev.slice(0, 19),
      ]);

      if (json.success && selectedCourtId) loadStats();
    } catch {
      setResult({ success: false, message: 'Network error. Please check your connection.' });
      toast.error('Scan failed');
    } finally {
      setIsVerifying(false);
      setManualCode('');
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') handleScan(manualCode);
  };

  const reset = () => {
    setResult(null);
    setManualCode('');
    setMemberScanResult(null);
    inputRef.current?.focus();
  };

  const handleMemberScan = async (memberId: string, memberScanType: 'In' | 'Out') => {
    setMemberScanLoading(memberId);
    setMemberScanResult(null);
    try {
      const res = await fetchWithAuth(`${API_BASE}/courts/members/${memberId}/scan`, {
        method: 'POST',
        body: JSON.stringify({ scanType: memberScanType }),
      });
      const json = await res.json();
      setMemberScanResult({ memberId, success: json.success, message: json.message });
      if (json.success) {
        toast.success(`${memberScanType === 'In' ? 'Marked IN' : 'Marked OUT'}`);
      } else {
        toast.error(json.message || 'Member scan failed');
      }

      if (json.success && result?.booking?.members) {
        setResult((prev) => {
          if (!prev?.booking?.members) return prev;
          return {
            ...prev,
            booking: {
              ...prev.booking,
              members: prev.booking.members.map((m) =>
                m.id === memberId
                  ? { ...m, scanStatus: memberScanType, scannedInAt: memberScanType === 'In' ? new Date().toISOString() : m.scannedInAt, scannedOutAt: memberScanType === 'Out' ? new Date().toISOString() : m.scannedOutAt }
                  : m
              ),
              scannedInCount: memberScanType === 'In' ? prev.booking.scannedInCount + 1 : prev.booking.scannedInCount,
              scannedOutCount: memberScanType === 'Out' ? prev.booking.scannedOutCount + 1 : prev.booking.scannedOutCount,
            },
          };
        });
        if (selectedCourtId) loadStats();
      }
    } catch {
      setMemberScanResult({ memberId, success: false, message: 'Network error' });
      toast.error('Member scan failed');
    } finally {
      setMemberScanLoading(null);
    }
  };

  const booking = result?.booking;

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Court Pass Scanner" />}
    >
      <div className="max-w-[1400px] mx-auto pb-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-text-dark">Court Pass Scanner</h1>
          <p className="text-text-muted text-sm mt-1">
            Scan a member's QR (or the booking QR) at the gate to mark people IN or OUT. The booking time slot is validated automatically.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* ── Left: Scanner ── */}
          <div className="lg:col-span-2 space-y-5">

            {/* Scan type toggle */}
            <div className="bg-white rounded-2xl border border-border p-5">
              <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">Scan Mode</p>
              <div className="grid grid-cols-2 gap-3">
                <button
                  onClick={() => { setScanType('In'); reset(); }}
                  className={`flex items-center justify-center gap-2 py-4 rounded-xl font-black text-sm uppercase tracking-wider transition-all ${
                    scanType === 'In' ? 'bg-emerald-500 text-white shadow-lg shadow-emerald-500/20' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                  }`}
                >
                  <LogIn size={18} /> Scan IN (Entry)
                </button>
                <button
                  onClick={() => { setScanType('Out'); reset(); }}
                  className={`flex items-center justify-center gap-2 py-4 rounded-xl font-black text-sm uppercase tracking-wider transition-all ${
                    scanType === 'Out' ? 'bg-blue-500 text-white shadow-lg shadow-blue-500/20' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                  }`}
                >
                  <LogOut size={18} /> Scan OUT (Exit)
                </button>
              </div>
            </div>

            {/* Scanner input */}
            <div className="bg-white rounded-2xl border border-border p-5">
              <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">Scan or Enter Pass Code</p>
              <div className="flex gap-3">
                <div className="relative flex-1">
                  <ScanLine className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input
                    ref={inputRef}
                    type="text"
                    value={manualCode}
                    onChange={(e) => setManualCode(e.target.value)}
                    onKeyDown={handleKeyDown}
                    placeholder="Scan QR or type pass code (e.g. BOOK-2026-000042 or …-M01)"
                    autoFocus
                    className="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-200 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
                  />
                </div>
                <button
                  onClick={() => handleScan(manualCode)}
                  disabled={isVerifying || !manualCode.trim()}
                  className={`px-6 py-4 rounded-xl font-black text-sm uppercase tracking-wider transition-all flex items-center gap-2 disabled:opacity-50 ${
                    scanType === 'In' ? 'bg-emerald-500 hover:bg-emerald-600 text-white shadow-lg shadow-emerald-500/20' : 'bg-blue-500 hover:bg-blue-600 text-white shadow-lg shadow-blue-500/20'
                  }`}
                >
                  {isVerifying ? <Loader2 size={18} className="animate-spin" /> : scanType === 'In' ? <LogIn size={18} /> : <LogOut size={18} />}
                  {isVerifying ? 'Verifying...' : scanType === 'In' ? 'Mark IN' : 'Mark OUT'}
                </button>
              </div>
              <p className="text-[10px] text-slate-400 mt-2 ml-1">
                Tip: If using a QR scanner device, just scan — it auto-submits on Enter.
              </p>
            </div>

            {/* Scan result */}
            <AnimatePresence mode="wait">
              {result && (
                <motion.div
                  key={result.success ? 'success' : 'fail'}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -12 }}
                  className={`rounded-2xl border-2 overflow-hidden ${result.success ? 'border-emerald-200 bg-emerald-50' : 'border-red-200 bg-red-50'}`}
                >
                  <div className={`px-6 py-4 flex items-center gap-4 ${result.success ? 'bg-emerald-500 text-white' : 'bg-red-500 text-white'}`}>
                    <div className="w-12 h-12 bg-white/20 rounded-xl flex items-center justify-center shrink-0">
                      {result.success ? <CheckCircle2 size={28} /> : <XCircle size={28} />}
                    </div>
                    <div className="flex-1">
                      <p className="font-black text-lg">
                        {result.success ? (scanType === 'In' ? '✓ Entry Granted' : '✓ Exit Recorded') : '✗ Access Denied'}
                      </p>
                      <p className="text-white/80 text-sm">{result.message}</p>
                    </div>
                    <button onClick={reset} className="p-2 bg-white/20 hover:bg-white/30 rounded-xl transition-all" title="Scan next">
                      <RotateCcw size={18} />
                    </button>
                  </div>

                  {result.success && booking && (
                    <div className="p-5 space-y-4">
                      <div className="grid grid-cols-2 gap-3">
                        <PassDetail icon={<Trophy size={14} />} label="Sport" value={booking.sport?.name ?? '—'} />
                        <PassDetail icon={<MapPin size={14} />} label="Court" value={booking.court?.name ?? '—'} />
                        <PassDetail
                          icon={<Users size={14} />}
                          label="Entered"
                          value={`${booking.scannedInCount ?? 0} / ${booking.maxPersons ?? 1}`}
                        />
                        <PassDetail icon={<Calendar size={14} />} label="Date" value={fmtDate(booking.date)} />
                        {booking.startTime && (
                          <PassDetail
                            icon={<Clock size={14} />}
                            label="Time"
                            value={booking.endTime ? `${fmtTime(booking.startTime)} – ${fmtTime(booking.endTime)}` : fmtTime(booking.startTime) ?? '—'}
                          />
                        )}
                        <PassDetail icon={<ScanLine size={14} />} label="Pass Code" value={booking.passCode} mono />
                      </div>

                      {/* Member list */}
                      {booking.members && booking.members.length > 0 && (
                        <div>
                          <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Allowed Members</p>
                          {memberScanResult && (
                            <div className={`mb-2 px-3 py-2 rounded-xl text-xs font-bold ${memberScanResult.success ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-600'}`}>
                              {memberScanResult.message}
                            </div>
                          )}
                          <div className="space-y-2">
                            {booking.members.map((member) => {
                              const isLoading = memberScanLoading === member.id;
                              const isIn = member.scanStatus === 'In';
                              const isOut = member.scanStatus === 'Out';
                              return (
                                <div
                                  key={member.id}
                                  className={`flex items-center gap-3 p-3 rounded-xl border ${
                                    isIn ? 'bg-emerald-50 border-emerald-200' : isOut ? 'bg-blue-50 border-blue-200' : 'bg-slate-50 border-slate-200'
                                  }`}
                                >
                                  <div className="flex-1 min-w-0">
                                    <p className="text-xs font-bold text-text-dark truncate">{member.name}</p>
                                    <p className="text-[10px] text-slate-400">+{member.phone}</p>
                                  </div>
                                  <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 ${
                                    isIn ? 'bg-emerald-100 text-emerald-700' : isOut ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-500'
                                  }`}>
                                    {isIn ? 'IN' : isOut ? 'OUT' : 'Not Scanned'}
                                  </span>
                                  {!isIn && (
                                    <button
                                      onClick={() => handleMemberScan(member.id, 'In')}
                                      disabled={isLoading}
                                      className="p-1.5 bg-emerald-500 text-white rounded-lg hover:bg-emerald-600 transition-all disabled:opacity-50 shrink-0"
                                      title="Mark IN"
                                    >
                                      {isLoading ? <Loader2 size={12} className="animate-spin" /> : <LogIn size={12} />}
                                    </button>
                                  )}
                                  {isIn && (
                                    <button
                                      onClick={() => handleMemberScan(member.id, 'Out')}
                                      disabled={isLoading}
                                      className="p-1.5 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-all disabled:opacity-50 shrink-0"
                                      title="Mark OUT"
                                    >
                                      {isLoading ? <Loader2 size={12} className="animate-spin" /> : <LogOut size={12} />}
                                    </button>
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      )}

                      {(!booking.members || booking.members.length === 0) && (booking.maxPersons ?? 1) > 1 && (
                        <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 text-xs text-amber-700">
                          No members registered for this booking. Using counter-based entry ({booking.scannedInCount}/{booking.maxPersons} entered).
                        </div>
                      )}
                    </div>
                  )}
                </motion.div>
              )}
            </AnimatePresence>

            {/* Recent scans log */}
            {recentScans.length > 0 && (
              <div className="bg-white rounded-2xl border border-border p-5">
                <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">Recent Scans (this session)</p>
                <div className="space-y-2 max-h-64 overflow-y-auto">
                  {recentScans.map((scan, i) => (
                    <div
                      key={i}
                      className={`flex items-center gap-3 px-3 py-2 rounded-xl text-xs ${
                        scan.success ? (scan.type === 'In' ? 'bg-emerald-50 border border-emerald-100' : 'bg-blue-50 border border-blue-100') : 'bg-red-50 border border-red-100'
                      }`}
                    >
                      <div className={`w-6 h-6 rounded-lg flex items-center justify-center shrink-0 ${
                        scan.success ? (scan.type === 'In' ? 'bg-emerald-500 text-white' : 'bg-blue-500 text-white') : 'bg-red-500 text-white'
                      }`}>
                        {scan.success ? (scan.type === 'In' ? <LogIn size={12} /> : <LogOut size={12} />) : <XCircle size={12} />}
                      </div>
                      <span className="font-bold text-text-dark flex-1 truncate">{scan.name}</span>
                      <span className="font-mono text-slate-400 text-[10px] truncate max-w-[120px]">{scan.passCode}</span>
                      <span className="text-slate-400 shrink-0">{scan.time}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* ── Right: Stats ── */}
          <div className="space-y-5">
            <div className="bg-white rounded-2xl border border-border p-5 space-y-3">
              <p className="text-[10px] font-black text-text-muted uppercase tracking-widest">Live IN/OUT Stats</p>
              <select
                value={selectedCourtId}
                onChange={(e) => setSelectedCourtId(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
              >
                <option value="">— Select a Court —</option>
                {courts.map((c) => (
                  <option key={c.id} value={c.id}>{c.name}{c.complex ? ` · ${c.complex}` : ''}</option>
                ))}
              </select>
              <input
                type="date"
                value={statsDate}
                onChange={(e) => setStatsDate(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
              />
            </div>

            {selectedCourtId && (
              <>
                {isLoadingStats ? (
                  <div className="flex items-center justify-center py-12 text-slate-400">
                    <Loader2 size={24} className="animate-spin" />
                  </div>
                ) : stats ? (
                  <div className="space-y-3">
                    <StatCard label="Currently Inside" value={stats.currentlyInside} icon={<User size={20} />} color="bg-emerald-500" bg="bg-emerald-50" text="text-emerald-700" />
                    <div className="grid grid-cols-2 gap-3">
                      <StatCard label="Persons IN" value={stats.in} icon={<LogIn size={18} />} color="bg-green-500" bg="bg-green-50" text="text-green-700" small />
                      <StatCard label="Persons OUT" value={stats.out} icon={<LogOut size={18} />} color="bg-blue-500" bg="bg-blue-50" text="text-blue-700" small />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <StatCard label="Passes Unused" value={stats.notScanned} icon={<QrCode size={18} />} color="bg-slate-400" bg="bg-slate-50" text="text-slate-600" small />
                      <StatCard label="Total Persons" value={stats.totalPersons} icon={<Users size={18} />} color="bg-purple-500" bg="bg-purple-50" text="text-purple-700" small />
                    </div>

                    <div className="bg-white rounded-2xl border border-border p-4">
                      <div className="flex items-center justify-between mb-2">
                        <p className="text-[10px] font-black text-text-muted uppercase tracking-widest">Attendance Progress</p>
                        <p className="text-xs font-bold text-text-dark">{stats.totalPersons > 0 ? Math.round((stats.in / stats.totalPersons) * 100) : 0}%</p>
                      </div>
                      <div className="h-3 bg-slate-100 rounded-full overflow-hidden">
                        <div className="h-full bg-emerald-500 rounded-full transition-all duration-500" style={{ width: `${stats.totalPersons > 0 ? (stats.in / stats.totalPersons) * 100 : 0}%` }} />
                      </div>
                      <p className="text-[10px] text-slate-400 mt-1.5">{stats.in} of {stats.totalPersons} persons entered</p>
                    </div>

                    <button onClick={loadStats} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-slate-100 text-slate-600 text-xs font-bold hover:bg-slate-200 transition-all">
                      <RotateCcw size={14} /> Refresh Stats
                    </button>
                  </div>
                ) : (
                  <div className="flex items-center gap-3 bg-amber-50 border border-amber-200 text-amber-700 px-4 py-3 rounded-xl text-sm">
                    <AlertCircle size={16} /> Could not load stats.
                  </div>
                )}
              </>
            )}

            {!selectedCourtId && (
              <div className="bg-slate-50 rounded-2xl border border-border p-6 text-center text-slate-400">
                <BarChart3 size={32} className="mx-auto mb-2 opacity-40" />
                <p className="text-sm font-medium">Select a court + date above to see live IN/OUT counts</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </UnifiedDashboardLayout>
  );
}

const PassDetail: React.FC<{ icon: React.ReactNode; label: string; value: string; mono?: boolean }> = ({ icon, label, value, mono }) => (
  <div className="flex items-start gap-2">
    <span className="text-slate-400 mt-0.5 shrink-0">{icon}</span>
    <div className="min-w-0">
      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">{label}</p>
      <p className={`text-sm font-bold text-text-dark truncate ${mono ? 'font-mono text-xs' : ''}`}>{value}</p>
    </div>
  </div>
);

const StatCard: React.FC<{ label: string; value: number; icon: React.ReactNode; color: string; bg: string; text: string; small?: boolean }> = ({ label, value, icon, color, bg, text, small }) => (
  <div className={`${bg} rounded-2xl border border-border p-4`}>
    <div className={`w-8 h-8 ${color} rounded-xl flex items-center justify-center text-white mb-2`}>{icon}</div>
    <p className={`${small ? 'text-2xl' : 'text-4xl'} font-black ${text}`}>{value}</p>
    <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-0.5">{label}</p>
  </div>
);
