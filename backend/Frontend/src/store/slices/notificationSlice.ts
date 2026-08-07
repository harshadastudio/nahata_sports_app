import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface Notification {
 id: number;
 userId: number;
 title: string;
 message: string;
 type: 'Booking' | 'Payment' | 'System' | 'Alert' | 'Promotion' | 'Feedback';
 isRead: boolean;
 actionUrl?: string;
 sentAt: string;
 createdAt: string;
 updatedAt: string;
}

interface NotificationState {
 unreadCount: number;
 notifications: Notification[];
 loading: boolean;
 error: string | null;
}

const initialState: NotificationState = {
 unreadCount: 0,
 notifications: [],
 loading: false,
 error: null,
};

// Helper to get auth headers from localStorage
const getAuthHeaders = () => {
 const token = localStorage.getItem('accessToken');
 return token ? { Authorization: `Bearer ${token}` } : {};
};

// Async thunks
export const fetchUnreadCount = createAsyncThunk(
 'notifications/fetchUnreadCount',
 async () => {
 const response = await axios.get(`${API_URL}/notifications/unread-count`, {
 withCredentials: true,
 headers: getAuthHeaders(),
 });
 return response.data.count;
 }
);

export const fetchNotifications = createAsyncThunk(
 'notifications/fetchNotifications',
 async (params: { page?: number; limit?: number } = {}) => {
 const response = await axios.get(`${API_URL}/notifications`, {
 params,
 withCredentials: true,
 headers: getAuthHeaders(),
 });
 return response.data.data;
 }
);

export const markAsRead = createAsyncThunk(
 'notifications/markAsRead',
 async (notificationId: number) => {
 const response = await axios.patch(
 `${API_URL}/notifications/${notificationId}/read`,
 {},
 {
 withCredentials: true,
 headers: getAuthHeaders(),
 }
 );
 return response.data.data;
 }
);

const notificationSlice = createSlice({
 name: 'notifications',
 initialState,
 reducers: {
 decrementUnreadCount: (state) => {
 if (state.unreadCount > 0) {
 state.unreadCount -= 1;
 }
 },
 clearError: (state) => {
 state.error = null;
 },
 },
 extraReducers: (builder) => {
 // Fetch unread count
 builder
 .addCase(fetchUnreadCount.pending, (state) => {
 state.loading = true;
 state.error = null;
 })
 .addCase(fetchUnreadCount.fulfilled, (state, action: PayloadAction<number>) => {
 state.loading = false;
 state.unreadCount = typeof action.payload === 'number' ? action.payload : 0;
 })
 .addCase(fetchUnreadCount.rejected, (state, action) => {
 state.loading = false;
 state.error = action.error.message || 'Failed to fetch unread count';
 });

 // Fetch notifications
 builder
 .addCase(fetchNotifications.pending, (state) => {
 state.loading = true;
 state.error = null;
 })
 .addCase(fetchNotifications.fulfilled, (state, action: PayloadAction<Notification[]>) => {
 state.loading = false;
 state.notifications = Array.isArray(action.payload) ? action.payload : [];
 })
 .addCase(fetchNotifications.rejected, (state, action) => {
 state.loading = false;
 state.error = action.error.message || 'Failed to fetch notifications';
 });

 // Mark as read
 builder
 .addCase(markAsRead.pending, (state) => {
 state.loading = true;
 state.error = null;
 })
 .addCase(markAsRead.fulfilled, (state, action: PayloadAction<Notification>) => {
 state.loading = false;
 const index = state.notifications.findIndex(n => n.id === action.payload.id);
 if (index !== -1) {
 state.notifications[index] = action.payload;
 }
 // Decrement unread count if notification was unread
 if (!action.payload.isRead) {
 state.unreadCount = Math.max(0, state.unreadCount - 1);
 }
 })
 .addCase(markAsRead.rejected, (state, action) => {
 state.loading = false;
 state.error = action.error.message || 'Failed to mark notification as read';
 });
 },
});

export const { decrementUnreadCount, clearError } = notificationSlice.actions;
export default notificationSlice.reducer;

