import React, { useState, useEffect } from 'react';
import { Calendar, DollarSign, CheckCircle, Loader2, IndianRupee, Trophy, Clock } from 'lucide-react';
import { UnifiedDashboardLayout } from '../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../lib/fetchWithAuth';
import toast from 'react-hot-toast';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

interface DashboardStats {
  todayBookings: number;
  totalRevenue: number;
  upcomingBookings: number;
}

interface RecentBooking {
  id: number;
  user?: { name: string };
  sport?: { name: string };
  court?: { name: string };
  startTime: string;
  totalAmount: number;
  createdAt: string;
}

/**
 * EmployeeDashboard - Overview page for the EMPLOYEE role
 *
 * Displays key operational stats and recent activity for employees.
 * Wrapped with UnifiedDashboardLayout using RoleBasedSidebar and DashboardNavbar.
 *
 * Validates: Requirements 4.1, 8.1
 */
export default function EmployeeDashboard() {
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<DashboardStats>({
    todayBookings: 0,
    totalRevenue: 0,
    upcomingBookings: 0,
  });
  const [recentBookings, setRecentBookings] = useState<RecentBooking[]>([]);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    setLoading(true);
    try {
      // Fetch dashboard overview stats
      const statsRes = await fetchWithAuth(`${API_BASE}/reports/overview`);
      if (statsRes.ok) {
        const statsData = await statsRes.json();
        setStats({
          todayBookings: statsData.data.todayBookings || 0,
          totalRevenue: statsData.data.totalRevenue || 0,
          upcomingBookings: statsData.data.upcomingBookings || 0,
        });
      }

      // Fetch recent bookings
      const bookingsRes = await fetchWithAuth(`${API_BASE}/bookings?page=1&limit=5&sortBy=createdAt&sortOrder=DESC`);
      if (bookingsRes.ok) {
        const bookingsData = await bookingsRes.json();
        const bookings = bookingsData.bookings || bookingsData.data || [];
        setRecentBookings(bookings.slice(0, 5));
      }
    } catch (error: any) {
      console.error('Failed to load dashboard data:', error);
      toast.error('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (timeStr: string) => {
    if (!timeStr) return '—';
    const [h, m] = timeStr.split(':').map(Number);
    const ampm = h >= 12 ? 'PM' : 'AM';
    return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${ampm}`;
  };

  const getTimeAgo = (dateStr: string) => {
    const now = new Date();
    const created = new Date(dateStr);
    const diffInMinutes = Math.floor((now.getTime() - created.getTime()) / (1000 * 60));
    
    if (diffInMinutes < 1) return 'Just now';
    if (diffInMinutes < 60) return `${diffInMinutes} min${diffInMinutes > 1 ? 's' : ''} ago`;
    if (diffInMinutes < 1440) {
      const hours = Math.floor(diffInMinutes / 60);
      return `${hours} hour${hours > 1 ? 's' : ''} ago`;
    }
    const days = Math.floor(diffInMinutes / 1440);
    return `${days} day${days > 1 ? 's' : ''} ago`;
  };
 return (
 <UnifiedDashboardLayout
 sidebar={<RoleBasedSidebar />}
 navbar={<DashboardNavbar pageTitle="Employee Dashboard"/>}
 >
 <div className="space-y-6">
 {/* Welcome Section */}
 <div className="bg-gradient-to-r from-green-500 to-green-600 rounded-xl p-8 text-white">
 <h1 className="text-3xl mb-2">Employee Dashboard</h1>
 <p className="text-green-100">Manage bookings, users, and operations</p>
 </div>

 {/* Quick Stats */}
 {loading ? (
 <div className="flex items-center justify-center py-12">
 <Loader2 size={32} className="animate-spin text-blue-600" />
 </div>
 ) : (
 <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
 {/* Today's Bookings */}
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
 <Calendar className="w-5 h-5"/>
 </div>
 </div>
 
 {/* Barlow 700 for stat numbers - Tier 3 design */}
 <p className="font-barlow font-700 text-4xl text-slate-900 leading-none mb-1">{stats.todayBookings}</p>
 <p className="text-xs text-slate-500 uppercase tracking-wider">Today's Bookings</p>
 </div>
 </div>

 {/* Total Revenue */}
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
 <IndianRupee className="w-5 h-5"/>
 </div>
 </div>
 
 {/* Barlow 700 for stat numbers - Tier 3 design */}
 <p className="font-barlow font-700 text-4xl text-slate-900 leading-none mb-1">
 ₹{stats.totalRevenue.toLocaleString('en-IN')}
 </p>
 <p className="text-xs text-slate-500 uppercase tracking-wider">Total Revenue</p>
 </div>
 </div>

 {/* Upcoming Bookings */}
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
 <CheckCircle className="w-5 h-5"/>
 </div>
 </div>
 
 {/* Barlow 700 for stat numbers - Tier 3 design */}
 <p className="font-barlow font-700 text-4xl text-slate-900 leading-none mb-1">{stats.upcomingBookings}</p>
 <p className="text-xs text-slate-500 uppercase tracking-wider">Upcoming Bookings</p>
 </div>
 </div>
 </div>
 )}

 {/* Recent Activity */}
 <div className="bg-white rounded-xl border border-border p-6">
 <h2 className="text-xl text-text-dark mb-4">Recent Bookings</h2>
 {loading ? (
 <div className="flex items-center justify-center py-8">
 <Loader2 size={24} className="animate-spin text-blue-600" />
 </div>
 ) : recentBookings.length === 0 ? (
 <div className="text-center py-8 text-text-muted">
 <Calendar size={40} className="mx-auto mb-2 text-slate-300" />
 <p>No recent bookings found</p>
 </div>
 ) : (
 <div className="space-y-3">
 {recentBookings.map((booking) => (
 <div key={booking.id} className="flex items-center justify-between p-4 bg-slate-50 rounded-lg hover:bg-slate-100 transition-colors">
 <div className="flex-1">
 <p className="text-text-dark">
 New booking by {booking.user?.name || 'Unknown User'}
 </p>
 <div className="flex items-center gap-3 mt-1">
 <span className="text-sm text-text-muted flex items-center gap-1">
 <Trophy size={12} className="text-blue-600" />
 {booking.sport?.name || 'Sport'}
 </span>
 <span className="text-sm text-text-muted flex items-center gap-1">
 <Clock size={12} className="text-slate-400" />
 {formatTime(booking.startTime)}
 </span>
 <span className="text-sm text-green-600 flex items-center gap-1">
 <IndianRupee size={12} />
 {booking.totalAmount?.toLocaleString('en-IN') || 0}
 </span>
 </div>
 </div>
 <span className="text-xs text-text-muted whitespace-nowrap ml-4">
 {getTimeAgo(booking.createdAt)}
 </span>
 </div>
 ))}
 </div>
 )}
 </div>
 </div>
 </UnifiedDashboardLayout>
 );
}

