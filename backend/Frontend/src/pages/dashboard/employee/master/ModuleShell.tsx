/**
 * Shared scaffolding for the employee "operations" modules (Sports, Court,
 * Slot, Batch, Blocked Slots, Fees Management).
 *
 * Every one of these modules is COMPLEX-SCOPED: the API restricts reads and
 * writes to the employee's own sportComplexId (EMPLOYEE is listed in
 * COMPLEX_SCOPED_ROLES in the API's complexScope middleware), so these screens
 * never send a complex id and never offer a complex picker — there is only ever
 * one complex to act on.
 */
import React from 'react';
import { Loader2, AlertCircle, RefreshCw, Plus, Inbox } from 'lucide-react';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';

const _rawBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
export const API = _rawBase.endsWith('/api') ? _rawBase : `${_rawBase}/api`;

/** Read the API error message rather than showing a bare "HTTP 403". */
export async function readError(res: Response, fallback: string): Promise<string> {
  try {
    const json = await res.json();
    return json?.message || fallback;
  } catch {
    return fallback;
  }
}

interface ModuleShellProps {
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  loading?: boolean;
  error?: string | null;
  onRefresh?: () => void;
  onAdd?: () => void;
  addLabel?: string;
  toolbar?: React.ReactNode;
  children: React.ReactNode;
}

export const ModuleShell: React.FC<ModuleShellProps> = ({
  title, subtitle, icon, loading, error, onRefresh, onAdd, addLabel, toolbar, children,
}) => (
  <UnifiedDashboardLayout sidebar={<RoleBasedSidebar />} navbar={<DashboardNavbar pageTitle={title} />}>
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="w-11 h-11 rounded-2xl bg-primary/10 text-primary flex items-center justify-center shrink-0">
            {icon}
          </span>
          <div>
            <h1 className="text-2xl font-bold text-text-dark">{title}</h1>
            <p className="text-text-muted text-sm mt-0.5">{subtitle}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {toolbar}
          {onRefresh && (
            <button
              onClick={onRefresh}
              disabled={loading}
              className="p-2.5 bg-white border border-border rounded-xl text-slate-500 hover:bg-slate-50 transition-colors disabled:opacity-50"
              title="Refresh"
            >
              <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
            </button>
          )}
          {onAdd && (
            <button
              onClick={onAdd}
              className="flex items-center gap-2 bg-primary hover:opacity-90 text-white px-4 py-2.5 rounded-xl text-sm font-bold transition-opacity"
            >
              <Plus size={16} /> {addLabel ?? 'Add'}
            </button>
          )}
        </div>
      </div>

      {/* Scope notice — employees only ever act on their own complex */}
      <p className="text-[11px] text-text-muted bg-slate-50 border border-border rounded-xl px-3 py-2">
        You are viewing and managing records for your own sports complex only.
      </p>

      {error && (
        <div className="flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 rounded-xl p-4 text-sm">
          <AlertCircle size={18} className="shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-24 gap-3 text-slate-400">
          <Loader2 size={24} className="animate-spin" />
          <span className="text-sm">Loading...</span>
        </div>
      ) : (
        children
      )}
    </div>
  </UnifiedDashboardLayout>
);

export const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="bg-white rounded-2xl border border-border py-16 text-center">
    <Inbox size={32} className="text-slate-300 mx-auto mb-3" />
    <p className="text-text-muted text-sm">{message}</p>
  </div>
);

/** Standard table wrapper — horizontal scroll on narrow screens. */
export const DataCard: React.FC<{ headers: string[]; children: React.ReactNode }> = ({ headers, children }) => (
  <div className="bg-white rounded-2xl border border-border overflow-hidden">
    <div className="overflow-x-auto">
      <table className="w-full text-left border-collapse">
        <thead>
          <tr className="bg-slate-50 border-b border-border">
            {headers.map((h) => (
              <th key={h} className="px-5 py-3 text-[10px] font-bold text-text-muted uppercase tracking-wider whitespace-nowrap">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-border">{children}</tbody>
      </table>
    </div>
  </div>
);

/** Slide-over form panel used by every module's add/edit flow. */
export const FormPanel: React.FC<{
  open: boolean;
  title: string;
  saving?: boolean;
  error?: string | null;
  onClose: () => void;
  onSave: () => void;
  children: React.ReactNode;
}> = ({ open, title, saving, error, onClose, onSave, children }) => {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-[120] flex">
      <div className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm" onClick={saving ? undefined : onClose} />
      <div className="relative ml-auto h-full w-full max-w-lg bg-white shadow-2xl flex flex-col">
        <div className="p-6 border-b border-border">
          <h2 className="text-lg font-bold text-text-dark">{title}</h2>
        </div>
        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          {error && (
            <div className="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl p-3 text-xs">
              <AlertCircle size={14} className="shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}
          {children}
        </div>
        <div className="p-5 border-t border-border flex gap-3">
          <button
            onClick={onSave}
            disabled={saving}
            className="flex-1 flex items-center justify-center gap-2 bg-primary text-white py-3 rounded-xl text-sm font-bold disabled:opacity-60"
          >
            {saving ? <><Loader2 size={16} className="animate-spin" /> Saving...</> : 'Save'}
          </button>
          <button
            onClick={onClose}
            disabled={saving}
            className="px-5 py-3 bg-slate-100 text-slate-600 rounded-xl text-sm font-bold hover:bg-slate-200 transition-colors"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};

export const inputCls =
  'w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all';

export const Field: React.FC<{ label: string; children: React.ReactNode }> = ({ label, children }) => (
  <div className="space-y-1.5">
    <label className="text-[11px] font-bold text-text-muted uppercase tracking-wider block">{label}</label>
    {children}
  </div>
);

export const StatusPill: React.FC<{ active: boolean; label?: string }> = ({ active, label }) => (
  <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${active ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-600'}`}>
    {label ?? (active ? 'Active' : 'Inactive')}
  </span>
);
