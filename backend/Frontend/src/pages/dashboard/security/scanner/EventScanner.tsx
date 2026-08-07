import React, { useState, useRef } from 'react';
import {
  ScanLine,
  CheckCircle,
  XCircle,
  QrCode,
  RefreshCw,
  Search,
  Loader2,
  LogIn,
  LogOut,
  CalendarDays,
  Users,
  Clock,
  AlertCircle,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types ─────────────────────────────────────────────────────────────────────

type ScanType = 'In' | 'Out';
type ScanResult = 'granted' | 'denied' | null;

interface EventIndividualPass {
  id: number;
  passCode: string;
  maxPersons: number;
  scannedInCount: number;
  scannedOutCount: number;
  scanStatus?: string;
  event?: { id: number; title: string };
  slot?: {
    id: number;
    name?: string;
    date?: string;
    passType?: string;
    startTime?: string;
    endTime?: string;
  };
}

interface ScanResponse {
  success: boolean;
  message?: string;
  data?: EventIndividualPass;
  pass?: EventIndividualPass;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const formatDate = (dateStr?: string) => {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
};

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * EventScanner — IN/OUT scanner for EVENT passes (SECURITY role).
 *
 * The guard picks a direction (IN or OUT), enters/scans an event pass code, and
 * the scan is recorded against them so the Security Dashboard can show how many
 * event passes they scanned. Shows clear Access Granted / Denied notifications.
 */
export default function EventScanner() {
  useAuth();

  const [passCode, setPassCode] = useState('');
  const [scanType, setScanType] = useState<ScanType>('In');
  const [loading, setLoading] = useState(false);
  const [scanResult, setScanResult] = useState<ScanResult>(null);
  const [pass, setPass] = useState<EventIndividualPass | null>(null);
  const [resultMessage, setResultMessage] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  const handleScan = async (code = passCode) => {
    const trimmed = code.trim();
    if (!trimmed) {
      toast.error('Please enter an event pass code');
      return;
    }

    setLoading(true);
    setScanResult(null);
    setPass(null);
    setResultMessage('');

    try {
      const res = await fetchWithAuth(`${API_BASE}/event-passes/scan`, {
        method: 'POST',
        body: JSON.stringify({ passCode: trimmed, scanType }),
      });
      const data: ScanResponse = await res.json();
      const scanned = data.data ?? data.pass ?? null;

      if (res.ok && data.success) {
        setScanResult('granted');
        setPass(scanned);
        setResultMessage(data.message || 'Scan successful');
        toast.success(`${scanType === 'In' ? 'Entry' : 'Exit'} recorded`);
      } else {
        setScanResult('denied');
        setPass(scanned);
        setResultMessage(data.message || 'Invalid or expired event pass');
        toast.error(data.message || 'Scan denied');
      }
    } catch (err) {
      setScanResult('denied');
      setResultMessage('Unable to connect to server. Please try again.');
      toast.error('Scan failed');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setPassCode('');
    setScanResult(null);
    setPass(null);
    setResultMessage('');
    setTimeout(() => inputRef.current?.focus(), 50);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') handleScan();
  };

  const inside = pass ? pass.scannedInCount - pass.scannedOutCount : 0;
  const remaining = pass ? pass.maxPersons - pass.scannedInCount : 0;

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Event Scanner" />}
    >
      <div className="max-w-2xl mx-auto space-y-6">

        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-text-dark">Event Pass Scanner</h1>
          <p className="text-text-muted text-sm mt-1">
            Scan event passes for entry (IN) and exit (OUT)
          </p>
        </div>

        {/* Scanner Card */}
        <div className="bg-white rounded-2xl border border-border p-8 shadow-sm">
          {/* IN / OUT toggle */}
          <div className="flex items-center justify-center gap-2 mb-6">
            <button
              onClick={() => setScanType('In')}
              className={`flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-bold transition-all ${
                scanType === 'In'
                  ? 'bg-green-600 text-white shadow'
                  : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
              }`}
            >
              <LogIn size={16} /> Scan IN
            </button>
            <button
              onClick={() => setScanType('Out')}
              className={`flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-bold transition-all ${
                scanType === 'Out'
                  ? 'bg-orange-600 text-white shadow'
                  : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
              }`}
            >
              <LogOut size={16} /> Scan OUT
            </button>
          </div>

          {/* QR Icon */}
          <div className="flex flex-col items-center mb-8">
            <div className="w-24 h-24 bg-slate-50 rounded-2xl flex items-center justify-center border-2 border-dashed border-slate-200 mb-4">
              <QrCode size={40} className="text-slate-400" />
            </div>
            <p className="text-sm text-text-muted text-center">
              Scan the event QR code or enter the pass code manually below
            </p>
          </div>

          {/* Input */}
          <div className="space-y-3">
            <label className="block text-sm font-semibold text-text-dark">
              Event Pass Code
            </label>
            <div className="flex gap-3">
              <div className="relative flex-1">
                <ScanLine
                  size={18}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
                />
                <input
                  ref={inputRef}
                  type="text"
                  value={passCode}
                  onChange={(e) => setPassCode(e.target.value.toUpperCase())}
                  onKeyDown={handleKeyDown}
                  placeholder="e.g. EVTPASS-2026-000123"
                  autoFocus
                  className="w-full pl-10 pr-4 py-3 border border-border rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
                />
              </div>
              <button
                onClick={() => handleScan()}
                disabled={loading || !passCode.trim()}
                className="flex items-center gap-2 px-5 py-3 bg-brand-primary text-white rounded-xl text-sm font-semibold hover:bg-brand-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {loading ? <Loader2 size={16} className="animate-spin" /> : <Search size={16} />}
                {loading ? 'Scanning…' : `Scan ${scanType}`}
              </button>
            </div>
          </div>
        </div>

        {/* Result Card */}
        {scanResult === 'granted' && pass && (
          <div className="bg-white rounded-2xl border-2 border-green-400 shadow-sm overflow-hidden">
            <div className="bg-green-500 px-6 py-5 flex items-center gap-4">
              <CheckCircle size={36} className="text-white shrink-0" />
              <div>
                <h2 className="text-xl font-bold text-white">
                  {scanType === 'In' ? 'Entry Granted' : 'Exit Recorded'}
                </h2>
                <p className="text-green-100 text-sm">{resultMessage}</p>
              </div>
            </div>

            <div className="p-6 space-y-4">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400">
                Event Pass Details
              </h3>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="flex items-start gap-3">
                  <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                    <CalendarDays size={16} className="text-slate-500" />
                  </div>
                  <div>
                    <p className="text-xs text-text-muted">Event</p>
                    <p className="font-semibold text-text-dark">{pass.event?.title ?? '—'}</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                    <Clock size={16} className="text-slate-500" />
                  </div>
                  <div>
                    <p className="text-xs text-text-muted">Slot</p>
                    <p className="font-semibold text-text-dark">
                      {pass.slot?.name ?? pass.slot?.passType ?? '—'}
                      {pass.slot?.date ? ` · ${formatDate(pass.slot.date)}` : ''}
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                    <QrCode size={16} className="text-slate-500" />
                  </div>
                  <div>
                    <p className="text-xs text-text-muted">Pass Code</p>
                    <p className="font-mono font-semibold text-text-dark">{pass.passCode}</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                    <Users size={16} className="text-slate-500" />
                  </div>
                  <div>
                    <p className="text-xs text-text-muted">Entered</p>
                    <p className="font-semibold text-text-dark">
                      {pass.scannedInCount}/{pass.maxPersons}
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between pt-2 border-t border-border text-sm">
                <span className="text-text-muted">Currently inside</span>
                <span className="font-semibold text-text-dark">{inside}</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-text-muted">Remaining entries</span>
                <span className="font-semibold text-text-dark">{remaining}</span>
              </div>
            </div>
          </div>
        )}

        {scanResult === 'denied' && (
          <div className="bg-white rounded-2xl border-2 border-red-400 shadow-sm overflow-hidden">
            <div className="bg-red-500 px-6 py-5 flex items-center gap-4">
              <XCircle size={36} className="text-white shrink-0" />
              <div>
                <h2 className="text-xl font-bold text-white">Scan Denied</h2>
                <p className="text-red-100 text-sm">Event pass could not be accepted</p>
              </div>
            </div>
            <div className="p-6">
              <div className="flex items-start gap-3 bg-red-50 rounded-xl p-4">
                <AlertCircle size={18} className="text-red-500 shrink-0 mt-0.5" />
                <p className="text-sm text-red-700">{resultMessage}</p>
              </div>
            </div>
          </div>
        )}

        {/* Reset Button */}
        {scanResult !== null && (
          <button
            onClick={handleReset}
            className="w-full flex items-center justify-center gap-2 px-5 py-3 bg-white border border-border rounded-xl text-sm font-semibold text-slate-600 hover:bg-slate-50 hover:border-brand-primary hover:text-brand-primary transition-all"
          >
            <RefreshCw size={16} />
            Scan Another Pass
          </button>
        )}
      </div>
    </UnifiedDashboardLayout>
  );
}
