import React, { useState, useEffect } from 'react';
import { ClipboardList, RefreshCw } from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { fetchWithAuth } from '../../lib/fetchWithAuth';

interface AttendanceRecord {
  id: number;
  date: string;
  sport?: string | null;
  batch?: string | null;
  status: 'Present' | 'Absent' | 'Late' | 'Leave';
  checkInTime?: string | null;
  checkOutTime?: string | null;
  notes?: string | null;
}

const STATUS_COLORS: Record<string, string> = {
  Present: 'bg-green-100 text-green-700',
  Absent:  'bg-red-100 text-red-600',
  Late:    'bg-yellow-100 text-yellow-700',
  Leave:   'bg-blue-100 text-blue-700',
};

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export const AttendanceSheet: React.FC = () => {
  const [records, setRecords]   = useState<AttendanceRecord[]>([]);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);
  const [filter, setFilter]     = useState<'All' | 'Present' | 'Absent' | 'Late' | 'Leave'>('All');

  const fetchAttendance = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetchWithAuth(`${API_BASE}/attendance/my`);
      const json = await res.json();

      if (!res.ok) {
        throw new Error(json?.message || `Server error ${res.status}`);
      }

      setRecords(Array.isArray(json.data) ? json.data : []);
    } catch (err: any) {
      console.error('Attendance fetch error:', err);
      setError(err.message || 'Failed to load attendance data');
      setRecords([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAttendance();
  }, []);

  const filtered      = filter === 'All' ? records : records.filter((r) => r.status === filter);
  const presentCount  = records.filter((r) => r.status === 'Present').length;
  const absentCount   = records.filter((r) => r.status === 'Absent').length;
  const lateCount     = records.filter((r) => r.status === 'Late').length;
  const percentage    = records.length > 0 ? Math.round((presentCount / records.length) * 100) : 0;

  return (
    <UserMainLayout
      breadcrumbs={[
        { label: 'Dashboard' },
        { label: 'Attendance Sheet', active: true },
      ]}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Attendance Sheet</h1>
            <p className="text-text-muted text-sm mt-1">View your attendance history.</p>
          </div>
          <button
            onClick={fetchAttendance}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm font-semibold text-text-muted hover:bg-slate-50 transition-colors disabled:opacity-50"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            Refresh
          </button>
        </div>

        {/* Error banner */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
            {error}
          </div>
        )}

        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="bg-white rounded-2xl border border-border p-5 animate-pulse">
                <div className="h-8 bg-slate-200 rounded mb-2" />
                <div className="h-3 bg-slate-200 rounded w-2/3" />
              </div>
            ))}
          </div>
        ) : (
          <>
            {/* Summary cards */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              {[
                { label: 'Total Sessions', value: records.length,  color: 'text-text-dark' },
                { label: 'Present',        value: presentCount,    color: 'text-green-600' },
                { label: 'Absent',         value: absentCount,     color: 'text-red-600'   },
                { label: 'Attendance %',   value: `${percentage}%`, color: 'text-primary'  },
              ].map((stat) => (
                <div key={stat.label} className="bg-white rounded-2xl border border-border p-5 text-center">
                  <p className={`text-2xl font-bold ${stat.color}`}>{stat.value}</p>
                  <p className="text-xs text-text-muted mt-1">{stat.label}</p>
                </div>
              ))}
            </div>

            {/* Filter tabs */}
            <div className="flex gap-2 flex-wrap">
              {(['All', 'Present', 'Absent', 'Late', 'Leave'] as const).map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  className={`px-4 py-2 rounded-xl text-xs font-bold transition-colors ${
                    filter === f
                      ? 'bg-primary text-white'
                      : 'bg-white border border-border text-text-muted hover:bg-slate-50'
                  }`}
                >
                  {f}
                  {f !== 'All' && (
                    <span className="ml-1 opacity-70">
                      ({records.filter((r) => r.status === f).length})
                    </span>
                  )}
                </button>
              ))}
            </div>

            {/* Records list */}
            <div className="bg-white rounded-2xl border border-border overflow-hidden">
              {filtered.length === 0 ? (
                <div className="p-12 text-center">
                  <ClipboardList size={32} className="text-slate-300 mx-auto mb-3" />
                  <p className="text-text-muted text-sm font-medium">
                    {records.length === 0
                      ? 'No attendance records found. Your coach will mark attendance after each session.'
                      : `No ${filter.toLowerCase()} records found.`}
                  </p>
                </div>
              ) : (
                <div className="divide-y divide-border">
                  {filtered.map((record) => (
                    <div
                      key={record.id}
                      className="flex items-center justify-between p-5 hover:bg-slate-50 transition-colors"
                    >
                      <div className="flex items-center gap-4">
                        <div className="w-10 h-10 bg-brand-secondary rounded-xl flex items-center justify-center shrink-0">
                          <ClipboardList size={18} className="text-primary" />
                        </div>
                        <div>
                          <p className="font-semibold text-text-dark text-sm">
                            {record.sport ?? 'Sport'}
                            {record.batch ? ` — ${record.batch} batch` : ''}
                          </p>
                          <p className="text-xs text-text-muted mt-0.5">{record.date}</p>
                          {record.checkInTime && (
                            <p className="text-xs text-text-muted mt-0.5">
                              Check-in: {record.checkInTime}
                              {record.checkOutTime ? ` · Check-out: ${record.checkOutTime}` : ''}
                            </p>
                          )}
                          {record.notes && (
                            <p className="text-xs text-text-muted mt-0.5 italic">{record.notes}</p>
                          )}
                        </div>
                      </div>
                      <span
                        className={`px-3 py-1 rounded-full text-xs font-semibold ${
                          STATUS_COLORS[record.status] ?? 'bg-slate-100 text-slate-600'
                        }`}
                      >
                        {record.status}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </UserMainLayout>
  );
};

export default AttendanceSheet;
