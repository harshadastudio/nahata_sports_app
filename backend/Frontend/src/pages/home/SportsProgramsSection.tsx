/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import { Link } from 'react-router-dom';
import { MapPin, ArrowRight } from 'lucide-react';
import { useState, useEffect } from 'react';
import { Button, SectionHeader } from '../../components/UI';
import { PROGRAMS } from '../../constants';
import { getImageUrl } from '../../lib/utils';
import { viewportOnce, scaleIn } from '../../components/ui/MotionPresets';
import { SmartImage } from '../../components/ui/SmartImage';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// Sport color map with beautiful gradients
const SPORT_COLORS: Record<string, { solid: string; gradient: string; shadow: string }> = {
 cricket: { 
 solid: '#059669', 
 gradient: 'linear-gradient(135deg, #059669 0%, #10b981 100%)',
 shadow: 'rgba(5, 150, 105, 0.4)'
 },
 basketball: { 
 solid: '#EA580C', 
 gradient: 'linear-gradient(135deg, #EA580C 0%, #F97316 100%)',
 shadow: 'rgba(234, 88, 12, 0.4)'
 },
 badminton: { 
 solid: '#2563EB', 
 gradient: 'linear-gradient(135deg, #2563EB 0%, #3B82F6 100%)',
 shadow: 'rgba(37, 99, 235, 0.4)'
 },
 skating: { 
 solid: '#0891B2', 
 gradient: 'linear-gradient(135deg, #0891B2 0%, #06B6D4 100%)',
 shadow: 'rgba(8, 145, 178, 0.4)'
 },
 karate: { 
 solid: '#DC2626', 
 gradient: 'linear-gradient(135deg, #DC2626 0%, #EF4444 100%)',
 shadow: 'rgba(220, 38, 38, 0.4)'
 },
 fitness: { 
 solid: '#CA8A04', 
 gradient: 'linear-gradient(135deg, #CA8A04 0%, #EAB308 100%)',
 shadow: 'rgba(202, 138, 4, 0.4)'
 },
 dance: { 
 solid: '#DB2777', 
 gradient: 'linear-gradient(135deg, #DB2777 0%, #EC4899 100%)',
 shadow: 'rgba(219, 39, 119, 0.4)'
 },
 zumba: { 
 solid: '#DB2777', 
 gradient: 'linear-gradient(135deg, #DB2777 0%, #EC4899 100%)',
 shadow: 'rgba(219, 39, 119, 0.4)'
 },
 hockey: { 
 solid: '#0EA5E9', 
 gradient: 'linear-gradient(135deg, #0EA5E9 0%, #06B6D4 50%, #14B8A6 100%)',
 shadow: 'rgba(14, 165, 233, 0.5)'
 },
 tennis: { 
 solid: '#059669', 
 gradient: 'linear-gradient(135deg, #059669 0%, #10b981 100%)',
 shadow: 'rgba(5, 150, 105, 0.4)'
 },
 yoga: { 
 solid: '#F59E0B', 
 gradient: 'linear-gradient(135deg, #F59E0B 0%, #FBBF24 100%)',
 shadow: 'rgba(245, 158, 11, 0.4)'
 },
 football: { 
 solid: '#16A34A', 
 gradient: 'linear-gradient(135deg, #16A34A 0%, #22C55E 100%)',
 shadow: 'rgba(22, 163, 74, 0.4)'
 },
 default: { 
 solid: '#6C52E8', 
 gradient: 'linear-gradient(135deg, #6C52E8 0%, #8B5CF6 100%)',
 shadow: 'rgba(108, 82, 232, 0.4)'
 },
};

function getSportColor(name: string): { solid: string; gradient: string; shadow: string } {
 const key = name.toLowerCase().replace(/[^a-z]/g, '');
 for (const [k, v] of Object.entries(SPORT_COLORS)) {
 if (key.includes(k)) return v;
 }
 return SPORT_COLORS.default;
}

interface SportProgram {
    id: string;
    title: string;
    location: string;
    image: string;
    category?: string;
    venueLabel?: string;
}

interface SportCardProps {
    program: SportProgram;
    index: number;
}

const SportCard = ({ program, index, isMobile = false }: SportCardProps & { isMobile?: boolean }) => {
    const color = getSportColor(program.title);
    // Make the first card larger on desktop
    const isFirst = index === 0;

 return (
 <motion.div
 variants={scaleIn}
 initial="hidden"
 whileInView="visible"
 viewport={viewportOnce}
 transition={{ delay: index * 0.07 }}
 className={`group relative rounded-[24px] overflow-hidden cursor-pointer shadow-sm hover:shadow-[0_16px_40px_rgba(47,44,143,0.12)] transition-shadow duration-500 bg-white ${
 isFirst ? 'md:col-span-2 md:row-span-2' : ''
 }`}
 style={{ aspectRatio: isFirst ? 'auto' : '2/3' }}
 >
 {/* Top accent border */}
 <div className="absolute top-0 left-0 right-0 h-[3px] z-20"style={{ background: color.solid }} />

            {/* Background image container for zoom effect */}
            <div className="absolute inset-0 z-0 overflow-hidden bg-slate-100">
                <SmartImage
                    src={program.image}
                    alt={program.title}
                    className="w-full h-full object-cover transition-transform duration-600 ease-out group-hover:scale-105"
                />
            </div>

            {/* Gradient overlay */}
            <div className="absolute inset-0 z-10 bg-gradient-to-t from-[rgba(15,23,42,0.9)] via-[rgba(15,23,42,0.15)] to-transparent" />

            {/* Optional Top Right Badge (venue pill) */}
            {(program.venueLabel ?? '2 Venues') && (
                <div className="absolute top-4 right-4 z-20 glass-card-light rounded-full px-2.5 py-1 text-[10px] text-slate-800 border border-white/20 shadow-sm backdrop-blur-md bg-white/70">
                    {program.venueLabel ?? '2 Venues'}
                </div>
            )}

 {/* Sport color glow behind card on hover (we'll do an inner glow for better containment) */}
 <div
 className="absolute inset-0 z-10 opacity-0 group-hover:opacity-20 transition-opacity duration-500 mix-blend-screen"
 style={{ background: `radial-gradient(circle at bottom, ${color.solid}, transparent 60%)` }}
 />

 {/* Card content */}
 <div className="absolute inset-x-0 bottom-0 z-20 p-6 flex flex-col justify-end">
 {/* Sport icon circle */}
 <div
 className="w-10 h-10 rounded-full flex items-center justify-center mb-3 shrink-0 shadow-md"
 style={{ background: color.gradient }}
 >
 {/* Replace with actual sport icon if available, using a generic dot for now */}
 <div className="w-2.5 h-2.5 rounded-full bg-white opacity-80"/>
 </div>

                <h3 className={` text-white uppercase tracking-tight leading-none mb-1.5 ${isFirst ? 'text-4xl' : 'text-2xl'}`}>
                    {program.title}
                </h3>

                <p className="text-white/70 text-[11px] flex items-center gap-1.5 mb-2">
                    <MapPin size={11} className="opacity-70" /> {program.location}
                </p>

 {/* Book now pill — slides up on hover with beautiful gradient */}
 <div className="h-0 overflow-hidden opacity-0 translate-y-4 group-hover:h-auto group-hover:opacity-100 group-hover:translate-y-0 transition-all duration-400 ease-out mt-2">
 <Link to="/book"className="inline-block"onClick={(e) => e.stopPropagation()}>
 <span
 className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full text-white text-[11px] font-bold uppercase tracking-wider shadow-lg hover:shadow-xl hover:scale-105 transition-all duration-300"
 style={{ 
 background: color.gradient,
 boxShadow: `0 4px 14px ${color.shadow}`
 }}
 >
 Book Now <ArrowRight size={12} className="group-hover:translate-x-0.5 transition-transform" />
 </span>
 </Link>
 </div>
 </div>
 </motion.div>
 );
};

export const SportsProgramsSection = () => {
    const [programs, setPrograms] = useState<SportProgram[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // Independent CMS Sports — managed directly in Admin → CMS → Sports.
        // Not linked to the master Sports list.
        fetch(`${API_BASE}/cms-sports/frontend`)
            .then(r => r.json())
            .then(json => {
                const data = json.data ?? [];
                if (data.length > 0) {
                    setPrograms(data.map((sport: any) => ({
                        id: String(sport.id),
                        title: String(sport.name || '').toUpperCase(),
                        location: sport.location || 'Nahata Sports Complex',
                        image: getImageUrl(sport.image),
                        category: sport.category,
                        venueLabel: sport.venueLabel,
                    })));
                } else {
                    setPrograms(PROGRAMS);
                }
            })
            .catch(() => setPrograms(PROGRAMS))
            .finally(() => setLoading(false));
    }, []);

    return (
        <section className="py-16 md:py-24 bg-surface-base border-t border-slate-100 relative">
            <div className="container-custom relative z-10">
                <SectionHeader
                    eyebrow="Sports Programs"
                    title="7 Sports. 2 Locations. Endless Possibilities."
                    subtitle="Designed for all ages and skill levels at Nahata Sports Complex, Pune."
                    centered={true}
                />

                {loading ? (
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-5">
                        {Array.from({ length: 5 }).map((_, i) => (
                            <div
                                key={i}
                                className={`rounded-[24px] bg-slate-200 animate-shimmer ${i === 0 ? 'md:col-span-2 md:row-span-2' : ''
                                    }`}
                                style={{ aspectRatio: i === 0 ? 'auto' : '2/3' }}
                            />
                        ))}
                    </div>
                ) : (
                    <>
                        {/* Mobile: Horizontal scroll with snap points - full width edge to edge */}
                        <div className="md:hidden -mx-6">
                            <div className="overflow-x-auto snap-x snap-mandatory scrollbar-hide">
                                <div className="flex gap-4 pb-4 pl-6 pr-6">
                                    {programs.map((program, index) => (
                                        <div key={program.id} className="snap-start shrink-0 w-[280px]">
                                            <SportCard program={program} index={index} isMobile={true} />
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>

                        {/* Desktop: Grid layout - 4 or 5 columns */}
                        {/* Using 4 columns where the first takes 2x2 */}
                        <div className="hidden md:grid md:grid-cols-4 lg:grid-cols-5 gap-5 md:gap-6">
                            {programs.slice(0, 7).map((program, index) => (
                                <SportCard key={program.id} program={program} index={index} />
                            ))}
                        </div>
                    </>
                )}

                <motion.div
                    initial={{ opacity: 0, y: 16 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={viewportOnce}
                    transition={{ delay: 0.3 }}
                    className="mt-12 text-center"
                >
                    <Link to="/coaching">
                        <button className="btn-outline px-6 py-2.5 flex items-center gap-2 mx-auto text-sm">
                            View All Programs <ArrowRight size={15} />
                        </button>
                    </Link>
                </motion.div>
            </div>
        </section>
    );
};

