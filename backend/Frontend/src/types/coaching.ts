/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { LucideIcon } from 'lucide-react';

export interface Sport {
 id: number;
 name: string;
 description?: string;
 category: 'Indoor' | 'Outdoor' | 'Aquatic' | 'Adventure';
 image?: string;
 status: 'Active' | 'Inactive';
 iconName?: string; // Store icon name (string) instead of component for Redux serialization
}

export interface Coach {
 id: number;
 name: string;
 email?: string;
 phone?: string;
 sportId: number;
 sport?: Sport;
 ground?: string;
 certification?: string;
 bio?: string;
 image?: string;
 experience?: string;
 specialization?: string;
 qualifications?: string;
 availability?: string;
 status: 'Active' | 'Inactive';
 awards?: string[];
 achievements?: string[];
}

export interface Batch {
 id: number;
 name: string;
 type: string;
 sessions: string;
 duration: string;
 price: string;
 timing: string;
 days: string;
 ageGroup: string;
 startDate?: string;
 endDate?: string;
 maxStudents: number;
 currentStudents: number;
 availableSlots: number;
 status: 'Active' | 'Completed' | 'Cancelled';
 isFull: boolean;
 isLimitedSpots: boolean;
 coach?: { id: number; name: string } | null;
}

export interface Ground {
 id: string;
 name: string;
 image: string;
}

export interface SportComplex {
 id: number;
 name: string;
 address?: string;
 city?: string;
 state?: string;
 contactPhone?: string;
 status: 'Active' | 'Inactive';
 image?: string;
}

