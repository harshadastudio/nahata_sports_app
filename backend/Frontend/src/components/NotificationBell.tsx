/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect, useState, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Bell } from 'lucide-react';
import { fetchUnreadCount, fetchNotifications } from '../store/slices/notificationSlice';
import { RootState, AppDispatch } from '../store';
import NotificationPopup from './NotificationPopup';
import NotificationModal from './NotificationModal';

export default function NotificationBell() {
 const dispatch = useDispatch<AppDispatch>();
 const { unreadCount } = useSelector((state: RootState) => state.notifications);
 const [isPopupOpen, setIsPopupOpen] = useState(false);
 const [selectedNotificationId, setSelectedNotificationId] = useState<number | null>(null);
 const bellRef = useRef<HTMLDivElement>(null);

 // Fetch unread count on mount
 useEffect(() => {
 dispatch(fetchUnreadCount());
 }, [dispatch]);

 // Polling mechanism - fetch unread count every 30 seconds
 useEffect(() => {
 const interval = setInterval(() => {
 dispatch(fetchUnreadCount());
 }, 30000); // 30 seconds

 return () => clearInterval(interval);
 }, [dispatch]);

 // Fetch notifications when popup opens
 useEffect(() => {
 if (isPopupOpen) {
 dispatch(fetchNotifications({ page: 1, limit: 10 }));
 }
 }, [isPopupOpen, dispatch]);

 // Close popup when clicking outside
 useEffect(() => {
 const handleClickOutside = (event: MouseEvent) => {
 if (bellRef.current && !bellRef.current.contains(event.target as Node)) {
 setIsPopupOpen(false);
 }
 };

 if (isPopupOpen) {
 document.addEventListener('mousedown', handleClickOutside);
 }

 return () => {
 document.removeEventListener('mousedown', handleClickOutside);
 };
 }, [isPopupOpen]);

 const handleBellClick = () => {
 setIsPopupOpen(!isPopupOpen);
 };

 const handleNotificationClick = (notificationId: number) => {
 setSelectedNotificationId(notificationId);
 setIsPopupOpen(false);
 };

 const handleCloseModal = () => {
 setSelectedNotificationId(null);
 };

 return (
 <>
 <div ref={bellRef} className="relative">
 <button
 onClick={handleBellClick}
 className="relative p-2 hover:bg-gray-100 rounded-full transition-colors"
 aria-label="Notifications"
 >
 <Bell className="w-6 h-6 text-gray-700"/>
 {unreadCount > 0 && (
 <span className="absolute top-0 right-0 inline-flex items-center justify-center px-2 py-1 text-xs leading-none text-white transform translate-x-1/2 -translate-y-1/2 bg-red-600 rounded-full min-w-[20px]">
 {unreadCount > 99 ? '99+' : unreadCount}
 </span>
 )}
 </button>

 {isPopupOpen && (
 <NotificationPopup
 onNotificationClick={handleNotificationClick}
 onClose={() => setIsPopupOpen(false)}
 />
 )}
 </div>

 {selectedNotificationId && (
 <NotificationModal
 notificationId={selectedNotificationId}
 onClose={handleCloseModal}
 />
 )}
 </>
 );
}

