/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion, AnimatePresence } from 'motion/react';
import {
 Mail,
 User,
 MessageSquare,
 Send,
 MapPin,
 Phone,
 Clock,
 CheckCircle,
 AlertCircle,
 Loader2,
} from 'lucide-react';
import { useState, useEffect, ChangeEvent, FormEvent } from 'react';
import { contactService, ContactFormData, ContactInfo } from '../services/contactService';
import { coachingApi } from '../services/coachingApi';
import type { SportComplex } from '../types/coaching';
import { getImageUrl } from '../lib/utils';

// ─── Types ────────────────────────────────────────────────────────────────────

type FormFields = ContactFormData;

type FieldErrors = Partial<Record<keyof FormFields, string>>;

type SubmitState = 'idle' | 'loading' | 'success' | 'error';

// ─── Validation ───────────────────────────────────────────────────────────────

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateForm(fields: FormFields): FieldErrors {
 const errors: FieldErrors = {};

 const fullName = fields.fullName.trim();
 if (!fullName) {
 errors.fullName = 'Full name is required.';
 } else if (fullName.length > 100) {
 errors.fullName = 'Full name must not exceed 100 characters.';
 }

 const email = fields.email.trim();
 if (!email) {
 errors.email = 'Email address is required.';
 } else if (!EMAIL_REGEX.test(email)) {
 errors.email = 'Please enter a valid email address.';
 }

 if (!fields.sportComplexId) {
 errors.sportComplexId = 'Please select a sports complex.';
 }

 const subject = fields.subject.trim();
 if (!subject) {
 errors.subject = 'Subject is required.';
 } else if (subject.length > 200) {
 errors.subject = 'Subject must not exceed 200 characters.';
 }

 const message = fields.message.trim();
 if (!message) {
 errors.message = 'Message is required.';
 } else if (message.length > 5000) {
 errors.message = 'Message must not exceed 5000 characters.';
 }

 return errors;
}

// ─── Sub-components ───────────────────────────────────────────────────────────

interface FieldErrorProps {
 message?: string;
}

const FieldError = ({ message }: FieldErrorProps) => (
 <AnimatePresence>
 {message && (
 <motion.p
 key={message}
 initial={{ opacity: 0, y: -4 }}
 animate={{ opacity: 1, y: 0 }}
 exit={{ opacity: 0, y: -4 }}
 transition={{ duration: 0.15 }}
 className="flex items-center gap-1.5 text-xs text-red-500 mt-1.5 ml-1"
 >
 <AlertCircle size={12} className="shrink-0"/>
 {message}
 </motion.p>
 )}
 </AnimatePresence>
);

// ─── Main Component ───────────────────────────────────────────────────────────

const INITIAL_FORM: FormFields = {
 fullName: '',
 email: '',
 sportComplexId: '',
 subject: '',
 message: '',
};

const DUMMY_CONTACT_INFO: ContactInfo = {
  id: '0',
  address: 'Nahata Sports Complex, Sinhagad Road, Near Pu La Deshpande Garden, Pune, Maharashtra 411030',
  phone: '+91 98765 43210',
  email: 'info@nahatasports.com',
  hours: 'Mon - Sun: 06:00 AM - 10:00 PM',
  mapEmbedUrl: 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3783.381373514!2d73.829!3d18.520!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3bc2bf2e!2sNahata%20Sports%20Complex!5e0!3m2!1sen!2sin!4v1620560000000!5m2!1sen!2sin',
  image: '',
  description: 'Have questions about our coaching programs or facility bookings? We are here to help! Visit us or drop a message below.',
  isActive: true,
  createdAt: '2025-01-01',
  updatedAt: '2025-01-01'
};

export const ContactPage = () => {
  const [form, setForm] = useState<FormFields>(INITIAL_FORM);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [submitState, setSubmitState] = useState<SubmitState>('idle');
  const [referenceNumber, setReferenceNumber] = useState<string | null>(null);
  const [apiError, setApiError] = useState<string | null>(null);
  const [contactInfo, setContactInfo] = useState<ContactInfo | null>(DUMMY_CONTACT_INFO);
  const [isLoadingInfo, setIsLoadingInfo] = useState(true);
  const [complexes, setComplexes] = useState<SportComplex[]>([]);

  // ── Fetch Contact Information ──────────────────────────────────────────────

  useEffect(() => {
    const fetchContactInfo = async () => {
      try {
        const response = await contactService.getContactInfo();
        if (response.data.contactInfo) {
          setContactInfo(response.data.contactInfo);
        }
      } catch (error) {
        console.error('Failed to fetch contact information:', error);
        setContactInfo(DUMMY_CONTACT_INFO);
      } finally {
        setIsLoadingInfo(false);
      }
    };

    fetchContactInfo();
  }, []);

  // ── Fetch Sports Complexes ─────────────────────────────────────────────────

  useEffect(() => {
    coachingApi
      .getSportComplexes()
      .then((data) => setComplexes(data))
      .catch(() => setComplexes([]));
  }, []);

 // ── Handlers ────────────────────────────────────────────────────────────────

 const handleChange = (
 e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>
 ) => {
 const { name, value } = e.target;
 setForm((prev) => ({
 ...prev,
 [name]: name === 'sportComplexId' ? (value === '' ? '' : Number(value)) : value,
 }));

 // Clear the field error as the user types
 if (fieldErrors[name as keyof FormFields]) {
 setFieldErrors((prev) => ({ ...prev, [name]: undefined }));
 }
 };

 const handleSubmit = async (e: FormEvent) => {
 e.preventDefault();
 setApiError(null);

 // Trim all fields before validation
 const trimmed: FormFields = {
 fullName: form.fullName.trim(),
 email: form.email.trim(),
 sportComplexId: form.sportComplexId,
 subject: form.subject.trim(),
 message: form.message.trim(),
 };

 // Frontend validation
 const errors = validateForm(trimmed);
 if (Object.keys(errors).length > 0) {
 setFieldErrors(errors);
 return;
 }

 setSubmitState('loading');

 try {
 const response = await contactService.submitContactForm(trimmed);
 setReferenceNumber(response.data?.referenceNumber ?? null);
 setSubmitState('success');
 setForm(INITIAL_FORM);
 setFieldErrors({});
 } catch (err: unknown) {
 setSubmitState('error');

 // Handle structured backend validation errors (HTTP 422)
 if (
 err &&
 typeof err === 'object' &&
 'errors' in err &&
 Array.isArray((err as { errors: unknown[] }).errors)
 ) {
 const backendErrors: FieldErrors = {};
 (err as { errors: Array<{ field: string; message: string }> }).errors.forEach(
 ({ field, message }) => {
 backendErrors[field as keyof FormFields] = message;
 }
 );
 setFieldErrors(backendErrors);
 setSubmitState('idle');
 return;
 }

 // Generic error message
 const message =
 err && typeof err === 'object' && 'message' in err
 ? String((err as { message: string }).message)
 : 'Something went wrong. Please try again.';
 setApiError(message);
 }
 };

 const handleReset = () => {
 setSubmitState('idle');
 setReferenceNumber(null);
 setApiError(null);
 setFieldErrors({});
 };

 // ── Input class helper ───────────────────────────────────────────────────────

 const inputClass = (field: keyof FormFields) =>
 `w-full bg-slate-50 border rounded-2xl py-4 pl-12 pr-4 focus:outline-none focus:ring-2 transition-all text-slate-900 placeholder:text-slate-400 ${
 fieldErrors[field]
 ? 'border-red-300 focus:ring-red-200 focus:border-red-400'
 : 'border-slate-100 focus:ring-brand-primary/20 focus:border-brand-primary'
 }`;

 // ─── Render ──────────────────────────────────────────────────────────────────

 return (
 <div className="pt-32 pb-20 bg-white min-h-screen">
 <div className="container-custom">
 <motion.div
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 className="text-center mb-16"
 >
  <h1 className="text-4xl md:text-6xl text-slate-900 uppercase tracking-tight leading-[0.9] mb-2">
  Contact <span className="text-brand-primary">Us</span>
  </h1>
 <div className="w-20 h-1.5 bg-brand-primary mx-auto rounded-full"></div>
 </motion.div>

 {/* Contact Form & Image Section */}
 <div className="grid lg:grid-cols-2 gap-12 items-stretch mb-20">
 {/* Left Column: Image */}
 <motion.div
 initial={{ opacity: 0, x: -30 }}
 animate={{ opacity: 1, x: 0 }}
 className="rounded-[2.5rem] overflow-hidden shadow-xl"
 >
 {isLoadingInfo ? (
 <div className="w-full h-full min-h-[400px] flex items-center justify-center bg-slate-100">
 <Loader2 size={32} className="animate-spin text-slate-400"/>
 </div>
 ) : contactInfo?.image ? (
 <img
 src={getImageUrl(contactInfo.image)}
 alt="Contact Us"
 className="w-full h-full object-cover"
 />
 ) : (
 <div className="w-full h-full min-h-[400px] flex flex-col items-center justify-center bg-slate-50 gap-3">
 <MapPin size={40} className="text-slate-300"/>
 <p className="text-slate-400 text-sm">No image set</p>
 <p className="text-slate-300 text-xs">Admin can add one via CMS → Contact Info</p>
 </div>
 )}
 </motion.div>

 {/* Right Column: Form / Success / Error */}
 <motion.div
 initial={{ opacity: 0, x: 30 }}
 animate={{ opacity: 1, x: 0 }}
 className="bg-white rounded-[2.5rem] border border-slate-100 shadow-xl p-8 md:p-10 flex flex-col justify-center"
 >
 {/* Description Banner (if exists) */}
 {contactInfo?.description && (
 <div className="mb-6 bg-blue-50 border border-blue-100 rounded-2xl p-4 flex items-start gap-3">
 <AlertCircle className="text-blue-600 shrink-0 mt-0.5"size={18} />
 <p className="text-sm text-blue-900 leading-relaxed">
 {contactInfo.description}
 </p>
 </div>
 )}

 {/* ── Success State ── */}
 <AnimatePresence mode="wait">
 {submitState === 'success' ? (
 <motion.div
 key="success"
 initial={{ opacity: 0, scale: 0.95 }}
 animate={{ opacity: 1, scale: 1 }}
 exit={{ opacity: 0, scale: 0.95 }}
 className="flex flex-col items-center text-center gap-5 py-8"
 >
 <div className="bg-green-50 p-5 rounded-full">
 <CheckCircle size={48} className="text-green-500"/>
 </div>
 <div>
 <h2 className="text-2xl text-slate-900 mb-2">
 Message Sent!
 </h2>
 <p className="text-slate-500 text-sm leading-relaxed">
 Thank you for reaching out. We'll get back to you shortly.
 </p>
 {referenceNumber && (
 <p className="mt-3 text-xs text-slate-400 tracking-widest uppercase">
 Reference:{' '}
 <span className="text-brand-primary">{referenceNumber}</span>
 </p>
 )}
 </div>
 <button
 onClick={handleReset}
 className="text-sm text-slate-500 hover:text-slate-900 underline underline-offset-4 transition-colors"
 >
 Send another message
 </button>
 </motion.div>
 ) : (
 /* ── Form State ── */
 <motion.form
 key="form"
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onSubmit={handleSubmit}
 noValidate
 className="space-y-5"
 >
 {/* API-level error banner */}
 <AnimatePresence>
 {apiError && (
 <motion.div
 initial={{ opacity: 0, y: -8 }}
 animate={{ opacity: 1, y: 0 }}
 exit={{ opacity: 0, y: -8 }}
 className="flex items-start gap-3 bg-red-50 border border-red-100 text-red-600 text-sm rounded-2xl px-4 py-3"
 >
 <AlertCircle size={16} className="shrink-0 mt-0.5"/>
 {apiError}
 </motion.div>
 )}
 </AnimatePresence>

 {/* Full Name */}
 <div className="space-y-1.5">
 <label className="text-[10px] uppercase text-slate-400 tracking-[0.2em] ml-1">
 Full Name
 </label>
 <div className="relative">
 <User
 className={`absolute left-4 top-1/2 -translate-y-1/2 ${fieldErrors.fullName ? 'text-red-400' : 'text-slate-400'}`}
 size={18}
 />
 <input
 type="text"
 name="fullName"
 value={form.fullName}
 onChange={handleChange}
 placeholder="Enter your name"
 className={inputClass('fullName')}
 disabled={submitState === 'loading'}
 />
 </div>
 <FieldError message={fieldErrors.fullName} />
 </div>

 {/* Email */}
 <div className="space-y-1.5">
 <label className="text-[10px] uppercase text-slate-400 tracking-[0.2em] ml-1">
 Email Address
 </label>
 <div className="relative">
 <Mail
 className={`absolute left-4 top-1/2 -translate-y-1/2 ${fieldErrors.email ? 'text-red-400' : 'text-slate-400'}`}
 size={18}
 />
 <input
 type="email"
 name="email"
 value={form.email}
 onChange={handleChange}
 placeholder="Enter your email"
 className={inputClass('email')}
 disabled={submitState === 'loading'}
 />
 </div>
 <FieldError message={fieldErrors.email} />
 </div>

 {/* Sports Complex */}
 <div className="space-y-1.5">
 <label className="text-[10px] uppercase text-slate-400 tracking-[0.2em] ml-1">
 Sports Complex
 </label>
 <div className="relative">
 <MapPin
 className={`absolute left-4 top-1/2 -translate-y-1/2 ${fieldErrors.sportComplexId ? 'text-red-400' : 'text-slate-400'}`}
 size={18}
 />
 <select
 name="sportComplexId"
 value={form.sportComplexId}
 onChange={handleChange}
 className={`${inputClass('sportComplexId')} appearance-none pr-12`}
 disabled={submitState === 'loading'}
 >
 <option value="">Select a sports complex</option>
 {complexes.map((c) => (
 <option key={c.id} value={c.id}>{c.name}</option>
 ))}
 </select>
 </div>
 <FieldError message={fieldErrors.sportComplexId} />
 </div>

 {/* Subject */}
 <div className="space-y-1.5">
 <label className="text-[10px] uppercase text-slate-400 tracking-[0.2em] ml-1">
 Subject
 </label>
 <div className="relative">
 <MessageSquare
 className={`absolute left-4 top-1/2 -translate-y-1/2 ${fieldErrors.subject ? 'text-red-400' : 'text-slate-400'}`}
 size={18}
 />
 <input
 type="text"
 name="subject"
 value={form.subject}
 onChange={handleChange}
 placeholder="Subject of your message"
 className={inputClass('subject')}
 disabled={submitState === 'loading'}
 />
 </div>
 <FieldError message={fieldErrors.subject} />
 </div>

 {/* Message */}
 <div className="space-y-1.5">
 <label className="text-[10px] uppercase text-slate-400 tracking-[0.2em] ml-1">
 Message
 </label>
 <textarea
 name="message"
 value={form.message}
 onChange={handleChange}
 placeholder="Write your message here"
 rows={4}
 className={`w-full bg-slate-50 border rounded-2xl py-4 px-4 focus:outline-none focus:ring-2 transition-all text-slate-900 placeholder:text-slate-400 resize-none ${
 fieldErrors.message
 ? 'border-red-300 focus:ring-red-200 focus:border-red-400'
 : 'border-slate-100 focus:ring-brand-primary/20 focus:border-brand-primary'
 }`}
 disabled={submitState === 'loading'}
 />
 <div className="flex items-start justify-between">
 <FieldError message={fieldErrors.message} />
 <span
 className={`text-[10px] ml-auto mt-1.5 mr-1 ${
 form.message.length > 4800 ? 'text-red-400' : 'text-slate-300'
 }`}
 >
 {form.message.length}/5000
 </span>
 </div>
 </div>

 {/* Submit */}
 <button
 type="submit"
 disabled={submitState === 'loading'}
 className="w-full py-5 uppercase tracking-[0.2em] bg-slate-900 hover:bg-slate-800 text-white shadow-xl shadow-slate-900/10 rounded-full flex items-center justify-center gap-2 transition-all duration-300 disabled:opacity-60 disabled:cursor-not-allowed"
 >
 {submitState === 'loading' ? (
 <>
 <Loader2 size={18} className="mr-2 animate-spin"/>
 Sending...
 </>
 ) : (
 <>
 Send Message
 <Send size={18} className="ml-2"/>
 </>
 )}
 </button>
 </motion.form>
 )}
 </AnimatePresence>
 </motion.div>
 </div>

 {/* Map Section — only render when admin has set a map URL */}
 {!isLoadingInfo && contactInfo?.mapEmbedUrl && (
 <motion.div
 initial={{ opacity: 0, y: 30 }}
 whileInView={{ opacity: 1, y: 0 }}
 viewport={{ once: true }}
 className="rounded-[3rem] overflow-hidden shadow-xl border border-slate-100 h-[450px] relative"
 >
 <iframe
 src={contactInfo.mapEmbedUrl}
 className="w-full h-full border-0 grayscale hover:grayscale-0 transition-all duration-700"
 allowFullScreen
 loading="lazy"
 referrerPolicy="no-referrer-when-downgrade"
 />
 </motion.div>
 )}

 {/* Info Cards — only show when contact info is available */}
 {!isLoadingInfo && contactInfo && (
 <div className="grid md:grid-cols-3 gap-6 mt-12">
 {contactInfo.address && (
 <div className="bg-slate-50 p-6 rounded-[2rem] flex items-center gap-4 border border-slate-100">
 <div className="bg-white p-3 rounded-xl shadow-sm text-brand-primary">
 <MapPin size={24} />
 </div>
 <div>
 <p className="text-[10px] uppercase text-slate-400 tracking-widest">Address</p>
 <p className="text-sm text-slate-900">{contactInfo.address}</p>
 </div>
 </div>
 )}
 {contactInfo.phone && (
 <div className="bg-slate-50 p-6 rounded-[2rem] flex items-center gap-4 border border-slate-100">
 <div className="bg-white p-3 rounded-xl shadow-sm text-brand-primary">
 <Phone size={24} />
 </div>
 <div>
 <p className="text-[10px] uppercase text-slate-400 tracking-widest">Phone</p>
 <p className="text-sm text-slate-900">{contactInfo.phone}</p>
 </div>
 </div>
 )}
 {contactInfo.hours && (
 <div className="bg-slate-50 p-6 rounded-[2rem] flex items-center gap-4 border border-slate-100">
 <div className="bg-white p-3 rounded-xl shadow-sm text-brand-primary">
 <Clock size={24} />
 </div>
 <div>
 <p className="text-[10px] uppercase text-slate-400 tracking-widest">Hours</p>
 <p className="text-sm text-slate-900">{contactInfo.hours}</p>
 </div>
 </div>
 )}
 </div>
 )}
 </div>
 </div>
 );
};
