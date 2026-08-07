/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useSelector } from 'react-redux';
import { RootState } from '../store';
import { Clock, Loader2 } from 'lucide-react';

interface NotificationPopupProps {
 onNotificationClick: (notificationId: number) => void;
 onClose: () => void;
}

export default function NotificationPopup({ onNotificationClick, onClose }: NotificationPopupProps) {
 const { notifications: rawNotifications, loading, error } = useSelector((state: RootState) => state.notifications);
 const notifications = Array.isArray(rawNotifications) ? rawNotifications : [];

 const formatTimestamp = (timestamp: string) => {
 const date = new Date(timestamp);
 const now = new Date();
 const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

 if (diffInSeconds < 60) return 'Just now';
 if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
 if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
 if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d ago`;
 return date.toLocaleDateString();
 };

 const truncateMessage = (message: string, maxLength: number = 50) => {
 if (typeof message !== 'string') return '';
 if (message.length <= maxLength) return message;
 return message.substring(0, maxLength) + '...';
 };

 return (
 <div className="absolute right-0 mt-2 w-80 md:w-96 bg-white rounded-lg shadow-xl border border-gray-200 z-50 max-h-[500px] overflow-hidden flex flex-col">
 {/* Header */}
 <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
 <h3 className="text-lg text-gray-900">Notifications</h3>
 </div>

 {/* Content */}
 <div className="flex-1 overflow-y-auto">
 {loading && (
 <div className="flex items-center justify-center py-8">
 <Loader2 className="w-6 h-6 animate-spin text-primary"/>
 </div>
 )}

 {error && (
 <div className="px-4 py-8 text-center text-red-600">
 <p>{error}</p>
 </div>
 )}

 {!loading && !error && notifications.length === 0 && (
 <div className="px-4 py-8 text-center text-gray-500">
 <p>No notifications</p>
 </div>
 )}

 {!loading && !error && notifications.length > 0 && (
 <div className="divide-y divide-gray-100">
 {notifications.slice(0, 10).map((notification) => (
 <button
 key={notification.id}
 onClick={() => onNotificationClick(notification.id)}
 className={`w-full px-4 py-3 text-left hover:bg-gray-50 transition-colors ${
 !notification.isRead ? 'bg-blue-50' : ''
 }`}
 >
 <div className="flex items-start gap-3">
 <div className="flex-1 min-w-0">
 <p className={`text-sm text-gray-900 ${!notification.isRead ? '' : ''}`}>
 {notification.title}
 </p>
 <p className="text-sm text-gray-600 mt-1 line-clamp-2">
 {truncateMessage(notification.message)}
 </p>
 <div className="flex items-center gap-1 mt-2 text-xs text-gray-500">
 <Clock className="w-3 h-3"/>
 <span>{formatTimestamp(notification.sentAt)}</span>
 </div>
 </div>
 {!notification.isRead && (
 <div className="w-2 h-2 bg-blue-600 rounded-full mt-1 flex-shrink-0"/>
 )}
 </div>
 </button>
 ))}
 </div>
 )}
 </div>

 {/* Footer */}
 {notifications.length > 0 && (
 <div className="px-4 py-3 border-t border-gray-200 bg-gray-50">
 <button
 onClick={onClose}
 className="w-full text-center text-sm text-primary hover:text-primary/80 transition-colors"
 >
 View All Notifications
 </button>
 </div>
 )}
 </div>
 );
}

