import { motion, AnimatePresence } from 'motion/react';
import { Link } from 'react-router-dom';
import { ArrowRight, MapPin } from 'lucide-react';
import { useState, useEffect } from 'react';
import { getFrontendHeroSlides, HeroSlide } from '../../services/heroApi';
import { staggerContainer } from '../../components/ui/MotionPresets';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// Text-only defaults. Hero background images come exclusively from the CMS —
// there are no bundled fallback images (removed to cut ~8.4 MB of page weight).
const DEFAULT_HERO: HeroSlide = {
 id: 0,
 title: 'PLAY AT YOUR',
 titleHighlight: 'BEST LEVEL.',
 subtitle:"Pune's Premier Sports Facility",
 description: 'World-class courts, expert coaches, and a community built for athletic excellence. Book your slot in seconds.',
 button1Text: 'Book a Court',
 button1Url: '/book',
 button2Text: 'Explore Programs',
 button2Url: '/coaching',
};

export const HeroSection = () => {
 const [heroData, setHeroData] = useState<HeroSlide | null>(null);
 const [currentImageIndex, setCurrentImageIndex] = useState(0);
 const [nextSlot, setNextSlot] = useState<{ sport: string; time: string; price: string; court: string } | null>(null);

 useEffect(() => {
 getFrontendHeroSlides()
 .then((slides) => {
 // Use the CMS slide whenever one exists (text-only edits apply too).
 if (slides?.length) {
 setHeroData(slides[0]);
 }
 })
 .catch(() => {
 // On error, fall back to the text-only defaults (already set)
 });
 }, []);

 // Text falls back to DEFAULT_HERO; images do not (CMS is the only source).
 const data = heroData || DEFAULT_HERO;

 const allImages = [
 data.backgroundImage,
 ...(data.backgroundImages || []),
 ].filter(Boolean);

 // Auto-rotate images with longer interval for smoother experience
 useEffect(() => {
 if (allImages.length <= 1) return;
 const id = setInterval(() => setCurrentImageIndex(p => (p + 1) % allImages.length), 7000); // Increased from 5500ms to 7000ms
 return () => clearInterval(id);
 }, [allImages.length]);

 // Fetch next available slot for the floating card
 useEffect(() => {
 fetch(`${API_BASE}/courts?status=Active&showOnFrontend=true&limit=1`)
 .then(r => r.json())
 .then(json => {
 const court = json.data?.[0];
 if (court) {
 const now = new Date();
 const nextHour = new Date(now);
 nextHour.setMinutes(0, 0, 0);
 nextHour.setHours(nextHour.getHours() + 1);
 const timeStr = nextHour.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
 setNextSlot({
 sport: court.Sport?.name ?? 'Badminton',
 court: court.name ?? 'Court 1',
 time: timeStr,
 price: `₹${parseFloat(court.hourlyRate ?? '800').toLocaleString('en-IN')}`,
 });
 } else {
 setNextSlot({
 sport: 'Badminton',
 court: 'Premium Court A',
 time: '06:00 PM',
 price: '₹800',
 });
 }
 })
 .catch(() => {
 setNextSlot({
 sport: 'Badminton',
 court: 'Premium Court A',
 time: '06:00 PM',
 price: '₹800',
 });
 });
 }, []);

 return (
 <section className="relative min-h-[100svh] flex flex-col lg:flex-row bg-surface-base overflow-hidden">
 
 {/* ── Left Column (Content) ── */}
 <div className="relative w-full lg:w-[55%] flex items-center pt-32 pb-20 lg:py-0 px-6 lg:pl-[max(2.5rem,calc((100vw-1320px)/2))] lg:pr-16 z-10">
 {/* Gradient blend overlay - creates smooth transition to right side */}
 <div className="absolute inset-y-0 right-0 w-32 bg-gradient-to-r from-transparent to-surface-base/0 pointer-events-none lg:block hidden"/>
 <div className="diagonal-pattern absolute inset-0 pointer-events-none opacity-40"/>
 
 <motion.div
 variants={staggerContainer}
 initial="hidden"
 animate="visible"
 className="relative w-full max-w-2xl mx-auto lg:mx-0 mt-8"
 >
 {/* Eyebrow */}
 <motion.div variants={{
 hidden: { opacity: 0, x: -20 },
 visible: { opacity: 1, x: 0, transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } }
 }}>
 <span className="inline-flex items-center px-3 py-1 bg-brand-tint text-brand-bright text-[11px] uppercase tracking-[0.1em] rounded-full mb-6">
 {data.subtitle ||"Pune's Premier Sports Facility"}
 </span>
 </motion.div>

          {/* Headline */}
          <div className="mb-6">
            <motion.h1
              variants={{
                hidden: { opacity: 0, y: 30 },
                visible: { opacity: 1, y: 0, transition: { duration: 0.7, ease: [0.22, 1, 0.36, 1] } }
              }}
              className="text-slate-900 uppercase leading-[0.95] tracking-tight"
              style={{ fontSize: 'clamp(2.5rem, 8vw, 6.5rem)' }}
            >
              {data.title || DEFAULT_HERO.title}
            </motion.h1>
            {/* Second line is a styled span (not an <h1>) so the page keeps a
                single, SEO-correct H1 while preserving the two-line visual. */}
            {(data.titleHighlight ?? DEFAULT_HERO.titleHighlight) && (
              <motion.span
                variants={{
                  hidden: { opacity: 0, y: 30 },
                  visible: { opacity: 1, y: 0, transition: { duration: 0.7, delay: 0.15, ease: [0.22, 1, 0.36, 1] } }
                }}
                className="block uppercase leading-[0.95] tracking-tight gradient-text-brand"
                style={{ fontSize: 'clamp(2.5rem, 8vw, 6.5rem)' }}
              >
                {data.titleHighlight ?? DEFAULT_HERO.titleHighlight}
              </motion.span>
            )}
          </div>

          {/* Subline */}
          <motion.p
            variants={{
              hidden: { opacity: 0, y: 20 },
              visible: { opacity: 1, y: 0, transition: { duration: 0.6, delay: 0.2, ease: [0.22, 1, 0.36, 1] } }
            }}
            className="text-slate-600 text-base md:text-lg mb-8 md:mb-10 max-w-[65ch] leading-relaxed"
          >
            {data.description}
          </motion.p>

 {/* CTAs */}
 <motion.div
 variants={{
 hidden: { opacity: 0, y: 16 },
 visible: { opacity: 1, y: 0, transition: { duration: 0.5, delay: 0.3, ease: [0.22, 1, 0.36, 1] } }
 }}
 className="flex flex-wrap items-center gap-4"
 >
 {data.button1Text && data.button1Url && (
 <Link to={data.button1Url}>
 <button className="btn-primary px-8 py-3.5 text-[15px] flex items-center gap-2">
 {data.button1Text} <ArrowRight size={16} />
 </button>
 </Link>
 )}
 {data.button2Text && data.button2Url && (
 <Link to={data.button2Url}>
 <button className="btn-outline px-8 py-3.5 text-[15px]">
 {data.button2Text}
 </button>
 </Link>
 )}
 </motion.div>

          {/* Location indicator */}
          <motion.div
            variants={{
              hidden: { opacity: 0, y: 16 },
              visible: { opacity: 1, y: 0, transition: { duration: 0.5, delay: 0.4, ease: [0.22, 1, 0.36, 1] } }
            }}
            className="mt-10 md:mt-14 flex items-center gap-2 text-slate-500"
          >
            <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
              <MapPin size={14} className="text-brand-bright" />
            </div>
            <span className="text-xs md:text-sm">2 Premium Locations in Pune</span>
          </motion.div>
 </motion.div>
 </div>

 {/* ── Right Column (Image & Floating Cards) ── */}
 <div className="relative w-full lg:w-[45%] min-h-[40vh] lg:min-h-screen lg:absolute lg:right-0 lg:top-0 lg:bottom-0 z-0">
 {/* Smooth blend gradient from left to right - creates cinematic depth */}
 <div className="hidden lg:block absolute left-0 top-0 bottom-0 w-64 bg-gradient-to-r from-surface-base via-surface-base/60 to-transparent z-20 pointer-events-none"/>
 
 {/* Images with smoother cross-fade transitions */}
 {allImages.map((img, i) => (
 <motion.img
 key={img}
 src={img}
 alt="Sports Complex in Pune — Nahata Sports facilities and courts"
 // The first slide is the LCP element: fetch it eagerly at high priority.
 // The rotating slides behind it must not compete for bandwidth.
 fetchPriority={i === 0 ? 'high' : 'low'}
 loading={i === 0 ? 'eager' : 'lazy'}
 decoding="async"
 className="absolute inset-0 w-full h-full object-cover"
 // The slide that is already active when this mounts must render at full
 // opacity straight away. Fading it in from 0 delayed LCP by the whole
 // transition duration, because the browser does not count an invisible
 // element as painted. `initial` only applies on mount, so the rotation
 // between slides still cross-fades normally.
 initial={{ opacity: currentImageIndex === i ? 1 : 0 }}
 animate={{
 opacity: currentImageIndex === i ? 1 : 0,
 zIndex: currentImageIndex === i ? 10 : 0
 }}
 transition={{
 duration: 2.2, // Even slower for high-end feel
 ease: [0.4, 0, 0.2, 1]
 }}
 />
 ))}
 
 {/* Multi-layer gradient overlays for depth and blend */}
 <div className="absolute inset-0 bg-gradient-to-br from-slate-900/5 via-transparent to-transparent pointer-events-none"/>
 <div className="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-t from-[#0F0C3D]/60 to-transparent pointer-events-none"/>
 <div className="absolute inset-x-0 top-0 h-1/4 bg-gradient-to-b from-slate-900/10 to-transparent pointer-events-none"/>

 {/* Floating Glass Card with smoother animation */}
 <AnimatePresence>
 {nextSlot && (
 <motion.div
 initial={{ opacity: 0, y: 30, x: -30, scale: 0.95 }}
 animate={{ opacity: 1, y: 0, x: 0, scale: 1 }}
 transition={{ 
 delay: 0.6, 
 type: 'spring', 
 stiffness: 100, 
 damping: 20,
 opacity: { duration: 0.6 }
 }}
 className="absolute bottom-8 lg:bottom-auto lg:top-[60%] lg:-translate-y-1/2 left-6 lg:-left-20 z-30 p-5 w-[280px] rounded-2xl shadow-2xl backdrop-blur-xl bg-white/95 border border-slate-200/50"
 >
 <div className="flex items-center gap-2 mb-3">
 <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse shadow-lg shadow-emerald-500/50"/>
 <span className="text-[10px] text-slate-600 uppercase tracking-widest">
 Available Now
 </span>
 </div>
 <div className="flex items-end justify-between">
 <div>
 <p className="text-xl text-slate-900 uppercase tracking-tight">
 {nextSlot.sport}
 </p>
 <p className="text-slate-500 text-xs mt-0.5">{nextSlot.court}</p>
 <p className="text-brand-primary text-sm mt-1">
 {nextSlot.time}
 </p>
 </div>
 <div className="text-right flex flex-col items-end">
 <p className="text-xl text-slate-900">{nextSlot.price}</p>
 <Link to="/book"className="mt-2 block">
 <button className="bg-brand-primary hover:bg-brand-mid text-white px-3 py-1.5 rounded-[6px] text-[11px] uppercase transition-colors shadow-sm">
 Book &rarr;
 </button>
 </Link>
 </div>
 </div>
 </motion.div>
 )}
 </AnimatePresence>

 {/* Decorative Sport Category Pills with staggered animation */}
 <motion.div
 initial={{ opacity: 0, y: 30 }}
 animate={{ opacity: 1, y: 0 }}
 transition={{ delay: 0.8, duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
 className="absolute bottom-8 right-8 flex flex-wrap gap-2 justify-end max-w-[200px]"
 >
 {['Badminton', 'Cricket', 'Basketball'].map((sport, idx) => (
 <motion.span 
 key={sport}
 initial={{ opacity: 0, scale: 0.8 }}
 animate={{ opacity: 1, scale: 1 }}
 transition={{ delay: 0.9 + (idx * 0.1), duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
 className="px-3 py-1.5 rounded-full bg-black/40 backdrop-blur-md border border-white/10 text-white text-[11px] tracking-wide"
 >
 {sport}
 </motion.span>
 ))}
 </motion.div>
 </div>

 </section>
 );
};

