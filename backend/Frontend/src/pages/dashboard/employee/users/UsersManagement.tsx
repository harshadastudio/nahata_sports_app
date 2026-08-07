/**
 * Employee Dashboard - Users Management
 * Copied from Admin Panel Users.tsx and adapted for employee dashboard
 * Uses direct API calls instead of Redux
 */

import React, { useState, useEffect } from 'react';
import { UnifiedDashboardLayout } from '../../../../components/dashboard/UnifiedDashboardLayout';
import { RoleBasedSidebar } from '../../../../components/dashboard/RoleBasedSidebar';
import { DashboardNavbar } from '../../../../components/dashboard/DashboardNavbar';
import { fetchWithAuth } from '../../../../lib/fetchWithAuth';
import { 
  Plus, 
  Edit2, 
  Trash2, 
  Eye, 
  Search, 
  Filter, 
  Phone, 
  Mail, 
  Users as UsersIcon, 
  Calendar, 
  X, 
  Save, 
  RotateCcw,
  User,
  Shield,
  AlertCircle,
  CheckCircle,
  Crown,
  Star,
  Activity,
  Briefcase,
  Loader2,
  ChevronLeft,
  ChevronRight
} from 'lucide-react';
import toast from 'react-hot-toast';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

interface UserData {
  id: string | number;
  name: string;
  email: string;
  phoneNumber: string;
  role: string;
  status: string;
  totalBookings: number;
  membershipType?: string;
  joinDate?: string;
  lastActive?: string;
  avatar?: string;
  employeeId?: string;
  department?: string;
  assignedSports?: string;
  assignedLocation?: string;
}

const membershipTypes = ['Basic', 'Premium', 'VIP', 'Corporate'];
const statusTypes = ['Active', 'Blocked'];

export default function UsersManagement() {
  const [users, setUsers] = useState<UserData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalRecords, setTotalRecords] = useState(0);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('');
  const [selectedMembership, setSelectedMembership] = useState('');
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [viewingUser, setViewingUser] = useState<UserData | null>(null);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<UserData | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    phoneNumber: '',
    email: '',
    role: 'USER',
    membershipType: 'Basic',
    status: 'Active'
  });

  useEffect(() => {
    loadUsers();
  }, [currentPage, selectedStatus, selectedMembership, searchQuery]);

  const loadUsers = async () => {
    setLoading(true);
    setError('');
    try {
      let url = `${API_BASE}/admin/users?page=${currentPage}&limit=10`;
      if (selectedStatus) url += `&status=${selectedStatus}`;
      if (selectedMembership) url += `&membership_type=${selectedMembership}`;
      if (searchQuery) url += `&search=${searchQuery}`;

      const res = await fetchWithAuth(url);
      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || `HTTP ${res.status}`);
      }
      
      const data = await res.json();
      console.log('📊 Users API Response:', data);
      
      // API returns: { success: true, data: [...], pagination: { currentPage, totalPages, totalItems, itemsPerPage } }
      setUsers(data.data || []);
      setTotalRecords(data.pagination?.totalItems || 0);
      setTotalPages(data.pagination?.totalPages || 1);
      setCurrentPage(data.pagination?.currentPage || currentPage);
    } catch (err: any) {
      console.error('❌ Failed to load users:', err);
      setError(err.message || 'Failed to load users. Please try again.');
      toast.error(err.message || 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const handleView = (user: UserData) => {
    setViewingUser(user);
    setIsViewModalOpen(true);
  };

  const handleEdit = (user: UserData) => {
    setEditingUser(user);
    setFormData({
      name: user.name,
      phoneNumber: user.phoneNumber || '',
      email: user.email,
      role: user.role,
      membershipType: user.membershipType || 'Basic',
      status: user.status
    });
    setIsEditModalOpen(true);
  };

  const handleUpdateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingUser) return;

    try {
      // Convert role back to uppercase format for backend
      const roleMap: Record<string, string> = {
        'User': 'USER',
        'Admin': 'ADMIN',
        'Employee': 'EMPLOYEE',
        'Coach': 'COACH',
        'Security Guard': 'SECURITY',
        'Security': 'SECURITY'
      };

      const backendRole = roleMap[formData.role] || formData.role.toUpperCase();

      const res = await fetchWithAuth(`${API_BASE}/admin/users/${editingUser.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: formData.name,
          phone_number: formData.phoneNumber,
          email: formData.email,
          role: backendRole,
          membership_type: formData.membershipType,
          status: formData.status
        })
      });

      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || 'Failed to update user');
      }

      toast.success('User updated successfully');
      setIsEditModalOpen(false);
      setEditingUser(null);
      loadUsers();
    } catch (err: any) {
      console.error('Failed to update user:', err);
      toast.error(err.message || 'Failed to update user');
    }
  };

  const getStatusColor = (status: string) => {
    return status === 'Active' 
      ? 'bg-green-100 text-green-700 border-green-200' 
      : 'bg-red-100 text-red-700 border-red-200';
  };

  const getStatusIcon = (status: string) => {
    return status === 'Active' ? <CheckCircle size={16} /> : <AlertCircle size={16} />;
  };

  const getMembershipColor = (type?: string) => {
    switch (type) {
      case 'Basic': return 'bg-gray-100 text-gray-700';
      case 'Premium': return 'bg-purple-100 text-purple-700';
      case 'VIP': return 'bg-yellow-100 text-yellow-700';
      case 'Corporate': return 'bg-blue-100 text-blue-700';
      default: return 'bg-gray-100 text-gray-700';
    }
  };

  const getMembershipIcon = (type?: string) => {
    switch (type) {
      case 'Basic': return <Star size={16} />;
      case 'Premium': return <Crown size={16} />;
      case 'VIP': return <Activity size={16} />;
      case 'Corporate': return <Shield size={16} />;
      default: return <Star size={16} />;
    }
  };

  return (
    <UnifiedDashboardLayout
      sidebar={<RoleBasedSidebar />}
      navbar={<DashboardNavbar pageTitle="Users Management" />}
    >
      <div className="max-w-[1400px] mx-auto min-h-full">
        {/* Header */}
        <div className="mb-8 flex items-end justify-between">
          <div>
            <h1 className="text-3xl font-black text-slate-900 tracking-tight">Users</h1>
            <p className="text-sm text-slate-500 mt-1">
              {loading ? 'Loading...' : `Total: ${totalRecords} user${totalRecords !== 1 ? 's' : ''}`}
            </p>
          </div>
        </div>

        {/* Error Message */}
        {error && (
          <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg flex items-center gap-2">
            <AlertCircle size={20} />
            <span>{error}</span>
          </div>
        )}

        {/* Filters and Search */}
        <div className="mb-6 flex items-center gap-4">
          {/* Search */}
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-4 h-4" />
            <input
              type="text"
              placeholder="Search users..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setCurrentPage(1);
              }}
              className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
            />
          </div>

          {/* Status Filter */}
          <div className="relative">
            <Filter className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-4 h-4" />
            <select
              value={selectedStatus}
              onChange={(e) => {
                setSelectedStatus(e.target.value);
                setCurrentPage(1);
              }}
              className="pl-9 pr-4 py-2 bg-slate-50 border border-transparent rounded-full text-xs font-medium focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:bg-white focus:border-blue-500 transition-all appearance-none cursor-pointer"
            >
              <option value="">All Status</option>
              {statusTypes.map(status => (
                <option key={status} value={status}>{status}</option>
              ))}
            </select>
          </div>

          {/* Membership Filter */}
          <div className="relative">
            <Filter className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-4 h-4" />
            <select
              value={selectedMembership}
              onChange={(e) => {
                setSelectedMembership(e.target.value);
                setCurrentPage(1);
              }}
              className="pl-9 pr-4 py-2 bg-slate-50 border border-transparent rounded-full text-xs font-medium focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:bg-white focus:border-blue-500 transition-all appearance-none cursor-pointer"
            >
              <option value="">All Memberships</option>
              {membershipTypes.map(type => (
                <option key={type} value={type}>{type}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Loading State */}
        {loading ? (
          <div className="flex items-center justify-center p-12 bg-white rounded-2xl border border-slate-200">
            <Loader2 size={32} className="animate-spin text-blue-600" />
          </div>
        ) : users.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center">
            <User size={40} className="text-slate-300 mx-auto mb-3" />
            <p className="font-semibold text-slate-900 mb-1">No users found</p>
            <p className="text-slate-500 text-sm">No users available in the system.</p>
          </div>
        ) : (
          /* Users Table */
          <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50">
                    <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Phone Number</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Email</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Bookings</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Membership</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Status</th>
                    <th className="text-center px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {users.map((user) => (
                    <tr key={user.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                            <User size={20} className="text-blue-600" />
                          </div>
                          <div>
                            <p className="font-bold text-slate-900 text-sm">{user.name}</p>
                            <p className="text-[10px] text-slate-500">
                              Joined {user.joinDate || '—'}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <Phone size={16} className="text-slate-400" />
                          <span className="text-sm">{user.phoneNumber || '—'}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <Mail size={16} className="text-slate-400" />
                          <span className="text-sm">{user.email}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <Calendar size={16} className="text-slate-400" />
                          <span className="font-semibold">{user.totalBookings || 0}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        {user.membershipType ? (
                          <span className={`px-2 py-1 text-xs font-bold rounded-full ${getMembershipColor(user.membershipType)}`}>
                            {user.membershipType}
                          </span>
                        ) : (
                          <span className="text-slate-400 text-xs">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`px-2 py-1 text-xs font-bold rounded-full border ${getStatusColor(user.status)}`}>
                          {user.status}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => handleView(user)}
                            className="p-1.5 bg-blue-50 hover:bg-blue-100 text-blue-600 rounded-lg transition-colors"
                            title="View User"
                          >
                            <Eye size={14} />
                          </button>
                          <button
                            onClick={() => handleEdit(user)}
                            className="p-1.5 bg-green-50 hover:bg-green-100 text-green-600 rounded-lg transition-colors"
                            title="Edit User"
                          >
                            <Edit2 size={14} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Pagination */}
        {!loading && totalPages > 1 && (
          <div className="flex items-center justify-between mt-6">
            <p className="text-xs text-slate-500">Page {currentPage} of {totalPages}</p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage <= 1}
                className="p-2 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-blue-600 hover:border-blue-600 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
              >
                <ChevronLeft size={16} />
              </button>
              <button
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={currentPage >= totalPages}
                className="p-2 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-blue-600 hover:border-blue-600 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* View User Modal */}
      {isViewModalOpen && viewingUser && (
        <>
          <div 
            onClick={() => setIsViewModalOpen(false)}
            className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100]"
          />
          <div className="fixed inset-0 flex items-center justify-center p-8 z-[101]">
            <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 p-8 max-w-md w-full mx-4">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-black text-slate-900 tracking-tight">User Details</h2>
                <button 
                  onClick={() => setIsViewModalOpen(false)}
                  className="p-2 hover:bg-slate-100 rounded-xl text-slate-400 transition-colors"
                >
                  <X size={20} />
                </button>
              </div>

              <div className="space-y-6">
                {/* User Avatar and Basic Info */}
                <div className="flex items-center gap-4">
                  <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
                    <User size={32} className="text-blue-600" />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-slate-900">{viewingUser.name}</h3>
                    <span className={`px-2 py-1 text-xs font-bold rounded-full border ${getStatusColor(viewingUser.status)}`}>
                      {viewingUser.status}
                    </span>
                  </div>
                </div>

                {/* Contact Information */}
                <div className="space-y-4">
                  <div className="flex items-center gap-3">
                    <Phone size={16} className="text-slate-400" />
                    <span className="text-sm">{viewingUser.phoneNumber || '—'}</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <Mail size={16} className="text-slate-400" />
                    <span className="text-sm">{viewingUser.email}</span>
                  </div>
                </div>

                {/* Membership and Stats */}
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-slate-50 rounded-xl p-4">
                    <div className="flex items-center gap-2 mb-2">
                      {getMembershipIcon(viewingUser.membershipType)}
                      <span className="text-xs text-slate-600">Membership</span>
                    </div>
                    <p className="font-bold text-slate-900">{viewingUser.membershipType || '—'}</p>
                  </div>
                  <div className="bg-slate-50 rounded-xl p-4">
                    <div className="flex items-center gap-2 mb-2">
                      <Calendar size={16} className="text-slate-400" />
                      <span className="text-xs text-slate-600">Bookings</span>
                    </div>
                    <p className="font-bold text-slate-900">{viewingUser.totalBookings || 0}</p>
                  </div>
                </div>

                {/* Dates */}
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-600">Join Date:</span>
                    <span className="font-medium">{viewingUser.joinDate || '—'}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-600">Last Active:</span>
                    <span className="font-medium">{viewingUser.lastActive || '—'}</span>
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="flex items-center gap-3 pt-4 border-t border-slate-200">
                  <button
                    onClick={() => {
                      setIsViewModalOpen(false);
                      handleEdit(viewingUser);
                    }}
                    className="flex-1 bg-blue-50 hover:bg-blue-100 text-blue-600 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                  >
                    Edit User
                  </button>
                  <button
                    onClick={() => setIsViewModalOpen(false)}
                    className="flex-1 bg-slate-50 hover:bg-slate-100 text-slate-600 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                  >
                    Close
                  </button>
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Edit User Modal */}
      {isEditModalOpen && editingUser && (
        <>
          <div 
            onClick={() => setIsEditModalOpen(false)}
            className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100]"
          />
          <div className="fixed right-0 top-0 h-screen w-full max-w-2xl bg-white shadow-2xl z-[101] flex flex-col">
            <div className="p-8 border-b border-slate-200 flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-black text-slate-900 tracking-tight">Edit User</h2>
                <p className="text-xs font-bold text-slate-500 uppercase tracking-widest mt-1">
                  Update user information
                </p>
              </div>
              <button 
                onClick={() => setIsEditModalOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-xl text-slate-400 transition-colors"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleUpdateUser} className="flex-1 overflow-y-auto p-8 space-y-6">
              {/* Name */}
              <div className="space-y-2">
                <label className="text-[11px] font-black text-slate-500 uppercase tracking-widest block">
                  Full Name
                </label>
                <div className="relative">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                  <input
                    type="text"
                    placeholder="Enter full name"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500/20 focus:bg-white focus:border-blue-500 transition-all text-sm font-medium"
                    required
                  />
                </div>
              </div>

              {/* Phone Number */}
              <div className="space-y-2">
                <label className="text-[11px] font-black text-slate-500 uppercase tracking-widest block">
                  Mobile Number
                </label>
                <div className="relative">
                  <Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                  <input
                    type="tel"
                    placeholder="Enter phone number"
                    value={formData.phoneNumber}
                    onChange={(e) => setFormData({ ...formData, phoneNumber: e.target.value })}
                    className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500/20 focus:bg-white focus:border-blue-500 transition-all text-sm font-medium"
                    required
                  />
                </div>
              </div>

              {/* Email */}
              <div className="space-y-2">
                <label className="text-[11px] font-black text-slate-500 uppercase tracking-widest block">
                  Email Address
                </label>
                <div className="relative">
                  <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                  <input
                    type="email"
                    placeholder="Enter email address"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500/20 focus:bg-white focus:border-blue-500 transition-all text-sm font-medium"
                    required
                  />
                </div>
              </div>

              {/* Membership Type */}
              <div className="space-y-2">
                <label className="text-[11px] font-black text-slate-500 uppercase tracking-widest block">
                  Membership Type
                </label>
                <select
                  value={formData.membershipType}
                  onChange={(e) => setFormData({ ...formData, membershipType: e.target.value })}
                  className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500/20 focus:bg-white focus:border-blue-500 transition-all text-sm font-medium"
                >
                  {membershipTypes.map(type => (
                    <option key={type} value={type}>{type}</option>
                  ))}
                </select>
              </div>

              {/* Status */}
              <div className="space-y-2">
                <label className="text-[11px] font-black text-slate-500 uppercase tracking-widest block">
                  Status
                </label>
                <div className="flex items-center gap-4">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="radio"
                      name="status"
                      value="Active"
                      checked={formData.status === 'Active'}
                      onChange={() => setFormData({ ...formData, status: 'Active' })}
                      className="w-4 h-4 text-blue-600 border-slate-300 focus:ring-blue-500/20"
                    />
                    <span className="text-sm font-medium">Active</span>
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="radio"
                      name="status"
                      value="Blocked"
                      checked={formData.status === 'Blocked'}
                      onChange={() => setFormData({ ...formData, status: 'Blocked' })}
                      className="w-4 h-4 text-blue-600 border-slate-300 focus:ring-blue-500/20"
                    />
                    <span className="text-sm font-medium">Blocked</span>
                  </label>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center gap-4 pt-4">
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-xl text-sm font-bold shadow-lg shadow-blue-200 transition-all active:scale-95 uppercase tracking-wider"
                >
                  <Save size={16} className="inline mr-2" />
                  Update User
                </button>
                <button
                  type="button"
                  onClick={() => setIsEditModalOpen(false)}
                  className="flex-1 bg-white border border-slate-200 text-slate-600 px-6 py-3 rounded-xl text-sm font-bold transition-all hover:bg-slate-100 active:scale-95 uppercase tracking-wider"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </>
      )}
    </UnifiedDashboardLayout>
  );
}
