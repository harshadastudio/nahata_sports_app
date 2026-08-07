/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import type { Batch } from '../types/coaching';

export function mapBatchFromBackend(backendBatch: any): Batch {
 const availableSlots = backendBatch.maxStudents - backendBatch.currentStudents;
 // Prefer explicit start/end times (absorbed from the former Program), fall back to schedule text.
 const timing = (backendBatch.startTime && backendBatch.endTime)
 ? formatTimeRange(backendBatch.startTime, backendBatch.endTime)
 : formatTiming(backendBatch.schedule);

 // Duration is derived from the start/end date range; fall back to the stored value.
 const duration = computeDuration(backendBatch.startDate, backendBatch.endDate) || backendBatch.duration || '';

 return {
 id: backendBatch.id,
 name: backendBatch.name,
 type: backendBatch.description || deriveBatchType(backendBatch.name),
 sessions: duration,
 duration,
 price: formatPrice(backendBatch.fees),
 timing,
 days: backendBatch.days || 'Mon - Fri',
 ageGroup: backendBatch.ageGroup || '',
 startDate: backendBatch.startDate || undefined,
 endDate: backendBatch.endDate || undefined,
 maxStudents: backendBatch.maxStudents,
 currentStudents: backendBatch.currentStudents,
 availableSlots,
 status: backendBatch.status === 'Inactive' ? 'Cancelled' : (backendBatch.status as Batch['status']),
 isFull: availableSlots <= 0,
 isLimitedSpots: availableSlots > 0 && availableSlots <= 5,
 coach: backendBatch.coach
 ? { id: backendBatch.coach.id, name: backendBatch.coach.name }
 : null,
 };
}

// Build a human-friendly duration from a start/end date range, e.g. "8 Days", "3 Weeks", "2 Months".
function computeDuration(startDate?: string, endDate?: string): string {
 if (!startDate || !endDate) return '';
 const start = new Date(startDate);
 const end = new Date(endDate);
 if (isNaN(start.getTime()) || isNaN(end.getTime())) return '';
 const days = Math.round((end.getTime() - start.getTime()) / 86400000);
 if (days <= 0) return '';
 if (days < 7) return `${days} Day${days > 1 ? 's' : ''}`;
 if (days < 30) {
 const weeks = Math.round(days / 7);
 return `${weeks} Week${weeks > 1 ? 's' : ''}`;
 }
 if (days < 365) {
 const months = Math.round(days / 30);
 return `${months} Month${months > 1 ? 's' : ''}`;
 }
 const years = Math.round((days / 365) * 10) / 10;
 return `${years} Year${years > 1 ? 's' : ''}`;
}

function deriveBatchType(batchName: string): string {
 const lowerName = batchName.toLowerCase();
 if (lowerName.includes('morning')) return 'Morning Batch';
 if (lowerName.includes('evening')) return 'Evening Batch';
 if (lowerName.includes('weekend')) return 'Weekend Special';
 if (lowerName.includes('elite')) return 'Elite Training';
 if (lowerName.includes('beginner')) return 'Beginner Friendly';
 if (lowerName.includes('value')) return 'Value For Money';
 if (lowerName.includes('performance')) return 'Performance';
 if (lowerName.includes('foundation')) return 'Foundations';
 return 'Regular Batch';
}

function formatPrice(price: number): string {
 if (!price) return '₹0';
 return `₹${price.toLocaleString('en-IN')}`;
}

function formatTiming(schedule?: string): string {
 if (!schedule) return '09:00 AM - 11:00 AM';
 // If schedule already contains time information, return as is
 return schedule;
}

function formatTimeRange(startTime?: string, endTime?: string): string {
 if (!startTime || !endTime) return '09:00 AM - 11:00 AM';
 
 const formatTime = (time: string) => {
 // Handle both HH:mm and HH:mm:ss formats
 const parts = time.split(':');
 const hours = parseInt(parts[0]);
 const minutes = parts[1];
 const ampm = hours >= 12 ? 'PM' : 'AM';
 const displayHour = hours > 12 ? hours - 12 : hours === 0 ? 12 : hours;
 return `${displayHour.toString().padStart(2, '0')}:${minutes} ${ampm}`;
 };
 
 return `${formatTime(startTime)} - ${formatTime(endTime)}`;
}

