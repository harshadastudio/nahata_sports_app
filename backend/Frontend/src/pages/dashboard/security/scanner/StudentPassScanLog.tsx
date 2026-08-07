import React, { useState, useEffect, useCallback } from 'react';
import {
  ScanLine, RefreshCw, Loader2, AlertCircle, Calendar, UserCheck, CheckCircle2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface ScanLogEntry {
  id: number;
  scannedAt: string;
  attendanceMarked: boolean;
  scannerRole: string | null;
  scannerName: string;
  studentName: string;
  studentPhone: string;
  batchName: string;
  passCode: string | null;
}

interface ScanLogsResponse {
  success: boolean;
  data: {
    logs: ScanLogEntry[];
    total: number;
    page: number;
    totalPages: number;
  };
}

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
}

const ROLE_STYLES: Record<string, string> = {
  COACH: 'bg-emerald-50 text-emerald-700',
  SECURITY: 'bg-blue-50 text-blue-700',
  EMPLOYEE: 'bg-purple-50 text-purple-700',
  ADMIN: 'bg-slate-100 text-slate-700',
  COMPLEX_ADMIN: 'bg-slate-100 text-slate-700',
};

export default function StudentPassScanLog() {
  const [logs, setLogs] = useState<ScanLogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [date, setDate] = useState(todayStr());

  const limit = 50;

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ page: String(p), limit: String(limit) });
      if (date) params.set('date', date);

      const res = await fetchWithAuth(`${API_BASE}/fees/scan-logs?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: ScanLogsResponse = await res.json();

      setLogs(data.data.logs ?? []);
      setTotal(data.data.total ?? 0);
      setTotalPages(data.data.totalPages ?? 1);
      setPage(p);
    } catch (err) {
      console.error('Failed to load scan logs:', err);
      setError('Failed to load scan log. Please try again.');
      toast.error('Failed to load scan log');
    } finally {
      setLoading(false);
    }
  }, [date]);

  useEffect(() => { load(1); }, [load]);

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Student Pass Scan Log" />}
    >
      <div className="max-w-[1100px] mx-auto pb-10">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Student Pass Scan Log</h1>
            <p className="text-text-muted text-sm mt-1">
              {total} scan{total !== 1 ? 's' : ''} — date-wise record of every student gate-pass scan
            </p>
          </div>
          <div className="flex items-center gap-2">
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={15} />
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="pl-9 pr-3 py-2 border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
              />
            </div>
            <button
              onClick={() => load(page)}
              className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm text-slate-600 hover:text-brand-primary hover:border-brand-primary transition-all"
            >
              <RefreshCw size={15} /> Refresh
            </button>
          </div>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 text-sm px-4 py-3 rounded-xl flex items-center gap-2 mb-4">
            <AlertCircle size={16} /> {error}
          </div>
        )}

        <div className="bg-white rounded-xl border border-border overflow-hidden">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Loader2 size={32} className="animate-spin text-brand-primary" />
              <p className="text-text-muted text-sm">Loading scan log…</p>
            </div>
          ) : logs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <ScanLine size={40} className="text-slate-300" />
              <p className="font-semibold text-text-dark">No scans on this date</p>
              <p className="text-text-muted text-sm">Try a different date.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Time</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Student</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Batch</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Scanned By</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Attendance</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {logs.map((log) => (
                    <tr key={log.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3 text-text-muted text-xs whitespace-nowrap">{fmtTime(log.scannedAt)}</td>
                      <td className="px-4 py-3">
                        <p className="font-medium text-text-dark">{log.studentName}</p>
                        {log.studentPhone && <p className="text-xs text-text-muted">{log.studentPhone}</p>}
                      </td>
                      <td className="px-4 py-3 text-text-muted">{log.batchName || '—'}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-text-dark">{log.scannerName}</span>
                          {log.scannerRole && (
                            <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider ${ROLE_STYLES[log.scannerRole] ?? 'bg-slate-100 text-slate-600'}`}>
                              {log.scannerRole}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        {log.attendanceMarked ? (
                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700">
                            <CheckCircle2 size={12} /> Marked
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-blue-700">
                            <UserCheck size={12} /> Verified only
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {!loading && totalPages > 1 && (
          <div className="flex items-center justify-between mt-4">
            <p className="text-xs text-text-muted">Page {page} of {totalPages}</p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => load(page - 1)}
                disabled={page <= 1}
                className="px-3 py-1.5 bg-white border border-border rounded-xl text-sm text-slate-500 hover:text-brand-primary hover:border-brand-primary transition-all disabled:opacity-40"
              >
                Previous
              </button>
              <button
                onClick={() => load(page + 1)}
                disabled={page >= totalPages}
                className="px-3 py-1.5 bg-white border border-border rounded-xl text-sm text-slate-500 hover:text-brand-primary hover:border-brand-primary transition-all disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>
    </UnifiedDashboardLayout>
  );
}
