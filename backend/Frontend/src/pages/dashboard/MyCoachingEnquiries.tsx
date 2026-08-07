import React, { useEffect, useState } from 'react';
import { GraduationCap, Clock, CheckCircle2, XCircle, AlertCircle, RefreshCw, ChevronRight, Phone, Mail, Hash } from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import axios from 'axios';
import { getImageUrl } from '../../lib/utils';

interface CoachingEnquiry {
  id: number;
  name: string;
  email: string;
  phone: string;
  message: string | null;
  referenceNumber: string | null;
  status: 'Pending' | 'Reviewed' | 'Contacted' | 'Approved' | 'Rejected';
  createdAt: string;
  batch?: { id: number; name: string; fees: number; duration: string };
  sport?: { id: number; name: string; image: string };
  coach?: { id: number; name: string; email: string; phone: string };
}

const STATUS_CONFIG: Record<
  CoachingEnquiry['status'],
  { label: string; color: string; icon: React.ReactNode; description: string }
> = {
  Pending: {
    label: 'Pending',
    color: 'bg-blue-100 text-blue-700',
    icon: <Clock size={14} />,
    description: 'Your enquiry has been received and is awaiting review.',
  },
  Reviewed: {
    label: 'Reviewed',
    color: 'bg-purple-100 text-purple-700',
    icon: <AlertCircle size={14} />,
    description: 'Our team has reviewed your enquiry.',
  },
  Contacted: {
    label: 'Contacted',
    color: 'bg-yellow-100 text-yellow-800',
    icon: <ChevronRight size={14} />,
    description: 'Our team will contact you shortly to confirm details.',
  },
  Approved: {
    label: 'Approved',
    color: 'bg-green-100 text-green-700',
    icon: <CheckCircle2 size={14} />,
    description: 'Congratulations! Your enrollment has been approved.',
  },
  Rejected: {
    label: 'Rejected',
    color: 'bg-red-100 text-red-600',
    icon: <XCircle size={14} />,
    description: 'Unfortunately your enquiry was not approved at this time.',
  },
};

export const MyCoachingEnquiries: React.FC = () => {
  const [enquiries, setEnquiries] = useState<CoachingEnquiry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchEnquiries = async () => {
    setLoading(true);
    setError(null);
    try {
      // MyCoachingEnquiries appends /api/... paths itself
      const _rawEnqBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
      const API_URL = _rawEnqBase.endsWith('/api') ? _rawEnqBase.slice(0, -4) : _rawEnqBase;
      const accessToken = localStorage.getItem('accessToken');
      const res = await axios.get(`${API_URL}/api/coaching-enquiries/my-enquiries`, {
        withCredentials: true,
        headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : {},
      });
      setEnquiries(res.data.data?.enquiries ?? []);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to load enquiries. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEnquiries();
  }, []);

  const formatDate = (dateStr: string) =>
    new Date(dateStr).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });

  return (
    <UserMainLayout
      breadcrumbs={[
        { label: 'Dashboard' },
        { label: 'My Coaching Enquiries', active: true },
      ]}
    >
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">My Coaching Enquiries</h1>
            <p className="text-text-muted text-sm mt-1">
              Track the status of your coaching enrollment requests.
            </p>
          </div>
          <button
            onClick={fetchEnquiries}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-border rounded-xl text-sm font-semibold text-text-muted hover:bg-slate-50 transition-colors"
          >
            <RefreshCw size={14} />
            Refresh
          </button>
        </div>

        {loading ? (
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="bg-white rounded-2xl border border-border p-6 animate-pulse">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-slate-200 rounded-xl" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 bg-slate-200 rounded w-1/3" />
                    <div className="h-3 bg-slate-200 rounded w-1/4" />
                  </div>
                  <div className="h-6 w-20 bg-slate-200 rounded-full" />
                </div>
              </div>
            ))}
          </div>
        ) : error ? (
          <div className="bg-red-50 border border-red-100 rounded-2xl p-8 text-center">
            <AlertCircle size={32} className="text-red-400 mx-auto mb-3" />
            <p className="text-red-700 font-semibold mb-4">{error}</p>
            <button
              onClick={fetchEnquiries}
              className="px-6 py-2 bg-red-600 text-white rounded-xl text-sm font-bold hover:bg-red-700 transition-colors"
            >
              Try Again
            </button>
          </div>
        ) : enquiries.length === 0 ? (
          <div className="bg-white rounded-2xl border border-border p-12 text-center">
            <div className="w-16 h-16 bg-brand-secondary rounded-2xl flex items-center justify-center mx-auto mb-4">
              <GraduationCap size={28} className="text-primary" />
            </div>
            <h3 className="text-lg font-bold text-text-dark mb-2">No Enquiries Yet</h3>
            <p className="text-text-muted text-sm mb-6">
              You haven't submitted any coaching enrollment enquiries yet.
            </p>
            <a
              href="/coaching"
              className="inline-flex items-center gap-2 px-6 py-3 bg-primary text-white rounded-xl text-sm font-bold hover:bg-primary/90 transition-colors"
            >
              Browse Coaching Programs
              <ChevronRight size={16} />
            </a>
          </div>
        ) : (
          <div className="space-y-4">
            {enquiries.map((enquiry) => {
              const statusCfg = STATUS_CONFIG[enquiry.status];
              return (
                <div
                  key={enquiry.id}
                  className="bg-white rounded-2xl border border-border p-6 hover:shadow-md transition-shadow"
                >
                  <div className="flex items-start gap-4">
                    {/* Sport image / icon */}
                    <div className="w-12 h-12 rounded-xl overflow-hidden bg-slate-100 shrink-0">
                      {enquiry.sport?.image ? (
                        <img
                          src={getImageUrl(enquiry.sport.image)}
                          alt={enquiry.sport.name}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <GraduationCap size={20} className="text-slate-400" />
                        </div>
                      )}
                    </div>

                    {/* Details */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-3 flex-wrap">
                        <div>
                          <h3 className="font-bold text-text-dark text-sm">
                            {enquiry.batch?.name ?? 'Batch'}
                          </h3>
                          <p className="text-xs text-text-muted mt-0.5">
                            {enquiry.sport?.name && (
                              <span className="font-semibold">{enquiry.sport.name}</span>
                            )}
                            {enquiry.coach && (
                              <span> · Coach: {enquiry.coach.name}</span>
                            )}
                          </p>
                        </div>
                        <span
                          className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold shrink-0 ${statusCfg.color}`}
                        >
                          {statusCfg.icon}
                          {statusCfg.label}
                        </span>
                      </div>

                      {/* Reference number */}
                      {enquiry.referenceNumber && (
                        <div className="flex items-center gap-1.5 mt-2">
                          <Hash size={11} className="text-text-muted" />
                          <span className="text-xs font-mono font-bold text-text-muted tracking-wider">
                            {enquiry.referenceNumber}
                          </span>
                        </div>
                      )}

                      {/* Status description */}
                      <p className="text-xs text-text-muted mt-2 bg-slate-50 rounded-lg px-3 py-2">
                        {statusCfg.description}
                      </p>

                      {/* Coach contact card — shown only when Approved */}
                      {enquiry.status === 'Approved' && enquiry.coach && (
                        <div className="mt-3 bg-green-50 border border-green-100 rounded-xl p-3">
                          <p className="text-xs font-black text-green-700 uppercase tracking-widest mb-2">Your Coach</p>
                          <p className="text-sm font-bold text-text-dark">{enquiry.coach.name}</p>
                          <div className="flex items-center gap-4 mt-1 flex-wrap">
                            {enquiry.coach.phone && (
                              <a href={`tel:${enquiry.coach.phone}`} className="flex items-center gap-1 text-xs text-green-700 font-semibold hover:underline">
                                <Phone size={11} /> {enquiry.coach.phone}
                              </a>
                            )}
                            {enquiry.coach.email && (
                              <a href={`mailto:${enquiry.coach.email}`} className="flex items-center gap-1 text-xs text-green-700 font-semibold hover:underline">
                                <Mail size={11} /> {enquiry.coach.email}
                              </a>
                            )}
                          </div>
                        </div>
                      )}

                      {/* Batch details row */}
                      {enquiry.batch && (
                        <div className="flex items-center gap-4 mt-3 flex-wrap">
                          <span className="text-xs font-semibold text-primary">
                            ₹{enquiry.batch.fees?.toLocaleString('en-IN') ?? '—'}/month
                          </span>
                          {enquiry.batch.duration && (
                            <span className="text-xs text-text-muted">
                              Duration: {enquiry.batch.duration}
                            </span>
                          )}
                          <span className="text-xs text-text-muted ml-auto">
                            Submitted: {formatDate(enquiry.createdAt)}
                          </span>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </UserMainLayout>
  );
};

export default MyCoachingEnquiries;
