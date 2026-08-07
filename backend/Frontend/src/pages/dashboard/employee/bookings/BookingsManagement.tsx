import React, { useState, useEffect } from 'react';
import {
  Eye, Trash2, Calendar, Clock, Globe, Trophy,
  CreditCard, CheckCircle, XCircle, AlertCircle,
  Filter, X, IndianRupee, MapPin, User, Phone,
  Mail, Loader2, RefreshCw, Edit, Save, QrCode, Users,
  ChevronLeft, ChevronRight,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import toast from 'react-hot-toast';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

// Utility function
const cn = (...classes: (string | boolean | undefined)[]) => classes.filter(Boolean).join(' ');

// ── Types ─────────────────────────────────────────────────────────────────────
interface Booking {
  id: number;
  userId: number;
  sportId: number;
  courtId: number;
  date: string;
  startTime: string;
  endTime: string;
  bookingSource: string;
  paymentStatus: string;
  bookingStatus: string;
  totalAmount: number;
  transactionId?: string;
  passCode?: string;
  qrCode?: string;
  maxPersons?: number | null;
  notes?: string;
  /** Per-booking display name set by staff; null falls back to the account name. */
  customerName?: string | null;
  movedFromCourtId?: number | null;
  movedAt?: string | null;
  moveReason?: string | null;
  user?: { id: number; name: string; email: string; phone_number: string };
  sport?: { id: number; name: string; category: string };
  court?: { id: number; name: string; hourlyRate: string; SportComplex?: { id: number; name: string; city: string } };
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const fmt12 = (t: string) => {
  if (!t) return '—';
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${ampm}`;
};

const formatDate = (dateStr: string) => {
  if (!dateStr) return '—';
  const date = new Date(dateStr);
  const day = String(date.getDate()).padStart(2, '0');
  const month = date.toLocaleDateString('en-US', { month: 'short' });
  const year = date.getFullYear();
  return `${day} ${month} ${year}`;
};

/**
 * Name to show for a booking: the per-booking name when staff set one,
 * otherwise the linked account's name.
 */
const bookingName = (b: Booking) => b.customerName?.trim() || b.user?.name || '—';

const BOOKING_STATUS_STYLE: Record<string, string> = {
  Confirmed: 'bg-green-50 text-green-700 border-green-200',
  Completed: 'bg-slate-50 text-slate-600 border-slate-200',
  Pending:   'bg-blue-50 text-blue-700 border-blue-200',
  Cancelled: 'bg-red-50 text-red-600 border-red-200',
};

const PAYMENT_STATUS_STYLE: Record<string, string> = {
  Paid:     'bg-emerald-50 text-emerald-700 border-emerald-200',
  Pending:  'bg-amber-50 text-amber-700 border-amber-200',
  Failed:   'bg-red-50 text-red-600 border-red-200',
  Refunded: 'bg-purple-50 text-purple-700 border-purple-200',
};

// ── Component ─────────────────────────────────────────────────────────────────
export default function BookingsManagement() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [sports, setSports] = useState<any[]>([]);
  // Courts power the editable Sport/Court pickers in the edit form. Both lists
  // are complex-scoped by the API, so an employee can only move a booking to a
  // court in their own complex.
  const [courts, setCourts] = useState<any[]>([]);

  const pageSize = 10;

  // Filters
  const [filterDate, setFilterDate]       = useState('');
  const [filterSport, setFilterSport]     = useState('');
  const [filterPayment, setFilterPayment] = useState('');
  const [filterBooking, setFilterBooking] = useState('');

  // Drawer
  const [viewBooking, setViewBooking] = useState<Booking | null>(null);
  const [updating, setUpdating]       = useState(false);
  
  // Edit functionality
  const [editingBooking, setEditingBooking] = useState<Booking | null>(null);
  const [isEditFormOpen, setIsEditFormOpen] = useState(false);
  const [editFormData, setEditFormData] = useState({
    userName: '',
    date: '',
    startTime: '',
    endTime: '',
    totalAmount: '',
    notes: '',
    bookingStatus: 'Pending',
    paymentStatus: 'Pending',
    sportId: '',
    courtId: '',
  });

  const load = async (page = 1) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(page),
        limit: String(pageSize),
      });
      if (filterDate) params.set('date', filterDate);
      if (filterSport) params.set('sportId', filterSport);
      if (filterPayment) params.set('paymentStatus', filterPayment);
      if (filterBooking) params.set('bookingStatus', filterBooking);

      const res = await fetchWithAuth(`${API_BASE}/bookings?${params}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      
      const data = await res.json();
      
      // Handle both old and new API response formats
      const bookingsData = data.bookings || data.data || [];
      const total = data.total || data.pagination?.totalCount || 0;
      const pages = data.totalPages || data.pagination?.totalPages || 1;
      
      setBookings(bookingsData);
      setTotalCount(total);
      setTotalPages(pages);
      setCurrentPage(page);
    } catch (err: any) {
      console.error('Failed to load bookings:', err);
      setError('Failed to load bookings. Please try again.');
      toast.error('Failed to load bookings');
    } finally {
      setLoading(false);
    }
  };

  const loadSports = async () => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/sports?page=1&limit=100`);
      if (res.ok) {
        const data = await res.json();
        setSports(data.sports || data.data || []);
      }
    } catch (err) {
      console.error('Failed to load sports:', err);
    }
  };

  useEffect(() => { load(1); }, [filterDate, filterSport, filterPayment, filterBooking]);
  const loadCourts = async () => {
    try {
      const res = await fetchWithAuth(`${API_BASE}/courts?limit=200`);
      if (res.ok) {
        const data = await res.json();
        setCourts(Array.isArray(data.data) ? data.data : []);
      }
    } catch (err) {
      console.error('Failed to load courts:', err);
    }
  };

  useEffect(() => { loadSports(); loadCourts(); }, []);

  useEffect(() => {
    if (error) toast.error(error);
  }, [error]);

  const handleDelete = async (b: Booking) => {
    if (!confirm(`Delete booking #${b.id} for ${b.user?.name ?? 'user'}?`)) return;
    try {
      const res = await fetchWithAuth(`${API_BASE}/bookings/${b.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Delete failed');
      toast.success('Booking deleted');
      load(currentPage);
    } catch (e: any) { 
      toast.error(e.message || 'Delete failed'); 
    }
  };

  const handleUpdatePayment = async (id: number, paymentStatus: string) => {
    setUpdating(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/bookings/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ paymentStatus }),
      });
      if (!res.ok) throw new Error('Update failed');
      toast.success(`Marked as ${paymentStatus}`);
      setViewBooking((prev) => prev ? { ...prev, paymentStatus } : null);
      load(currentPage);
    } catch (e: any) { 
      toast.error(e.message || 'Update failed'); 
    }
    finally { setUpdating(false); }
  };

  const handleUpdateBookingStatus = async (id: number, bookingStatus: string) => {
    setUpdating(true);
    try {
      const res = await fetchWithAuth(`${API_BASE}/bookings/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ bookingStatus }),
      });
      if (!res.ok) throw new Error('Update failed');
      toast.success(`Booking ${bookingStatus}`);
      setViewBooking((prev) => prev ? { ...prev, bookingStatus } : null);
      load(currentPage);
    } catch (e: any) { 
      toast.error(e.message || 'Update failed'); 
    }
    finally { setUpdating(false); }
  };

  const handleEdit = (booking: Booking) => {
    setEditingBooking(booking);
    setEditFormData({
      userName: booking.customerName?.trim() || booking.user?.name || '',
      date: booking.date,
      startTime: booking.startTime,
      endTime: booking.endTime,
      totalAmount: String(booking.totalAmount),
      notes: booking.notes || '',
      bookingStatus: booking.bookingStatus || 'Pending',
      paymentStatus: booking.paymentStatus || 'Pending',
      sportId: booking.sportId != null ? String(booking.sportId) : '',
      courtId: booking.courtId != null ? String(booking.courtId) : '',
    });
    setIsEditFormOpen(true);
  };

  const handleEditSubmit = async () => {
    if (!editingBooking) return;

    if (!editFormData.userName?.trim()) {
      toast.error('User name is required');
      return;
    }

    if (!editFormData.date || !editFormData.startTime || !editFormData.endTime) {
      toast.error('Date and time are required');
      return;
    }

    setUpdating(true);
    try {
      // Update the booking using PUT method.
      // The name is stored ON THE BOOKING (customerName), not on the user
      // account: Huddle/KheloMore bookings all share one account, so renaming
      // the account would rename every one of their bookings at once.
      const bookingRes = await fetchWithAuth(`${API_BASE}/bookings/${editingBooking.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          customerName: editFormData.userName.trim(),
          date: editFormData.date,
          startTime: editFormData.startTime,
          endTime: editFormData.endTime,
          totalAmount: editFormData.totalAmount ? parseFloat(editFormData.totalAmount) : editingBooking.totalAmount,
          notes: editFormData.notes || undefined,
          bookingStatus: editFormData.bookingStatus,
          paymentStatus: editFormData.paymentStatus,
          sportId: editFormData.sportId ? Number(editFormData.sportId) : undefined,
          courtId: editFormData.courtId ? Number(editFormData.courtId) : undefined,
        }),
      });
      
      if (!bookingRes.ok) {
        const errorData = await bookingRes.json().catch(() => ({}));
        throw new Error(errorData.message || `HTTP ${bookingRes.status}: Failed to update booking`);
      }
      
      toast.success('Booking updated successfully');
      setIsEditFormOpen(false);
      setEditingBooking(null);
      load(currentPage);
    } catch (e: any) {
      console.error('Update booking error:', e);
      toast.error(e.message || 'Failed to update booking');
    } finally {
      setUpdating(false);
    }
  };

  // ── Table columns ────────────────────────────────────────────────────────────
  const renderTable = () => {
    if (loading) {
      return (
        <div className="flex items-center justify-center h-64 bg-white rounded-2xl border border-slate-200">
          <Loader2 size={32} className="animate-spin text-blue-600" />
        </div>
      );
    }

    if (bookings.length === 0) {
      return (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center mt-4">
          <Calendar size={40} className="text-slate-300 mx-auto mb-3" />
          <p className="font-semibold text-slate-900 mb-1">No bookings found</p>
          <p className="text-slate-500 text-sm">Try adjusting your filters.</p>
        </div>
      );
    }

    return (
      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1200px]">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50">
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider w-14 text-center">#</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">User</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Sport / Court</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Date & Time</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Amount</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Source</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Booking</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Payment</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Pass</th>
                <th className="text-right px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider w-32">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {bookings.map((b, idx) => (
                <tr key={b.id} className="hover:bg-slate-50 transition-colors">
                  <td className="px-4 py-3 text-slate-500 text-center">
                    <span className="font-mono text-xs">#{b.id}</span>
                  </td>
                  <td className="px-4 py-3">
                    <div>
                      <p className="font-bold text-slate-900 text-sm">{bookingName(b)}</p>
                      <p className="text-[10px] text-slate-500">{b.user?.email ?? ''}</p>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <div>
                      <div className="flex items-center gap-1.5">
                        <Trophy size={13} className="text-blue-600" />
                        <span className="font-semibold text-sm text-slate-900">{b.sport?.name ?? '—'}</span>
                      </div>
                      <p className="text-[10px] text-slate-500 mt-0.5">{b.court?.name ?? '—'}</p>
                      {b.movedFromCourtId && (
                        <span
                          className="inline-block mt-0.5 px-1.5 py-0.5 rounded bg-blue-50 text-blue-700 text-[9px] font-bold uppercase tracking-wide border border-blue-100"
                          title={`Auto-reassigned from court #${b.movedFromCourtId}${b.movedAt ? ' on ' + new Date(b.movedAt).toLocaleString() : ''}${b.moveReason ? ' (' + b.moveReason + ')' : ''}`}
                        >
                          ↪ Reassigned
                        </span>
                      )}
                      {b.court?.SportComplex && (
                        <p className="text-[10px] text-slate-500 flex items-center gap-0.5">
                          <MapPin size={9} /> {b.court.SportComplex.name}
                        </p>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="space-y-1">
                      <div className="flex items-center gap-1.5 text-sm font-semibold text-slate-900">
                        <Calendar size={14} className="text-slate-400" />
                        {formatDate(b.date)}
                      </div>
                      <div className="flex items-center gap-1.5 text-xs text-slate-600">
                        <Clock size={12} className="text-slate-400" />
                        {fmt12(b.startTime)} – {fmt12(b.endTime)}
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1 font-bold text-slate-900">
                      <IndianRupee size={13} className="text-blue-600" />
                      {parseFloat(String(b.totalAmount || 0)).toLocaleString('en-IN')}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className="flex items-center gap-1 text-xs font-medium text-slate-500">
                      <Globe size={12} /> {b.bookingSource}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={cn('px-2 py-1 rounded-lg text-[10px] font-bold border',
                      BOOKING_STATUS_STYLE[b.bookingStatus] ?? 'bg-slate-50 text-slate-600 border-slate-200')}>
                      {b.bookingStatus ?? '—'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={cn('px-2 py-1 rounded-lg text-[10px] font-bold border',
                      PAYMENT_STATUS_STYLE[b.paymentStatus] ?? 'bg-slate-50 text-slate-600 border-slate-200')}>
                      {b.paymentStatus}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {b.qrCode ? (
                      <button
                        onClick={() => setViewBooking(b as Booking)}
                        className="flex items-center gap-1 text-[10px] font-bold text-blue-600 bg-blue-50 px-2 py-1 rounded-lg hover:bg-blue-100 transition-colors"
                        title="View QR Pass"
                      >
                        <QrCode size={12} /> QR Pass
                      </button>
                    ) : (
                      <span className="text-[10px] text-slate-400">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-end gap-2">
                      <button onClick={() => setViewBooking(b as Booking)}
                        className="p-1.5 bg-blue-50 hover:bg-blue-100 text-blue-600 rounded-lg transition-colors" title="View">
                        <Eye size={14} />
                      </button>
                      <button onClick={() => handleEdit(b as Booking)}
                        className="p-1.5 bg-slate-50 hover:bg-slate-100 text-slate-600 rounded-lg transition-colors" title="Edit">
                        <Edit size={14} />
                      </button>
                      <button onClick={() => handleDelete(b as Booking)}
                        className="p-1.5 bg-red-50 hover:bg-red-100 text-red-600 rounded-lg transition-colors" title="Delete">
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    );
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Bookings Management" />}
    >
      <div className="max-w-[1500px] mx-auto min-h-full space-y-6">

        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
          <div>
            <p className="text-[10px] text-slate-500 font-bold uppercase tracking-widest mb-1">Booking Management</p>
            <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">Bookings</h1>
            <p className="text-xs sm:text-sm text-slate-500 mt-1">Total: {totalCount} bookings</p>
          </div>
          <button onClick={() => load(currentPage)}
            className="flex items-center justify-center gap-2 bg-white border border-slate-200 text-slate-600 px-4 py-2.5 rounded-lg text-sm font-bold hover:bg-slate-50 transition-all w-full sm:w-auto">
            <RefreshCw size={16} /> Refresh
          </button>
        </div>

        {/* Filters */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <div className="relative">
            <Calendar size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
            <input type="date" value={filterDate} onChange={(e) => setFilterDate(e.target.value)}
              className="w-full pl-8 pr-3 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all shadow-sm" />
          </div>
          <div className="relative">
            <Filter size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
            <select value={filterSport} onChange={(e) => setFilterSport(e.target.value)}
              className="w-full pl-8 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all appearance-none cursor-pointer shadow-sm">
              <option value="">All Sports</option>
              {sports.map((s) => <option key={s.id} value={String(s.id)}>{s.name}</option>)}
            </select>
          </div>
          <div className="relative">
            <Filter size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
            <select value={filterPayment} onChange={(e) => setFilterPayment(e.target.value)}
              className="w-full pl-8 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all appearance-none cursor-pointer shadow-sm">
              <option value="">All Payments</option>
              {['Pending', 'Paid', 'Failed', 'Refunded'].map((s) => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>
          <div className="relative">
            <Filter size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
            <select value={filterBooking} onChange={(e) => setFilterBooking(e.target.value)}
              className="w-full pl-8 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all appearance-none cursor-pointer shadow-sm">
              <option value="">All Statuses</option>
              {['Confirmed', 'Pending', 'Completed', 'Cancelled'].map((s) => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>
          {(filterDate || filterSport || filterPayment || filterBooking) && (
            <button onClick={() => { setFilterDate(''); setFilterSport(''); setFilterPayment(''); setFilterBooking(''); }}
              className="flex items-center justify-center gap-1 text-xs font-bold text-red-500 hover:text-red-700 transition-colors sm:col-span-2 lg:col-span-4">
              <X size={13} /> Clear filters
            </button>
          )}
        </div>

        {/* Table */}
        {renderTable()}

        {/* Pagination */}
        {!loading && totalPages > 1 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
            <p className="text-xs text-slate-500">Page {currentPage} of {totalPages}</p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => load(currentPage - 1)}
                disabled={currentPage <= 1}
                className="p-2 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-blue-600 hover:border-blue-600 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
              >
                <ChevronLeft size={16} />
              </button>
              <button
                onClick={() => load(currentPage + 1)}
                disabled={currentPage >= totalPages}
                className="p-2 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-blue-600 hover:border-blue-600 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ── View / Manage Drawer ── */}
      <AnimatePresence>
        {viewBooking && (
          <>
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setViewBooking(null)}
              className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-100" />

            <motion.div
              initial={{ x: '100%' }} animate={{ x: 0 }} exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="fixed right-0 top-0 h-full w-full max-w-lg bg-white shadow-2xl z-101 flex flex-col">

              {/* Drawer header */}
              <div className="p-6 border-b border-border flex items-center justify-between shrink-0">
                <div>
                  <h2 className="text-xl font-black text-text-dark">Booking Details</h2>
                  <p className="text-xs text-text-muted font-mono mt-0.5">
                    #NSC-{String(viewBooking.id).padStart(6, '0')}
                  </p>
                </div>
                <button onClick={() => setViewBooking(null)}
                  className="p-2 hover:bg-slate-100 rounded-xl text-slate-400 transition-colors">
                  <X size={20} />
                </button>
              </div>

              {/* Drawer body */}
              <div className="flex-1 overflow-y-auto p-6 space-y-5">

                {/* Status badges */}
                <div className="flex items-center gap-3 flex-wrap">
                  <span className={cn('px-3 py-1.5 rounded-xl text-xs font-bold border',
                    BOOKING_STATUS_STYLE[viewBooking.bookingStatus] ?? 'bg-slate-50 text-slate-600 border-slate-200')}>
                    Booking: {viewBooking.bookingStatus}
                  </span>
                  <span className={cn('px-3 py-1.5 rounded-xl text-xs font-bold border',
                    PAYMENT_STATUS_STYLE[viewBooking.paymentStatus] ?? 'bg-slate-50 text-slate-600 border-slate-200')}>
                    Payment: {viewBooking.paymentStatus}
                  </span>
                </div>

                {/* User */}
                <div className="bg-slate-50 rounded-2xl p-4 space-y-2">
                  <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">Customer</p>
                  <div className="flex items-center gap-2 text-sm">
                    <User size={14} className="text-primary" />
                    <span className="font-semibold text-text-dark">{bookingName(viewBooking)}</span>
                  </div>
                  {viewBooking.user?.email && (
                    <div className="flex items-center gap-2 text-sm text-text-muted">
                      <Mail size={14} /> {viewBooking.user.email}
                    </div>
                  )}
                  {viewBooking.user?.phone_number && (
                    <div className="flex items-center gap-2 text-sm text-text-muted">
                      <Phone size={14} /> {viewBooking.user.phone_number}
                    </div>
                  )}
                </div>

                {/* Booking details */}
                <div className="bg-slate-50 rounded-2xl p-4 space-y-2">
                  <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-3">Booking Info</p>
                  <div className="grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <p className="text-[10px] text-text-muted uppercase font-bold">Sport</p>
                      <p className="font-semibold text-text-dark flex items-center gap-1 mt-0.5">
                        <Trophy size={13} className="text-primary" /> {viewBooking.sport?.name ?? '—'}
                      </p>
                    </div>
                    <div>
                      <p className="text-[10px] text-text-muted uppercase font-bold">Court</p>
                      <p className="font-semibold text-text-dark mt-0.5">{viewBooking.court?.name ?? '—'}</p>
                    </div>
                    <div>
                      <p className="text-[10px] text-text-muted uppercase font-bold">Venue</p>
                      <p className="font-semibold text-text-dark flex items-center gap-1 mt-0.5">
                        <MapPin size={12} className="text-primary" />
                        {viewBooking.court?.SportComplex?.name ?? '—'}
                      </p>
                    </div>
                    <div>
                      <p className="text-[10px] text-text-muted uppercase font-bold">Source</p>
                      <p className="font-semibold text-text-dark flex items-center gap-1 mt-0.5">
                        <Globe size={12} /> {viewBooking.bookingSource}
                      </p>
                    </div>
                    <div>
                      <p className="text-[10px] text-text-muted uppercase font-bold">Date</p>
                      <p className="font-semibold text-text-dark flex items-center gap-1 mt-0.5">
                        <Calendar size={12} /> {viewBooking.date}
                      </p>
                    </div>
                    <div>
                      <p className="text-[10px] text-text-muted uppercase font-bold">Time</p>
                      <p className="font-semibold text-text-dark flex items-center gap-1 mt-0.5">
                        <Clock size={12} /> {fmt12(viewBooking.startTime)} – {fmt12(viewBooking.endTime)}
                      </p>
                    </div>
                    <div>
                      <p className="text-[10px] text-text-muted uppercase font-bold">Amount</p>
                      <p className="font-bold text-text-dark flex items-center gap-1 mt-0.5">
                        <IndianRupee size={12} className="text-primary" />
                        {parseFloat(String(viewBooking.totalAmount || 0)).toLocaleString('en-IN')}
                      </p>
                    </div>
                    {viewBooking.transactionId && (
                      <div>
                        <p className="text-[10px] text-text-muted uppercase font-bold">Transaction ID</p>
                        <p className="font-mono text-xs text-text-dark mt-0.5">{viewBooking.transactionId}</p>
                      </div>
                    )}
                  </div>
                  {viewBooking.notes && (
                    <div className="pt-3 border-t border-border">
                      <p className="text-[10px] text-text-muted uppercase font-bold mb-1">Notes</p>
                      <p className="text-sm text-text-dark">{viewBooking.notes}</p>
                    </div>
                  )}
                </div>

                {/* ── QR Pass ── */}
                {viewBooking.qrCode && (
                  <div className="bg-slate-50 rounded-2xl p-4">
                    <p className="text-[10px] font-black text-text-muted uppercase tracking-widest mb-4">
                      Booking Pass QR
                    </p>
                    <div className="flex flex-col items-center gap-3">
                      <div className="p-3 bg-white border-2 border-slate-200 rounded-2xl shadow-sm">
                        <img
                          src={viewBooking.qrCode}
                          alt="Booking QR Code"
                          className="w-40 h-40 object-contain"
                        />
                      </div>
                      <p className="font-mono text-sm font-black text-text-dark tracking-widest">
                        {viewBooking.passCode}
                      </p>
                      {viewBooking.maxPersons && (
                        <span className="inline-flex items-center gap-1.5 text-xs font-bold text-blue-700 bg-blue-50 border border-blue-200 px-3 py-1.5 rounded-full">
                          <Users size={12} /> Valid for {viewBooking.maxPersons} person{viewBooking.maxPersons > 1 ? 's' : ''}
                        </span>
                      )}
                      <a
                        href={viewBooking.qrCode}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-[11px] font-bold text-primary hover:underline"
                      >
                        Open full-size QR ↗
                      </a>
                    </div>
                  </div>
                )}
              </div>

              {/* Drawer footer — action buttons */}
              <div className="p-6 bg-slate-50 border-t border-border space-y-3 shrink-0">
                {/* Payment actions */}
                <p className="text-[10px] font-black text-text-muted uppercase tracking-widest">Update Payment</p>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={() => handleUpdatePayment(viewBooking.id, 'Paid')}
                    disabled={updating || viewBooking.paymentStatus === 'Paid'}
                    className="flex items-center justify-center gap-2 bg-emerald-500 hover:bg-emerald-600 disabled:opacity-40 text-white px-4 py-3 rounded-2xl text-[11px] font-black uppercase tracking-wider transition-all active:scale-95">
                    {updating ? <Loader2 size={14} className="animate-spin" /> : <CheckCircle size={14} />}
                    Mark Paid
                  </button>
                  <button
                    onClick={() => handleUpdatePayment(viewBooking.id, 'Refunded')}
                    disabled={updating || viewBooking.paymentStatus === 'Refunded'}
                    className="flex items-center justify-center gap-2 bg-purple-500 hover:bg-purple-600 disabled:opacity-40 text-white px-4 py-3 rounded-2xl text-[11px] font-black uppercase tracking-wider transition-all active:scale-95">
                    {updating ? <Loader2 size={14} className="animate-spin" /> : <CreditCard size={14} />}
                    Refund
                  </button>
                </div>

                {/* Booking status actions */}
                <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest pt-1">Update Booking</p>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={() => handleUpdateBookingStatus(viewBooking.id, 'Completed')}
                    disabled={updating || viewBooking.bookingStatus === 'Completed'}
                    className="flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-40 text-white px-4 py-3 rounded-2xl text-[11px] font-black uppercase tracking-wider transition-all active:scale-95">
                    {updating ? <Loader2 size={14} className="animate-spin" /> : <CheckCircle size={14} />}
                    Complete
                  </button>
                  <button
                    onClick={() => handleUpdateBookingStatus(viewBooking.id, 'Cancelled')}
                    disabled={updating || viewBooking.bookingStatus === 'Cancelled'}
                    className="flex items-center justify-center gap-2 bg-red-500 hover:bg-red-600 disabled:opacity-40 text-white px-4 py-3 rounded-2xl text-[11px] font-black uppercase tracking-wider transition-all active:scale-95">
                    {updating ? <Loader2 size={14} className="animate-spin" /> : <XCircle size={14} />}
                    Cancel
                  </button>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* ── Edit Booking Slide-over ── */}
      <AnimatePresence>
        {isEditFormOpen && editingBooking && (
          <>
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setIsEditFormOpen(false)}
              className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-100"
            />
            <motion.div
              initial={{ x: '100%' }} animate={{ x: 0 }} exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="fixed right-0 top-0 h-full w-full max-w-lg bg-white shadow-2xl z-101 flex flex-col"
            >
              {/* Header */}
              <div className="p-8 border-b border-border flex items-center justify-between shrink-0">
                <div>
                  <h2 className="text-2xl font-black text-text-dark tracking-tight">Edit Booking</h2>
                  <p className="text-xs font-bold text-text-muted uppercase tracking-widest mt-1">
                    Update booking details
                  </p>
                </div>
                <button onClick={() => setIsEditFormOpen(false)} className="p-2 hover:bg-slate-100 rounded-xl text-slate-400">
                  <X size={22} />
                </button>
              </div>

              {/* Body */}
              <div className="flex-1 overflow-y-auto p-8 space-y-6">
                {/* User Name (editable) */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">User Name *</label>
                  <div className="relative">
                    <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="text"
                      value={editFormData.userName}
                      onChange={(e) => setEditFormData(p => ({ ...p, userName: e.target.value }))}
                      placeholder="Enter user name"
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    />
                  </div>
                </div>

                {/* Sport (editable) — changing it filters the court list below. */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Sport</label>
                  <div className="relative">
                    <Trophy className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 z-10" size={16} />
                    <select
                      value={editFormData.sportId}
                      onChange={(e) => setEditFormData(p => ({ ...p, sportId: e.target.value, courtId: '' }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    >
                      <option value="">— Select Sport —</option>
                      {sports.map((sp: any) => (
                        <option key={sp.id} value={String(sp.id)}>{sp.name}</option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* Court (editable) — used to move a booking to another court. */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Court</label>
                  <div className="relative">
                    <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 z-10" size={16} />
                    <select
                      value={editFormData.courtId}
                      onChange={(e) => setEditFormData(p => ({ ...p, courtId: e.target.value }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    >
                      <option value="">— Select Court —</option>
                      {courts
                        .filter((c: any) => !editFormData.sportId || String(c.sportId) === editFormData.sportId)
                        .map((c: any) => (
                          <option key={c.id} value={String(c.id)}>{c.name}</option>
                        ))}
                    </select>
                  </div>
                </div>

                {/* Date (editable) */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Date *</label>
                  <div className="relative">
                    <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="date"
                      value={editFormData.date}
                      onChange={(e) => setEditFormData(p => ({ ...p, date: e.target.value }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    />
                  </div>
                </div>

                {/* Start Time (editable) */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Start Time *</label>
                  <div className="relative">
                    <Clock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="time"
                      value={editFormData.startTime}
                      onChange={(e) => setEditFormData(p => ({ ...p, startTime: e.target.value }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    />
                  </div>
                </div>

                {/* End Time (editable) */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">End Time *</label>
                  <div className="relative">
                    <Clock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="time"
                      value={editFormData.endTime}
                      onChange={(e) => setEditFormData(p => ({ ...p, endTime: e.target.value }))}
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    />
                  </div>
                </div>

                {/* Amount (editable) */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Total Amount (₹)</label>
                  <div className="relative">
                    <IndianRupee className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                    <input
                      type="number"
                      min="0"
                      value={editFormData.totalAmount}
                      onChange={(e) => setEditFormData(p => ({ ...p, totalAmount: e.target.value }))}
                      placeholder="0"
                      className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    />
                  </div>
                </div>

                {/* Booking & payment status — the two an employee actually needs
                    to change (confirm/cancel a slot, mark a walk-in as paid). */}
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Booking Status</label>
                    <select
                      value={editFormData.bookingStatus}
                      onChange={(e) => setEditFormData(p => ({ ...p, bookingStatus: e.target.value }))}
                      className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    >
                      {['Pending', 'Confirmed', 'Completed', 'Cancelled'].map((s) => (
                        <option key={s} value={s}>{s}</option>
                      ))}
                    </select>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Payment Status</label>
                    <select
                      value={editFormData.paymentStatus}
                      onChange={(e) => setEditFormData(p => ({ ...p, paymentStatus: e.target.value }))}
                      className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    >
                      {['Pending', 'Paid', 'Failed', 'Refunded'].map((s) => (
                        <option key={s} value={s}>{s}</option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* Notes (editable) */}
                <div className="space-y-2">
                  <label className="text-[11px] font-black text-text-muted uppercase tracking-widest block">Notes</label>
                  <textarea
                    value={editFormData.notes}
                    onChange={(e) => setEditFormData(p => ({ ...p, notes: e.target.value }))}
                    rows={3}
                    placeholder="Optional notes..."
                    className="w-full px-4 py-3 bg-slate-50 border border-slate-100 rounded-xl text-sm font-medium focus:ring-2 focus:ring-primary/20 focus:border-primary resize-none"
                  />
                </div>
              </div>

              {/* Footer */}
              <div className="p-8 bg-slate-50 border-t border-slate-200 flex gap-4 shrink-0">
                <button
                  onClick={handleEditSubmit}
                  disabled={updating}
                  className="flex-1 bg-blue-600 hover:bg-blue-700 text-white px-6 py-3.5 rounded-2xl text-[11px] font-black uppercase tracking-widest shadow-xl shadow-blue-600/20 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  {updating ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
                  {updating ? 'Updating...' : 'Update Booking'}
                </button>
                <button
                  onClick={() => setIsEditFormOpen(false)}
                  className="flex-1 bg-white border border-slate-200 text-slate-600 px-6 py-3.5 rounded-2xl text-[11px] font-black uppercase tracking-widest hover:bg-slate-50"
                >
                  Cancel
                </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </UnifiedDashboardLayout>
  );
}
