/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import { Link } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { ArrowRight, Check, Zap } from 'lucide-react';
import { Button, SectionHeader } from '../../components/UI';
import { getImageUrl } from '../../lib/utils';
import { viewportOnce } from '../../components/ui/MotionPresets';
import { SmartImage } from '../../components/ui/SmartImage';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export const BookingSection = () => {
 const [sports, setSports] = useState<{ id: string; name: string }[]>([]);
 const [courts, setCourts] = useState<any[]>([]);
 const [activeTab, setActiveTab] = useState('');
 const [loading, setLoading] = useState(true);

 useEffect(() => {
 // Independent CMS Courts — managed directly in Admin → CMS → Court or Ground.
 // Not linked to the master Court inventory. Cards are grouped by `sportName`.
 fetch(`${API_BASE}/cms-courts/frontend`)
 .then(r => r.json())
 .then(json => {
 const all: any[] = json.data ?? [];
 setCourts(all);
 const seen = new Set<string>();
 const unique: { id: string; name: string }[] = [];
 for (const c of all) {
 const key = (c.sportName || '').trim();
 if (key && !seen.has(key)) {
 seen.add(key);
 unique.push({ id: key, name: key });
 }
 }
 setSports(unique);
 if (unique.length > 0) setActiveTab(unique[0].id);
 })
 .catch(() => {
 setSports([
 { id: 'Badminton', name: 'Badminton' },
 { id: 'Pickleball', name: 'Pickleball' },
 { id: 'Cricket', name: 'Cricket' },
 ]);
 setActiveTab('Badminton');
 })
 .finally(() => setLoading(false));
 }, []);

 const activeSport = sports.find(s => s.id === activeTab);
 const activeCourts = courts.filter(c => (c.sportName || '').trim() === activeTab);
 const displayCourt = activeCourts[0] ?? null;

 const features = [
 'Real-time availability',
 'Book hourly slots',
 'QR code entry pass',
 ];

 return (
 <section className="py-16 md:py-24 bg-white">
 <div className="container-custom">
 <SectionHeader
 eyebrow="Court Booking"
 title="Book a Court or Ground"
 subtitle="Simple, fast, and secure — reserve your slot in under 60 seconds."
 centered={true}
 />

 {loading ? (
 <div className="grid lg:grid-cols-2 gap-0 rounded-[24px] overflow-hidden border border-slate-200 animate-shimmer bg-slate-50 h-[450px]"/>
 ) : (
 <>
 {/* Sport Filter Tabs */}
 <div className="flex justify-center gap-3 mb-12 flex-wrap">
 {sports.map(sport => (
 <button
 key={sport.id}
 onClick={() => setActiveTab(sport.id)}
 className={`relative px-6 py-2.5 rounded-full text-[13px] tracking-wide transition-all duration-300 ${
 activeTab === sport.id
 ? 'bg-slate-900 text-white shadow-md'
 : 'bg-white text-slate-500 hover:text-slate-900 border border-slate-200 hover:border-slate-300 hover:bg-slate-50'
 }`}
 >
 {sport.name}
 {activeCourts.length > 1 && activeTab === sport.id && (
 <span className="absolute -top-1.5 -right-1.5 w-5 h-5 bg-brand-bright rounded-full text-white text-[10px] flex items-center justify-center shadow-sm">
 {activeCourts.length}
 </span>
 )}
 </button>
 ))}
 </div>

 {/* Selected Court Card */}
 <motion.div
 key={activeTab}
 initial={{ opacity: 0, y: 16 }}
 animate={{ opacity: 1, y: 0 }}
 transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
 className="grid lg:grid-cols-2 rounded-[24px] overflow-hidden bg-white shadow-sm hover:shadow-[0_20px_40px_rgba(15,23,42,0.06)] transition-shadow duration-500 border border-slate-200"
 >
 {/* Left — content */}
 <div className="p-8 md:p-14 flex flex-col justify-center relative">
 {/* Status pill */}
 <div className="inline-flex items-center gap-2 text-[11px] uppercase tracking-widest text-emerald-600 mb-6 bg-emerald-50 px-3 py-1.5 rounded-full w-fit border border-emerald-100">
 <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"/>
 Available now
 </div>

  <h3 className="text-slate-900 uppercase tracking-tight leading-[0.95] mb-4 text-3xl md:text-5xl lg:text-6xl">
  {activeSport?.name ?? '—'}
  </h3>

 {displayCourt && (
 <p className="text-[15px] text-slate-500 mb-8">{displayCourt.name}</p>
 )}

 <ul className="space-y-4 mb-10">
 {features.map(item => (
 <li key={item} className="flex items-center gap-3 text-slate-600 text-[15px]">
 <div className="w-5 h-5 rounded-full bg-brand-tint flex items-center justify-center shrink-0">
 <Check size={12} className="text-brand-bright"strokeWidth={3} />
 </div>
 {item}
 </li>
 ))}
 </ul>

 <div className="flex flex-col sm:flex-row sm:items-center gap-6 mt-auto pt-6 border-t border-slate-100">
 <Link to="/book">
 <button className="btn-primary px-8 py-3.5 text-[15px] flex items-center gap-2 w-full sm:w-auto justify-center">
 Reserve Slot <ArrowRight size={16} />
 </button>
 </Link>
 {displayCourt && (
 <div className="flex items-baseline gap-1.5">
 <div className="text-3xl text-slate-900">
 ₹{parseFloat(displayCourt.hourlyRate ?? '800').toLocaleString('en-IN')}
 </div>
 <div className="text-sm text-slate-500">/hour</div>
 </div>
 )}
 </div>
 </div>

 {/* Right — image */}
 <div className="relative h-[300px] lg:h-auto overflow-hidden bg-slate-100">
 <SmartImage
 src={getImageUrl(displayCourt?.image)}
 className="w-full h-full object-cover transition-transform duration-600 ease-out hover:scale-105"
 alt={activeSport?.name ?? 'Court'}
 />
 
 {/* Inner shadow overlay */}
 <div className="absolute inset-0 border-[4px] border-white/10 rounded-r-[24px] pointer-events-none"/>

 {/* Surface pill inside image */}
 <div className="absolute bottom-6 left-6 glass-card-light px-4 py-2 rounded-full text-[12px] text-slate-900 shadow-sm border border-white/40">
 {displayCourt?.surfaceType ? `${displayCourt.surfaceType} Surface` : 'Indoor · Premium Surface'}
 </div>
 </div>
 </motion.div>
 </>
 )}
 </div>
 </section>
 );
};

