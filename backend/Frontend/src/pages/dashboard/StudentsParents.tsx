import React, { useState, useEffect } from 'react';
import {
  Users, Search, Loader2, AlertCircle, User, Phone, Mail, Calendar, Droplets,
  GraduationCap, History, CheckCircle, XCircle,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';

import { fetchWithAuth } from '../../lib/fetchWithAuth';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface Enrollment {
  id: number;
  batchId: number;
  batchName: string;
  sportName: string;
  coachName: string;
  complexName: string | null;
  enrollmentDate: string | null;
  validTill: string | null;
  status: string;
  approvalStatus: string;
  paymentStatus: string;
  isActive: boolean;
}

interface StudentProfile {
  id: number;
  userId: number;
  parentName: string | null;
  parentPhone: string | null;
  parentEmail: string | null;
  schoolName: string | null;
  grade: string | null;
  enrollmentDate: string | null;
  status: string;
  User: {
    id: number;
    name: string;
    email: string;
    phone_number: string | null;
    dob: string | null;
    gender: string | null;
    blood_group: string | null;
    avatar: string | null;
    join_date: string;
  };
}

export const StudentsParents: React.FC = () => {
  const [profile, setProfile] = useState<StudentProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');

  // Enrollment history — active shown by default, past behind a toggle.
  const [enrollments, setEnrollments] = useState<Enrollment[]>([]);
  const [isLoadingEnrollments, setIsLoadingEnrollments] = useState(true);
  const [showPrevious, setShowPrevious] = useState(false);

  useEffect(() => {
    const fetchEnrollments = async () => {
      setIsLoadingEnrollments(true);
      try {
        const response = await fetchWithAuth(`${API_BASE_URL}/students/me/enrollments`);
        if (!response.ok) throw new Error('Failed to load enrollments.');
        const result = await response.json();
        setEnrollments(Array.isArray(result.data) ? result.data : []);
      } catch {
        setEnrollments([]);
      } finally {
        setIsLoadingEnrollments(false);
      }
    };

    fetchEnrollments();
  }, []);

  useEffect(() => {
    const fetchProfile = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const response = await fetchWithAuth(`${API_BASE_URL}/students/me`);

        if (response.status === 404) {
          // User is logged in but has no student profile
          setProfile(null);
          setIsLoading(false);
          return;
        }

        if (!response.ok) {
          throw new Error('Failed to load student profile.');
        }

        const result = await response.json();
        setProfile(result.data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Something went wrong.');
      } finally {
        setIsLoading(false);
      }
    };

    fetchProfile();
  }, []);

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleDateString('en-IN', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
  };

  return (
    <UserMainLayout
      breadcrumbs={[
        { label: 'Dashboard' },
        { label: 'Students / Parents', active: true },
      ]}
    >
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-dark">Students / Parents</h1>
            <p className="text-text-muted text-sm mt-1">Your student profile and parent information.</p>
          </div>
          {profile && (
            <div className="relative">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                type="text"
                placeholder="Search..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-9 pr-4 py-2.5 bg-white border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all w-64"
              />
            </div>
          )}
        </div>

        {/* Loading */}
        {isLoading && (
          <div className="flex items-center justify-center py-20 gap-3 text-slate-400">
            <Loader2 size={24} className="animate-spin" />
            <span className="text-sm">Loading your profile...</span>
          </div>
        )}

        {/* Error */}
        {!isLoading && error && (
          <div className="flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 rounded-xl p-4 text-sm">
            <AlertCircle size={18} className="shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        {/* No student profile */}
        {!isLoading && !error && !profile && (
          <div className="bg-white rounded-2xl border border-border p-12 text-center">
            <Users size={36} className="text-slate-300 mx-auto mb-3" />
            <p className="text-text-dark font-semibold mb-1">No Student Profile Found</p>
            <p className="text-text-muted text-sm">
              You don't have a student profile yet. Register as a student from the home page to get started.
            </p>
          </div>
        )}

        {/* Student Profile Card */}
        {!isLoading && !error && profile && (
          <div className="space-y-4">
            {/* Main Profile Card */}
            <div className="bg-white rounded-2xl border border-border overflow-hidden">
              {/* Card Header */}
              <div className="bg-gradient-to-r from-primary to-primary/80 p-6 text-white">
                <div className="flex items-center gap-4">
                  {profile.User.avatar ? (
                    <img
                      src={`${API_BASE_URL.replace('/api', '')}${profile.User.avatar}`}
                      alt={profile.User.name}
                      className="w-16 h-16 rounded-full object-cover border-2 border-white/40"
                    />
                  ) : (
                    <div className="w-16 h-16 rounded-full bg-white/20 flex items-center justify-center text-2xl font-bold">
                      {profile.User.name.charAt(0).toUpperCase()}
                    </div>
                  )}
                  <div>
                    <h2 className="text-xl font-bold">{profile.User.name}</h2>
                    <p className="text-white/70 text-sm">{profile.User.email}</p>
                    <span className={`mt-1 inline-block px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                      profile.status === 'Active'
                        ? 'bg-green-400/30 text-green-100'
                        : 'bg-red-400/30 text-red-100'
                    }`}>
                      {profile.status}
                    </span>
                  </div>
                </div>
              </div>

              {/* Personal Details */}
              <div className="p-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <InfoItem
                  icon={<Phone size={15} />}
                  label="Mobile"
                  value={profile.User.phone_number ?? '—'}
                />
                <InfoItem
                  icon={<Calendar size={15} />}
                  label="Date of Birth"
                  value={formatDate(profile.User.dob)}
                />
                <InfoItem
                  icon={<User size={15} />}
                  label="Gender"
                  value={profile.User.gender ?? '—'}
                />
                <InfoItem
                  icon={<Droplets size={15} />}
                  label="Blood Group"
                  value={profile.User.blood_group ?? '—'}
                />
                <InfoItem
                  icon={<Calendar size={15} />}
                  label="Joined"
                  value={formatDate(profile.User.join_date)}
                />
                {profile.schoolName && (
                  <InfoItem
                    icon={<User size={15} />}
                    label="School"
                    value={profile.schoolName}
                  />
                )}
                {profile.grade && (
                  <InfoItem
                    icon={<User size={15} />}
                    label="Grade"
                    value={profile.grade}
                  />
                )}
              </div>
            </div>

            {/* Enrollment History */}
            <EnrollmentHistory
              enrollments={enrollments}
              isLoading={isLoadingEnrollments}
              showPrevious={showPrevious}
              onTogglePrevious={() => setShowPrevious((v) => !v)}
              formatDate={formatDate}
            />

            {/* Parent / Guardian Card */}
            {(profile.parentName || profile.parentPhone || profile.parentEmail) && (
              <div className="bg-white rounded-2xl border border-border overflow-hidden">
                <div className="px-6 py-4 border-b border-border">
                  <h3 className="font-bold text-text-dark text-sm">Parent / Guardian</h3>
                </div>
                <div className="p-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {profile.parentName && (
                    <InfoItem icon={<User size={15} />} label="Name" value={profile.parentName} />
                  )}
                  {profile.parentPhone && (
                    <InfoItem icon={<Phone size={15} />} label="Phone" value={profile.parentPhone} />
                  )}
                  {profile.parentEmail && (
                    <InfoItem icon={<Mail size={15} />} label="Email" value={profile.parentEmail} />
                  )}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </UserMainLayout>
  );
};

// ── Enrollment history ────────────────────────────────────────────────────────
// Active enrollments are listed by default. Everything that is no longer active
// (completed / dropped / transferred / suspended, or a batch whose end date has
// passed) is kept behind the "previous enrollments" toggle.
function EnrollmentHistory({
  enrollments,
  isLoading,
  showPrevious,
  onTogglePrevious,
  formatDate,
}: {
  enrollments: Enrollment[];
  isLoading: boolean;
  showPrevious: boolean;
  onTogglePrevious: () => void;
  formatDate: (d: string | null) => string;
}) {
  const active = enrollments.filter((e) => e.isActive);
  const previous = enrollments.filter((e) => !e.isActive);
  const rows = showPrevious ? previous : active;

  return (
    <div className="bg-white rounded-2xl border border-border overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 border-b border-border flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <span className="w-8 h-8 rounded-xl bg-primary/10 text-primary flex items-center justify-center shrink-0">
            {showPrevious ? <History size={15} /> : <GraduationCap size={15} />}
          </span>
          <div>
            <h3 className="font-bold text-text-dark text-sm">
              {showPrevious ? 'Previous Enrollments' : 'Active Enrollments'}
            </h3>
            <p className="text-[11px] text-text-muted mt-0.5">
              {showPrevious
                ? 'Batches you are no longer enrolled in.'
                : 'Batches you are currently enrolled in.'}
            </p>
          </div>
        </div>

        <button
          onClick={onTogglePrevious}
          className="self-start sm:self-auto inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl border border-primary/20 bg-primary/5 text-primary text-xs font-bold hover:bg-primary hover:text-white transition-all"
        >
          {showPrevious ? (
            <><GraduationCap size={13} /> Show Active Enrollments</>
          ) : (
            <><History size={13} /> See Previous Enrollments ({previous.length})</>
          )}
        </button>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12 gap-3 text-slate-400">
          <Loader2 size={20} className="animate-spin" />
          <span className="text-sm">Loading enrollments...</span>
        </div>
      ) : rows.length === 0 ? (
        <div className="py-12 text-center">
          <GraduationCap size={30} className="text-slate-300 mx-auto mb-2" />
          <p className="text-text-muted text-sm">
            {showPrevious ? 'No previous enrollments.' : 'No active enrollments yet.'}
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50 border-b border-border">
                {['Batch Name', 'Sport', 'Coach', 'Enrolled Date', 'Valid Till', 'Status'].map((h) => (
                  <th
                    key={h}
                    className="px-5 py-3 text-[10px] font-bold text-text-muted uppercase tracking-wider whitespace-nowrap"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {rows.map((e) => (
                <tr key={e.id} className="hover:bg-slate-50 transition-colors">
                  <td className="px-5 py-3.5">
                    <p className="text-sm font-bold text-text-dark">{e.batchName}</p>
                    {e.complexName && (
                      <p className="text-[10px] text-text-muted mt-0.5">{e.complexName}</p>
                    )}
                  </td>
                  <td className="px-5 py-3.5 text-sm text-text-dark whitespace-nowrap">{e.sportName}</td>
                  <td className="px-5 py-3.5 text-sm text-text-dark whitespace-nowrap">{e.coachName}</td>
                  <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">
                    {formatDate(e.enrollmentDate)}
                  </td>
                  <td className="px-5 py-3.5 text-sm text-text-muted whitespace-nowrap">
                    {e.validTill ? formatDate(e.validTill) : 'No expiry'}
                  </td>
                  <td className="px-5 py-3.5 whitespace-nowrap">
                    <span
                      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold ${
                        e.isActive
                          ? 'bg-green-50 text-green-700'
                          : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      {e.isActive ? <CheckCircle size={10} /> : <XCircle size={10} />}
                      {e.isActive ? 'Active' : e.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// ── Helper component ──────────────────────────────────────────────────────────
function InfoItem({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-start gap-3 p-3 bg-slate-50 rounded-xl">
      <span className="text-primary mt-0.5 shrink-0">{icon}</span>
      <div>
        <p className="text-[10px] font-bold text-text-muted uppercase tracking-wider">{label}</p>
        <p className="text-sm font-semibold text-text-dark mt-0.5">{value}</p>
      </div>
    </div>
  );
}

export default StudentsParents;
