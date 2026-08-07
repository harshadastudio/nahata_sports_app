import React, { useState, useRef } from 'react';
import {
  ShieldCheck,
  ShieldOff,
  Search,
  CheckCircle,
  XCircle,
  Loader2,
  AlertCircle,
  User,
  Phone,
  Briefcase,
  QrCode,
  History,
  Trash2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import {
  type VisitorPass,
  VisitorPassStatusBadge,
  getPassStatusMeta,
  formatDateTime,
} from '../../../../components/security/visitorPass';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types ─────────────────────────────────────────────────────────────────────

type VerificationOutcome = 'valid' | 'invalid';

interface VerifyResponse {
  success: boolean;
  message?: string;
  pass?: VisitorPass;
  valid?: boolean;
}

interface VerificationRecord {
  id: string;
  passCode: string;
  outcome: VerificationOutcome;
  pass?: VisitorPass;
  errorMessage?: string;
  verifiedAt: Date;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const formatWhen = (value?: string | Date | null) =>
  value instanceof Date
    ? value.toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      })
    : formatDateTime(value);

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * EntryPassVerification - Manual pass verification page for SECURITY role
 *
 * Allows security personnel to verify visitor passes by entering a pass code.
 * Shows verification result with visitor details and pass status. Maintains
 * a history of recent verifications in component state.
 *
 * Validates: Requirements 6.5, 8.3, 9.2, 13.1
 */
export default function EntryPassVerification() {
  useAuth();

  const [passCode, setPassCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [currentResult, setCurrentResult] = useState<VerificationRecord | null>(null);
  const [history, setHistory] = useState<VerificationRecord[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleVerify = async () => {
    const trimmed = passCode.trim();
    if (!trimmed) {
      toast.error('Please enter a pass code');
      return;
    }

    setLoading(true);

    try {
      // READ-ONLY check: /lookup returns the pass + validity WITHOUT marking it
      // Used. (Use the Entry Scanner to actually record entry / consume a pass.)
      const res = await fetchWithAuth(`${API_BASE}/visitor-passes/lookup`, {
        method: 'POST',
        body: JSON.stringify({ passCode: trimmed }),
      });

      const data: VerifyResponse = await res.json();
      const foundPass = data.pass ?? (data as any).data ?? undefined;

      const record: VerificationRecord = {
        id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
        passCode: trimmed,
        outcome: (res.ok && data.valid && foundPass) ? 'valid' : 'invalid',
        pass: foundPass,
        errorMessage: (!res.ok || !data.valid) ? (data.message || 'Invalid or expired pass code') : undefined,
        verifiedAt: new Date(),
      };

      setCurrentResult(record);
      setHistory((prev) => [record, ...prev].slice(0, 20)); // keep last 20
      setPassCode('');

      if (record.outcome === 'valid') {
        toast.success('Pass is valid (not consumed)');
      } else {
        toast.error(record.errorMessage || 'Pass is not valid');
      }
    } catch (err: any) {
      const record: VerificationRecord = {
        id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
        passCode: trimmed,
        outcome: 'invalid',
        errorMessage: 'Unable to connect to server. Please try again.',
        verifiedAt: new Date(),
      };
      setCurrentResult(record);
      setHistory((prev) => [record, ...prev].slice(0, 20));
      setPassCode('');
      toast.error('Verification failed');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') handleVerify();
  };

  const handleClearHistory = () => {
    setHistory([]);
    setCurrentResult(null);
    toast.success('History cleared');
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Entry Pass Verification" />}
    >
      <div className="max-w-3xl mx-auto space-y-6">

        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-text-dark">Entry Pass Verification</h1>
          <p className="text-text-muted text-sm mt-1">
            Check a visitor pass's validity and details. This is a read-only check —
            it does <span className="font-semibold">not</span> mark the pass as used. Use the
            Entry Scanner to record actual entry.
          </p>
        </div>

        {/* Verification Input Card */}
        <div className="bg-white rounded-2xl border border-border p-6 shadow-sm">
          <div className="flex items-center gap-3 mb-5">
            <div className="bg-brand-primary/10 p-2.5 rounded-xl">
              <ShieldCheck size={22} className="text-brand-primary" />
            </div>
            <div>
              <h2 className="font-bold text-text-dark">Verify Pass</h2>
              <p className="text-xs text-text-muted">Enter the pass code to check validity</p>
            </div>
          </div>

          <div className="flex gap-3">
            <div className="relative flex-1">
              <Search
                size={18}
                className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
              />
              <input
                ref={inputRef}
                type="text"
                value={passCode}
                onChange={(e) => setPassCode(e.target.value.toUpperCase())}
                onKeyDown={handleKeyDown}
                placeholder="Enter pass code (e.g. VP-ABC123)"
                autoFocus
                className="w-full pl-10 pr-4 py-3 border border-border rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
              />
            </div>
            <button
              onClick={handleVerify}
              disabled={loading || !passCode.trim()}
              className="flex items-center gap-2 px-5 py-3 bg-brand-primary text-white rounded-xl text-sm font-semibold hover:bg-brand-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              {loading ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <Search size={16} />
              )}
              {loading ? 'Verifying…' : 'Verify'}
            </button>
          </div>
        </div>

        {/* Current Verification Result */}
        {currentResult && (
          <div className={`bg-white rounded-2xl border-2 shadow-sm overflow-hidden ${currentResult.outcome === 'valid' ? 'border-green-400' : 'border-red-400'}`}>
            {/* Result Banner */}
            <div className={`px-6 py-5 flex items-center gap-4 ${currentResult.outcome === 'valid' ? 'bg-green-500' : 'bg-red-500'}`}>
              {currentResult.outcome === 'valid' ? (
                <ShieldCheck size={32} className="text-white shrink-0" />
              ) : (
                <ShieldOff size={32} className="text-white shrink-0" />
              )}
              <div>
                <h2 className="text-xl font-bold text-white">
                  {currentResult.outcome === 'valid' ? 'Pass Valid' : 'Pass Invalid'}
                </h2>
                <p className={`text-sm ${currentResult.outcome === 'valid' ? 'text-green-100' : 'text-red-100'}`}>
                  {currentResult.outcome === 'valid'
                    ? 'This pass is valid and active — not consumed'
                    : 'This pass could not be verified'}
                </p>
              </div>
            </div>

            <div className="p-6">
              {currentResult.outcome === 'valid' && currentResult.pass ? (
                <div className="space-y-4">
                  {/* Visitor Details */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div className="flex items-start gap-3">
                      <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                        <User size={16} className="text-slate-500" />
                      </div>
                      <div>
                        <p className="text-xs text-text-muted">Visitor Name</p>
                        <p className="font-semibold text-text-dark">{currentResult.pass.visitorName}</p>
                      </div>
                    </div>

                    {currentResult.pass.phoneNumber && (
                      <div className="flex items-start gap-3">
                        <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                          <Phone size={16} className="text-slate-500" />
                        </div>
                        <div>
                          <p className="text-xs text-text-muted">Phone</p>
                          <p className="font-semibold text-text-dark">{currentResult.pass.phoneNumber}</p>
                        </div>
                      </div>
                    )}

                    <div className="flex items-start gap-3">
                      <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                        <Briefcase size={16} className="text-slate-500" />
                      </div>
                      <div>
                        <p className="text-xs text-text-muted">Purpose</p>
                        <p className="font-semibold text-text-dark">{currentResult.pass.visitPurpose}</p>
                      </div>
                    </div>

                    <div className="flex items-start gap-3">
                      <div className="bg-slate-100 p-2 rounded-lg shrink-0">
                        <QrCode size={16} className="text-slate-500" />
                      </div>
                      <div>
                        <p className="text-xs text-text-muted">Pass Code</p>
                        <p className="font-mono font-semibold text-text-dark">{currentResult.pass.passCode}</p>
                      </div>
                    </div>
                  </div>

                  {/* Status Row */}
                  <div className="flex items-center justify-between pt-3 border-t border-border">
                    <span className="text-sm text-text-muted">Pass Status</span>
                    <VisitorPassStatusBadge status={currentResult.pass.status} size="md" />
                  </div>

                  <div className="flex items-center justify-between">
                    <span className="text-sm text-text-muted">Generated At</span>
                    <span className="text-sm font-medium text-text-dark">
                      {formatDateTime(currentResult.pass.generatedAt)}
                    </span>
                  </div>

                  {currentResult.pass.checkInTime && (
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-text-muted">Checked In</span>
                      <span className="text-sm font-medium text-text-dark">
                        {formatDateTime(currentResult.pass.checkInTime)}
                      </span>
                    </div>
                  )}

                  {currentResult.pass.checkOutTime && (
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-text-muted">Checked Out</span>
                      <span className="text-sm font-medium text-text-dark">
                        {formatDateTime(currentResult.pass.checkOutTime)}
                      </span>
                    </div>
                  )}

                  <p className="text-xs text-text-muted bg-slate-50 rounded-xl p-3">
                    {getPassStatusMeta(currentResult.pass.status).hint}
                  </p>
                </div>
              ) : (
                <div className="flex items-start gap-3 bg-red-50 rounded-xl p-4">
                  <AlertCircle size={18} className="text-red-500 shrink-0 mt-0.5" />
                  <p className="text-sm text-red-700">{currentResult.errorMessage}</p>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Verification History */}
        {history.length > 0 && (
          <div className="bg-white rounded-2xl border border-border shadow-sm">
            <div className="flex items-center justify-between px-6 py-4 border-b border-border">
              <div className="flex items-center gap-2">
                <History size={18} className="text-slate-400" />
                <h2 className="font-bold text-text-dark">Recent Verifications</h2>
                <span className="text-xs bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-semibold">
                  {history.length}
                </span>
              </div>
              <button
                onClick={handleClearHistory}
                className="flex items-center gap-1.5 text-xs text-slate-400 hover:text-red-500 transition-colors"
              >
                <Trash2 size={13} />
                Clear
              </button>
            </div>

            <div className="divide-y divide-border">
              {history.map((record) => (
                <div
                  key={record.id}
                  className="flex items-center justify-between px-6 py-3 hover:bg-slate-50 transition-colors"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    {record.outcome === 'valid' ? (
                      <CheckCircle size={18} className="text-green-500 shrink-0" />
                    ) : (
                      <XCircle size={18} className="text-red-500 shrink-0" />
                    )}
                    <div className="min-w-0">
                      <p className="font-mono text-sm font-semibold text-text-dark truncate">
                        {record.passCode}
                      </p>
                      {record.pass && (
                        <p className="text-xs text-text-muted truncate">
                          {record.pass.visitorName} · {record.pass.visitPurpose}
                        </p>
                      )}
                      {!record.pass && record.errorMessage && (
                        <p className="text-xs text-red-500 truncate">{record.errorMessage}</p>
                      )}
                    </div>
                  </div>
                  <div className="text-right shrink-0 ml-4">
                    {record.pass ? (
                      <VisitorPassStatusBadge status={record.pass.status} />
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-700">
                        <XCircle size={11} /> Invalid
                      </span>
                    )}
                    <p className="text-xs text-text-muted mt-1">
                      {formatWhen(record.verifiedAt)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </UnifiedDashboardLayout>
  );
}
