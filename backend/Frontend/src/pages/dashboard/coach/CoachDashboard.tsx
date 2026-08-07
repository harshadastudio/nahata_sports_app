import React, { useState, useEffect } from 'react';
import {
 Users, Calendar, CheckCircle, TrendingUp, Bell, Award,
 Plus, X, User, Phone, Mail, RefreshCw, Loader2,
} from 'lucide-react';
import { UnifiedDashboardLayout } from '../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../components/dashboard/DashboardNavbar';
import { useAuth } from '../../../contexts/AuthContext';
import { fetchWithAuth } from '../../../lib/fetchWithAuth';
import toast from 'react-hot-toast';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface DashboardStats {
  totalStudents: number;
  presentToday: number;
  sessionsToday: number;
  avgPerformance: number;
  totalBatches: number;
  activeEnquiries: number;
}

interface TodaySchedule {
  id: number;
  batchName: string;
  startTime: string;
  endTime: string;
  court: string;
  status: string;
  studentCount: number;
  sport?: { name: string };
  batch?: { name: string };
}

interface TopPerformer {
  id: number;
  name: string;
  performance: number;
  detail: string;
  sport: string;
  color: string;
}

interface Enquiry {
 id: number;
 name: string;
 email: string;
 phone: string;
 status: string;
 referenceNumber?: string;
 createdAt: string;
 batch?: { name: string };
}

interface Sport {
 id: number;
 name: string;
}

interface Program {
 id: number;
 name: string;
}

/**
 * CoachDashboard - Overview page for the COACH role
 *
 * Displays key coaching stats, today's schedule, top performers,
 * recent notifications, and coaching enquiries.
 * Wrapped with UnifiedDashboardLayout using RoleBasedSidebar and DashboardNavbar.
 *
 * Validates: Requirements 5.1, 8.2
 */
export default function CoachDashboard() {
 const { user } = useAuth();

 // State for dashboard data
 const [stats, setStats] = useState<DashboardStats>({
 totalStudents: 0,
 presentToday: 0,
 sessionsToday: 0,
 avgPerformance: 0,
 totalBatches: 0,
 activeEnquiries: 0,
 });
 const [todaySchedule, setTodaySchedule] = useState<TodaySchedule[]>([]);
 const [topPerformers, setTopPerformers] = useState<TopPerformer[]>([]);
 const [enquiries, setEnquiries] = useState<Enquiry[]>([]);
 const [totalEnquiries, setTotalEnquiries] = useState(0);

 // State for form
 const [isFormOpen, setIsFormOpen] = useState(false);
 const [loading, setLoading] = useState(false);
 const [dataLoading, setDataLoading] = useState(true);
 const [sports, setSports] = useState<Sport[]>([]);
 const [programs, setPrograms] = useState<Program[]>([]);

 const [formData, setFormData] = useState({
 name: '',
 email: '',
 phone: '',
 sportId: '',
 batchId: '',
 message: '',
 });

 // Fetch all dashboard data
 const fetchDashboardData = async () => {
 setDataLoading(true);
 try {
 const [statsRes, scheduleRes, performersRes, enquiriesRes, sportsRes, programsRes] = await Promise.all([
 fetchWithAuth(`${API_BASE}/coach/dashboard/stats`),
 fetchWithAuth(`${API_BASE}/coach/dashboard/schedule/today`),
 fetchWithAuth(`${API_BASE}/coach/dashboard/students/top-performers`),
 fetchWithAuth(`${API_BASE}/coaching-enquiries/coach/my-enquiries?page=1&limit=5`),
 fetchWithAuth(`${API_BASE}/sports?page=1&limit=100`),
 fetchWithAuth(`${API_BASE}/batches?page=1&limit=100`),
 ]);

 // Parse stats
 if (statsRes.ok) {
 const data = await statsRes.json();
 setStats(data.data || {});
 }

 // Parse schedule
 if (scheduleRes.ok) {
 const data = await scheduleRes.json();
 setTodaySchedule(data.data || []);
 }

 // Parse top performers
 if (performersRes.ok) {
 const data = await performersRes.json();
 setTopPerformers(data.data || []);
 }

 // Parse enquiries
 if (enquiriesRes.ok) {
 const data = await enquiriesRes.json();
 setEnquiries(data.data?.enquiries || []);
 setTotalEnquiries(data.data?.total || 0);
 }

 // Parse sports
 if (sportsRes.ok) {
 const data = await sportsRes.json();
 setSports(Array.isArray(data.data) ? data.data : []);
 }

 // Parse batches (offerings)
 if (programsRes.ok) {
 const data = await programsRes.json();
 setPrograms(Array.isArray(data.data?.batches) ? data.data.batches : []);
 }
 } catch (err) {
 console.error('Failed to fetch dashboard data:', err);
 toast.error('Failed to load dashboard data');
 } finally {
 setDataLoading(false);
 }
 };

 useEffect(() => {
 fetchDashboardData();
 }, []);

 const handleInputChange = (
 e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>
 ) => {
 const { name, value } = e.target;
 
 // Phone number validation - only allow 10 digits
 if (name === 'phone') {
 // Remove all non-digit characters
 const digitsOnly = value.replace(/\D/g, '');
 // Limit to 10 digits
 const limitedValue = digitsOnly.slice(0, 10);
 setFormData((prev) => ({ ...prev, [name]: limitedValue }));
 return;
 }
 
 setFormData((prev) => ({ ...prev, [name]: value }));
 };

 const resetForm = () => {
 setFormData({ name: '', email: '', phone: '', sportId: '', batchId: '', message: '' });
 };

 const handleSubmit = async () => {
 if (!formData.name) { toast.error('Please enter student name'); return; }
 if (!formData.email) { toast.error('Please enter email'); return; }
 if (!formData.phone) { toast.error('Please enter phone number'); return; }
 if (formData.phone.length !== 10) { 
 toast.error('Phone number must be exactly 10 digits'); 
 return; 
 }
 if (!formData.batchId) { toast.error('Please select a batch'); return; }

 setLoading(true);
 try {
 const payload = {
 name: formData.name,
 email: formData.email,
 phone: formData.phone,
 batchId: parseInt(formData.batchId),
 sportId: formData.sportId ? parseInt(formData.sportId) : undefined,
 message: formData.message || undefined,
 };

 console.log('📤 Sending enquiry payload:', payload);
 console.log('📍 API endpoint:', `${API_BASE}/coaching-enquiries/coach/create`);

 const res = await fetchWithAuth(`${API_BASE}/coaching-enquiries/coach/create`, {
 method: 'POST',
 body: JSON.stringify(payload),
 });

 console.log('📥 Response status:', res.status);

 if (res.ok) {
 const result = await res.json();
 console.log('✅ Success response:', result);
 toast.success('Enquiry sent to admin successfully');
 setIsFormOpen(false);
 resetForm();
 // Refresh enquiries
 fetchDashboardData();
 } else {
 const err = await res.json().catch(() => ({}));
 console.error('❌ Error response:', err);
 toast.error(err.message || 'Failed to create enquiry');
 }
 } catch (err: any) {
 console.error('❌ Enquiry submit error:', err);
 toast.error(err.message || 'Failed to send enquiry');
 } finally {
 setLoading(false);
 }
 };

 const getStatusColor = (status: string) => {
 switch (status) {
 case 'In Progress': return 'bg-green-100 text-green-700';
 case 'Upcoming': return 'bg-blue-100 text-blue-700';
 case 'Completed': return 'bg-gray-100 text-gray-700';
 default: return 'bg-slate-100 text-slate-700';
 }
 };

 const getEnquiryStatusColor = (status: string) => {
 switch (status) {
 case 'Pending': return 'bg-amber-100 text-amber-700';
 case 'Reviewed': return 'bg-blue-100 text-blue-700';
 case 'Contacted': return 'bg-purple-100 text-purple-700';
 case 'Approved': return 'bg-green-100 text-green-700';
 case 'Rejected': return 'bg-red-100 text-red-700';
 default: return 'bg-slate-100 text-slate-700';
 }
 };

 return (
 <UnifiedDashboardLayout
 sidebar={<RoleBasedSidebar />}
 navbar={<DashboardNavbar pageTitle="Coach Dashboard"/>}
 >
 <div className="space-y-6">
 {/* Welcome Section */}
 <div className="bg-gradient-to-r from-orange-500 to-orange-600 rounded-xl p-8 text-white">
 <div className="flex items-center justify-between flex-wrap gap-4">
 <div>
 <h1 className="text-3xl mb-2">Coach Dashboard</h1>
 <p className="text-orange-100">Manage students, attendance, and track performance</p>
 </div>
 <div className="flex gap-3">
 <button
 onClick={fetchDashboardData}
 disabled={dataLoading}
 className="bg-white/20 hover:bg-white/30 text-white px-4 py-3 rounded-xl text-sm transition-all flex items-center gap-2"
 >
 <RefreshCw size={18} className={dataLoading ? 'animate-spin' : ''} />
 Refresh
 </button>
 <button
 onClick={() => setIsFormOpen(true)}
 className="bg-white hover:bg-orange-50 text-orange-600 px-6 py-3 rounded-xl text-sm transition-all shadow-lg hover:shadow-xl active:scale-95 flex items-center gap-2"
 >
 <Plus size={18} />
 SEND ENQUIRY
 </button>
 </div>
 </div>
 </div>

 {/* Loading State */}
 {dataLoading ? (
 <div className="flex items-center justify-center py-20">
 <Loader2 size={40} className="animate-spin text-orange-500" />
 </div>
 ) : (
 <>
 {/* Quick Stats - Tier 3 Premium Design */}
 <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
 {/* My Students */}
 <div className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-premium transition-all relative overflow-hidden group">
 {/* Left accent stripe - Tier 3 design */}
 <div className="absolute left-0 top-0 bottom-0 w-1 bg-[#2563EB]"/>
 
 {/* Mesh gradient top-right corner - Tier 3 design */}
 <div 
 className="absolute top-0 right-0 w-32 h-32 opacity-10 pointer-events-none transition-opacity group-hover:opacity-15"
 style={{ background: 'radial-gradient(circle at top right, #2563EB, transparent)' }}
 />
 
 <div className="relative z-10">
 <div className="flex items-center justify-between mb-3">
 <div className="p-2.5 rounded-xl bg-blue-100 text-blue-600">
 <Users className="w-5 h-5"/>
 </div>
 </div>
 
 {/* Barlow 700 for stat numbers - Tier 3 design */}
 <p className="font-barlow font-700 text-4xl text-slate-900 leading-none mb-1">{stats.totalStudents}</p>
 <p className="text-xs text-slate-500 uppercase tracking-wider">My Students</p>
 </div>
 </div>

 {/* Present Today */}
 <div className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-premium transition-all relative overflow-hidden group">
 {/* Left accent stripe - Tier 3 design */}
 <div className="absolute left-0 top-0 bottom-0 w-1 bg-[#059669]"/>
 
 {/* Mesh gradient top-right corner - Tier 3 design */}
 <div 
 className="absolute top-0 right-0 w-32 h-32 opacity-10 pointer-events-none transition-opacity group-hover:opacity-15"
 style={{ background: 'radial-gradient(circle at top right, #059669, transparent)' }}
 />
 
 <div className="relative z-10">
 <div className="flex items-center justify-between mb-3">
 <div className="p-2.5 rounded-xl bg-green-100 text-green-600">
 <CheckCircle className="w-5 h-5"/>
 </div>
 </div>
 
 {/* Barlow 700 for stat numbers - Tier 3 design */}
 <p className="font-barlow font-700 text-4xl text-slate-900 leading-none mb-1">{stats.presentToday}</p>
 <p className="text-xs text-slate-500 uppercase tracking-wider">Present Today</p>
 </div>
 </div>

 {/* Sessions Today */}
 <div className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-premium transition-all relative overflow-hidden group">
 {/* Left accent stripe - Tier 3 design */}
 <div className="absolute left-0 top-0 bottom-0 w-1 bg-[#FF6B2C]"/>
 
 {/* Mesh gradient top-right corner - Tier 3 design */}
 <div 
 className="absolute top-0 right-0 w-32 h-32 opacity-10 pointer-events-none transition-opacity group-hover:opacity-15"
 style={{ background: 'radial-gradient(circle at top right, #FF6B2C, transparent)' }}
 />
 
 <div className="relative z-10">
 <div className="flex items-center justify-between mb-3">
 <div className="p-2.5 rounded-xl bg-orange-100 text-orange-600">
 <Calendar className="w-5 h-5"/>
 </div>
 </div>
 
 {/* Barlow 700 for stat numbers - Tier 3 design */}
 <p className="font-barlow font-700 text-4xl text-slate-900 leading-none mb-1">{stats.sessionsToday}</p>
 <p className="text-xs text-slate-500 uppercase tracking-wider">Sessions Today</p>
 </div>
 </div>

 {/* Avg Performance */}
 <div className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-premium transition-all relative overflow-hidden group">
 {/* Left accent stripe - Tier 3 design */}
 <div className="absolute left-0 top-0 bottom-0 w-1 bg-[#6C52E8]"/>
 
 {/* Mesh gradient top-right corner - Tier 3 design */}
 <div 
 className="absolute top-0 right-0 w-32 h-32 opacity-10 pointer-events-none transition-opacity group-hover:opacity-15"
 style={{ background: 'radial-gradient(circle at top right, #6C52E8, transparent)' }}
 />
 
 <div className="relative z-10">
 <div className="flex items-center justify-between mb-3">
 <div className="p-2.5 rounded-xl bg-purple-100 text-purple-600">
 <TrendingUp className="w-5 h-5"/>
 </div>
 </div>
 
 {/* Barlow 700 for stat numbers - Tier 3 design */}
 <p className="font-barlow font-700 text-4xl text-slate-900 leading-none mb-1">{stats.avgPerformance}%</p>
 <p className="text-xs text-slate-500 uppercase tracking-wider">Avg Performance</p>
 </div>
 </div>
 </div>

 {/* Today's Schedule */}
 <div className="bg-white rounded-xl border border-border p-6">
 <h2 className="text-xl text-text-dark mb-4">Today's Schedule</h2>
 {todaySchedule.length > 0 ? (
 <div className="space-y-3">
 {todaySchedule.map((session) => (
 <div
 key={session.id}
 className="flex items-center justify-between p-4 bg-slate-50 rounded-lg"
 >
 <div className="flex items-center gap-4">
 <div className="bg-orange-100 text-orange-600 p-3 rounded-lg">
 <Calendar className="w-5 h-5"/>
 </div>
 <div>
 <p className="text-text-dark">{session.batchName}</p>
 <p className="text-sm text-text-muted">
 {session.startTime} - {session.endTime} · {session.court}
 </p>
 <p className="text-xs text-text-muted mt-1">
 {session.studentCount} students · {session.sport?.name}
 </p>
 </div>
 </div>
 <span className={`px-3 py-1 rounded-full text-xs ${getStatusColor(session.status)}`}>
 {session.status}
 </span>
 </div>
 ))}
 </div>
 ) : (
 <p className="text-center text-text-muted py-8">No sessions scheduled for today</p>
 )}
 </div>

 {/* Student Performance + Notifications */}
 <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
 <div className="bg-white rounded-xl border border-border p-6">
 <h2 className="text-xl text-text-dark mb-4">Top Performers</h2>
 {topPerformers.length > 0 ? (
 <div className="space-y-3">
 {topPerformers.map((p) => (
 <div
 key={p.id}
 className={`flex items-center justify-between p-3 bg-${p.color}-50 rounded-lg`}
 >
 <div className="flex items-center gap-3">
 <Award className={`w-5 h-5 text-${p.color}-600`} />
 <div>
 <p className="text-text-dark">{p.name}</p>
 <p className="text-xs text-text-muted">{p.detail}</p>
 </div>
 </div>
 <span className={`text-${p.color}-600`}>{p.performance}%</span>
 </div>
 ))}
 </div>
 ) : (
 <p className="text-center text-text-muted py-8">No performance data available</p>
 )}
 </div>

 <div className="bg-white rounded-xl border border-border p-6">
 <h2 className="text-xl text-text-dark mb-4">Recent Activity</h2>
 {enquiries.length > 0 ? (
 <div className="space-y-3">
 {enquiries.slice(0, 5).map((enquiry) => (
 <div key={enquiry.id} className="flex items-start gap-3 p-3 bg-slate-50 rounded-lg">
 <Bell className="w-5 h-5 text-blue-600 mt-0.5"/>
 <div className="flex-1 min-w-0">
 <p className="text-text-dark text-sm">New coaching enquiry from {enquiry.name}</p>
 <p className="text-xs text-text-muted truncate">
 {enquiry.batch?.name ? `${enquiry.batch.name} · ` : ''}{enquiry.status}
 </p>
 <p className="text-xs text-text-muted mt-1">
 {new Date(enquiry.createdAt).toLocaleDateString('en-IN', {
 day: '2-digit',
 month: 'short',
 year: 'numeric',
 })}
 </p>
 </div>
 </div>
 ))}
 </div>
 ) : (
 <p className="text-center text-text-muted py-8">No recent activity</p>
 )}
 </div>
 </div>

 {/* My Enquiries Section */}
 <div className="bg-white rounded-xl border border-border p-6">
 <div className="flex items-center justify-between mb-4">
 <h2 className="text-xl text-text-dark">My Coaching Enquiries</h2>
 <span className="text-sm text-text-muted">Total: {totalEnquiries} enquiries</span>
 </div>

 {enquiries.length > 0 ? (
 <div className="space-y-3">
 {enquiries.map((enquiry) => (
 <div
 key={enquiry.id}
 className="flex items-center justify-between p-4 bg-slate-50 rounded-lg hover:bg-slate-100 transition-colors"
 >
 <div className="flex-1">
 <div className="flex items-center gap-3 mb-1">
 <p className="text-text-dark">{enquiry.name}</p>
 <span className={`px-2 py-0.5 rounded-full text-[10px] uppercase ${getEnquiryStatusColor(enquiry.status)}`}>
 {enquiry.status}
 </span>
 </div>
 <div className="flex items-center gap-4 text-xs text-text-muted">
 <span>{enquiry.email}</span>
 <span>·</span>
 <span>{enquiry.phone}</span>
 {enquiry.batch?.name && (
 <>
 <span>·</span>
 <span>{enquiry.batch.name}</span>
 </>
 )}
 </div>
 {enquiry.referenceNumber && (
 <p className="text-[10px] text-slate-400 mt-1">
 {enquiry.referenceNumber}
 </p>
 )}
 </div>
 <div className="text-right">
 <p className="text-xs text-text-muted">
 {new Date(enquiry.createdAt).toLocaleDateString('en-IN', {
 day: '2-digit',
 month: 'short',
 year: 'numeric',
 })}
 </p>
 </div>
 </div>
 ))}
 {totalEnquiries > 5 && (
 <div className="text-center pt-2">
 <a
 href="/dashboard/coaching-enquiries"
 className="text-sm text-primary hover:text-primary/80"
 >
 View all {totalEnquiries} enquiries →
 </a>
 </div>
 )}
 </div>
 ) : (
 <div className="text-center py-8">
 <p className="text-text-muted">No enquiries yet</p>
 <p className="text-sm text-text-muted mt-1">
 Click "SEND ENQUIRY" to create your first enquiry
 </p>
 </div>
 )}
 </div>
 </>
 )}
 </div>

 {/* Send Enquiry Form Modal */}
 {isFormOpen && (
 <>
 {/* Backdrop */}
 <div
 className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100]"
 onClick={() => setIsFormOpen(false)}
 />

 {/* Slide-over panel */}
 <div className="fixed right-0 top-0 h-full w-full max-w-2xl bg-white shadow-2xl z-[101] flex flex-col">
 {/* Header */}
 <div className="p-8 border-b border-border flex items-center justify-between shrink-0">
 <div>
 <h2 className="text-2xl text-text-dark tracking-tight">
 Send Enquiry to Admin
 </h2>
 <p className="text-xs text-text-muted uppercase tracking-widest mt-1">
 Submit a new coaching enquiry to admin
 </p>
 </div>
 <button
 onClick={() => setIsFormOpen(false)}
 className="p-2 hover:bg-slate-100 rounded-xl text-slate-400 transition-colors"
 >
 <X size={22} />
 </button>
 </div>

 {/* Form body */}
 <div className="flex-1 overflow-y-auto p-8 space-y-6">
 <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
 {/* Student Name */}
 <div className="space-y-2 md:col-span-2">
 <label className="text-[11px] text-text-muted uppercase tracking-widest block">
 Student Name *
 </label>
 <div className="relative">
 <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={16} />
 <input
 type="text"
 name="name"
 value={formData.name}
 onChange={handleInputChange}
 placeholder="Enter student full name"
 className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl focus:ring-2 focus:ring-primary/20 focus:bg-white focus:border-primary transition-all text-sm"
 />
 </div>
 </div>

 {/* Phone */}
 <div className="space-y-2">
 <label className="text-[11px] text-text-muted uppercase tracking-widest block">
 Phone *
 </label>
 <div className="relative">
 <Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={16} />
 <input
 type="tel"
 name="phone"
 value={formData.phone}
 onChange={handleInputChange}
 placeholder="Enter 10-digit mobile number"
 maxLength={10}
 pattern="[0-9]{10}"
 className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl focus:ring-2 focus:ring-primary/20 focus:bg-white focus:border-primary transition-all text-sm"
 />
 {formData.phone && formData.phone.length < 10 && (
 <p className="text-xs text-red-500 mt-1">
 {10 - formData.phone.length} more digit{10 - formData.phone.length !== 1 ? 's' : ''} required
 </p>
 )}
 </div>
 </div>

 {/* Email */}
 <div className="space-y-2">
 <label className="text-[11px] text-text-muted uppercase tracking-widest block">
 Email *
 </label>
 <div className="relative">
 <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={16} />
 <input
 type="email"
 name="email"
 value={formData.email}
 onChange={handleInputChange}
 placeholder="Enter email address"
 className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl focus:ring-2 focus:ring-primary/20 focus:bg-white focus:border-primary transition-all text-sm"
 />
 </div>
 </div>

 {/* Sport */}
 <div className="space-y-2">
 <label className="text-[11px] text-text-muted uppercase tracking-widest block">
 Select Sport
 </label>
 <select
 name="sportId"
 value={formData.sportId}
 onChange={handleInputChange}
 className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl focus:ring-2 focus:ring-primary/20 focus:bg-white focus:border-primary transition-all text-sm"
 >
 <option value="">-- Select Sport --</option>
 {sports.map((sport) => (
 <option key={sport.id} value={sport.id}>
 {sport.name}
 </option>
 ))}
 </select>
 </div>

 {/* Batch */}
 <div className="space-y-2">
 <label className="text-[11px] text-text-muted uppercase tracking-widest block">
 Select Batch *
 </label>
 <select
 name="batchId"
 value={formData.batchId}
 onChange={handleInputChange}
 className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl focus:ring-2 focus:ring-primary/20 focus:bg-white focus:border-primary transition-all text-sm"
 >
 <option value="">-- Select Batch --</option>
 {programs.map((program) => (
 <option key={program.id} value={program.id}>
 {program.name}
 </option>
 ))}
 </select>
 </div>

 {/* Message */}
 <div className="space-y-2 md:col-span-2">
 <label className="text-[11px] text-text-muted uppercase tracking-widest block">
 Message
 </label>
 <textarea
 name="message"
 value={formData.message}
 onChange={handleInputChange}
 placeholder="Enter any additional message or requirements"
 rows={4}
 className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl focus:ring-2 focus:ring-primary/20 focus:bg-white focus:border-primary transition-all text-sm resize-none"
 />
 </div>
 </div>
 </div>

 {/* Footer actions */}
 <div className="p-8 bg-slate-50 border-t border-border flex items-center gap-4 shrink-0">
 <button
 type="button"
 onClick={handleSubmit}
 disabled={loading}
 className="flex-1 bg-primary hover:bg-primary/90 text-white px-6 py-3.5 rounded-2xl text-[11px] uppercase tracking-[0.2em] shadow-xl shadow-primary/20 transition-all flex items-center justify-center gap-2 active:scale-95 disabled:opacity-50"
 >
 {loading ? 'Sending...' : 'Send Enquiry'}
 </button>
 <button
 type="button"
 onClick={() => { setIsFormOpen(false); resetForm(); }}
 className="flex-1 bg-white border border-border text-text-muted px-6 py-3.5 rounded-2xl text-[11px] uppercase tracking-[0.2em] transition-all hover:bg-slate-50 flex items-center justify-center gap-2"
 >
 Cancel
 </button>
 </div>
 </div>
 </>
 )}
 </UnifiedDashboardLayout>
 );
}

