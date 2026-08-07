/**
 * Events Service
 * Fetches events created by the admin via CMS → Events module.
 * Source: /api/event-passes (EventPasses table with slots)
 */

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export interface EventPassSlot {
 id: string;
 name: string;
 date: string;
 price: number;
 passType?: string;
 startTime?: string;
 endTime?: string;
}

export interface EventFaq {
 question: string;
 answer: string;
}

/** Extra input the admin added to this event's booking form (CMS → Events). */
export interface EventCustomField {
 key: string;
 label: string;
 type: 'text' | 'textarea' | 'number' | 'email' | 'phone' | 'date' | 'select';
 required: boolean;
 placeholder?: string | null;
 options?: string[];
}

export interface CmsEvent {
 id: string;
 title: string;
 description?: string;
 image?: string;
 status: 'Active' | 'Inactive';
 sportComplexId?: number | null;
 sportComplex?: { id: number; name: string } | null;
 slots: EventPassSlot[];
 faqs?: EventFaq[];
 customFields?: EventCustomField[];
 createdAt: string;
}

// Keep EventAnnouncement as an alias so existing imports don't break
export type EventAnnouncement = CmsEvent;

class EventsService {
 /**
 * Fetch all active events for the public frontend.
 */
 async getActiveEvents(page = 1, limit = 50, sportComplexId?: number | string): Promise<CmsEvent[]> {
 try {
 let url = `${API_BASE_URL}/event-passes?status=Active&page=${page}&limit=${limit}`;
 if (sportComplexId !== undefined && sportComplexId !== null && sportComplexId !== '') {
 url += `&sportComplexId=${sportComplexId}`;
 }
 const res = await fetch(url);

 if (!res.ok) {
 console.error('Failed to fetch events:', res.statusText);
 return [];
 }

 const json = await res.json();
 return json.data ?? [];
 } catch (error) {
 console.error('Error fetching events:', error);
 return [];
 }
 }
}

export const eventsService = new EventsService();

