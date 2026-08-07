/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import { Link } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { MapPin, ArrowUpRight, Star, Trophy, Calendar, PhoneCall, Phone, Mail, Clock } from 'lucide-react';
import { Button, SectionHeader } from '../../components/UI';
import { getImageUrl } from '../../lib/utils';
import { viewportOnce } from '../../components/ui/MotionPresets';
import { SmartImage } from '../../components/ui/SmartImage';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

const ICON_MAP: Record<string, React.ComponentType<{ size?: number; className?: string }>> = {
 Star, Trophy, Calendar, PhoneCall,
};

// ── Locations ──────────────────────────────────────────────────────────
export const LocationsSection = () => {
 const [centers, setCenters] = useState<any[]>([]);
 const [loading, setLoading] = useState(true);

 useEffect(() => {
 fetch(`${API_BASE}/sports-complexes?status=Active&showOnFrontend=true&limit=50`)
 .then(r => r.json())
 .then(json => setCenters(json.data?.sportsComplexes ?? []))
 .catch(() => setCenters([
 {
 id: 1, name: 'Sinhagad Road',
 address: 'Near Veer Baji Pasalkar Chowk, Wadgaon Budruk, Pune — 411041',
 sportsOffered: ['CRICKET', 'BASKETBALL', 'SKATING', 'KARATE', 'FUN FITNESS'],
 image: '', mapUrl: null,
 },
 {
 id: 2, name: 'Gangadham Chowk',
 address: 'Near Aai Mata Mandir, Ganga Dham Chowk, Pune — 411037',
 sportsOffered: ['BADMINTON', 'DANCE', 'ZUMBA', 'SKATING'],
 image: '', mapUrl: null,
 },
 ]))
 .finally(() => setLoading(false));
 }, []);

 if (!loading && centers.length === 0) return null;

 return (
    <section className="py-16 md:py-24 bg-white">
 <div className="container-custom">
 <SectionHeader
 eyebrow="Our Locations"
 title="Two World-Class Venues in Pune"
 subtitle="Conveniently located across the city — find a center near you."
 centered={true}
 />

 {loading ? (
 <div className="grid lg:grid-cols-2 gap-8">
 {[0, 1].map(i => (
 <div key={i} className="rounded-[24px] bg-slate-100 animate-shimmer h-[500px]"/>
 ))}
 </div>
 ) : (
 <div className="grid lg:grid-cols-2 gap-8">
 {centers.map((loc, idx) => (
 <motion.div
 key={loc.id ?? idx}
 initial={{ opacity: 0, y: 28 }}
 whileInView={{ opacity: 1, y: 0 }}
 viewport={viewportOnce}
 transition={{ delay: idx * 0.12, duration: 0.55, ease: [0.22, 1, 0.36, 1] }}
 className="group bg-white rounded-[24px] overflow-hidden border border-slate-200 shadow-sm hover:shadow-[0_16px_40px_rgba(15,23,42,0.06)] transition-shadow duration-500 flex flex-col"
 >
 {/* Image */}
 <div className="relative h-64 overflow-hidden shrink-0">
 <SmartImage
 src={getImageUrl(loc.image)}
 alt={loc.name}
 className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700 ease-out"
 />
 {/* Subtle dark overlay at bottom */}
 <div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-slate-900/40 to-transparent"/>
 
 {/* Name badge */}
 <div className="absolute top-5 left-5 px-3 py-1.5 rounded-full bg-white/95 backdrop-blur-md text-slate-900 text-[11px] uppercase tracking-widest shadow-sm">
 {loc.name}
 </div>
 {/* Sport count */}
 {(loc.sportsOffered?.length ?? 0) > 0 && (
 <div className="absolute bottom-4 right-4 px-3 py-1.5 rounded-full bg-slate-900/60 backdrop-blur-md text-white border border-white/20 text-[11px] tracking-wide">
 {loc.sportsOffered.length} sports
 </div>
 )}
 </div>

 {/* Content */}
 <div className="p-8 flex-1 flex flex-col">
          <h3 className="text-2xl md:text-3xl text-slate-900 mb-3 tracking-tight uppercase">{loc.name}</h3>
 <p className="text-slate-500 text-[15px] flex items-start gap-2.5 leading-relaxed mb-4">
 <MapPin size={18} className="text-brand-bright shrink-0 mt-0.5"/>
 {loc.address}{loc.city ? `, ${loc.city}` : ''}
 </p>

 {(loc.contactPhone || loc.contactEmail || loc.openingHours) && (
 <div className="flex flex-col gap-2 mb-6 text-slate-500 text-[14px]">
 {loc.contactPhone && (
 <a href={`tel:${loc.contactPhone}`} className="flex items-center gap-2.5 hover:text-brand-primary transition-colors w-fit">
 <Phone size={16} className="text-brand-bright shrink-0"/>
 {loc.contactPhone}
 </a>
 )}
 {loc.contactEmail && (
 <a href={`mailto:${loc.contactEmail}`} className="flex items-center gap-2.5 hover:text-brand-primary transition-colors w-fit">
 <Mail size={16} className="text-brand-bright shrink-0"/>
 {loc.contactEmail}
 </a>
 )}
 {loc.openingHours && (
 <span className="flex items-center gap-2.5">
 <Clock size={16} className="text-brand-bright shrink-0"/>
 {loc.openingHours}
 </span>
 )}
 </div>
 )}

 {(loc.sportsOffered ?? []).length > 0 && (
 <div className="flex flex-wrap gap-2 mb-8">
 {(loc.sportsOffered as string[]).slice(0, 5).map(s => (
 <span
 key={s}
 className="px-2.5 py-1.5 bg-brand-tint text-brand-primary rounded-md text-[10px] uppercase tracking-wider"
 >
 {s}
 </span>
 ))}
 {loc.sportsOffered.length > 5 && (
 <span className="px-2.5 py-1.5 bg-slate-100 text-slate-500 rounded-md text-[10px] uppercase tracking-wider">
 +{loc.sportsOffered.length - 5} more
 </span>
 )}
 </div>
 )}

 <div className="mt-auto flex items-center gap-4 pt-4">
 {loc.mapUrl ? (
 <a href={loc.mapUrl} target="_blank"rel="noopener noreferrer"className="w-full">
 <button className="btn-outline w-full px-4 py-2.5 flex justify-center items-center gap-2">
 Get Directions <ArrowUpRight size={15} />
 </button>
 </a>
 ) : (
 <button className="btn-outline w-full px-4 py-2.5 flex justify-center items-center gap-2 opacity-50 cursor-not-allowed">
 Get Directions <ArrowUpRight size={15} />
 </button>
 )}
 </div>
 </div>
 </motion.div>
 ))}
 </div>
 )}
 </div>
 </section>
 );
};

// ── Events / Announcements ─────────────────────────────────────────────
export const EventsSection = () => {
 const [events, setEvents] = useState<any[]>([]);

 useEffect(() => {
 fetch(`${API_BASE}/announcements?status=Active&limit=20`)
 .then(r => r.json())
 .then(json => setEvents(json.data ?? []))
 .catch(() => setEvents([
 { id: 1, title: 'Summer Coaching Camp', description: 'Intensive 2-week training camps to improve your game from scratch.', icon: 'Star', date: 'MAY 15' },
 { id: 2, title: 'Holiday Notice', description: 'Complex will remain closed on upcoming Sunday for maintenance.', icon: 'Calendar', date: 'MAY 20' },
 { id: 3, title: 'District Tournament', description: 'Open registration for Pune district badminton league.', icon: 'Trophy', date: 'JUN 05' },
 { id: 4, title: 'WhatsApp Alerts', description: 'Join our broadcast group for timely facility updates.', icon: 'PhoneCall', date: 'LIVE'},
 ]));
 }, []);

 if (events.length === 0) return null;

 return (
    <section className="py-16 md:py-24 bg-surface-base border-t border-slate-100">
 <div className="container-custom">
 <SectionHeader
 eyebrow="Announcements"
 title="Upcoming Events & Updates"
 centered={true}
 />

 <div className="grid lg:grid-cols-2 gap-5 mt-10">
 {events.map((event, idx) => {
 const IconComp = ICON_MAP[event.icon] ?? Star;
 const isLive = event.date === 'LIVE' || event.date === 'SOON';
 
 return (
 <motion.div
 key={event.id ?? idx}
 initial={{ opacity: 0, x: idx % 2 === 0 ? -20 : 20 }}
 whileInView={{ opacity: 1, x: 0 }}
 viewport={viewportOnce}
 transition={{ delay: idx * 0.08 }}
 className="bg-white border border-slate-200 rounded-[20px] p-6 flex items-start gap-6 group hover:border-brand-bright/30 hover:shadow-[0_8px_30px_rgba(15,23,42,0.06)] transition-all duration-300"
 >
 {/* Date / Status Block */}
 <div className={`shrink-0 w-16 h-16 rounded-[14px] flex flex-col items-center justify-center tracking-tight shadow-sm border ${
 isLive 
 ? 'bg-brand-bright text-white border-brand-primary' 
 : 'bg-slate-50 text-slate-800 border-slate-100'
 }`}>
 {isLive ? (
 <span className="text-[15px] uppercase">{event.date}</span>
 ) : event.date ? (
 <>
 <span className="text-[11px] text-slate-500 uppercase">{event.date.split(' ')[0]}</span>
 <span className="text-xl leading-none mt-0.5">{event.date.split(' ')[1]}</span>
 </>
 ) : (
 <IconComp size={24} className="text-brand-bright"/>
 )}
 </div>

 <div className="flex-1 py-0.5">
 <div className="flex items-center gap-2 mb-2">
 {isLive && (
 <span className="w-1.5 h-1.5 rounded-full bg-brand-bright animate-pulse"/>
 )}
              <h4 className="text-lg md:text-xl text-slate-900 uppercase tracking-tight line-clamp-1">{event.title}</h4>
 </div>
 <p className="text-slate-500 text-[14px] leading-relaxed line-clamp-2">{event.description}</p>
 
 {event.buttonTitle && event.buttonUrl && (
 <a
 href={event.buttonUrl}
 target="_blank"
 rel="noopener noreferrer"
 className="mt-4 inline-flex items-center gap-1.5 text-[12px] text-brand-bright hover:text-brand-primary transition-colors uppercase tracking-widest group/link"
 >
 {event.buttonTitle}
 <span className="transition-transform group-hover/link:translate-x-1">→</span>
 </a>
 )}
 </div>
 </motion.div>
 );
 })}
 </div>
 
 <div className="mt-12 text-center">
 <Link to="/events">
 <button className="text-slate-500 hover:text-slate-900 text-sm transition-colors border-b border-transparent hover:border-slate-900 pb-0.5">
 View All Announcements
 </button>
 </Link>
 </div>
 </div>
 </section>
 );
};

