/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

export interface NavItem {
 label: string;
 href: string;
}

export const NAV_ITEMS: NavItem[] = [
 { label: 'Coaching', href: '/coaching' },
 { label: 'Events', href: '/events' },
 { label: 'About Us', href: '/about' },
 { label: 'Contacts', href: '/contacts' },
];

export const NAVBAR_ITEMS: NavItem[] = NAV_ITEMS.filter(
 (item) => item.label !== 'Contacts'
);

export interface Program {
 title: string;
 location: string;
 image: string;
 id: string;
}

// No fallback images — offline/sample programs render the "No image" placeholder.
export const PROGRAMS: Program[] = [
 { id: 'cricket', title: 'CRICKET', location: 'Sinhagad Road', image: '' },
 { id: 'basketball', title: 'BASKETBALL', location: 'Sinhagad Road', image: '' },
 { id: 'skating', title: 'SKATING', location: 'Gangadham Chowk', image: '' },
 { id: 'badminton', title: 'BADMINTON', location: 'Gangadham Chowk', image: '' },
 { id: 'karate', title: 'KARATE', location: 'Sinhagad Road', image: '' },
 { id: 'fitness', title: 'FUN FITNESS', location: 'Sinhagad Road', image: '' },
 { id: 'dance', title: 'DANCE & ZUMBA', location: 'Gangadham Chowk', image: '' },
];

