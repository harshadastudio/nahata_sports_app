/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion, AnimatePresence } from 'motion/react';
import { Menu, X, LogOut, User, ArrowRight, Trophy } from 'lucide-react';
import { useState, useEffect } from 'react';
import { Button } from './UI';
import { NAV_ITEMS, NAVBAR_ITEMS } from '../constants';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { staggerContainer, fadeUp } from './ui/MotionPresets';

// ── Navbar ────────────────────────────────────────────────────────────

export const Navbar = ({
 onOpenAuth,
 onOpenRegister,
}: {
 onOpenAuth: () => void;
 onOpenRegister: () => void;
}) => {
 const [isOpen, setIsOpen] = useState(false);
 const [scrolled, setScrolled] = useState(false);
 const { pathname } = useLocation();
 const { user, logout, isAuthenticated, isLoading } = useAuth();

 const handleLogout = async () => {
 try {
 await logout();
 } catch (error) {
 console.error('Logout failed:', error);
 }
 };

 useEffect(() => {
 const handleScroll = () => setScrolled(window.scrollY > 24);
 window.addEventListener('scroll', handleScroll, { passive: true });
 return () => window.removeEventListener('scroll', handleScroll);
 }, []);

 // Lock body scroll when mobile menu open
 useEffect(() => {
 document.body.style.overflow = isOpen ? 'hidden' : '';
 return () => { document.body.style.overflow = ''; };
 }, [isOpen]);

 // Close menu on route change
 useEffect(() => { setIsOpen(false); }, [pathname]);

 const navTextColor = 'text-slate-900';
 const navTextHover = 'text-brand-primary';
 const navTextMuted = scrolled ? 'text-slate-600' : 'text-slate-700';

 return (
 <>
 <motion.nav
 initial={{ y: -12, opacity: 0 }}
 animate={{ y: 0, opacity: 1 }}
 transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
 className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
 isOpen
? 'bg-[#0F0C3D] py-4'
: scrolled 
? 'bg-white/98 backdrop-blur-md py-3 border-b border-slate-200 shadow-md' 
: 'bg-white py-4 border-b border-slate-100 shadow-sm'
 }`}
 >
 <div className="container-custom flex items-center justify-between">

 {/* ── Logo ── */}
 <Link to="/"className="flex items-center gap-2.5 group shrink-0">
  <img 
  src="/nahata_logo.png" 
  alt="Nahata Sports" 
  className="h-20 w-auto object-contain transition-transform duration-300 group-hover:scale-105"
  />
 <div className="flex flex-col leading-none">
  <span className={` text-[1.1rem] sm:text-[1.35rem] tracking-tighter uppercase transition-colors duration-300 ${isOpen ? 'text-white' : navTextColor} ${!scrolled && pathname === '/' ? 'drop-shadow-sm' : ''}`}>
  NAHATA<span className="text-brand-bright drop-shadow-sm">SPORTS</span>
  </span>
 </div>
 </Link>

 {/* ── Desktop Nav Links (center) ── */}
 <div className="hidden lg:flex flex-1 justify-center">
 <div className="flex items-center gap-8">
 {NAVBAR_ITEMS.map((item) => {
 const isActive = pathname === item.href;
 return (
 <Link
 key={item.label}
 to={item.href}
 className="relative group flex flex-col items-center py-1"
 >
 <span
 className={` text-[15px] tracking-wide transition-colors duration-200 ${
 isActive ? navTextColor : `${navTextMuted} hover:${navTextHover}`
 }`}
 >
 {item.label}
 </span>
 {/* Active indicator */}
 {isActive && (
 <motion.span
 layoutId="nav-indicator"
 className="absolute -bottom-1 left-0 w-full h-[3px] rounded-t-full bg-brand-bright"
 initial={{ scaleX: 0 }}
 animate={{ scaleX: 1 }}
 transition={{ type: 'spring', stiffness: 400, damping: 30 }}
 style={{ originX: 0 }}
 />
 )}
 </Link>
 );
 })}
 </div>
 </div>

 {/* ── Desktop Right Actions ── */}
 <div className="hidden lg:flex items-center gap-3">
 {isLoading ? (
 <div className="w-24 h-8 bg-slate-200 animate-pulse rounded-full"/>
 ) : isAuthenticated && user ? (
 <>
 {/* User info pill */}
 <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full border transition-colors ${scrolled ? 'bg-slate-50 border-slate-200' : 'bg-slate-100 border-slate-200'}`}>
 <div className="w-6 h-6 rounded-full gradient-brand flex items-center justify-center shrink-0">
 <User size={13} className="text-white"/>
 </div>
 <span className={`text-sm text-slate-700`}>{user.name.split(' ')[0]}</span>
 </div>
 <Link
 to="/dashboard"
 className={`text-[13px] transition-colors px-2 ${navTextColor} hover:text-brand-primary`}
 >
 Dashboard
 </Link>
 <button
 onClick={handleLogout}
 className={`flex items-center gap-1.5 text-[13px] px-2 transition-colors ${scrolled ? 'text-red-500 hover:text-red-600' : 'text-red-400 hover:text-red-300'}`}
 >
 <LogOut size={14} />
 Logout
 </button>
 </>
 ) : (
 <>
 <button
 onClick={onOpenRegister}
 className={`text-[14px] px-3 transition-colors text-slate-600 hover:text-slate-900`}
 >
 Register
 </button>
 <button
 onClick={onOpenAuth}
 className={`text-[14px] px-3 transition-colors text-slate-600 hover:text-slate-900`}
 >
 Login
 </button>
 </>
 )}
 <Link to="/book">
 <button className="bg-brand-primary hover:bg-brand-mid text-white text-sm px-5 py-2.5 rounded-[8px] transition-colors flex items-center gap-2 shadow-sm">
 Book Your Court <ArrowRight size={14} />
 </button>
 </Link>
 </div>

 {/* ── Mobile Hamburger ── */}
 <motion.button
 whileTap={{ scale: 0.92 }}
 className={`lg:hidden relative w-10 h-10 flex items-center justify-center ${isOpen ? 'text-white' : navTextColor}`}
 onClick={() => setIsOpen(!isOpen)}
 aria-label={isOpen ? 'Close menu' : 'Open menu'}
 >
 <AnimatePresence mode="wait">
 {isOpen ? (
 <motion.span
 key="close"
 initial={{ opacity: 0, rotate: -90 }}
 animate={{ opacity: 1, rotate: 0 }}
 exit={{ opacity: 0, rotate: 90 }}
 transition={{ duration: 0.2 }}
 className="relative"
 >
 <X size={26} />
 </motion.span>
 ) : (
 <motion.span
 key="menu"
 initial={{ opacity: 0, rotate: 90 }}
 animate={{ opacity: 1, rotate: 0 }}
 exit={{ opacity: 0, rotate: -90 }}
 transition={{ duration: 0.2 }}
 >
 <Menu size={26} />
 </motion.span>
 )}
 </AnimatePresence>
 </motion.button>
 </div>
 </motion.nav>

 {/* ── Mobile Full-Screen Overlay Menu ── */}
 <AnimatePresence>
 {isOpen && (
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 transition={{ duration: 0.25 }}
 className="fixed inset-0 z-40 bg-[#0F0C3D] lg:hidden flex flex-col"
 >
 {/* Noise texture */}
 <div className="noise-overlay"aria-hidden="true"/>

 {/* Spacer for navbar height */}
 <div className="h-28 shrink-0"/>

 {/* Nav Items */}
 <div className="flex-1 flex flex-col items-center justify-center px-8">
 <motion.ul
 variants={{
 hidden: { opacity: 0 },
 visible: { opacity: 1, transition: { staggerChildren: 0.06 } }
 }}
 initial="hidden"
 animate="visible"
 className="space-y-4 mb-10 w-full max-w-sm text-center"
 >
 {NAVBAR_ITEMS.map((item) => {
 const isActive = pathname === item.href;
 return (
 <motion.li key={item.label} variants={{
 hidden: { opacity: 0, y: 20 },
 visible: { opacity: 1, y: 0, transition: { type: 'spring', stiffness: 300, damping: 24 } }
 }}>
  <Link
  to={item.href}
  className={`block py-2 text-[clamp(1.75rem,8vw,2.5rem)] tracking-tight uppercase transition-colors ${
 isActive
 ? 'text-brand-glow'
 : 'text-white hover:text-white/70'
 }`}
 onClick={() => setIsOpen(false)}
 >
 {item.label}
 </Link>
 </motion.li>
 );
 })}
 </motion.ul>

 {/* Auth actions */}
 <motion.div
 initial={{ opacity: 0, y: 24 }}
 animate={{ opacity: 1, y: 0 }}
 transition={{ delay: 0.35, duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
 className="w-full max-w-sm space-y-3"
 >
 {isLoading ? (
 <div className="w-full h-14 bg-white/10 animate-pulse rounded-full"/>
 ) : isAuthenticated && user ? (
 <>
 {/* User info */}
 <div className="bg-white/5 border border-white/10 p-4 rounded-2xl text-center mb-2">
 <div className="flex items-center justify-center gap-2 mb-1.5">
 <div className="w-8 h-8 rounded-full bg-brand-primary flex items-center justify-center">
 <User size={15} className="text-white"/>
 </div>
 <span className="text-white">{user.name}</span>
 </div>
 <span className="text-[11px] px-3 py-1 bg-brand-bright/20 text-brand-glow rounded-full inline-block tracking-wider uppercase">
 {user.role.charAt(0) + user.role.slice(1).toLowerCase()}
 </span>
 </div>
 <Link to="/dashboard"onClick={() => setIsOpen(false)}>
 <button className="w-full py-3.5 bg-white/10 hover:bg-white/20 text-white rounded-[10px] transition-colors border border-white/20">
 Dashboard
 </button>
 </Link>
 <button
 className="w-full py-3.5 flex items-center justify-center gap-2 text-red-400 border border-red-400/20 hover:bg-red-400/10 rounded-[10px] transition-colors"
 onClick={() => { handleLogout(); setIsOpen(false); }}
 >
 <LogOut size={16} /> Logout
 </button>
 </>
 ) : (
 <>
 <button
 className="w-full py-3.5 bg-brand-primary hover:bg-brand-mid text-white rounded-[10px] transition-colors"
 onClick={() => { onOpenRegister(); setIsOpen(false); }}
 >
 Student Register
 </button>
 <button
 className="w-full py-3.5 bg-transparent border border-white/30 text-white hover:bg-white/10 rounded-[10px] transition-colors"
 onClick={() => { onOpenAuth(); setIsOpen(false); }}
 >
 Login
 </button>
 </>
 )}

 <Link to="/book"onClick={() => setIsOpen(false)}>
 <button className="w-full mt-2 py-4 flex items-center justify-center gap-2 bg-gradient-to-r from-orange-500 to-orange-600 text-white rounded-[10px] text-[17px] shadow-lg">
 Book a Court <ArrowRight size={18} />
 </button>
 </Link>
 </motion.div>
 </div>

 {/* Bottom decoration */}
 <div className="pb-10 text-center">
 <p className="text-white/20 text-[11px] tracking-widest">
 NAHATA SPORTS COMPLEX • PUNE
 </p>
 </div>
 </motion.div>
 )}
 </AnimatePresence>
 </>
 );
};

// ── Footer ────────────────────────────────────────────────────────────

const FOOTER_API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export const Footer = () => {
 // Social links are managed in Admin → Settings → Social Links.
 const [social, setSocial] = useState<{ facebookUrl?: string; instagramUrl?: string; twitterUrl?: string }>({});

 useEffect(() => {
 fetch(`${FOOTER_API_BASE}/settings/public`)
 .then(r => r.json())
 .then(json => setSocial(json?.data ?? {}))
 .catch(() => {});
 }, []);

 const FB_ICON = <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>;
 const IG_ICON = <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/>;
 const X_ICON = <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>;

 const socialLinks = [
 { href: social.facebookUrl, label: 'Facebook', icon: FB_ICON },
 { href: social.instagramUrl, label: 'Instagram', icon: IG_ICON },
 { href: social.twitterUrl, label: 'X / Twitter', icon: X_ICON },
 ].filter(s => s.href && s.href.trim() !== '');

 return (
 <footer className="bg-[#0F0C3D] text-white pt-20 pb-0 relative overflow-hidden">
 {/* Top gradient border */}
 <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-brand-bright to-transparent opacity-50"/>

 {/* Mesh gradient */}
 <div
 className="absolute top-0 right-0 w-96 h-96 opacity-10 pointer-events-none"
 style={{
 background: 'radial-gradient(ellipse at 100% 0%, rgba(79,70,229,0.6) 0%, transparent 70%)',
 }}
 aria-hidden="true"
 />

 <div className="container-custom">
 <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-12 mb-16">

 {/* Brand column */}
 <div className="lg:col-span-2 md:col-span-2">
 <Link to="/"className="flex items-center gap-3 mb-6 group w-fit">
  <img 
  src="/nahata_logo.png" 
  alt="Nahata Sports" 
  className="h-24 w-auto object-contain transition-transform duration-300 group-hover:scale-105"
  />
 <span className="text-2xl tracking-wide text-white uppercase font-light">
 NAHATA<span className="text-[#8B7FE8] font-light">SPORTS</span>
 </span>
 </Link>
 <p className="text-white/60 text-sm leading-relaxed mb-8 max-w-md">
 Pune's premier sports complex. Empowering athletes through expert coaching and world-class facilities since 2015.
 </p>
 {/* Social icons — managed in Admin → Settings → Social Links */}
 {socialLinks.length > 0 && (
 <div className="flex gap-3">
 {socialLinks.map(({ href, label, icon }) => (
 <a
 key={label}
 href={href}
 target="_blank"
 rel="noopener noreferrer"
 aria-label={label}
 className="group w-9 h-9 rounded-full border border-white/10 flex items-center justify-center text-white/40 hover:text-white hover:bg-white/10 hover:border-white/20 transition-all duration-300"
 >
 <svg className="w-4 h-4"fill="currentColor"viewBox="0 0 24 24">
 {icon}
 </svg>
 </a>
 ))}
 </div>
 )}

 {/* Google reviews — ludocid + #lrd opens the Google review summary panel directly */}
 <a
 href="https://www.google.com/search?q=nahata+sports+complex+reviews&ludocid=12038802752389620910#lrd=0x3bc29573c75d803d:0xa7126b51a92da4ae,1,,,,"
 target="_blank"
 rel="noopener noreferrer"
 aria-label="Find our reviews on Google"
 className="mt-5 inline-flex items-center gap-2.5 px-4 py-2.5 rounded-full border border-white/10 text-white/70 text-[13px] hover:text-white hover:bg-white/10 hover:border-white/20 transition-all duration-300"
 >
 <svg className="w-4 h-4" viewBox="0 0 48 48" aria-hidden="true">
 <path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>
 <path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/>
 <path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238A11.91 11.91 0 0124 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>
 <path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 01-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/>
 </svg>
 Find Our Reviews on Google
 </a>
 </div>

 {/* Location 1 */}
 <div>
 <h4 className="text-sm text-white mb-4">Sinhagad Road</h4>
 <p className="text-white/60 text-[13px] leading-relaxed">
 Nahata Sports Complex & Lawns, Near Veer Baji Pasalkar Chowk, Wadgaon Budruk, Sinhagad Road, Pune — 411041
 </p>
 </div>

 {/* Location 2 */}
 <div>
 <h4 className="text-sm text-white mb-4">Gangadham Chowk</h4>
 <p className="text-white/60 text-[13px] leading-relaxed">
 Aai Mata Mandir, Najushree Hall, Ganga Dham Chowk, Pune — 411037
 </p>
 </div>

 {/* Explore links */}
 <div>
 <h4 className="text-sm text-white mb-4">Explore</h4>
 <ul className="space-y-2.5 text-[13px] text-white/60">
 {NAV_ITEMS.map((item) => (
 <li key={item.label}>
 <Link to={item.href} className="hover:text-white transition-colors duration-200">
 {item.label}
 </Link>
 </li>
 ))}
 <li><Link to="/blogs" className="hover:text-white transition-colors duration-200">Blogs</Link></li>
 </ul>
 </div>

 {/* Legal links */}
 <div>
 <h4 className="text-sm text-white mb-4">Legal</h4>
 <ul className="space-y-2.5 text-[13px] text-white/60">
 {[
 { to: '/holidays', label: 'Holiday Schedule' },
 { to: '/equipment-rental', label: 'Equipment Rental' },
 { to: '/privacy-policy', label: 'Privacy Policy' },
 { to: '/cancellation-policy', label: 'Cancellation' },
 { to: '/terms-and-conditions', label: 'Terms & Conditions' },
 { to: '/disclaimer', label: 'Disclaimer' },
 ].map(({ to, label }) => (
 <li key={label}>
 <Link to={to} className="hover:text-white transition-colors duration-200">{label}</Link>
 </li>
 ))}
 </ul>
 </div>
 </div>
 </div>

 {/* Bottom bar */}
 <div className="bg-[#0A0828] border-t border-white/5 py-5 mt-8">
 <div className="container-custom flex flex-col md:flex-row justify-between items-center gap-3">
 <p className="text-white/40 text-[11px] tracking-wider">
 © {new Date().getFullYear()} Nahata Sports Complex. All rights reserved.
 </p>
 <p className="text-white/40 text-[12px]">
 Developed By{' '}
                        <a
                            href="https://anantkamalsoftwarelabs.com/"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="hover:text-white transition-colors"
                        >
                            Anantkamal Software Labs
                        </a>
 </p>
 </div>
 </div>
 </footer>
 );
};

