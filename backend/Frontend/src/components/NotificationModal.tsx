/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect } from 'react';
import { createPortal } from 'react-dom';
import { useDispatch, useSelector } from 'react-redux';
import { markAsRead } from '../store/slices/notificationSlice';
import { RootState, AppDispatch } from '../store';
import { Modal } from './ui/Modal';

interface NotificationModalProps {
  notificationId: number;
  onClose: () => void;
}

export default function NotificationModal({ notificationId, onClose }: NotificationModalProps) {
  const dispatch = useDispatch<AppDispatch>();
  const { notifications } = useSelector((state: RootState) => state.notifications);

  const notification = notifications.find(n => n.id === notificationId);

  useEffect(() => {
    if (notification && !notification.isRead) {
      dispatch(markAsRead(notificationId));
    }
  }, [notification, notificationId, dispatch]);

  if (!notification) return null;

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const typeColorMap: Record<string, string> = {
    Booking: 'bg-blue-100 text-blue-800',
    Payment: 'bg-green-100 text-green-800',
    System: 'bg-gray-100 text-gray-800',
    Alert: 'bg-red-100 text-red-800',
    Promotion: 'bg-purple-100 text-purple-800',
    Feedback: 'bg-yellow-100 text-yellow-800',
  };

  const badgeClass = typeColorMap[notification.type] ?? 'bg-gray-100 text-gray-800';

  const modalContent = (
    <Modal
      isOpen={true}
      onClose={onClose}
      title={notification.title}
      size="lg"
      mobileBottomSheet={true}
    >
      {/* Notification image (if actionUrl is an image) */}
      {notification.actionUrl && (
        <div className="mb-5">
          <img
            src={notification.actionUrl}
            alt="Notification"
            className="w-full h-auto rounded-xl object-cover"
            referrerPolicy="no-referrer"
            onError={(e) => {
              (e.currentTarget as HTMLImageElement).style.display = 'none';
            }}
          />
        </div>
      )}

      {/* Message body */}
      <p className="text-base text-gray-700 whitespace-pre-wrap leading-relaxed">
        {notification.message}
      </p>

      {/* Meta info */}
      <div className="mt-6 pt-4 border-t border-gray-100 flex items-center justify-between flex-wrap gap-3">
        <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${badgeClass}`}>
          {notification.type}
        </span>
        <span className="text-sm text-gray-500">{formatTimestamp(notification.sentAt)}</span>
      </div>

      {/* Close button */}
      <div className="mt-6">
        <button
          onClick={onClose}
          className="w-full px-4 py-2.5 bg-primary text-white rounded-xl hover:bg-primary/90 transition-colors text-sm font-medium"
        >
          Close
        </button>
      </div>
    </Modal>
  );

  // Render via portal to escape any parent stacking context (navbar z-index, overflow, etc.)
  return createPortal(modalContent, document.body);
}
