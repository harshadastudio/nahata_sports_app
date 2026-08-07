/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import { Link } from 'react-router-dom';
import { useState, useEffect, useRef } from 'react';
import { SectionHeader } from '../../components/UI';
import { viewportOnce } from '../../components/ui/MotionPresets';
import { useCountUp } from '../../hooks/useCountUp';
import {
 CheckCircle2, Calendar, Users, Smartphone,
 ShieldCheck, Star, Trophy, PhoneCall,
} from 'lucide-react';
import { getImageUrl } from '../../lib/utils';
import { SmartImage } from '../../components/ui/SmartImage';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface StatItem { raw: number; suffix: string; label: string; color: string }

// Fallback counter used until the CMS values load (or if the request fails).
const DEFAULT_STATS: StatItem[] = [
 { raw: 2, suffix: '', label: 'Venues', color: '#6C52E8' },
 { raw: 7, suffix: '+', label: 'Sports', color: '#FF6B2C' },
 { raw: 500, suffix: '+', label: 'Members', color: '#059669' },
 { raw: 10, suffix: '+', label: 'Pro Coaches', color: '#0891B2' },
];

const ICON_MAP: Record<string, React.ComponentType<{ size?: number; className?: string }>> = {
 ShieldCheck, Calendar, Users, Smartphone, Star, Trophy, PhoneCall, CheckCircle2,
};
const getIcon = (name: string) => ICON_MAP[name] ?? CheckCircle2;

// ── Stats counter section ──────────────────────────────────────────────
const StatsBlock = ({ stats }: { stats: StatItem[] }) => {
 const ref = useRef<HTMLDivElement>(null);
 const [inView, setInView] = useState(false);

 useEffect(() => {
 const obs = new IntersectionObserver(
 ([entry]) => { if (entry.isIntersecting) setInView(true); },
 { threshold: 0.3 }
 );
 if (ref.current) obs.observe(ref.current);
 return () => obs.disconnect();
 }, []);

 // Only start counting when in view. Fixed 4 hooks (the section is a 4-up grid).
 const c0 = useCountUp(inView ? (stats[0]?.raw ?? 0) : 0, 1400);
 const c1 = useCountUp(inView ? (stats[1]?.raw ?? 0) : 0, 1200);
 const c2 = useCountUp(inView ? (stats[2]?.raw ?? 0) : 0, 1800);
 const c3 = useCountUp(inView ? (stats[3]?.raw ?? 0) : 0, 1500);
 const counts = [c0, c1, c2, c3];

 return (
 <div ref={ref} className="grid grid-cols-2 md:grid-cols-4 gap-px bg-white/[0.03] rounded-[32px] overflow-hidden mb-16 md:mb-24 border border-white/[0.05] shadow-2xl">
 {stats.slice(0, 4).map((stat, i) => (
 <div
 key={stat.label}
 className="bg-slate-900/50 backdrop-blur-sm px-6 py-12 text-center hover:bg-white/[0.02] transition-colors duration-500 relative group"
 >
 {/* Subtle color glow on hover */}
 <div 
 className="absolute inset-0 opacity-0 group-hover:opacity-10 transition-opacity duration-500 blur-xl pointer-events-none"
 style={{ background: `radial-gradient(circle, ${stat.color}, transparent 70%)` }}
 />
 <div
 className="text-white leading-none mb-3 relative z-10"
 style={{ fontSize: 'clamp(2rem, 5vw, 4.5rem)' }}
 >
 {counts[i]}
 <span className="text-[0.6em]"style={{ color: stat.color }}>{stat.suffix}</span>
 </div>
 <div className="text-xs uppercase tracking-[0.2em] text-slate-400 relative z-10">
 {stat.label}
 </div>
 </div>
 ))}
 </div>
 );
};

// ── Why Nahata features ────────────────────────────────────────────────
export const FeaturesSection = () => {
 const [features, setFeatures] = useState<any[]>([]);
 const [sectionImages, setSectionImages] = useState({ image1: '', image2: '' });
 const [stats, setStats] = useState<StatItem[]>(DEFAULT_STATS);

 useEffect(() => {
 Promise.all([
 fetch(`${API_BASE}/student-parent-features`).then(r => r.json()),
 fetch(`${API_BASE}/student-parent-features/section-settings`).then(r => r.json()),
 ])
 .then(([featJson, settingsJson]) => {
 setFeatures(featJson.data ?? []);
 const s = settingsJson.data;
 setSectionImages({ image1: s?.image1 ?? '', image2: s?.image2 ?? '' });
 if (Array.isArray(s?.counters) && s.counters.length) {
 setStats(s.counters.map((c: any) => ({
 raw: Number(c.value) || 0,
 suffix: c.suffix ?? '',
 label: c.label ?? '',
 color: c.color || '#6C52E8',
 })));
 }
 })
 .catch(() => {
 setFeatures([
 { id: 1, title: 'Check Fee Status', description: 'Secure online payment history & receipts', icon: 'ShieldCheck' },
 { id: 2, title: 'Track Attendance', description: 'Real-time updates on training sessions', icon: 'Calendar' },
 { id: 3, title: 'View Coach Feedback', description: 'Direct performance analytical reports', icon: 'Users' },
 { id: 4, title: 'Book & Play', description: 'Easy court reservation in seconds', icon: 'Smartphone' },
 ]);
 });
 }, []);

 if (features.length === 0) return null;

 const img1 = getImageUrl(sectionImages.image1);
 const img2 = getImageUrl(sectionImages.image2);

 return (
 <section className="py-16 md:py-28 bg-slate-900 relative overflow-hidden">
 {/* Decorative background elements */}
 <div className="absolute top-0 right-0 w-[800px] h-[800px] bg-brand-primary/10 rounded-full blur-[120px] opacity-50 pointer-events-none -translate-y-1/2 translate-x-1/3"/>
 <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-emerald-500/5 rounded-full blur-[100px] opacity-50 pointer-events-none translate-y-1/3 -translate-x-1/4"/>
 
 <div className="container-custom relative z-10">
 {/* Stats */}
 <StatsBlock stats={stats} />

 {/* Features split */}
 <div className="grid lg:grid-cols-2 gap-16 items-center">

 {/* Left — stacked images */}
 <motion.div
 initial={{ opacity: 0, x: -32 }}
 whileInView={{ opacity: 1, x: 0 }}
 viewport={viewportOnce}
 transition={{ duration: 0.65, ease: [0.22, 1, 0.36, 1] }}
 className="relative hidden lg:block"
 >
 <div className="grid grid-cols-2 gap-6 relative z-10">
 <div className="space-y-6 translate-y-12">
 <SmartImage
 src={img1}
 alt="Facility"
 className="rounded-[24px] w-full h-[360px] object-cover shadow-2xl border border-white/10"
 />
 </div>
 <div className="space-y-6">
 <SmartImage
 src={img2}
 alt="Facility"
 className="rounded-[24px] w-full h-[420px] object-cover shadow-2xl border border-white/10"
 />
 </div>
 </div>
 </motion.div>

 {/* Right — feature list */}
 <motion.div
 initial={{ opacity: 0, x: 32 }}
 whileInView={{ opacity: 1, x: 0 }}
 viewport={viewportOnce}
 transition={{ duration: 0.65, ease: [0.22, 1, 0.36, 1] }}
 className="lg:pl-8"
 >
 <SectionHeader
 eyebrow="Student & Parent Portal"
 title="Everything You Need in One Place"
 subtitle="Track fees, attendance, coach feedback, and book sessions — all from your dashboard."
 centered={false}
 dark
 />

 <div className="space-y-5 mt-6">
 {features.map((item, i) => {
 const IconComp = getIcon(item.icon);
 return (
 <motion.div
 key={item.id ?? i}
 initial={{ opacity: 0, y: 16 }}
 whileInView={{ opacity: 1, y: 0 }}
 viewport={viewportOnce}
 transition={{ delay: i * 0.08 }}
 className="flex gap-5 group items-start p-4 -ml-4 rounded-2xl hover:bg-white/[0.02] transition-colors cursor-default"
 >
 <div className="w-12 h-12 rounded-[14px] bg-white/5 border border-white/10 flex items-center justify-center shrink-0 group-hover:bg-brand-primary group-hover:border-brand-primary group-hover:shadow-[0_0_20px_rgba(79,70,229,0.4)] transition-all duration-300 group-hover:scale-105">
 <IconComp size={20} className="text-white/60 group-hover:text-white transition-colors"/>
 </div>
 <div className="group-hover:translate-x-1 transition-transform duration-300">
 <h4 className="text-white text-xl md:text-[22px] tracking-tight mb-1">
 {item.title}
 </h4>
 {item.description && (
 <p className="text-slate-400 text-[15px] leading-relaxed">{item.description}</p>
 )}
 </div>
 </motion.div>
 );
 })}
 </div>

 <div className="mt-10 ml-4">
 <Link to="/coaching">
 <button className="inline-flex items-center gap-2 text-brand-bright text-[15px] hover:text-white transition-colors group">
 Learn about our programs
 <span className="transition-transform group-hover:translate-x-1">→</span>
 </button>
 </Link>
 </div>
 </motion.div>
 </div>
 </div>
 </section>
 );
};

