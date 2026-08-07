/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

export const VENUES = [
 { id: 'sinhagad', name: 'Sinhagad Road', address: 'Wadgaon Budruk, Pune', image: '' },
 { id: 'gangadham', name: 'Gangadham Chowk', address: 'Najushree Bhawan, Pune', image: '' },
];

export const SPORTS_BY_VENUE: Record<string, string[]> = {
 sinhagad: ['Cricket', 'Basketball', 'Karate', 'Fun Fitness'],
 gangadham: ['Skating', 'Badminton', 'Dance & Zumba'],
};

export const COURTS_BY_SPORT: Record<string, string[]> = {
 'Cricket': ['Main Turf A', 'Practice Net 1', 'Practice Net 2'],
 'Basketball': ['Court 1 (Full)', 'Court 2 (Half)'],
 'Badminton': ['Court A1', 'Court A2', 'Court B1', 'Court B2'],
 'Skating': ['Main Rink', 'Junior Area'],
 'Karate': ['Dojo 1', 'Dojo 2'],
 'Dance & Zumba': ['Studio A', 'Studio B'],
 'Fun Fitness': ['Group Area', 'Personal Training zone'],
};

export const SLOTS = ['06:00 AM', '07:00 AM', '08:00 AM', '04:00 PM', '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM'];

