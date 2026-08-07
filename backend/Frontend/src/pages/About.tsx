/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import { useState, useEffect } from 'react';
import { CheckCircle2, MapPin, Trophy, Loader2 } from 'lucide-react';
import { getImageUrl } from '../lib/utils';
import { SmartImage } from '../components/ui/SmartImage';

const API = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── Types matching the new API structure ──────────────────────────────────────
interface Section {
 id: number;
 label: string | null;
 heading: string | null;
 description: string | null;
 image: string | null;
 bulletPoints: string[] | null;
 extraText: string | null;
 imagePosition: 'left' | 'right';
 sortOrder: number;
}

interface Settings {
 heroTitle: string;
 whyChooseHeading: string | null;
 whyChoosePoints: string[] | null;
}

// ── Fallback data ─────────────────────────────────────────────────────────────
const FALLBACK_SETTINGS: Settings = {
 heroTitle: 'About Us',
 whyChooseHeading: 'Why Choose Nahata Sports?',
 whyChoosePoints: [
 'Convenient locations in Pune with modern amenities',
 'Expert instructors across multiple sports',
 'Simplified booking and payment systems',
 'A supportive environment for athletes of all ages',
 'Strong focus on progress, community, and real-time communication',
 ],
};

const FALLBACK_SECTIONS: Section[] = [
 {
 id: 1,
 label: 'Sinhagad Road',
 heading: 'Transforming Future Champions, One Game at a Time',
 description:"At Nahata Sports, we're on a mission to inspire, train, and empower the next generation of athletes across Maharashtra. With facilities at Sinhagad Road and Gangadham Chowk, our multi-center complexes offer world-class training and seamless booking experiences that make sports easily accessible for all.",
 image: '',
 bulletPoints: ['Cricket (Rajasthan Royals Academy)', 'Badminton', 'Basketball', 'Skating', 'Karate', 'Dance & Zumba', 'Fun Fitness (3+ years)'],
 extraText:"Need a space to play or train? Our Book & Play feature lets you reserve courts and grounds in real time—with hassle-free QR code payments offering fast, secure, and convenient access.",
 imagePosition: 'left',
 sortOrder: 1,
 },
 {
 id: 2,
 label: 'Gangadham Chowk',
 heading: 'Designed for You: Students and Parents Love It!',
 description: 'Our systems are built with families in mind:',
 image: '',
 bulletPoints: ['Easy access to fee status and receipts', 'Attendance tracking for students', 'Coach feedback visibility', 'A structured program timeline with clear expectations'],
 extraText:"We're more than just a sports center—we're a community. Stay in the loop with free training camps, tournaments, WhatsApp alerts, and schedule notifications.",
 imagePosition: 'right',
 sortOrder: 2,
 },
];

// ── Single Section Component ──────────────────────────────────────────────────
const AboutSection = ({ section, index }: { section: Section; index: number }) => {
 const isImageLeft = section.imagePosition === 'left';

 const imageEl = (
 <motion.div
 initial={{ opacity: 0, x: isImageLeft ? -30 : 30 }}
 whileInView={{ opacity: 1, x: 0 }}
 viewport={{ once: true }}
 transition={{ delay: 0.1 }}
 className={`relative rounded-[3rem] overflow-hidden shadow-2xl ${!isImageLeft ? 'lg:order-2' : ''}`}
 >
 <SmartImage
 src={getImageUrl(section.image)}
 alt={section.label || `Section ${index + 1}`}
 className="w-full aspect-[4/5] object-cover"
 />
 {section.label && (
 <div className="absolute inset-x-0 bottom-0 p-8 bg-gradient-to-t from-black/60 to-transparent">
 <div className="flex items-center gap-2 text-white uppercase tracking-widest text-sm">
 <MapPin size={18} className="text-indigo-400"/>
 {section.label}
 </div>
 </div>
 )}
 </motion.div>
 );

 const contentEl = (
 <motion.div
 initial={{ opacity: 0, x: isImageLeft ? 30 : -30 }}
 whileInView={{ opacity: 1, x: 0 }}
 viewport={{ once: true }}
 transition={{ delay: 0.2 }}
 className={`space-y-8 ${!isImageLeft ? 'lg:order-1' : ''}`}
 >
 {/* Label + Heading */}
 <div>
 {section.label && (
 <h2 className="text-brand-primary uppercase tracking-widest text-xs mb-3 flex items-center gap-2">
 <span className="w-2 h-2 rounded-full bg-brand-primary inline-block"/>
 {section.label}
 </h2>
 )}
  {section.heading && (
  <h3 className="text-2xl sm:text-3xl md:text-4xl text-slate-900 uppercase tracking-tight leading-[1.1] mb-6">
  {section.heading}
  </h3>
  )}
 {section.description && (
 <p className="text-slate-500 leading-relaxed">{section.description}</p>
 )}
 </div>

 {/* Bullet points */}
 {section.bulletPoints && section.bulletPoints.length > 0 && (
 <div className="bg-slate-50 p-8 rounded-[2rem] border border-slate-100">
 <h4 className="text-slate-900 uppercase tracking-tight mb-4 flex items-center gap-2">
 <Trophy className="text-brand-primary"size={20} />
 Key Highlights
 </h4>
 <ul className="grid sm:grid-cols-2 gap-3">
 {section.bulletPoints.map((item, i) => (
 <li key={i} className="flex items-center gap-2 text-xs text-slate-700 uppercase tracking-tight">
 <CheckCircle2 className="text-brand-primary shrink-0"size={14} />
 {item}
 </li>
 ))}
 </ul>
 </div>
 )}

 {/* Extra text */}
 {section.extraText && (
 <div>
 <p className="text-slate-500 text-sm leading-relaxed">{section.extraText}</p>
 </div>
 )}
 </motion.div>
 );

 return (
 <div className="grid lg:grid-cols-2 gap-12 items-center mb-24">
 {imageEl}
 {contentEl}
 </div>
 );
};

// ── Main Page ─────────────────────────────────────────────────────────────────
export const AboutPage = () => {
 const [settings, setSettings] = useState<Settings>(FALLBACK_SETTINGS);
 const [sections, setSections] = useState<Section[]>(FALLBACK_SECTIONS);
 const [loading, setLoading] = useState(true);

 useEffect(() => {
 fetch(`${API}/about`)
 .then((r) => r.json())
 .then((json) => {
 if (json.success && json.data) {
 // New API returns { settings, sections[] }
 const { settings: s, sections: sec } = json.data;

 setSettings({
 heroTitle: s?.heroTitle || FALLBACK_SETTINGS.heroTitle,
 whyChooseHeading: s?.whyChooseHeading || FALLBACK_SETTINGS.whyChooseHeading,
 whyChoosePoints: s?.whyChoosePoints?.length ? s.whyChoosePoints : FALLBACK_SETTINGS.whyChoosePoints,
 });

 if (sec && sec.length > 0) {
 setSections(sec);
 }
 // If no sections from API, keep fallback
 }
 })
 .catch(() => {
 // Keep fallback data on error
 })
 .finally(() => setLoading(false));
 }, []);

 if (loading) {
 return (
 <div className="min-h-screen flex items-center justify-center pt-32">
 <Loader2 size={32} className="animate-spin text-brand-primary"/>
 </div>
 );
 }

 const whyPoints = settings.whyChoosePoints ?? [];

 return (
 <div className="pt-32 pb-20 bg-white min-h-screen">
 <div className="container-custom">

 {/* Hero */}
 <motion.div
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 className="text-center mb-16"
 >
  <h1 className="text-4xl md:text-6xl text-slate-900 tracking-tight uppercase leading-[0.9] mb-2">
  About <span className="text-brand-primary">Us</span>
  </h1>
 <div className="w-20 h-1.5 bg-slate-900 mx-auto rounded-full"/>
 </motion.div>

 {/* Dynamic sections — renders ALL sections from CMS */}
 {sections.map((section, idx) => (
 <div key={section.id ?? idx}>
 <AboutSection section={section} index={idx} />
 </div>
 ))}

 {/* Why Choose Section */}
 {whyPoints.length > 0 && (
 <div className="bg-slate-900 rounded-[4rem] p-12 md:p-20 text-white relative overflow-hidden">
 <div className="absolute top-0 right-0 w-64 h-64 bg-brand-primary rounded-full blur-[120px] opacity-20 -mr-32 -mt-32"/>
 <div className="absolute bottom-0 left-0 w-64 h-64 bg-brand-primary rounded-full blur-[120px] opacity-20 -ml-32 -mb-32"/>

 <div className="relative z-10">
 <h3 className="text-3xl md:text-5xl uppercase tracking-tight text-center mb-16">
 {settings.whyChooseHeading?.includes('Nahata Sports') ? (
 <>Why Choose <span className="text-indigo-400">Nahata Sports?</span></>
 ) : (
 settings.whyChooseHeading
 )}
 </h3>

 <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
 {whyPoints.map((item, i) => (
 <motion.div
 key={i}
 initial={{ opacity: 0, y: 20 }}
 whileInView={{ opacity: 1, y: 0 }}
 viewport={{ once: true }}
 transition={{ delay: i * 0.1 }}
 className="bg-white/5 border border-white/10 p-8 rounded-[2.5rem] backdrop-blur-sm group hover:bg-white/10 transition-colors"
 >
 <CheckCircle2 className="text-indigo-400 mb-6 group-hover:scale-110 transition-transform"size={32} />
 <p className="text-lg leading-snug">{item}</p>
 </motion.div>
 ))}
 {/* Decorative filler card when grid has 2 items in last row */}
 {whyPoints.length % 3 === 2 && (
 <div className="hidden lg:flex items-center justify-center p-8 border-4 border-dashed border-white/10 rounded-[2.5rem]">
 <p className="text-white/30 text-4xl uppercase tracking-tighter text-center rotate-3">
 Play with <span className="text-white/10">Passion</span>
 </p>
 </div>
 )}
 </div>
 </div>
 </div>
 )}
 </div>
 </div>
 );
};
