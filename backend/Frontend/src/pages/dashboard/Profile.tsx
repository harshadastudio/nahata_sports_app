import React, { useState, useEffect, useRef } from 'react';
import {
  User, Mail, Phone, Camera, Lock, Save, KeyRound, Calendar, Droplet,
  Loader2, CheckCircle, AlertCircle, BadgeCheck,
} from 'lucide-react';
import { UserMainLayout } from '../../components/user-layout/UserMainLayout';
import { UnifiedDashboardLayout } from '../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../components/dashboard/DashboardNavbar';
import { useAuth } from '../../contexts/AuthContext';
import { authService } from '../../services/authService';
import { fetchWithAuth } from '../../lib/fetchWithAuth';

type AlertState = { type: 'success' | 'error'; message: string } | null;

/** A read-only block of admin-entered details, as returned by /auth/staff-details. */
interface StaffSection {
  title: string;
  fields: { label: string; value: string }[];
}

const ROLE_LABELS: Record<string, string> = {
  ADMIN: 'Admin',
  EMPLOYEE: 'Employee',
  COACH: 'Coach',
  SECURITY: 'Security Guard',
  USER: 'User',
};

export const Profile: React.FC = () => {
  const { user } = useAuth();

  const [profileForm, setProfileForm] = useState({
    name: '',
    email: '',
    phone_number: '',
    dob: '',
    gender: '',
    blood_group: '',
  });

  const [passwordForm, setPasswordForm] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });

  const [isLoadingProfile, setIsLoadingProfile] = useState(true);
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [isSavingPassword, setIsSavingPassword] = useState(false);
  const [isUploadingPicture, setIsUploadingPicture] = useState(false);
  const [profileAlert, setProfileAlert] = useState<AlertState>(null);
  const [passwordAlert, setPasswordAlert] = useState<AlertState>(null);
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);

  // Details the admin entered when creating this staff account. Read-only here —
  // a staff member views them but cannot change them. Pay is excluded server-side.
  const [staffSections, setStaffSections] = useState<StaffSection[]>([]);

  const fileInputRef = useRef<HTMLInputElement>(null);

  // ── Load profile on mount ───────────────────────────────────────────────────
  useEffect(() => {
    const loadProfile = async () => {
      setIsLoadingProfile(true);
      try {
        const profile: any = await authService.getProfile();
        if (profile) {
          setProfileForm({
            name: profile.name || '',
            email: profile.email || '',
            phone_number: profile.phone_number || '',
            dob: (profile.dob || profile.date_of_birth || '').slice(0, 10),
            gender: profile.gender || '',
            blood_group: profile.blood_group || '',
          });
          setAvatarUrl(profile.profile_picture || profile.avatar || null);
        } else if (user) {
          setProfileForm((p) => ({ ...p, name: user.name || '', email: user.email || '', phone_number: (user as any).phone_number || '' }));
        }
      } catch {
        if (user) {
          setProfileForm((p) => ({ ...p, name: user.name || '', email: user.email || '' }));
        }
      } finally {
        setIsLoadingProfile(false);
      }
    };
    loadProfile();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Admin-entered staff record (Employee / Coach) ───────────────────────────
  useEffect(() => {
    const role = user?.role;
    if (role !== 'EMPLOYEE' && role !== 'COACH') return;

    const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
    fetchWithAuth(`${API_BASE}/auth/staff-details`)
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => {
        const secs = j?.data?.sections;
        setStaffSections(Array.isArray(secs) ? secs : []);
      })
      .catch(() => setStaffSections([]));
  }, [user?.role]);

  const roleLabel = ROLE_LABELS[user?.role ?? ''] ?? 'User';
  const avatarInitial = (profileForm.name || roleLabel).charAt(0).toUpperCase();

  const showAlert = (
    setter: React.Dispatch<React.SetStateAction<AlertState>>,
    type: 'success' | 'error',
    message: string
  ) => {
    setter({ type, message });
    setTimeout(() => setter(null), 4000);
  };

  // ── Profile picture upload ──────────────────────────────────────────────────
  const handlePictureChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 1024 * 1024) {
      showAlert(setProfileAlert, 'error', 'File too large. Maximum size is 1 MB.');
      return;
    }

    const previewUrl = URL.createObjectURL(file);
    setAvatarUrl(previewUrl);
    setIsUploadingPicture(true);

    try {
      const res = await authService.uploadProfilePicture(file);
      if (res.data?.url) setAvatarUrl(res.data.url);
      showAlert(setProfileAlert, 'success', 'Profile picture updated.');
    } catch (err: any) {
      setAvatarUrl(null);
      showAlert(setProfileAlert, 'error', err.message || 'Failed to upload picture.');
    } finally {
      setIsUploadingPicture(false);
    }
  };

  // ── Save profile ────────────────────────────────────────────────────────────
  const handleSaveProfile = async () => {
    if (!profileForm.name.trim()) {
      showAlert(setProfileAlert, 'error', 'Name is required.');
      return;
    }
    if (profileForm.phone_number && !/^[0-9]{10}$/.test(profileForm.phone_number)) {
      showAlert(setProfileAlert, 'error', 'Phone number must be exactly 10 digits.');
      return;
    }

    setIsSavingProfile(true);
    setProfileAlert(null);

    try {
      const res = await authService.updateProfile({
        name: profileForm.name.trim(),
        phone_number: profileForm.phone_number || undefined,
        dob: profileForm.dob || undefined,
        gender: profileForm.gender || undefined,
        blood_group: profileForm.blood_group || undefined,
      });
      showAlert(setProfileAlert, 'success', res.message || 'Profile updated successfully.');
    } catch (err: any) {
      showAlert(setProfileAlert, 'error', err.message || 'Failed to update profile.');
    } finally {
      setIsSavingProfile(false);
    }
  };

  // ── Change password ─────────────────────────────────────────────────────────
  const handleChangePassword = async () => {
    const { currentPassword, newPassword, confirmPassword } = passwordForm;

    if (!currentPassword || !newPassword || !confirmPassword) {
      showAlert(setPasswordAlert, 'error', 'All password fields are required.');
      return;
    }
    if (newPassword.length < 6) {
      showAlert(setPasswordAlert, 'error', 'New password must be at least 6 characters.');
      return;
    }
    if (newPassword !== confirmPassword) {
      showAlert(setPasswordAlert, 'error', 'New passwords do not match.');
      return;
    }

    setIsSavingPassword(true);
    setPasswordAlert(null);

    try {
      const res = await authService.changePassword(currentPassword, newPassword);
      setPasswordForm({ currentPassword: '', newPassword: '', confirmPassword: '' });
      showAlert(setPasswordAlert, 'success', res.message || 'Password changed successfully.');
    } catch (err: any) {
      showAlert(setPasswordAlert, 'error', err.message || 'Failed to change password.');
    } finally {
      setIsSavingPassword(false);
    }
  };

  const inputClass =
    'w-full pl-10 pr-4 py-3 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-brand-primary/40 focus:border-brand-primary text-sm';

  const isUser = !user || user.role === 'USER';

  // Staff logins whose profile, password AND avatar are maintained by an admin.
  // The API 403s all three for these roles (MANAGED_STAFF_ROLES in
  // authController), so showing the self-service cards would only ever produce
  // an error — their details are read-only here.
  const isManagedStaff = ['EMPLOYEE', 'SECURITY', 'COACH'].includes(user?.role ?? '');

  const body = (
      <div className="max-w-4xl mx-auto space-y-6">
        {isLoadingProfile ? (
          <div className="flex flex-col items-center justify-center py-24 gap-3 text-slate-400">
            <Loader2 className="w-10 h-10 animate-spin text-brand-primary" />
            <p className="text-sm font-medium">Loading profile…</p>
          </div>
        ) : (
          <>
            {/* ── Profile header card ── */}
            <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
              <div className="flex flex-col sm:flex-row items-center gap-6 text-center sm:text-left">
                <div className="relative">
                  {avatarUrl ? (
                    <img
                      src={avatarUrl}
                      alt="Profile"
                      className="w-24 h-24 rounded-full object-cover border-4 border-white shadow-md"
                    />
                  ) : (
                    <div className="w-24 h-24 rounded-full bg-gradient-to-tr from-brand-primary to-indigo-400 flex items-center justify-center text-white text-3xl font-bold">
                      {avatarInitial}
                    </div>
                  )}
                  {/* Avatar upload is admin-managed for staff — the API rejects
                      it for those roles, so the control is not offered. */}
                  {!isManagedStaff && (
                    <>
                      <button
                        onClick={() => fileInputRef.current?.click()}
                        disabled={isUploadingPicture}
                        className="absolute bottom-0 right-0 bg-white border border-slate-200 rounded-full p-2 shadow-lg hover:bg-slate-50 transition-colors disabled:opacity-60"
                        title="Change profile picture"
                      >
                        {isUploadingPicture
                          ? <Loader2 className="w-4 h-4 text-brand-primary animate-spin" />
                          : <Camera className="w-4 h-4 text-brand-primary" />}
                      </button>
                      <input
                        ref={fileInputRef}
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={handlePictureChange}
                      />
                    </>
                  )}
                </div>
                <div>
                  <h1 className="text-2xl font-bold text-slate-900">{profileForm.name || roleLabel}</h1>
                  <p className="text-slate-500">{profileForm.email}</p>
                  <span className="inline-block mt-2 px-3 py-1 bg-brand-primary/10 text-brand-primary rounded-full text-sm font-semibold">
                    {roleLabel}
                  </span>
                </div>
              </div>
            </div>

            {/* ── Admin-entered staff details (read-only) ── */}
            {staffSections.map((section) => (
              <div key={section.title} className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
                <div className="px-6 py-4 border-b border-slate-200 flex items-center justify-between gap-3 flex-wrap">
                  <div className="flex items-center gap-2">
                    <BadgeCheck className="w-5 h-5 text-brand-primary" />
                    <h2 className="font-bold text-slate-900">{section.title}</h2>
                  </div>
                  <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 bg-slate-100 px-2.5 py-1 rounded-full">
                    Set by admin · read-only
                  </span>
                </div>
                <div className="p-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {section.fields.map((f) => (
                    <div key={f.label} className="bg-slate-50 rounded-xl p-3">
                      <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">{f.label}</p>
                      <p className="text-sm font-semibold text-slate-900 mt-0.5 break-words">{f.value}</p>
                    </div>
                  ))}
                </div>
              </div>
            ))}

            {/* Staff details are maintained by an admin, so no self-service
                profile / password / avatar editing is offered. */}
            {isManagedStaff && (
              <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm flex items-start gap-3">
                <Lock className="w-5 h-5 text-slate-400 shrink-0 mt-0.5" />
                <div>
                  <p className="font-bold text-slate-900 text-sm">Your profile is managed by your administrator</p>
                  <p className="text-sm text-slate-500 mt-1">
                    To update your details, password or photo, please contact your administrator.
                  </p>
                </div>
              </div>
            )}

            {/* ── Update profile card ── */}
            {!isManagedStaff && (
            <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
              <div className="bg-slate-900 text-white p-4 flex items-center gap-2">
                <User className="w-5 h-5" />
                <h2 className="font-bold">Update Profile</h2>
              </div>

              <div className="p-6 space-y-5">
                {profileAlert && (
                  <div className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium ${
                    profileAlert.type === 'success'
                      ? 'bg-green-50 text-green-700 border border-green-200'
                      : 'bg-red-50 text-red-700 border border-red-200'
                  }`}>
                    {profileAlert.type === 'success'
                      ? <CheckCircle className="w-4 h-4 shrink-0" />
                      : <AlertCircle className="w-4 h-4 shrink-0" />}
                    {profileAlert.message}
                  </div>
                )}

                {/* Full Name */}
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-2">
                    Full Name <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                    <input
                      type="text"
                      value={profileForm.name}
                      onChange={e => setProfileForm(p => ({ ...p, name: e.target.value }))}
                      className={inputClass}
                      placeholder="Full Name"
                    />
                  </div>
                </div>

                {/* Email (read-only) */}
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-2">
                    Email <span className="text-slate-400 font-normal text-xs">(cannot be changed)</span>
                  </label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                    <input
                      type="email"
                      value={profileForm.email}
                      readOnly
                      className="w-full pl-10 pr-4 py-3 border border-slate-200 rounded-xl bg-slate-50 text-slate-500 cursor-not-allowed text-sm"
                    />
                  </div>
                </div>

                {/* Phone / WhatsApp */}
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-2">Phone / WhatsApp Number</label>
                  <div className="relative">
                    <Phone className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                    <input
                      type="tel"
                      inputMode="numeric"
                      maxLength={10}
                      value={profileForm.phone_number}
                      onChange={e => setProfileForm(p => ({ ...p, phone_number: e.target.value.replace(/\D/g, '') }))}
                      className={inputClass}
                      placeholder="Enter 10-digit WhatsApp number"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {/* Date of birth */}
                  <div>
                    <label className="block text-sm font-semibold text-slate-700 mb-2">Date of Birth</label>
                    <div className="relative">
                      <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                      <input
                        type="date"
                        value={profileForm.dob}
                        onChange={e => setProfileForm(p => ({ ...p, dob: e.target.value }))}
                        className={inputClass}
                      />
                    </div>
                  </div>

                  {/* Gender */}
                  <div>
                    <label className="block text-sm font-semibold text-slate-700 mb-2">Gender</label>
                    <select
                      value={profileForm.gender}
                      onChange={e => setProfileForm(p => ({ ...p, gender: e.target.value }))}
                      className="w-full px-4 py-3 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-brand-primary/40 focus:border-brand-primary text-sm bg-white"
                    >
                      <option value="">Select</option>
                      <option value="Male">Male</option>
                      <option value="Female">Female</option>
                      <option value="Other">Other</option>
                    </select>
                  </div>

                  {/* Blood group */}
                  <div>
                    <label className="block text-sm font-semibold text-slate-700 mb-2">Blood Group</label>
                    <div className="relative">
                      <Droplet className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                      <input
                        type="text"
                        maxLength={5}
                        value={profileForm.blood_group}
                        onChange={e => setProfileForm(p => ({ ...p, blood_group: e.target.value }))}
                        className={inputClass}
                        placeholder="e.g. O+"
                      />
                    </div>
                  </div>
                </div>

                <button
                  onClick={handleSaveProfile}
                  disabled={isSavingProfile}
                  className="w-full bg-brand-primary hover:opacity-90 disabled:opacity-60 text-white font-bold py-3 rounded-xl transition-opacity flex items-center justify-center gap-2"
                >
                  {isSavingProfile
                    ? <><Loader2 className="w-5 h-5 animate-spin" /> Saving…</>
                    : <><Save className="w-5 h-5" /> Save Profile</>}
                </button>
              </div>
            </div>
            )}

            {/* ── Change password card ──
                Hidden for admin-managed staff: the API rejects a self-service
                password change for those roles. */}
            {!isManagedStaff && (
            <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
              <div className="bg-slate-900 text-white p-4 flex items-center gap-2">
                <Lock className="w-5 h-5" />
                <h2 className="font-bold">Change Password</h2>
              </div>

              <div className="p-6 space-y-4">
                {passwordAlert && (
                  <div className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium ${
                    passwordAlert.type === 'success'
                      ? 'bg-green-50 text-green-700 border border-green-200'
                      : 'bg-red-50 text-red-700 border border-red-200'
                  }`}>
                    {passwordAlert.type === 'success'
                      ? <CheckCircle className="w-4 h-4 shrink-0" />
                      : <AlertCircle className="w-4 h-4 shrink-0" />}
                    {passwordAlert.message}
                  </div>
                )}

                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-2">Current Password</label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                    <input
                      type="password"
                      value={passwordForm.currentPassword}
                      onChange={e => setPasswordForm(p => ({ ...p, currentPassword: e.target.value }))}
                      className={inputClass}
                      placeholder="Current password"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-2">New Password</label>
                  <div className="relative">
                    <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                    <input
                      type="password"
                      value={passwordForm.newPassword}
                      onChange={e => setPasswordForm(p => ({ ...p, newPassword: e.target.value }))}
                      className={inputClass}
                      placeholder="New password (min 6 characters)"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-2">Confirm New Password</label>
                  <div className="relative">
                    <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                    <input
                      type="password"
                      value={passwordForm.confirmPassword}
                      onChange={e => setPasswordForm(p => ({ ...p, confirmPassword: e.target.value }))}
                      className={inputClass}
                      placeholder="Confirm new password"
                    />
                  </div>
                </div>

                <button
                  onClick={handleChangePassword}
                  disabled={isSavingPassword}
                  className="w-full bg-slate-900 hover:bg-slate-800 disabled:opacity-60 text-white font-bold py-3 rounded-xl transition-colors flex items-center justify-center gap-2"
                >
                  {isSavingPassword
                    ? <><Loader2 className="w-5 h-5 animate-spin" /> Updating…</>
                    : <><Lock className="w-5 h-5" /> Change Password</>}
                </button>
              </div>
            </div>
            )}
          </>
        )}
      </div>
  );

  if (isUser) {
    return (
      <UserMainLayout breadcrumbs={[{ label: 'My Profile', active: true }]}>
        {body}
      </UserMainLayout>
    );
  }

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="My Profile" />}
    >
      {body}
    </UnifiedDashboardLayout>
  );
};

export default Profile;
