import React, { useState, useRef } from 'react';
import {
  ScanLine,
  CheckCircle,
  XCircle,
  QrCode,
  RefreshCw,
  Search,
  Loader2,
  User,
  Phone,
  Briefcase,
  AlertCircle,
  LogIn,
  LogOut,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import {
  type VisitorPass,
  VisitorPassStatusBadge,
  formatDateTime,
} from '../../../../components/security/visitorPass';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types ─────────────────────────────────────────────────────────────────────

type ScanResult = 'granted' | 'denied' | null;
type Direction = 'In' | 'Out';

interface VerifyResponse {
  success: boolean;
  message?: string;
  pass?: VisitorPass;
  data?: VisitorPass;
  valid?: boolean;
  direction?: Direction | null;
}

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * EntryScanner - QR code scanner UI for entry validation
 *
 * Allows security personnel to enter a pass code and record the visitor's
 * movement at the gate. The IN scan checks the visitor in; the OUT scan closes
 * the visit and permanently invalidates the QR code.
 *
 * Validates: Requirements 6.3, 8.3, 9.2, 13.1
 */
export default function EntryScanner() {
  useAuth();

  const [passCode, setPassCode] = useState('');
  const [direction, setDirection] = useState<Direction>('In');
  const [loading, setLoading] = useState(false);
  const [scanResult, setScanResult] = useState<ScanResult>(null);
  const [visitorPass, setVisitorPass] = useState<VisitorPass | null>(null);
  const [errorMessage, setErrorMessage] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  const handleVerify = async (code = passCode) => {
    const trimmed = code.trim();
    if (!trimmed) {
      toast.error('Please enter a pass code');
      return;
    }

    setLoading(true);
    setScanResult(null);
    setVisitorPass(null);
    setErrorMessage('');

    try {
      const res = await fetchWithAuth(`${API_BASE}/visitor-passes/verify`, {
        method: 'POST',
        body: JSON.stringify({ passCode: trimmed, scanType: direction }),
      });

      const data: VerifyResponse = await res.json();
      const pass = data.data ?? data.pass ?? null;

      if (res.ok && (data.success || data.valid)) {
        setScanResult('granted');
        setVisitorPass(pass);
        toast.success(
          `${direction === 'In' ? 'Checked In' : 'Checked Out'} — ${pass?.visitorName ?? trimmed}`
        );
      } else {
        setScanResult('denied');
        // A rejected scan still returns the pass, so the guard can see why.
        setVisitorPass(pass);
        const msg = data.message || 'Invalid or expired pass code';
        setErrorMessage(msg);
        toast.error(`Access Denied — ${msg}`);
      }
    } catch (err: any) {
      setScanResult('denied');
      setErrorMessage('Unable to connect to server. Please try again.');
      toast.error('Verification failed');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setPassCode('');
    setScanResult(null);
    setVisitorPass(null);
    setErrorMessage('');
    setTimeout(() => inputRef.current?.focus(), 50);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') handleVerify();
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Entry Scanner" />}
    >
      <div className="max-w-2xl mx-auto space-y-6">

        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-text-dark">Entry Scanner</h1>
          <p className="text-text-muted text-sm mt-1">
            Enter a visitor pass code to record check-in or check-out
          </p>
        </div>

        {/* Scanner Card */}
        <div className="bg-white rounded-2xl border border-border p-8 shadow-sm">
          {/* Direction */}
          <div className="mb-8">
            <p className="text-xs font-semibold uppercase tracking-wider text-text-muted mb-3">
              Scan Direction
            </p>
            <div className="grid grid-cols-2 gap-3">
              <button
                onClick={() => setDirection('In')}
                className={`flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold uppercase tracking-wider transition-all ${
                  direction === 'In'
                    ? 'bg-emerald-500 text-white shadow-lg shadow-emerald-500/20'
                    : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                }`}
              >
                <LogIn size={17} /> Check In
              </button>
              <button
                onClick={() => setDirection('Out')}
                className={`flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold uppercase tracking-wider transition-all ${
                  direction === 'Out'
                    ? 'bg-blue-500 text-white shadow-lg shadow-blue-500/20'
                    : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                }`}
              >
                <LogOut size={17} /> Check Out
              </button>
            </div>
            <p className="text-xs text-text-muted mt-3">
              {direction === 'In'
                ? 'Records the visitor’s entry. The pass then stays valid only for the check-out scan.'
                : 'Closes the visit — the QR code stops working once the visitor is checked out.'}
            </p>
          </div>

          {/* QR Icon */}
          <div className="flex flex-col items-center mb-8">
            <div className="w-24 h-24 bg-slate-50 rounded-2xl flex items-center justify-center border-2 border-dashed border-slate-200 mb-4">
              <QrCode size={40} className="text-slate-400" />
            </div>
            <p className="text-sm text-text-muted text-center">
              Scan QR code or enter pass code manually below
            </p>
          </div>

          {/* Input */}
          <div className="space-y-3">
            <label className="block text-sm font-semibold text-text-dark">
              Pass Code
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
                  placeholder="e.g. VP-ABC123"
                  autoFocus
                  className="w-full pl-10 pr-4 py-3 border border-border rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
                />
              </div>
              <button
                onClick={() => handleVerify()}
                disabled={loading || !passCode.trim()}
                className="flex items-center gap-2 px-5 py-3 bg-brand-primary text-white rounded-xl text-sm font-semibold hover:bg-brand-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {loading ? (
                  <Loader2 size={16} className="animate-spin" />
                ) : (
                  <Search size={16} />
                )}
                {loading ? 'Verifying…' : direction === 'In' ? 'Check In' : 'Check Out'}
              </button>
            </div>
          </div>
        </div>

        {/* Result Card */}
        {scanResult === 'granted' && visitorPass && (
          <div className="bg-white rounded-2xl border-2 border-green-400 shadow-sm overflow-hidden">
            {/* Success Banner */}
            <div className="bg-green-500 px-6 py-5 flex items-center gap-4">
              <CheckCircle size={36} className="text-white shrink-0" />
              <div>
                <h2 className="text-xl font-bold text-white">
                  {direction === 'In' ? 'Checked In' : 'Checked Out'}
                </h2>
                <p className="text-green-100 text-sm">
                  {direction === 'In'
                    ? 'Entry recorded — access granted'
                    : 'Visit closed — this QR code is no longer valid'}
                </p>
              </div>
            </div>

            {/* Visitor Details */}
            <div className="p-6 space-y-4">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400">
                Visitor Details
              </h3>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="flex items-start gap-3">
                  <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                    <User size={16} className="text-slate-500" />
                  </div>
                  <div>
                    <p className="text-xs text-text-muted">Visitor Name</p>
                    <p className="font-semibold text-text-dark">{visitorPass.visitorName}</p>
                  </div>
                </div>

                {visitorPass.phoneNumber && (
                  <div className="flex items-start gap-3">
                    <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                      <Phone size={16} className="text-slate-500" />
                    </div>
                    <div>
                      <p className="text-xs text-text-muted">Phone</p>
                      <p className="font-semibold text-text-dark">{visitorPass.phoneNumber}</p>
                    </div>
                  </div>
                )}

                <div className="flex items-start gap-3">
                  <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                    <Briefcase size={16} className="text-slate-500" />
                  </div>
                  <div>
                    <p className="text-xs text-text-muted">Purpose</p>
                    <p className="font-semibold text-text-dark">{visitorPass.visitPurpose}</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                    <QrCode size={16} className="text-slate-500" />
                  </div>
                  <div>
                    <p className="text-xs text-text-muted">Pass Code</p>
                    <p className="font-mono font-semibold text-text-dark">{visitorPass.passCode}</p>
                  </div>
                </div>
              </div>

              {/* Status */}
              <div className="flex items-center justify-between pt-2 border-t border-border">
                <span className="text-sm text-text-muted">Pass Status</span>
                <VisitorPassStatusBadge status={visitorPass.status} size="md" />
              </div>

              <div className="flex items-center justify-between">
                <span className="text-sm text-text-muted">Generated At</span>
                <span className="text-sm font-medium text-text-dark">
                  {formatDateTime(visitorPass.generatedAt)}
                </span>
              </div>

              {visitorPass.checkInTime && (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-text-muted flex items-center gap-1.5">
                    <LogIn size={13} /> Checked In
                  </span>
                  <span className="text-sm font-medium text-text-dark">
                    {formatDateTime(visitorPass.checkInTime)}
                  </span>
                </div>
              )}

              {visitorPass.checkOutTime && (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-text-muted flex items-center gap-1.5">
                    <LogOut size={13} /> Checked Out
                  </span>
                  <span className="text-sm font-medium text-text-dark">
                    {formatDateTime(visitorPass.checkOutTime)}
                  </span>
                </div>
              )}
            </div>
          </div>
        )}

        {scanResult === 'denied' && (
          <div className="bg-white rounded-2xl border-2 border-red-400 shadow-sm overflow-hidden">
            {/* Denied Banner */}
            <div className="bg-red-500 px-6 py-5 flex items-center gap-4">
              <XCircle size={36} className="text-white shrink-0" />
              <div>
                <h2 className="text-xl font-bold text-white">Access Denied</h2>
                <p className="text-red-100 text-sm">Pass verification failed</p>
              </div>
            </div>

            <div className="p-6 space-y-4">
              <div className="flex items-start gap-3 bg-red-50 rounded-xl p-4">
                <AlertCircle size={18} className="text-red-500 shrink-0 mt-0.5" />
                <p className="text-sm text-red-700">{errorMessage}</p>
              </div>

              {visitorPass && (
                <div className="space-y-3 text-sm">
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Visitor</span>
                    <span className="font-semibold text-text-dark">{visitorPass.visitorName}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Pass Status</span>
                    <VisitorPassStatusBadge status={visitorPass.status} />
                  </div>
                  {visitorPass.checkInTime && (
                    <div className="flex items-center justify-between">
                      <span className="text-text-muted">Checked In</span>
                      <span className="font-medium text-text-dark">
                        {formatDateTime(visitorPass.checkInTime)}
                      </span>
                    </div>
                  )}
                  {visitorPass.checkOutTime && (
                    <div className="flex items-center justify-between">
                      <span className="text-text-muted">Checked Out</span>
                      <span className="font-medium text-text-dark">
                        {formatDateTime(visitorPass.checkOutTime)}
                      </span>
                    </div>
                  )}
                </div>
              )}
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
