/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion, AnimatePresence } from 'motion/react';
import { Link } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { ChevronDown, ArrowRight } from 'lucide-react';
import { Button, SectionHeader } from '../../components/UI';
import { viewportOnce } from '../../components/ui/MotionPresets';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// ── FAQ Section ────────────────────────────────────────────────────────
export const FAQSection = () => {
 const [faqs, setFaqs] = useState<any[]>([]);
 const [openIdx, setOpenIdx] = useState<number | null>(0);

 useEffect(() => {
 fetch(`${API_BASE}/faqs`)
 .then(r => r.json())
 .then(json => setFaqs(json.data ?? []))
 .catch(() => setFaqs([
 { id: 1, question: 'Where is Nahata Sports located?', answer: 'Nahata Sports Complex is located on Sinhagad Road, near Wadgaon Budruk, Pune — easily accessible from Narhe, Katraj, and Dhayari areas. We also have a second centre at Gangadham Chowk.' },
 { id: 2, question: 'What are your operating hours?', answer: 'We are open from 6:00 AM to 11:00 PM daily, including weekends and public holidays (subject to holiday schedule).' },
 { id: 3, question: 'How do I book a court or turf?', answer: 'You can book directly from our website — click"Book a Court", select your sport, court, date, and time slot, then pay securely online. You receive an instant QR entry pass.' },
 { id: 4, question: 'Do you offer professional coaching?', answer: 'Yes! We have certified coaches for Cricket, Basketball, Badminton, Skating, Karate, Fun Fitness, and Dance & Zumba for all age groups.' },
 { id: 5, question: 'Can I cancel or reschedule my booking?', answer: 'Cancellations made 24 hours before the slot are eligible for a full refund or credit. Please refer to our Cancellation Policy for complete details.' },
 ]));
 }, []);

  const [showAll, setShowAll] = useState(false);
  const displayedFaqs = showAll ? faqs : faqs.slice(0, 5);

  if (faqs.length === 0) return null;

  return (
    <section className="py-24 bg-white border-t border-slate-100">
      <div className="container-custom max-w-4xl">
        <SectionHeader
          eyebrow="FAQ"
          title="Frequently Asked Questions"
          subtitle="Everything you need to know before you book."
          centered={true}
        />

        <div className="space-y-4">
          <AnimatePresence mode="popLayout">
            {displayedFaqs.map((faq, idx) => (
              <motion.div
                key={faq.id ?? idx}
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -16 }}
                viewport={viewportOnce}
                transition={{ delay: idx * 0.05 }}
                className={`bg-slate-50 rounded-[20px] overflow-hidden transition-all duration-300 border ${
                  openIdx === idx
                    ? 'border-slate-300 shadow-md bg-white'
                    : 'border-transparent hover:border-slate-200 hover:shadow-sm hover:bg-white'
                }`}
              >
                <button
                  onClick={() => setOpenIdx(openIdx === idx ? null : idx)}
                  className="w-full px-8 py-6 flex items-center justify-between gap-4 text-left group"
                  aria-expanded={openIdx === idx}
                >
                  <span className={` text-[17px] leading-snug transition-colors ${
                    openIdx === idx ? 'text-brand-primary' : 'text-slate-800 group-hover:text-brand-primary'
                  }`}>
                    {faq.question}
                  </span>
                  <div className={`shrink-0 w-8 h-8 rounded-full flex items-center justify-center transition-all duration-300 ${
                    openIdx === idx
                      ? 'bg-brand-primary text-white'
                      : 'bg-white border border-slate-200 text-slate-400 group-hover:border-brand-primary group-hover:text-brand-primary'
                  }`}>
                    <ChevronDown
                      size={18}
                      className={`transition-transform duration-300 ${
                        openIdx === idx ? 'rotate-180' : ''
                      }`}
                    />
                  </div>
                </button>

                <AnimatePresence initial={false}>
                  {openIdx === idx && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.32, ease: [0.22, 1, 0.36, 1] }}
                      className="overflow-hidden"
                    >
                      <div className="px-8 pb-7 pt-0 text-slate-600 text-[15px] leading-relaxed border-t border-slate-100">
                        <div className="pt-6">{faq.answer}</div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>

        {faqs.length > 5 && !showAll && (
          <div className="mt-12 text-center">
            <button 
              onClick={() => setShowAll(true)}
              className="text-slate-500 hover:text-slate-900 text-sm transition-colors border-b border-transparent hover:border-slate-900 pb-0.5"
            >
              View All FAQs
            </button>
          </div>
        )}
      </div>
    </section>
 );
};

// ── CTA Section ────────────────────────────────────────────────────────
export const CTASection = () => (
 <section className="py-32 bg-[#0F0C3D] relative overflow-hidden">
 <div className="noise-overlay opacity-30"aria-hidden="true"/>

 {/* Stadium photograph texture overlay (8% opacity) */}
 <div
 className="absolute inset-0 pointer-events-none opacity-10 mix-blend-overlay"
 style={{
 backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'800\' height=\'600\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cdefs%3E%3Cpattern id=\'stadium\' x=\'0\' y=\'0\' width=\'100\' height=\'100\' patternUnits=\'userSpaceOnUse\'%3E%3Crect x=\'0\' y=\'0\' width=\'100\' height=\'100\' fill=\'%23ffffff\' opacity=\'0.02\'/%3E%3Cpath d=\'M0,50 Q25,30 50,50 T100,50\' stroke=\'%23ffffff\' stroke-width=\'0.5\' fill=\'none\' opacity=\'0.15\'/%3E%3Ccircle cx=\'50\' cy=\'50\' r=\'30\' stroke=\'%23ffffff\' stroke-width=\'0.3\' fill=\'none\' opacity=\'0.1\'/%3E%3Cline x1=\'0\' y1=\'0\' x2=\'100\' y2=\'100\' stroke=\'%23ffffff\' stroke-width=\'0.2\' opacity=\'0.05\'/%3E%3Cline x1=\'100\' y1=\'0\' x2=\'0\' y2=\'100\' stroke=\'%23ffffff\' stroke-width=\'0.2\' opacity=\'0.05\'/%3E%3C/pattern%3E%3C/defs%3E%3Crect width=\'100%25\' height=\'100%25\' fill=\'url(%23stadium)\'/%3E%3C/svg%3E")',
 backgroundSize: '400px 300px',
 backgroundPosition: 'center',
 }}
 aria-hidden="true"
 />

 {/* Stadium atmosphere glow */}
 <div
 className="absolute inset-0 pointer-events-none"
 style={{
 background: 'radial-gradient(ellipse at 50% 100%, rgba(79,70,229,0.2) 0%, transparent 60%)',
 }}
 aria-hidden="true"
 />

 {/* Decorative large text bg */}
 <div
 className="absolute inset-0 flex items-center justify-center pointer-events-none select-none overflow-hidden"
 aria-hidden="true"
 >
 <span
 className="uppercase text-white/[0.025] whitespace-nowrap"
 style={{ fontSize: 'clamp(8rem, 20vw, 18rem)', letterSpacing: '-0.04em' }}
 >
 NAHATA
 </span>
 </div>

 <div className="container-custom relative z-10 text-center">
 <motion.div
 initial={{ opacity: 0, y: 32 }}
 whileInView={{ opacity: 1, y: 0 }}
 viewport={viewportOnce}
 transition={{ duration: 0.65, ease: [0.22, 1, 0.36, 1] }}
 >
 <p className="text-brand-glow text-[11px] uppercase tracking-[0.25em] mb-6">
 Your Court Is Waiting
 </p>

  <h2
  className="text-white uppercase tracking-tighter leading-[0.88] mb-8"
  style={{ fontSize: 'clamp(3rem, 10vw, 7.5rem)' }}
  >
  READY TO<br />
  <span className="text-brand-glow">PLAY?</span>
  </h2>

 <p className="text-white/60 text-lg max-w-xl mx-auto mb-12 leading-relaxed">
 Join 500+ athletes who trust Nahata Sports Complex for their training, coaching, and competitive play.
 </p>

 <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-10">
 <Link to="/book">
 <button className="btn-primary px-10 py-4 text-[16px] flex items-center gap-2">
 Book a Court Now <ArrowRight size={18} />
 </button>
 </Link>
 <Link to="/coaching">
 <button className="px-10 py-4 text-[16px] text-white bg-white/10 hover:bg-white/20 border border-white/20 rounded-full transition-colors flex items-center gap-2">
 Enroll in Coaching
 </button>
 </Link>
 </div>

 
 </motion.div>
 </div>
 </section>
);

