/**
 * Booking Service
 * Fetches venues (SportComplexes), sports, courts, available slots
 * and submits court bookings to the real API.
 */

import { fetchWithAuth } from '../lib/fetchWithAuth';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export interface Venue {
 id: string;
 name: string;
 address: string;
 city: string;
 image?: string;
}

export interface SportOption {
 id: string;
 name: string;
 image?: string;
}

export interface CourtOption {
 id: string;
 name: string;
 hourlyRate: number;
 surfaceType: string;
 lightingAvailable: boolean;
 status: string;
 image?: string;
 Sport?: SportOption;
 SportComplex?: { id: string; name: string };
}

export interface AvailableSlot {
 id: string;
 startTime: string; //"06:00:00"
 endTime: string;
 slotType: 'Regular' | 'Peak';
 price: number;
 isBooked: boolean;
}

export interface BookingPayload {
 courtId: string;
 date: string; // YYYY-MM-DD
 startTime: string; // HH:MM:SS
 endTime: string;
 totalAmount: number;
 notes?: string;
 couponCode?: string | null;
}

/** Court-hidden, time-first booking payload (the new flow). No courtId. */
export interface CourtHiddenBookingPayload {
 sportComplexId: string;
 sportId: string;
 date: string; // YYYY-MM-DD
 startTime: string; // HH:MM:SS
 endTime: string; // HH:MM:SS
 totalAmount: number; // ORIGINAL (pre-coupon) block price; backend applies the coupon once
 couponCode?: string | null;
}

/** One candidate start-time in the time grid for a chosen duration. */
export interface StartTimeOption {
 startTime: string; // "09:00:00"
 endTime: string; // "11:00:00"
 available: boolean;
 requiresRearrangement: boolean; // internal hint; the UI hides courts entirely
 price: number | null;
}

/** Result of an availability probe for one (startTime, duration). */
export interface AvailabilityResult {
 available: boolean;
 requiresRearrangement: boolean;
 startTime: string;
 endTime: string;
 durationMinutes: number;
 price: number | null;
 fallback: null | {
  startTime: string;
  endTime: string;
  durationMinutes: number;
  requiresRearrangement: boolean;
  price: number;
 };
}

/**"06:00:00"→"6:00 AM"*/
export function formatTime(t: string): string {
 const [h, m] = t.split(':').map(Number);
 const ampm = h >= 12 ? 'PM' : 'AM';
 const hour = h % 12 || 12;
 return `${hour}:${String(m).padStart(2, '0')} ${ampm}`;
}

export interface MyBooking {
 id: number;
 date: string;
 startTime: string;
 endTime: string;
 bookingStatus: 'Confirmed' | 'Cancelled' | 'Completed' | 'Pending';
 paymentStatus: 'Pending' | 'Paid' | 'Failed' | 'Refunded';
 totalAmount: number;
 bookingSource: string;
 passCode?: string;
 qrCode?: string;
 maxPersons?: number | null;
 scannedInCount?: number;
 scannedOutCount?: number;
 scanStatus?: 'NotScanned' | 'In' | 'Out';
 members?: BookingMember[];
 court?: { id: number; name: string; hourlyRate: string; SportComplex?: { id: number; name: string; city: string } };
 sport?: { id: number; name: string; image?: string };
}

export interface BookingMember {
 id: number;
 name: string;
 phone: string; // digits only, with country code e.g. "919876543210"
 email?: string | null;
 passCode: string;
 qrCode?: string;
 scanStatus: 'NotScanned' | 'In' | 'Out';
 scannedInAt?: string;
 scannedOutAt?: string;
}

class BookingService {
 /** CMS — fixed banner shown behind the Booking Summary (applies to all venues). */
 async getBookingSummaryBanner(): Promise<string> {
 try {
 const res = await fetch(`${API_BASE_URL}/settings/public`);
 const json = await res.json();
 return json.data?.bookingSummaryBanner ?? '';
 } catch {
 return '';
 }
 }

 /** Step 1 — load all active sport complexes (venues) */
 async getVenues(): Promise<Venue[]> {
 try {
 const res = await fetch(`${API_BASE_URL}/sports-complexes?status=Active&limit=50`);
 const json = await res.json();
 // API returns { data: { sportsComplexes: [...], ... } }
 const raw: any[] = json.data?.sportsComplexes ?? json.data ?? [];
 return raw.map((c) => ({
 id: String(c.id),
 name: c.name,
 address: c.address,
 city: c.city,
 image: c.image ?? null,
 }));
 } catch {
 return [];
 }
 }

 /** Step 2 — unique sports available at a venue (derived from courts) */
 async getSportsByVenue(venueId: string): Promise<SportOption[]> {
 try {
 const res = await fetch(
 `${API_BASE_URL}/courts?sportComplexId=${venueId}&status=Active&limit=100`
 );
 const json = await res.json();
 const courts: any[] = json.data ?? [];
 const seen = new Set<string>();
 const sports: SportOption[] = [];
 for (const c of courts) {
 if (c.Sport && !seen.has(String(c.Sport.id))) {
 seen.add(String(c.Sport.id));
 sports.push({ id: String(c.Sport.id), name: c.Sport.name, image: c.Sport.image });
 }
 }
 return sports;
 } catch {
 return [];
 }
 }

 /** Step 3 — courts at a venue for a specific sport */
 async getCourtsByVenueAndSport(
 venueId: string,
 sportId: string
 ): Promise<CourtOption[]> {
 try {
 const res = await fetch(
 `${API_BASE_URL}/courts?sportComplexId=${venueId}&sportId=${sportId}&status=Active&limit=50`
 );
 const json = await res.json();
 return (json.data ?? []).map((c: any) => ({
 id: String(c.id),
 name: c.name,
 hourlyRate: parseFloat(c.hourlyRate),
 surfaceType: c.surfaceType,
 lightingAvailable: c.lightingAvailable,
 status: c.status,
 image: c.image,
 Sport: c.Sport,
 SportComplex: c.SportComplex,
 }));
 } catch {
 return [];
 }
 }

 /** Step 5 — available time slots for a court on a date */
 async getAvailableSlots(
 courtId: string,
 date: string
 ): Promise<AvailableSlot[]> {
 try {
 const res = await fetch(
 `${API_BASE_URL}/courts/${courtId}/available-slots?date=${date}`
 );
 const json = await res.json();
 return json.data ?? [];
 } catch {
 return [];
 }
 }

 /**
  * Court-hidden grid of start-times for a chosen duration on a date.
  * Each cell says whether that start is bookable (possibly via auto-adjust) + price.
  */
 async getAvailableStartTimes(
  sportComplexId: string,
  sportId: string,
  date: string,
  durationHours: number
 ): Promise<StartTimeOption[]> {
  try {
   const res = await fetch(
    `${API_BASE_URL}/courts/availability/times?sportComplexId=${sportComplexId}&sportId=${sportId}&date=${date}&duration=${durationHours}`
   );
   const json = await res.json();
   return json.data ?? [];
  } catch {
   return [];
  }
 }

 /** Court-hidden availability probe for one (startTime, duration); includes a partial fallback. */
 async getAvailability(
  sportComplexId: string,
  sportId: string,
  date: string,
  startTime: string,
  durationHours: number
 ): Promise<AvailabilityResult | null> {
  try {
   const res = await fetch(
    `${API_BASE_URL}/courts/availability?sportComplexId=${sportComplexId}&sportId=${sportId}&date=${date}&startTime=${encodeURIComponent(startTime)}&duration=${durationHours}`
   );
   const json = await res.json();
   return json.data ?? null;
  } catch {
   return null;
  }
 }

 /** My bookings — requires auth */
 async getMyBookings(page = 1, limit = 20): Promise<{ bookings: MyBooking[]; totalItems: number; totalPages: number; currentPage: number }> {
 try {
 const res = await fetchWithAuth(
 `${API_BASE_URL}/courts/bookings/my?page=${page}&limit=${limit}`
 );
 const json = await res.json();
 const bookings = Array.isArray(json.data) ? json.data : [];
 return {
 bookings,
 totalItems: json.pagination?.totalItems ?? bookings.length,
 totalPages: json.pagination?.totalPages ?? 1,
 currentPage: json.pagination?.currentPage ?? 1,
 };
 } catch {
 return { bookings: [], totalItems: 0, totalPages: 1, currentPage: 1 };
 }
 }

 /** Save (replace) the allowed members for a booking. Each member gets an individual QR. */
 async saveMembers(bookingId: number, members: { name: string; phone: string; email?: string }[]): Promise<BookingMember[]> {
 const res = await fetchWithAuth(`${API_BASE_URL}/courts/bookings/${bookingId}/members`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({ members }),
 });
 const json = await res.json();
 if (!res.ok) throw new Error(json.message || 'Failed to save members');
 return json.data ?? [];
 }

 /** Email a single member their individual pass */
 async sendMemberPassByEmail(bookingId: number, memberId: number, recipientEmail?: string): Promise<void> {
 const res = await fetchWithAuth(`${API_BASE_URL}/courts/bookings/${bookingId}/members/${memberId}/send-email`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({ recipientEmail }),
 });
 const json = await res.json();
 if (!res.ok) throw new Error(json.message || 'Failed to send member pass email');
 }

 /** Share a booking pass to an email address */
 async sendPassByEmail(bookingId: number, recipientEmail: string, recipientName?: string): Promise<void> {
 const res = await fetchWithAuth(`${API_BASE_URL}/courts/bookings/${bookingId}/send-email`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({ recipientEmail, recipientName }),
 });
 const json = await res.json();
 if (!res.ok) throw new Error(json.message || 'Failed to send pass email');
 }

 /** Cancel a booking */
 async cancelBooking(bookingId: number): Promise<void> {
 const res = await fetchWithAuth(`${API_BASE_URL}/bookings/${bookingId}`, {
 method: 'DELETE',
 });
 const json = await res.json();
 if (!res.ok) throw new Error(json.message || 'Cancel failed');
 }

 /**
  * Release an unpaid booking hold — call this when the Razorpay checkout is
  * cancelled/dismissed or the payment fails, so the slot frees up straight away
  * and no unpaid booking is left behind. Never throws: it is a cleanup call.
  */
 async releaseBooking(bookingId: number): Promise<void> {
 try {
 await fetchWithAuth(`${API_BASE_URL}/courts/bookings/${bookingId}/release`, {
 method: 'POST',
 });
 } catch {
 /* best-effort — the hold expires on its own if this never lands */
 }
 }

 /** Create a booking (requires auth). Accepts the court-hidden payload (new flow) or the legacy court-specified one. */
 async createBooking(payload: CourtHiddenBookingPayload | BookingPayload): Promise<any> {
 const res = await fetchWithAuth(`${API_BASE_URL}/courts/bookings/create`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify(payload),
 });
 const json = await res.json();
 if (!res.ok) throw new Error(json.message || 'Booking failed');
 return json.data;
 }
}

export const bookingService = new BookingService();

