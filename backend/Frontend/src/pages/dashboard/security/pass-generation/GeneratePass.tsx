import React, { useState, useEffect, useCallback } from 'react';
import {
  UserPlus,
  QrCode,
  CheckCircle,
  Phone,
  User,
  Briefcase,
  Loader2,
  AlertCircle,
  RefreshCw,
  Clock,
  Copy,
  Share2,
  MessageCircle,
  Mail,
  Download,
  Printer,
  Eye,
  LogIn,
  LogOut,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { VisitorPassModal } from '../../../../components/security/VisitorPassModal';
import {
  type VisitorPass,
  VisitorPassStatusBadge,
  formatDateTime,
  qrImageUrl,
  shareOnWhatsApp,
  copyPassCode,
  copyPassDetails,
  downloadQr,
  emailPass,
  printPass,
} from '../../../../components/security/visitorPass';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { useAuth } from '../../../../contexts/AuthContext';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types ─────────────────────────────────────────────────────────────────────

interface GeneratePassForm {
  visitorName: string;
  phoneNumber: string;
  visitPurpose: string;
}

interface GeneratePassResponse {
  success: boolean;
  message?: string;
  pass?: VisitorPass;
  data?: VisitorPass;
}

interface VisitorPassesResponse {
  success: boolean;
  data?: VisitorPass[];
  passes?: VisitorPass[];
}

const VISIT_PURPOSES = [
  'Sports Activity',
  'Meeting',
  'Event',
  'Training',
  'Maintenance',
  'Other',
] as const;

// ── Main Component ────────────────────────────────────────────────────────────

/**
 * GeneratePass - Form to generate new visitor passes for SECURITY role
 *
 * Provides a form with visitor name, phone number, and visit purpose fields.
 * On submission, creates a new visitor pass via the API and displays the
 * generated pass with its QR code and share actions.
 *
 * The "Recently Generated Passes" list below is clickable — any row opens the
 * full pass (QR + details + share), and its status tracks the gate scans:
 * Active → Checked In → Checked Out.
 *
 * Validates: Requirements 6.5, 8.3, 9.2, 13.1
 */
export default function GeneratePass() {
  useAuth();

  const [form, setForm] = useState<GeneratePassForm>({
    visitorName: '',
    phoneNumber: '',
    visitPurpose: 'Sports Activity',
  });
  const [errors, setErrors] = useState<Partial<GeneratePassForm>>({});
  const [submitting, setSubmitting] = useState(false);
  const [generatedPass, setGeneratedPass] = useState<VisitorPass | null>(null);

  const [recentPasses, setRecentPasses] = useState<VisitorPass[]>([]);
  const [loadingRecent, setLoadingRecent] = useState(true);
  const [viewPass, setViewPass] = useState<VisitorPass | null>(null);

  const loadRecentPasses = useCallback(async () => {
    setLoadingRecent(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/visitor-passes?page=1&limit=8`);
      if (res.ok) {
        const data: VisitorPassesResponse = await res.json();
        const list = data.data ?? data.passes ?? [];
        setRecentPasses(list);
      }
    } catch (err) {
      console.error('Failed to load recent passes:', err);
    } finally {
      setLoadingRecent(false);
    }
  }, []);

  useEffect(() => { loadRecentPasses(); }, [loadRecentPasses]);

  const validate = (): boolean => {
    const newErrors: Partial<GeneratePassForm> = {};
    if (!form.visitorName.trim()) {
      newErrors.visitorName = 'Visitor name is required';
    }
    if (!form.phoneNumber.trim()) {
      newErrors.phoneNumber = 'Phone number is required';
    } else if (!/^\d{10}$/.test(form.phoneNumber.trim())) {
      newErrors.phoneNumber = 'Phone number must be exactly 10 digits';
    }
    if (!form.visitPurpose) {
      newErrors.visitPurpose = 'Visit purpose is required';
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    setGeneratedPass(null);

    try {
      const res = await fetchWithAuth(`${API_BASE}/visitor-passes`, {
        method: 'POST',
        body: JSON.stringify({
          visitorName: form.visitorName.trim(),
          phoneNumber: form.phoneNumber.trim(),
          visitPurpose: form.visitPurpose,
        }),
      });

      const data: GeneratePassResponse = await res.json();

      if (res.ok && data.success) {
        const pass = data.pass ?? data.data ?? null;
        if (pass) {
          setGeneratedPass(pass);
          toast.success('Visitor pass generated successfully');
          // Reset form
          setForm({ visitorName: '', phoneNumber: '', visitPurpose: 'Sports Activity' });
          setErrors({});
          // Refresh recent passes
          loadRecentPasses();
        } else {
          toast.success('Pass generated successfully');
          loadRecentPasses();
        }
      } else {
        toast.error(data.message || 'Failed to generate pass');
      }
    } catch (err: any) {
      toast.error('Unable to connect to server. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  /** Keep the list (and the just-generated card) in sync after a modal refresh. */
  const handlePassRefreshed = useCallback((fresh: VisitorPass) => {
    setRecentPasses((prev) =>
      prev.map((p) => (String(p.id) === String(fresh.id) ? { ...p, ...fresh } : p))
    );
    setGeneratedPass((prev) =>
      prev && String(prev.id) === String(fresh.id) ? { ...prev, ...fresh } : prev
    );
  }, []);

  const emailThisPass = (pass: VisitorPass) =>
    emailPass(pass, (path, init) => fetchWithAuth(`${API_BASE}${path}`, init));

  const handleReset = () => {
    setGeneratedPass(null);
    setForm({ visitorName: '', phoneNumber: '', visitPurpose: 'Sports Activity' });
    setErrors({});
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Generate Pass" />}
    >
      <div className="max-w-4xl mx-auto space-y-6">

        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-text-dark">Generate Visitor Pass</h1>
          <p className="text-text-muted text-sm mt-1">
            Create a new entry pass for a visitor
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

          {/* Form Card */}
          <div className="bg-white rounded-2xl border border-border p-6 shadow-sm">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-brand-primary/10 p-2.5 rounded-xl">
                <UserPlus size={22} className="text-brand-primary" />
              </div>
              <div>
                <h2 className="font-bold text-text-dark">Visitor Details</h2>
                <p className="text-xs text-text-muted">Fill in the visitor information</p>
              </div>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5">
              {/* Visitor Name */}
              <div>
                <label className="block text-sm font-semibold text-text-dark mb-1.5">
                  <span className="flex items-center gap-1.5">
                    <User size={14} className="text-slate-400" />
                    Visitor Name <span className="text-red-500">*</span>
                  </span>
                </label>
                <input
                  type="text"
                  value={form.visitorName}
                  onChange={(e) => setForm({ ...form, visitorName: e.target.value })}
                  placeholder="Enter full name"
                  className={`w-full px-3 py-2.5 border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all ${errors.visitorName ? 'border-red-400 bg-red-50' : 'border-border'}`}
                />
                {errors.visitorName && (
                  <p className="flex items-center gap-1 text-xs text-red-500 mt-1">
                    <AlertCircle size={11} /> {errors.visitorName}
                  </p>
                )}
              </div>

              {/* Phone Number */}
              <div>
                <label className="block text-sm font-semibold text-text-dark mb-1.5">
                  <span className="flex items-center gap-1.5">
                    <Phone size={14} className="text-slate-400" />
                    Phone Number <span className="text-red-500">*</span>
                  </span>
                </label>
                <input
                  type="tel"
                  value={form.phoneNumber}
                  onChange={(e) => setForm({ ...form, phoneNumber: e.target.value.replace(/\D/g, '').slice(0, 10) })}
                  placeholder="10-digit mobile number"
                  className={`w-full px-3 py-2.5 border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all ${errors.phoneNumber ? 'border-red-400 bg-red-50' : 'border-border'}`}
                />
                {errors.phoneNumber && (
                  <p className="flex items-center gap-1 text-xs text-red-500 mt-1">
                    <AlertCircle size={11} /> {errors.phoneNumber}
                  </p>
                )}
              </div>

              {/* Visit Purpose */}
              <div>
                <label className="block text-sm font-semibold text-text-dark mb-1.5">
                  <span className="flex items-center gap-1.5">
                    <Briefcase size={14} className="text-slate-400" />
                    Visit Purpose <span className="text-red-500">*</span>
                  </span>
                </label>
                <select
                  value={form.visitPurpose}
                  onChange={(e) => setForm({ ...form, visitPurpose: e.target.value })}
                  className={`w-full px-3 py-2.5 border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary bg-white transition-all ${errors.visitPurpose ? 'border-red-400 bg-red-50' : 'border-border'}`}
                >
                  {VISIT_PURPOSES.map((purpose) => (
                    <option key={purpose} value={purpose}>{purpose}</option>
                  ))}
                </select>
                {errors.visitPurpose && (
                  <p className="flex items-center gap-1 text-xs text-red-500 mt-1">
                    <AlertCircle size={11} /> {errors.visitPurpose}
                  </p>
                )}
              </div>

              {/* Submit */}
              <button
                type="submit"
                disabled={submitting}
                className="w-full flex items-center justify-center gap-2 px-5 py-3 bg-brand-primary text-white rounded-xl text-sm font-semibold hover:bg-brand-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {submitting ? (
                  <Loader2 size={16} className="animate-spin" />
                ) : (
                  <UserPlus size={16} />
                )}
                {submitting ? 'Generating Pass…' : 'Generate Pass'}
              </button>
            </form>
          </div>

          {/* Generated Pass Result */}
          {generatedPass ? (
            <div className="bg-white rounded-2xl border-2 border-green-400 shadow-sm overflow-hidden">
              {/* Success Banner */}
              <div className="bg-green-500 px-6 py-5 flex items-center gap-4">
                <CheckCircle size={32} className="text-white shrink-0" />
                <div>
                  <h2 className="text-xl font-bold text-white">Pass Generated!</h2>
                  <p className="text-green-100 text-sm">Visitor pass created successfully</p>
                </div>
              </div>

              <div className="p-6 space-y-5">
                {/* Pass Code */}
                <div className="bg-slate-50 rounded-xl p-4 text-center">
                  <p className="text-xs text-text-muted mb-2">Pass Code</p>
                  <div className="flex items-center justify-center gap-3">
                    <span className="font-mono text-2xl font-bold text-text-dark tracking-widest">
                      {generatedPass.passCode}
                    </span>
                    <button
                      onClick={() => copyPassCode(generatedPass.passCode)}
                      className="p-2 bg-white border border-border rounded-lg hover:bg-slate-100 transition-colors"
                      title="Copy pass code"
                    >
                      <Copy size={15} className="text-slate-500" />
                    </button>
                  </div>
                </div>

                {/* QR Code */}
                <div className="flex flex-col items-center gap-2">
                  <p className="text-xs text-text-muted">QR Code</p>
                  <button
                    onClick={() => setViewPass(generatedPass)}
                    className="bg-white border border-border rounded-xl p-3 hover:border-brand-primary transition-colors"
                    title="View full pass"
                  >
                    <img
                      src={qrImageUrl(generatedPass)}
                      alt="QR Code"
                      referrerPolicy="no-referrer"
                      className="w-40 h-40 object-contain"
                    />
                  </button>
                </div>

                {/* Share Pass */}
                <div className="border-t border-border pt-4">
                  <p className="flex items-center gap-1.5 text-xs font-semibold text-text-muted mb-3">
                    <Share2 size={13} /> Share Pass
                  </p>
                  <div className="grid grid-cols-2 gap-2">
                    <button
                      onClick={() => shareOnWhatsApp(generatedPass)}
                      className="flex items-center justify-center gap-2 px-3 py-2.5 bg-green-50 text-green-700 border border-green-200 rounded-xl text-sm font-semibold hover:bg-green-100 transition-colors"
                    >
                      <MessageCircle size={15} /> WhatsApp
                    </button>
                    <button
                      onClick={() => emailThisPass(generatedPass)}
                      className="flex items-center justify-center gap-2 px-3 py-2.5 bg-blue-50 text-blue-700 border border-blue-200 rounded-xl text-sm font-semibold hover:bg-blue-100 transition-colors"
                    >
                      <Mail size={15} /> Email
                    </button>
                    <button
                      onClick={() => copyPassDetails(generatedPass)}
                      className="flex items-center justify-center gap-2 px-3 py-2.5 bg-slate-50 text-slate-700 border border-border rounded-xl text-sm font-semibold hover:bg-slate-100 transition-colors"
                    >
                      <Copy size={15} /> Copy Details
                    </button>
                    <button
                      onClick={() => downloadQr(generatedPass)}
                      className="flex items-center justify-center gap-2 px-3 py-2.5 bg-slate-50 text-slate-700 border border-border rounded-xl text-sm font-semibold hover:bg-slate-100 transition-colors"
                    >
                      <Download size={15} /> Download QR
                    </button>
                    <button
                      onClick={() => printPass(generatedPass)}
                      className="col-span-2 flex items-center justify-center gap-2 px-3 py-2.5 bg-slate-50 text-slate-700 border border-border rounded-xl text-sm font-semibold hover:bg-slate-100 transition-colors"
                    >
                      <Printer size={15} /> Print Pass
                    </button>
                  </div>
                </div>

                {/* Visitor Details */}
                <div className="space-y-3 text-sm">
                  <div className="flex justify-between">
                    <span className="text-text-muted flex items-center gap-1.5">
                      <User size={13} /> Name
                    </span>
                    <span className="font-semibold text-text-dark">{generatedPass.visitorName}</span>
                  </div>
                  {generatedPass.phoneNumber && (
                    <div className="flex justify-between">
                      <span className="text-text-muted flex items-center gap-1.5">
                        <Phone size={13} /> Phone
                      </span>
                      <span className="font-medium text-text-dark">{generatedPass.phoneNumber}</span>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <span className="text-text-muted flex items-center gap-1.5">
                      <Briefcase size={13} /> Purpose
                    </span>
                    <span className="font-medium text-text-dark">{generatedPass.visitPurpose}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted flex items-center gap-1.5">
                      <QrCode size={13} /> Status
                    </span>
                    <VisitorPassStatusBadge status={generatedPass.status} />
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted flex items-center gap-1.5">
                      <Clock size={13} /> Generated
                    </span>
                    <span className="font-medium text-text-dark text-xs">
                      {formatDateTime(generatedPass.generatedAt)}
                    </span>
                  </div>
                </div>

                {/* Generate Another */}
                <button
                  onClick={handleReset}
                  className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-white border border-border rounded-xl text-sm font-semibold text-slate-600 hover:bg-slate-50 hover:border-brand-primary hover:text-brand-primary transition-all"
                >
                  <UserPlus size={15} />
                  Generate Another Pass
                </button>
              </div>
            </div>
          ) : (
            /* Placeholder when no pass generated yet */
            <div className="bg-white rounded-2xl border border-dashed border-slate-200 p-8 flex flex-col items-center justify-center text-center gap-4">
              <div className="w-20 h-20 bg-slate-50 rounded-2xl flex items-center justify-center">
                <QrCode size={36} className="text-slate-300" />
              </div>
              <div>
                <p className="font-semibold text-text-dark">No Pass Generated Yet</p>
                <p className="text-sm text-text-muted mt-1">
                  Fill in the form and click "Generate Pass" to create a new visitor pass
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Recently Generated Passes */}
        <div className="bg-white rounded-2xl border border-border shadow-sm">
          <div className="flex items-center justify-between px-6 py-4 border-b border-border">
            <div>
              <h2 className="font-bold text-text-dark">Recently Generated Passes</h2>
              <p className="text-xs text-text-muted mt-0.5">
                Click any pass to view its QR code and share it
              </p>
            </div>
            <button
              onClick={loadRecentPasses}
              disabled={loadingRecent}
              className="flex items-center gap-1.5 text-xs text-slate-500 hover:text-brand-primary transition-colors"
            >
              <RefreshCw size={13} className={loadingRecent ? 'animate-spin' : ''} />
              Refresh
            </button>
          </div>

          {loadingRecent ? (
            <div className="flex items-center justify-center py-12 gap-3">
              <Loader2 size={24} className="animate-spin text-brand-primary" />
              <p className="text-text-muted text-sm">Loading recent passes…</p>
            </div>
          ) : recentPasses.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 gap-3">
              <QrCode size={36} className="text-slate-300" />
              <p className="text-text-muted text-sm">No passes generated yet</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">#</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Visitor</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Phone</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Purpose</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Pass Code</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Status</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Generated At</th>
                    <th className="text-right px-4 py-3 text-xs font-semibold text-text-muted uppercase tracking-wider">Pass</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {recentPasses.map((pass, idx) => (
                    <tr
                      key={pass.id}
                      onClick={() => setViewPass(pass)}
                      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); setViewPass(pass); } }}
                      tabIndex={0}
                      role="button"
                      title={`View pass ${pass.passCode}`}
                      className="hover:bg-slate-50 focus:bg-slate-50 focus:outline-none cursor-pointer transition-colors"
                    >
                      <td className="px-4 py-3 text-text-muted">{idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-text-dark">{pass.visitorName}</td>
                      <td className="px-4 py-3 text-text-muted">{pass.phoneNumber ?? '—'}</td>
                      <td className="px-4 py-3 text-text-muted max-w-[120px] truncate">{pass.visitPurpose}</td>
                      <td className="px-4 py-3">
                        <span className="font-mono text-xs bg-slate-100 px-2 py-0.5 rounded">
                          {pass.passCode}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-col gap-1 items-start">
                          <VisitorPassStatusBadge status={pass.status} />
                          {pass.checkOutTime ? (
                            <span className="text-[10px] text-slate-400 flex items-center gap-1">
                              <LogOut size={9} /> {formatDateTime(pass.checkOutTime)}
                            </span>
                          ) : pass.checkInTime ? (
                            <span className="text-[10px] text-slate-400 flex items-center gap-1">
                              <LogIn size={9} /> {formatDateTime(pass.checkInTime)}
                            </span>
                          ) : null}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-text-muted text-xs whitespace-nowrap">
                        {formatDateTime(pass.generatedAt)}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold text-brand-primary bg-brand-primary/10">
                          <Eye size={13} /> View
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

      </div>

      {/* Pass viewer + share */}
      <VisitorPassModal
        pass={viewPass}
        onClose={() => setViewPass(null)}
        onRefreshed={handlePassRefreshed}
      />
    </UnifiedDashboardLayout>
  );
}
