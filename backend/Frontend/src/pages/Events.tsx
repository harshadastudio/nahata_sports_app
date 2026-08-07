/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { Calendar, ArrowRight, MapPin, Loader2, Ticket, ChevronDown, HelpCircle, Sparkles } from 'lucide-react';
import { eventsService, CmsEvent } from '../services/eventsService';
import { coachingApi } from '../services/coachingApi';
import type { SportComplex } from '../types/coaching';
import { BookEventModal, EventPassData } from '../components/BookEventModal';
import { getImageUrl } from '../lib/utils';
import { Modal } from '../components/ui/Modal';
import { SmartImage } from '../components/ui/SmartImage';

/** Format ISO date"2025-09-26"→"26-09-2025"for display */
function formatDate(dateStr?: string): string {
 if (!dateStr) return '';
 const [y, m, d] = dateStr.split('-');
 return `${d}-${m}-${y}`;
}

/** Pick the earliest slot date for display on the card */
function earliestDate(event: CmsEvent): string | undefined {
 if (!event.slots || event.slots.length === 0) return undefined;
 const sorted = [...event.slots].sort((a, b) => a.date.localeCompare(b.date));
 return sorted[0].date;
}

/**
 * A free event = every pass option costs ₹0. Surfaced on the card (and again in
 * the booking modal) so the price is obvious before opening anything.
 */
function isFreeEvent(event: CmsEvent): boolean {
 if (!event.slots || event.slots.length === 0) return false;
 return event.slots.every((s) => (parseFloat(String(s.price)) || 0) <= 0);
}

const DUMMY_EVENTS: CmsEvent[] = [
  {
    id: '1',
    title: 'Inter-Academy Cricket Tournament 2025',
    description: 'Join us for the biggest cricket tournament of the year. Witness the rising stars of Rajasthan Royals Academy compete for the championship trophy.',
    image: '',
    status: 'Active',
    createdAt: '2025-01-01',
    slots: [
      { id: '1', name: 'Morning Pass', date: '2025-09-26', startTime: '08:00', endTime: '12:00', price: 200, passType: 'General' },
      { id: '2', name: 'Full Day Pass', date: '2025-09-26', startTime: '08:00', endTime: '18:00', price: 500, passType: 'VIP' }
    ]
  },
  {
    id: '2',
    title: 'Badminton Summer Open',
    description: 'A professional-level badminton tournament for all age groups. Single and double categories available. Registration includes a welcome kit and refreshments.',
    image: '',
    status: 'Active',
    createdAt: '2025-01-01',
    slots: [
      { id: '3', name: 'Singles Entry', date: '2025-10-10', startTime: '10:00', endTime: '16:00', price: 300, passType: 'Player' }
    ]
  },
  {
    id: '3',
    title: 'Nahata Sports Carnival',
    description: 'A day of fun, sports, and community. Experience trial coaching sessions for all sports, food stalls, and music. Perfect for families and kids.',
    image: '',
    status: 'Active',
    createdAt: '2025-01-01',
    slots: [
      { id: '4', name: 'Family Entry (4 Pax)', date: '2025-11-15', startTime: '11:00', endTime: '20:00', price: 1000, passType: 'Family' }
    ]
  }
];

/** Accordion of event-specific FAQs, shown in the event detail modal */
const EventFaqs = ({ faqs }: { faqs: { question: string; answer: string }[] }) => {
  const [openIdx, setOpenIdx] = useState<number | null>(0);
  if (!faqs || faqs.length === 0) return null;

  return (
    <div className="border-t border-slate-100 pt-6">
      <div className="flex items-center gap-2 mb-4">
        <HelpCircle size={18} className="text-brand-primary" />
        <h4 className="text-sm uppercase tracking-widest text-slate-900">
          Frequently Asked Questions
        </h4>
      </div>
      <div className="space-y-3">
        {faqs.map((faq, idx) => {
          const isOpen = openIdx === idx;
          return (
            <div
              key={idx}
              className={`rounded-[20px] border transition-all ${
                isOpen ? 'border-slate-300 shadow-md bg-white' : 'border-transparent bg-slate-50'
              }`}
            >
              <button
                onClick={() => setOpenIdx(isOpen ? null : idx)}
                className="w-full flex items-center justify-between gap-4 text-left px-5 py-4"
              >
                <span className="text-sm font-medium text-slate-900">{faq.question}</span>
                <ChevronDown
                  size={18}
                  className={`shrink-0 text-brand-primary transition-transform duration-300 ${
                    isOpen ? 'rotate-180' : ''
                  }`}
                />
              </button>
              <AnimatePresence initial={false}>
                {isOpen && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.25 }}
                    className="overflow-hidden"
                  >
                    <p className="px-5 pb-4 text-sm text-slate-600 leading-relaxed whitespace-pre-wrap">
                      {faq.answer}
                    </p>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export const EventsPage = () => {
 const [events, setEvents] = useState<CmsEvent[]>([]);
 const [isLoading, setIsLoading] = useState(true);
 const [error, setError] = useState<string | null>(null);

 // Sports complex filter
 const [complexes, setComplexes] = useState<SportComplex[]>([]);
 const [selectedComplexId, setSelectedComplexId] = useState<string>('');

 // Booking modal state
  const [bookingEvent, setBookingEvent] = useState<EventPassData | null>(null);
  const [isBookingOpen, setIsBookingOpen] = useState(false);
  const [selectedEventForDetails, setSelectedEventForDetails] = useState<CmsEvent | null>(null);
  const [isDetailsOpen, setIsDetailsOpen] = useState(false);

  // Fetch sports complexes for the filter dropdown
  useEffect(() => {
    coachingApi
      .getSportComplexes()
      .then((data) => setComplexes(data))
      .catch(() => setComplexes([]));
  }, []);

  useEffect(() => {
    setIsLoading(true);
    setError(null);
    eventsService
      .getActiveEvents(1, 50, selectedComplexId || undefined)
      .then((data) => {
        if (data && data.length > 0) {
          setEvents(data);
        } else {
          setEvents(selectedComplexId ? [] : DUMMY_EVENTS);
        }
      })
      .catch(() => {
        setError('Could not load events. Please try again later.');
        setEvents(selectedComplexId ? [] : DUMMY_EVENTS);
      })
      .finally(() => setIsLoading(false));
  }, [selectedComplexId]);

 /** Open booking modal directly — slots are already in the event data */
 const handleBookNow = (event: CmsEvent) => {
 if (!event.slots || event.slots.length === 0) {
 alert('Booking is not yet available for this event. Please check back later.');
 return;
 }
 setBookingEvent({
 id: String(event.id),
 title: event.title,
 eventDate: earliestDate(event),
 slots: event.slots.map((s) => ({
 id: String(s.id),
 name: s.name,
 date: s.date,
 price: parseFloat(String(s.price)) || 0,
 passType: s.passType,
 startTime: s.startTime,
 endTime: s.endTime,
 })),
 customFields: event.customFields ?? [],
 });
  setIsBookingOpen(true);
  };

  const handleReadMore = (event: CmsEvent) => {
    setSelectedEventForDetails(event);
    setIsDetailsOpen(true);
  };

 return (
 <>
 <div className="pt-32 pb-20 bg-white min-h-screen">
 <div className="container-custom">
 {/* Header */}
 <div className="mb-12">
  <motion.h1
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  className="text-4xl md:text-6xl text-slate-900 tracking-tight uppercase text-center leading-[0.9]"
  >
  Upcoming <span className="text-brand-primary">Events</span>
  </motion.h1>
 <div className="w-16 h-1.5 bg-brand-primary mt-2 rounded-full mx-auto"/>

 {/* Sports Complex filter */}
 <div className="mt-6 flex justify-center">
 <div className="relative w-full max-w-xs">
 <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
 <select
 value={selectedComplexId}
 onChange={(e) => setSelectedComplexId(e.target.value)}
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-3 pl-11 pr-4 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary appearance-none transition-all"
 >
 <option value="">All Complexes</option>
 {complexes.map((c) => (
 <option key={c.id} value={c.id}>{c.name}</option>
 ))}
 </select>
 <ChevronDown className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" size={16} />
 </div>
 </div>
 </div>

 {/* Loading */}
 {isLoading && (
 <div className="flex items-center justify-center py-24 text-slate-400">
 <Loader2 size={36} className="animate-spin"/>
 </div>
 )}

 {/* Error */}
 {!isLoading && error && (
 <div className="flex flex-col items-center justify-center py-24 text-slate-400 gap-4">
 <Ticket size={48} strokeWidth={1} />
 <p className="text-base">{error}</p>
 </div>
 )}

  {/* Empty state */}
  {!isLoading && !error && events.length === 0 && (
  <div className="flex flex-col items-center justify-center py-24 text-slate-400 gap-4">
  <Ticket size={48} strokeWidth={1} />
  <p className="text-base">
  Stay tuned for our upcoming sports events and tournaments!
  </p>
  </div>
  )}

 {/* Events Grid */}
 {!isLoading && !error && events.length > 0 && (
 <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-8">
 {events.map((event, i) => {
 const displayDate = earliestDate(event);
 return (
 <motion.div
 key={event.id}
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 transition={{ delay: i * 0.08 }}
 className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden flex flex-col group hover:shadow-xl hover:-translate-y-1 transition-all duration-300"
 >
 {/* Image */}
 <div className="relative h-52 overflow-hidden">
 <SmartImage
 src={getImageUrl(event.image)}
 alt={event.title}
 className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
 />
 {/* FREE banner — top-left corner, only when every pass costs ₹0 */}
 {isFreeEvent(event) && (
 <div className="absolute top-0 left-0 z-10 flex items-center gap-1.5 bg-emerald-500 text-white pl-3 pr-4 py-1.5 rounded-br-2xl shadow-lg">
 <Sparkles size={13} />
 <span className="text-[11px] uppercase tracking-widest">Free Entry</span>
 </div>
 )}
 </div>

 {/* Content */}
 <div className="p-6 flex flex-col flex-1">
 {/* Date & slots badge */}
 <div className="flex items-center gap-4 text-[11px] uppercase tracking-widest text-slate-400 mb-3">
 {displayDate && (
 <span className="flex items-center gap-1.5">
 <Calendar size={13} className="text-brand-primary"/>
 {formatDate(displayDate)}
 </span>
 )}
 {event.slots.length > 0 && (
 <span className="flex items-center gap-1.5">
 <Ticket size={13} className="text-brand-primary"/>
 {event.slots.length} pass option{event.slots.length > 1 ? 's' : ''}
 </span>
 )}
 </div>

 <h3 className="text-base text-slate-900 leading-snug mb-3 group-hover:text-brand-primary transition-colors">
 {event.title}
 </h3>

 <p className="text-slate-500 text-sm leading-relaxed mb-5 flex-1 line-clamp-3">
 {event.description || 'Join us for this exciting event!'}
 </p>

 <div className="flex gap-3">
                      <button
                        onClick={() => handleReadMore(event)}
                        className="flex-1 py-2.5 border border-brand-primary text-brand-primary hover:bg-brand-primary hover:text-white text-xs uppercase tracking-widest rounded-xl transition-all flex items-center justify-center gap-1.5"
                      >
                        Read More
                        <ArrowRight size={13} />
                      </button>

 <button
 onClick={() => handleBookNow(event)}
 className="flex-1 py-2.5 bg-brand-primary hover:bg-brand-dark text-white text-xs uppercase tracking-widest rounded-xl transition-all shadow-md shadow-brand-primary/10 flex items-center justify-center gap-1.5"
 >
 Book Now
 </button>
 </div>
 </div>
 </motion.div>
 );
 })}
 </div>
 )}
 </div>
 </div>

 {/* Booking Modal */}
  <BookEventModal
  event={bookingEvent}
  isOpen={isBookingOpen}
  onClose={() => {
  setIsBookingOpen(false);
  setBookingEvent(null);
  }}
  />

  <Modal
    isOpen={isDetailsOpen}
    onClose={() => setIsDetailsOpen(false)}
    title={selectedEventForDetails?.title}
    size="lg"
  >
    {selectedEventForDetails && (
      <div className="space-y-6">
        <div className="relative h-[300px] rounded-2xl overflow-hidden">
          <SmartImage
            src={getImageUrl(selectedEventForDetails.image)}
            alt={selectedEventForDetails.title}
            className="w-full h-full object-cover"
          />
        </div>

        <div className="flex flex-wrap items-center gap-6 text-slate-400 text-xs uppercase tracking-widest border-b border-slate-100 pb-4">
          {earliestDate(selectedEventForDetails) && (
            <div className="flex items-center gap-2">
              <Calendar size={16} className="text-brand-primary" />
              {formatDate(earliestDate(selectedEventForDetails))}
            </div>
          )}
          {selectedEventForDetails.slots.length > 0 && (
            <div className="flex items-center gap-2">
              <Ticket size={16} className="text-brand-primary" />
              {selectedEventForDetails.slots.length} pass options
            </div>
          )}
        </div>

        <div className="prose prose-slate max-w-none">
          <div className="text-slate-600 leading-relaxed whitespace-pre-wrap">
            {selectedEventForDetails.description || "Join us for this exciting event!"}
          </div>
        </div>

        <EventFaqs faqs={selectedEventForDetails.faqs ?? []} />

        <div className="pt-4 flex justify-end">
          <button
            onClick={() => {
              setIsDetailsOpen(false);
              handleBookNow(selectedEventForDetails);
            }}
            className="px-8 py-3 bg-brand-primary hover:bg-brand-dark text-white text-xs uppercase tracking-widest rounded-xl transition-all shadow-md shadow-brand-primary/10"
          >
            Book Now
          </button>
        </div>
      </div>
    )}
  </Modal>
  </>
 );
};
