import React, { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
 ChevronLeft, ChevronDown, MapPin, Trophy, Clock, CheckCircle2, AlertCircle,
 ShieldCheck, Calendar as CalendarIcon, Minus, Plus, Loader2, CreditCard, Tag
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { AuthModal } from "../components/AuthModal";
import { PageTransition } from "../components/ui/PageTransition";
import { bookingService, Venue, SportOption, StartTimeOption, formatTime } from "../services/bookingService";
import { initiatePayment, isPaymentAbandoned } from "../services/razorpayService";
import { OffersPanel } from "../components/OffersPanel";
import { DateField } from "../components/ui/DateField";
import type { CouponValidationResult } from "../services/couponService";
import { getImageUrl } from "../lib/utils";
import { SmartImage } from '../components/ui/SmartImage';

// Duration stepper bounds (hours). Whole-hour steps → 1, 2, 3 … (no half hours).
const MIN_DURATION = 1;
const MAX_DURATION = 6;
const DURATION_STEP = 1;

type SelectedSlot = { startTime: string; endTime: string; price: number };
type Avail =
 | { status: 'idle' }
 | { status: 'checking' }
 | { status: 'available'; price: number; endTime: string }
 | { status: 'unavailable'; fallback: { startTime: string; endTime: string; durationMinutes: number; price: number } | null };

function toISODate(d: Date): string { return d.toISOString().split("T")[0]; }
function durLabel(h: number): string { return `${h} Hr`; }

// Preferred venue display order (matched by name substring, case-insensitive).
// Venues listed here come first in the given order; any others follow after,
// keeping the order the API returned them in.
const VENUE_ORDER = ["sinhagad", "gangadham"];
function orderVenues<T extends { name: string }>(list: T[]): T[] {
 const rank = (name: string) => {
  const i = VENUE_ORDER.findIndex((k) => name.toLowerCase().includes(k));
  return i === -1 ? VENUE_ORDER.length : i;
 };
 return [...list].sort((a, b) => rank(a.name) - rank(b.name));
}

function getSportEmoji(sportName: string): string {
  const key = (sportName || '').trim().toLowerCase();
  if (key.includes('football') || key.includes('soccer')) return '⚽';
  if (key.includes('cricket')) return '🏏';
  if (key.includes('badminton')) return '🏸';
  if (key.includes('basketball')) return '🏀';
  if (key.includes('tennis')) return '🎾';
  return '🏅';
}

export const BookFacilityPage = () => {
 const navigate = useNavigate();
 const { isAuthenticated } = useAuth();

 // Data
 const [venues, setVenues] = useState<Venue[]>([]);
 const [sports, setSports] = useState<SportOption[]>([]);
 // CMS-managed fixed banner for the Booking Summary (applies to all venues).
 const [bookingBanner, setBookingBanner] = useState<string>('');
 const [times, setTimes] = useState<StartTimeOption[]>([]);

 // Loaders
 const [loadingSports, setLoadingSports] = useState(false);
 const [loadingTimes, setLoadingTimes] = useState(false);
 const [isBooking, setIsBooking] = useState(false);

 // Selections (NO court — resolved server-side and hidden from the user)
 const [selVenueId, setSelVenueId] = useState("");
 const [selSportId, setSelSportId] = useState("");
 const [selDate, setSelDate] = useState("");
 const [durationHours, setDurationHours] = useState(1);
 const [selStartTime, setSelStartTime] = useState("");
 const [timeOpen, setTimeOpen] = useState(false);
 const timeRef = useRef<HTMLDivElement>(null);

 // Close the Start Time dropdown on outside click.
 useEffect(() => {
  if (!timeOpen) return;
  const onDown = (e: MouseEvent) => {
   if (timeRef.current && !timeRef.current.contains(e.target as Node)) setTimeOpen(false);
  };
  document.addEventListener("mousedown", onDown);
  return () => document.removeEventListener("mousedown", onDown);
 }, [timeOpen]);

 // Availability + chosen slot
 const [avail, setAvail] = useState<Avail>({ status: 'idle' });
 const [selSlot, setSelSlot] = useState<SelectedSlot | null>(null);
 const [usingFallback, setUsingFallback] = useState(false);

 // Flow
 const [showLogin, setShowLogin] = useState(false);
 const [pendingConfirm, setPendingConfirm] = useState(false);
 const [bookingError, setBookingError] = useState("");
 const [appliedCoupon, setAppliedCoupon] = useState<CouponValidationResult | null>(null);

 // Success
 const [confirmed, setConfirmed] = useState(false);
 const [bookingRef, setBookingRef] = useState("");
 const [bookingQrCode, setBookingQrCode] = useState("");
 const [bookingCourtName, setBookingCourtName] = useState("");
 const [bookingVenueName, setBookingVenueName] = useState("");

 const todayISO = toISODate(new Date());
 const maxDateObj = new Date(); maxDateObj.setDate(maxDateObj.getDate() + 14);
 const maxISO = toISODate(maxDateObj);

 // Load venues; auto-select if there is only one.
 useEffect(() => {
  bookingService.getVenues().then((v) => {
   const ordered = orderVenues(v);
   setVenues(ordered);
   if (ordered.length === 1) setSelVenueId(ordered[0].id);
  });
  // Load the fixed Booking Summary banner from CMS settings.
  bookingService.getBookingSummaryBanner().then(setBookingBanner);
 }, []);

 // Load sports when venue changes.
 useEffect(() => {
  if (!selVenueId) { setSports([]); return; }
  setSelSportId(""); setSelDate(""); setSelStartTime(""); setTimes([]);
  setLoadingSports(true);
  bookingService.getSportsByVenue(selVenueId).then((s) => {
   setSports(s);
   setLoadingSports(false);
   if (s.length === 1) setSelSportId(s[0].id);
  });
 }, [selVenueId]);

 // Load the start-time options whenever venue + sport + date + duration are set.
 useEffect(() => {
  if (!selVenueId || !selSportId || !selDate || !durationHours) { setTimes([]); return; }
  let cancelled = false;
  setLoadingTimes(true);
  bookingService.getAvailableStartTimes(selVenueId, selSportId, selDate, durationHours).then((t) => {
   if (cancelled) return;
   setTimes(t);
   setLoadingTimes(false);
   // keep the chosen start time only if it still fits this duration's window
   setSelStartTime((prev) => (prev && t.some((x) => x.startTime === prev) ? prev : ""));
  });
  return () => { cancelled = true; };
 }, [selVenueId, selSportId, selDate, durationHours]);

 // Resolve availability for the chosen start time (court-hidden).
 useEffect(() => {
  setSelSlot(null); setUsingFallback(false); setAppliedCoupon(null); setBookingError("");
  if (!selStartTime) { setAvail({ status: 'idle' }); return; }

  const cell = times.find((t) => t.startTime === selStartTime);
  if (cell && cell.available && cell.price != null) {
   setAvail({ status: 'available', price: cell.price, endTime: cell.endTime });
   setSelSlot({ startTime: selStartTime, endTime: cell.endTime, price: cell.price });
   return;
  }

  // Not directly available → fetch the partial fallback.
  let cancelled = false;
  setAvail({ status: 'checking' });
  bookingService.getAvailability(selVenueId, selSportId, selDate, selStartTime, durationHours).then((res) => {
   if (cancelled) return;
   if (res && res.available && res.price != null) {
    setAvail({ status: 'available', price: res.price, endTime: res.endTime });
    setSelSlot({ startTime: selStartTime, endTime: res.endTime, price: res.price });
   } else {
    setAvail({ status: 'unavailable', fallback: res?.fallback ?? null });
   }
  });
  return () => { cancelled = true; };
 // eslint-disable-next-line react-hooks/exhaustive-deps
 }, [selStartTime, times, durationHours]);

 // Resume booking after a login interrupt.
 useEffect(() => {
  if (isAuthenticated && pendingConfirm && !showLogin) {
   setPendingConfirm(false);
   setTimeout(() => doBooking(), 100);
  }
 // eslint-disable-next-line react-hooks/exhaustive-deps
 }, [isAuthenticated, showLogin, pendingConfirm]);

 const changeDuration = (delta: number) => {
  setDurationHours((d) => {
   const next = Math.min(MAX_DURATION, Math.max(MIN_DURATION, Math.round(d + delta)));
   return next;
  });
 };

 const bookFallback = (fb: { startTime: string; endTime: string; price: number }) => {
  setUsingFallback(true);
  setAppliedCoupon(null);
  setSelSlot({ startTime: fb.startTime, endTime: fb.endTime, price: fb.price });
 };

 const handlePayNow = () => {
  if (!selSlot) return;
  if (!isAuthenticated) { setPendingConfirm(true); setShowLogin(true); }
  else doBooking();
 };

 const doBooking = async () => {
  const s = selSlot;
  if (!s) return;
  setIsBooking(true); setBookingError("");
  // Held booking id — kept outside the try so a cancelled payment can release it.
  let heldBookingId: number | null = null;
  try {
   const chargeAmount = appliedCoupon ? appliedCoupon.finalAmount : s.price;
   const res = await bookingService.createBooking({
    sportComplexId: selVenueId,
    sportId: selSportId,
    date: selDate,
    startTime: s.startTime,
    endTime: s.endTime,
    totalAmount: s.price, // original price — backend applies the coupon once
    couponCode: appliedCoupon?.code ?? null,
   });
   const first = res.bookings && res.bookings.length > 0 ? res.bookings[0] : res;
   heldBookingId = first.id;

   // The booking is only a Pending hold at this point and carries NO pass. The
   // pass is issued by the backend during verification and comes back here.
   const payment = await initiatePayment(
    chargeAmount, 'facility', first.id,
    { name: undefined, email: undefined, contact: undefined },
    `Court Booking — ${selDate} ${formatTime(s.startTime)} to ${formatTime(s.endTime)}`
   );

   setBookingRef(`#NSC-${String(first.id).padStart(6, "0")}`);
   setBookingQrCode(payment.pass?.qrCode || "");
   setBookingCourtName(first.court?.name || "");
   setBookingVenueName(first.court?.SportComplex?.name || currentVenue?.name || "");
   setConfirmed(true);
  } catch (err: any) {
   // Cancelled popup / failed payment → drop the unpaid hold so the slot frees
   // up and no booking (and no pass) is left behind. A failure AFTER the money
   // moved (verification) is left alone — that booking needs reconciling, not
   // deleting.
   if (heldBookingId && isPaymentAbandoned(err)) {
    await bookingService.releaseBooking(heldBookingId);
   }
   setBookingError(err.message || 'Booking failed. Please try again.');
  } finally {
   setIsBooking(false);
  }
 };

 const resetAll = () => {
  setConfirmed(false); setSelSlot(null); setSelStartTime(""); setAvail({ status: 'idle' });
  setUsingFallback(false); setAppliedCoupon(null); setBookingError(""); setBookingRef(""); setBookingQrCode("");
 };

 const currentVenue = venues.find((v) => v.id === selVenueId);
 const currentSport = sports.find((s) => s.id === selSportId);
 const chargeAmount = selSlot ? (appliedCoupon ? appliedCoupon.finalAmount : selSlot.price) : 0;
 const basicsReady = !!(selVenueId && selSportId && selDate);

 // Primary button label/state (mirrors the reference's bottom button)
 let primaryLabel = 'Select sport, date & start time';
 if (selSlot) primaryLabel = `Pay & Reserve · ₹${chargeAmount.toFixed(0)}`;
 else if (avail.status === 'checking') primaryLabel = 'Checking availability…';
 else if (selStartTime && avail.status === 'unavailable') primaryLabel = 'Not available — pick another time';

 return (
 <PageTransition className="min-h-screen bg-slate-50 selection:bg-brand-primary/20 flex flex-col pt-[112px]">
  {/* Header */}
  <div className="bg-white border-b border-slate-100">
   <div className="container-custom max-w-[1200px] h-16 flex items-center gap-4">
    <button onClick={() => (confirmed ? resetAll() : navigate(-1))} className="w-10 h-10 flex items-center justify-center rounded-full bg-slate-50 hover:bg-slate-100 text-slate-600 hover:text-slate-900 transition-colors" aria-label="Go Back">
     <ChevronLeft size={20} />
    </button>
    <h1 className="text-xl text-slate-900 uppercase tracking-tight leading-none">{confirmed ? 'Booking Confirmed' : 'Book a Court'}</h1>
   </div>
  </div>

  <div className="flex-1 container-custom max-w-[1200px] py-8 flex flex-col lg:flex-row gap-8 items-start">

   {/* LEFT — single compact booking form */}
   <div className="w-full lg:max-w-[640px] flex-1">
    {confirmed ? (
     <motion.div initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }} className="bg-white rounded-[20px] border border-slate-200 shadow-sm p-10 flex flex-col items-center text-center">
      <div className="w-20 h-20 rounded-full bg-emerald-500 flex items-center justify-center text-white shadow-[0_0_40px_rgba(16,185,129,0.35)] mb-6"><CheckCircle2 size={38} strokeWidth={2.5} /></div>
      <h2 className="text-3xl text-slate-900 uppercase tracking-tighter mb-2">Booking <span className="text-emerald-500">Confirmed</span></h2>
      <p className="text-slate-500 text-[15px] max-w-sm mb-8">Your slot is reserved. Present the digital pass at reception for entry.</p>
      <div className="flex flex-col sm:flex-row gap-3 w-full sm:w-auto">
       <button onClick={() => navigate("/dashboard/bookings")} className="btn-outline px-8 py-3 text-[15px]">View Bookings</button>
       <button onClick={resetAll} className="btn-primary px-8 py-3 text-[15px]">Book Another</button>
      </div>
     </motion.div>
    ) : (
     <div className="bg-white rounded-[20px] border border-slate-200 shadow-sm">
      {/* Venue header */}
      <div className="px-7 pt-6 pb-5">
       <h2 className="text-2xl text-slate-900 tracking-tight leading-tight font-semibold">{currentVenue?.name || 'Select a venue'}</h2>
       {currentVenue?.address && <p className="text-[13px] text-slate-500 mt-0.5 flex items-center gap-1"><MapPin size={13} /> {currentVenue.address}{currentVenue.city ? `, ${currentVenue.city}` : ''}</p>}
      </div>

      {/* Promo banner (customizable copy) */}
      <div className="bg-gradient-to-r from-brand-primary to-brand-bright text-white text-center text-[13px] font-medium py-2.5 px-4">
       ✓ Instant confirmation · Secure online payment
      </div>

      {/* Form */}
      <div className="px-7 py-6 divide-y divide-slate-100">
       {venues.length > 1 && (
        <FormRow label="Venue">
         <SelectShell>
          <select value={selVenueId} onChange={(e) => setSelVenueId(e.target.value)} className="w-full appearance-none bg-white border border-slate-200 rounded-[12px] pl-4 pr-10 py-3 text-[15px] text-slate-900 focus:outline-none focus:border-brand-primary disabled:bg-slate-50 disabled:text-slate-400 cursor-pointer">
           <option value="">-- Select Venue --</option>
           {venues.map((v) => <option key={v.id} value={v.id}>{v.name}{v.city ? ` — ${v.city}` : ''}</option>)}
          </select>
         </SelectShell>
        </FormRow>
       )}

       <FormRow label="Sport">
        <SelectShell>
         <select value={selSportId} onChange={(e) => setSelSportId(e.target.value)} disabled={!selVenueId || loadingSports} className="w-full appearance-none bg-white border border-slate-200 rounded-[12px] pl-4 pr-10 py-3 text-[15px] text-slate-900 focus:outline-none focus:border-brand-primary disabled:bg-slate-50 disabled:text-slate-400 cursor-pointer">
          <option value="">{loadingSports ? 'Loading…' : '-- Select Sport --'}</option>
          {sports.map((s) => <option key={s.id} value={s.id}>{getSportEmoji(s.name)}  {s.name}</option>)}
         </select>
        </SelectShell>
       </FormRow>

       <FormRow label="Date">
        <DateField value={selDate} onChange={setSelDate} minDate={todayISO} maxDate={maxISO} disabled={!selSportId} placeholder="Select date" />
       </FormRow>

       <FormRow label="Start Time">
        <div className="relative" ref={timeRef}>
         {/* Trigger — looks like the other select fields */}
         <button
          type="button"
          onClick={() => { if (selDate && !loadingTimes && times.length > 0) setTimeOpen((o) => !o); }}
          disabled={!selDate || loadingTimes || times.length === 0}
          className="w-full flex items-center justify-between bg-white border border-slate-200 rounded-[12px] pl-4 pr-3.5 py-3 text-[15px] text-left focus:outline-none focus:border-brand-primary disabled:bg-slate-50 disabled:text-slate-400 cursor-pointer"
         >
          <span className={selStartTime ? 'text-slate-900' : 'text-slate-400'}>
           {!selDate ? 'Select a date first'
            : loadingTimes ? 'Loading times…'
            : times.length === 0 ? 'No slots this day'
            : selStartTime ? formatTime(selStartTime)
            : 'Select a start time'}
          </span>
          <span className="flex items-center gap-1 text-slate-400">
           <Clock size={17} />
           <ChevronDown size={17} className={`transition-transform ${timeOpen ? 'rotate-180' : ''}`} />
          </span>
         </button>

         {/* Dropdown panel with the time chips */}
         {timeOpen && (
          <div className="absolute left-0 right-0 top-full mt-2 z-20 bg-white border border-slate-200 rounded-[14px] shadow-xl p-3 max-h-64 overflow-y-auto">
           <div className="grid grid-cols-2 gap-2.5">
            {times.map((t) => {
             const selected = selStartTime === t.startTime;
             return (
              <button
               key={t.startTime}
               type="button"
               onClick={() => { setSelStartTime(t.startTime); setTimeOpen(false); }}
               disabled={!t.available}
               aria-pressed={selected}
               className={`rounded-[12px] py-3 px-2 text-[14px] font-medium border text-center transition-colors ${
                selected
                 ? 'bg-primary border-primary text-white shadow-sm'
                 : t.available
                  ? 'bg-white border-slate-200 text-slate-700 hover:border-brand-glow hover:text-brand-primary'
                  : 'bg-slate-50 border-slate-100 text-slate-300 line-through cursor-not-allowed'
               }`}
              >
               {formatTime(t.startTime)}
              </button>
             );
            })}
           </div>
          </div>
         )}
        </div>
       </FormRow>

       <FormRow label="Duration">
        <div className="flex items-center justify-between">
         <button type="button" onClick={() => changeDuration(-DURATION_STEP)} disabled={durationHours <= MIN_DURATION}
          className={`w-10 h-10 rounded-full flex items-center justify-center transition-colors ${durationHours <= MIN_DURATION ? 'bg-slate-100 text-slate-300 cursor-not-allowed' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`} aria-label="Decrease duration">
          <Minus size={18} />
         </button>
         <span className="text-[16px] font-semibold text-slate-900">{durLabel(durationHours)}</span>
         <button type="button" onClick={() => changeDuration(DURATION_STEP)} disabled={durationHours >= MAX_DURATION}
          className={`w-10 h-10 rounded-full flex items-center justify-center text-white transition-colors ${durationHours >= MAX_DURATION ? 'bg-indigo-200 cursor-not-allowed' : 'bg-brand-bright hover:bg-brand-primary'}`} aria-label="Increase duration">
          <Plus size={18} />
         </button>
        </div>
       </FormRow>

       {/* Coupon hint — nudges users before the Offers panel unlocks (it
           appears once a slot is chosen). Hidden during the unavailable state. */}
       {!selSlot && avail.status !== 'unavailable' && (
        <div className="pt-5">
         <div className="flex items-center gap-2.5 bg-brand-secondary/40 border border-brand-primary/15 rounded-[12px] px-4 py-3">
          <div className="w-7 h-7 rounded-lg bg-white flex items-center justify-center shrink-0">
           <Tag size={14} className="text-brand-primary" />
          </div>
          <p className="text-[12.5px] text-slate-600 leading-snug">
           <span className="font-medium text-slate-800">Have a coupon?</span> Pick your start time to unlock offers &amp; apply it at checkout.
          </p>
         </div>
        </div>
       )}

       {/* Availability / fallback */}
       {selStartTime && avail.status === 'unavailable' && (
        <div className="pt-5">
         <div className="bg-amber-50 border border-amber-200 rounded-[14px] p-4">
          <p className="text-[13px] text-amber-800 flex items-start gap-2 mb-2">
           <AlertCircle size={16} className="shrink-0 mt-0.5" />
           Sorry, {durLabel(durationHours)} isn't available at {formatTime(selStartTime)}.
          </p>
          {avail.fallback ? (
           <button onClick={() => bookFallback(avail.fallback!)} className="w-full mt-1 bg-white border border-amber-300 hover:border-amber-400 text-amber-900 rounded-[12px] py-2.5 text-[14px] font-medium transition-colors">
            Book {durLabel(avail.fallback.durationMinutes / 60)} instead · {formatTime(avail.fallback.startTime)}–{formatTime(avail.fallback.endTime)} · ₹{avail.fallback.price}
           </button>
          ) : (
           <p className="text-[12px] text-amber-700">Try another start time or a shorter duration.</p>
          )}
         </div>
        </div>
       )}

       {/* Chosen slot → coupon + total */}
       {selSlot && (
        <div className="pt-5 space-y-4">
         <div className="flex items-center gap-2 text-[13px] text-brand-primary font-medium">
          <CheckCircle2 size={16} />
          <span>{usingFallback ? 'Closest available slot' : 'Available'} · {formatTime(selSlot.startTime)}–{formatTime(selSlot.endTime)}</span>
         </div>
         <OffersPanel amount={selSlot.price} appliedCoupon={appliedCoupon} onApply={(r) => setAppliedCoupon(r)} onRemove={() => setAppliedCoupon(null)} scope={{ appliesTo: 'Court', sportComplexId: selVenueId, sportId: selSportId }} />
         <div className="bg-slate-50 rounded-[14px] p-4 flex items-center justify-between border border-slate-100">
          <span className="text-[12px] text-slate-500 uppercase tracking-widest">Total</span>
          {appliedCoupon ? (
           <div className="text-right">
            <span className="text-xs text-slate-400 line-through mr-2">₹{selSlot.price}</span>
            <span className="text-2xl text-brand-primary">₹{appliedCoupon.finalAmount.toFixed(2)}</span>
           </div>
          ) : <span className="text-2xl text-slate-900">₹{selSlot.price}</span>}
         </div>
        </div>
       )}

       {/* Error */}
       {bookingError && (
        <div className="pt-4">
         <div className="bg-red-50 border border-red-200 text-red-700 text-[13px] px-4 py-3 rounded-[12px] flex items-center gap-2"><AlertCircle size={16} /> {bookingError}</div>
        </div>
       )}
      </div>

      {/* Primary action (matches reference's bottom button) */}
      <div className="px-7 pb-7 pt-1">
       <button
        onClick={handlePayNow}
        disabled={!selSlot || isBooking}
        className={`w-full rounded-[12px] py-4 text-[15px] font-semibold flex items-center justify-center gap-2 transition-colors ${selSlot && !isBooking ? 'bg-brand-primary text-white hover:opacity-95' : 'bg-slate-100 text-slate-400 cursor-not-allowed'}`}
       >
        {isBooking ? <Loader2 size={18} className="animate-spin" /> : selSlot ? <CreditCard size={18} /> : null}
        {isBooking ? 'Processing…' : primaryLabel}
       </button>
       {!basicsReady && <p className="text-[12px] text-slate-400 text-center mt-2">Court is assigned automatically — you only choose the time.</p>}
      </div>
     </div>
    )}
   </div>

   {/* RIGHT — summary / wallet pass */}
   <div className="w-full lg:w-[340px] shrink-0">
    <AnimatePresence mode="popLayout">
     {!confirmed ? (
      <motion.div key="summary" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96 }} className="bg-white rounded-[20px] border border-slate-200 shadow-sm overflow-hidden">
       <div className="relative h-32 bg-slate-900">
        <SmartImage src={getImageUrl(bookingBanner) || (currentVenue ? getImageUrl(currentVenue.image) : '')} alt="Booking" className="w-full h-full object-cover opacity-60" />
        <div className="absolute inset-0 bg-gradient-to-t from-slate-900 to-transparent" />
        <div className="absolute bottom-4 left-5 text-white">
         <div className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-white/20 backdrop-blur-md rounded-full text-[10px] uppercase tracking-widest mb-2 border border-white/20"><span className="w-1.5 h-1.5 rounded-full bg-brand-glow animate-pulse" /> Booking Summary</div>
        </div>
       </div>
       <div className="p-5 space-y-3.5">
        <SummaryRow icon={<MapPin size={15} />} label="Venue" value={currentVenue?.name} />
        <SummaryRow icon={<Trophy size={15} />} label="Sport" value={currentSport?.name} />
        <SummaryRow icon={<CalendarIcon size={15} />} label="Date" value={selDate ? new Date(selDate).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }) : undefined} />
        <SummaryRow icon={<Clock size={15} />} label="Time" value={selSlot ? `${formatTime(selSlot.startTime)}–${formatTime(selSlot.endTime)}` : undefined} />
        <SummaryRow icon={<Clock size={15} />} label="Duration" value={durLabel(durationHours)} />
        {selSlot && (
         <div className="pt-3 mt-1 border-t border-slate-100 flex items-center justify-between">
          <span className="text-[12px] text-slate-500 uppercase tracking-widest">Total</span>
          <span className="text-xl text-slate-900">₹{chargeAmount.toFixed(0)}</span>
         </div>
        )}
       </div>
      </motion.div>
     ) : (
      <motion.div key="pass" initial={{ opacity: 0, scale: 0.92, y: 16 }} animate={{ opacity: 1, scale: 1, y: 0 }} className="bg-slate-900 rounded-[24px] overflow-hidden shadow-[0_20px_60px_rgba(15,23,42,0.2)] relative">
       <div className="absolute top-0 right-0 w-56 h-56 bg-emerald-500/20 rounded-full blur-3xl pointer-events-none" />
       <div className="px-7 py-6 border-b border-white/10 relative z-10">
        <div className="flex items-center justify-between mb-4">
         <div className="w-9 h-9 rounded-[10px] bg-white/10 flex items-center justify-center text-emerald-400"><ShieldCheck size={18} /></div>
         <span className="px-3 py-1 bg-emerald-500/20 text-emerald-400 text-[10px] uppercase tracking-widest rounded-full border border-emerald-500/30">Valid Pass</span>
        </div>
        <h3 className="text-2xl text-white tracking-tight leading-none mb-1">{bookingCourtName || currentSport?.name || 'Your Court'}</h3>
        <p className="text-white/60 text-[12px] uppercase tracking-widest">{bookingVenueName || currentVenue?.name}</p>
       </div>
       <div className="p-7 bg-white relative z-10">
        <div className="grid grid-cols-2 gap-5 mb-6">
         <div><span className="block text-[10px] text-slate-400 uppercase tracking-widest mb-1">Date</span><span className="block text-slate-900 text-lg">{selDate ? new Date(selDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ''}</span></div>
         <div><span className="block text-[10px] text-slate-400 uppercase tracking-widest mb-1">Time</span><span className="block text-brand-primary text-lg">{selSlot ? formatTime(selSlot.startTime) : ''}</span></div>
        </div>
        <div className="mb-5 text-center">
         <span className="block text-[10px] text-slate-400 uppercase tracking-widest mb-2">Booking Reference</span>
         <span className="inline-block bg-slate-100 px-4 py-2 rounded-lg text-base text-slate-900 tracking-widest">{bookingRef}</span>
        </div>
        <div className="w-36 h-36 mx-auto bg-slate-50 rounded-2xl flex items-center justify-center border-2 border-dashed border-slate-200 mb-3">
         {bookingQrCode ? <img src={bookingQrCode} alt="Booking QR Code" className="w-32 h-32 rounded-xl object-contain" /> : <span className="text-xs text-slate-400">QR Code</span>}
        </div>
        <p className="text-[10px] text-center text-slate-400 uppercase tracking-widest">Show this at reception</p>
       </div>
      </motion.div>
     )}
    </AnimatePresence>
   </div>
  </div>

  <AnimatePresence>
   {showLogin && <AuthModal isOpen={showLogin} onClose={() => { setShowLogin(false); setPendingConfirm(false); }} initialMode="login" />}
  </AnimatePresence>
 </PageTransition>
 );
};

// ── Helpers ─────────────────────────────────────────────────────────────

const FormRow: React.FC<{ label: string; children: React.ReactNode }> = ({ label, children }) => (
 <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4 py-4 first:pt-0">
  <label className="sm:w-32 shrink-0 text-[15px] text-slate-700 font-medium">{label}</label>
  <div className="flex-1 min-w-0">{children}</div>
 </div>
);

const SelectShell: React.FC<{ children: React.ReactNode; icon?: React.ReactNode }> = ({ children, icon }) => (
 <div className="relative">
  {children}
  <span className="absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none flex items-center gap-1 text-slate-400">
   {icon}
   <ChevronDown size={17} />
  </span>
 </div>
);

const SummaryRow: React.FC<{ icon: React.ReactNode; label: string; value?: string }> = ({ icon, label, value }) => (
 <div className="flex items-center gap-3">
  <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${value ? 'bg-brand-primary/10 text-brand-primary' : 'bg-slate-100 text-slate-400'}`}>{icon}</div>
  <div className="min-w-0">
   <span className="block text-[10px] text-slate-400 uppercase tracking-widest">{label}</span>
   <span className={`block text-[14px] truncate ${value ? 'text-slate-900' : 'text-slate-300 italic'}`}>{value || '—'}</span>
  </div>
 </div>
);

export default BookFacilityPage;
