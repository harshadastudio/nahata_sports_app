/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion } from 'motion/react';
import {
 X, User, Calendar, Droplets, User2, Phone, Mail, MapPin,
 Lock, Upload, Eye, EyeOff, CheckCircle, AlertCircle, Loader2,
} from 'lucide-react';
import { useState, useRef, useEffect } from 'react';
import { PhoneInput } from './PhoneInput';
import { coachingApi } from '../services/coachingApi';
import type { SportComplex } from '../types/coaching';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

interface StudentRegisterModalProps {
 isOpen: boolean;
 onClose: () => void;
}

interface FormState {
 name: string;
 dob: string;
 blood_group: string;
 gender: string;
 sport_complex_id: string;
 phone_number: string;
 email: string;
 password: string;
 confirmPassword: string;
 photo: File | null;
}

const initialForm: FormState = {
 name: '',
 dob: '',
 blood_group: '',
 gender: '',
 sport_complex_id: '',
 phone_number: '',
 email: '',
 password: '',
 confirmPassword: '',
 photo: null,
};

export const StudentRegisterModal = ({ isOpen, onClose }: StudentRegisterModalProps) => {
 const [form, setForm] = useState<FormState>(initialForm);
 const [showPassword, setShowPassword] = useState(false);
 const [showConfirmPassword, setShowConfirmPassword] = useState(false);
 const [isLoading, setIsLoading] = useState(false);
 const [error, setError] = useState<string | null>(null);
 const [success, setSuccess] = useState(false);
 const [photoPreview, setPhotoPreview] = useState<string | null>(null);
 const [complexes, setComplexes] = useState<SportComplex[]>([]);
 const fileInputRef = useRef<HTMLInputElement>(null);

 useEffect(() => {
 coachingApi
 .getSportComplexes()
 .then((data) => setComplexes(data))
 .catch(() => setComplexes([]));
 }, []);

 if (!isOpen) return null;

 const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
 setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
 setError(null);
 };

 const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
 const file = e.target.files?.[0] ?? null;
 setForm((prev) => ({ ...prev, photo: file }));
 if (file) {
 setPhotoPreview(URL.createObjectURL(file));
 }
 };

 const validate = (): string | null => {
 if (!form.name.trim()) return 'Full name is required.';
 if (!form.phone_number.trim()) return 'Phone number is required.';
 if (!/^[6-9]\d{9}$/.test(form.phone_number.replace(/\D/g, ''))) return 'Enter a valid 10-digit phone number (starting 6–9).';
 if (!form.email.trim()) return 'Email is required.';
 if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) return 'Enter a valid email address.';
 if (!form.sport_complex_id) return 'Please select a sports complex.';
 if (!form.password) return 'Password is required.';
 if (form.password.length < 6) return 'Password must be at least 6 characters.';
 if (form.password !== form.confirmPassword) return 'Passwords do not match.';
 return null;
 };

 const handleSubmit = async (e?: React.FormEvent | React.MouseEvent) => {
 if (e) e.preventDefault();
 const validationError = validate();
 if (validationError) {
 setError(validationError);
 return;
 }

 setIsLoading(true);
 setError(null);

 try {
 const formData = new FormData();
 formData.append('name', form.name.trim());
 formData.append('email', form.email.trim());
 formData.append('password', form.password);
 formData.append('phone_number', form.phone_number.replace(/\D/g, '')); // WhatsApp number (required)
 if (form.dob) formData.append('dob', form.dob);
 if (form.gender) formData.append('gender', form.gender);
 if (form.blood_group) formData.append('blood_group', form.blood_group);
 if (form.sport_complex_id) formData.append('sportComplexId', form.sport_complex_id);
 if (form.photo) formData.append('photo', form.photo);

 const response = await fetch(`${API_BASE_URL}/students/register`, {
 method: 'POST',
 credentials: 'include',
 body: formData,
 });

 const result = await response.json();

 if (!response.ok) {
 throw new Error(result.message || 'Registration failed. Please try again.');
 }

 setSuccess(true);
 setForm(initialForm);
 setPhotoPreview(null);

 // Auto-close after 2.5 seconds
 setTimeout(() => {
 setSuccess(false);
 onClose();
 }, 2500);
 } catch (err) {
 setError(err instanceof Error ? err.message : 'Something went wrong.');
 } finally {
 setIsLoading(false);
 }
 };

 const handleClose = () => {
 if (!isLoading) {
 setForm(initialForm);
 setError(null);
 setSuccess(false);
 setPhotoPreview(null);
 onClose();
 }
 };

 return (
 <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
 {/* Backdrop */}
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onClick={handleClose}
 className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
 />

 {/* Modal */}
 <motion.div
 initial={{ opacity: 0, scale: 0.95, y: 20 }}
 animate={{ opacity: 1, scale: 1, y: 0 }}
 exit={{ opacity: 0, scale: 0.95, y: 20 }}
 className="relative bg-white w-full max-w-2xl rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
 >
 {/* Header */}
 <div className="bg-brand-primary p-6 flex justify-between items-center text-white shrink-0">
 <h2 className="text-xl tracking-tight uppercase">
 Student Registration
 </h2>
 <button
 onClick={handleClose}
 disabled={isLoading}
 className="text-white/80 hover:text-white transition-colors disabled:opacity-50"
 >
 <X size={24} />
 </button>
 </div>

 {/* Success State */}
 {success ? (
 <div className="flex-1 flex flex-col items-center justify-center p-12 text-center gap-4">
 <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
 <CheckCircle className="text-green-500"size={36} />
 </div>
 <h3 className="text-xl text-slate-800">Registration Successful!</h3>
 <p className="text-slate-500 text-sm">
 Your student account has been created. You can now log in with your email and password.
 </p>
 </div>
 ) : (
 <>
 {/* Form Body */}
 <div className="p-6 md:p-8 overflow-y-auto no-scrollbar flex-1">
 {/* Error Banner */}
 {error && (
 <div className="mb-6 flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 rounded-xl p-4 text-sm">
 <AlertCircle size={18} className="shrink-0 mt-0.5"/>
 <span>{error}</span>
 </div>
 )}

 <form id="student-register-form"className="space-y-8"onSubmit={(e) => handleSubmit(e)}>
 {/* Personal Information */}
 <div className="p-6 border border-slate-100 rounded-2xl relative">
 <span className="absolute -top-3 left-6 bg-white px-3 text-sm text-slate-800">
 Personal Information
 </span>

 <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
 {/* Photo */}
 <div className="md:col-span-2 space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Student Photo
 </label>
 <div className="flex items-center gap-4">
 {photoPreview ? (
 <img
 src={photoPreview}
 alt="Preview"
 className="w-16 h-16 rounded-full object-cover border-2 border-brand-primary"
 />
 ) : (
 <div className="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center border-2 border-dashed border-slate-300">
 <User size={24} className="text-slate-300"/>
 </div>
 )}
 <label className="flex cursor-pointer">
 <div className="bg-slate-50 border border-r-0 border-slate-200 px-4 py-3 rounded-l-xl text-xs text-slate-600 hover:bg-slate-100 flex items-center gap-2">
 <Upload size={16} /> Choose File
 </div>
 <div className="flex-1 bg-white border border-slate-200 px-4 py-3 rounded-r-xl text-xs text-slate-400 flex items-center italic min-w-[120px]">
 {form.photo ? form.photo.name : 'No file chosen'}
 </div>
 <input
 ref={fileInputRef}
 type="file"
 accept="image/jpeg,image/jpg,image/png,image/webp"
 className="hidden"
 onChange={handlePhotoChange}
 />
 </label>
 </div>
 </div>

 {/* Full Name */}
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Full Name <span className="text-red-400">*</span>
 </label>
 <div className="relative">
 <User className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <input
 type="text"
 name="name"
 value={form.name}
 onChange={handleChange}
 placeholder="Enter full name"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-4 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 </div>
 </div>

 {/* Date of Birth */}
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Date of Birth
 </label>
 <div className="relative">
 <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <input
 type="date"
 name="dob"
 value={form.dob}
 onChange={handleChange}
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-4 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 </div>
 </div>

 {/* Blood Group */}
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Blood Group
 </label>
 <div className="relative">
 <Droplets className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <select
 name="blood_group"
 value={form.blood_group}
 onChange={handleChange}
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-4 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary appearance-none transition-all"
 >
 <option value="">Select</option>
 {['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((bg) => (
 <option key={bg} value={bg}>{bg}</option>
 ))}
 </select>
 </div>
 </div>

 {/* Gender */}
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Gender
 </label>
 <div className="relative">
 <User2 className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <select
 name="gender"
 value={form.gender}
 onChange={handleChange}
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-4 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary appearance-none transition-all"
 >
 <option value="">Select</option>
 <option value="Male">Male</option>
 <option value="Female">Female</option>
 <option value="Other">Other</option>
 </select>
 </div>
 </div>
 </div>
 </div>

 {/* Contact Information */}
 <div className="p-6 border border-slate-100 rounded-2xl relative">
 <span className="absolute -top-3 left-6 bg-white px-3 text-sm text-slate-800">
 Contact Information
 </span>

 <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
 <PhoneInput
 value={form.phone_number}
 onChange={(value) => setForm({ ...form, phone_number: value })}
 label="Phone Number"
 placeholder="Enter 10-digit phone number"
 required
 />

 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Email <span className="text-red-400">*</span>
 </label>
 <div className="relative">
 <Mail className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <input
 type="email"
 name="email"
 value={form.email}
 onChange={handleChange}
 placeholder="Enter email address"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-4 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 </div>
 </div>

 {/* Sports Complex */}
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Sports Complex <span className="text-red-400">*</span>
 </label>
 <div className="relative">
 <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <select
 name="sport_complex_id"
 value={form.sport_complex_id}
 onChange={handleChange}
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-4 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary appearance-none transition-all"
 >
 <option value="">Select</option>
 {complexes.map((c) => (
 <option key={c.id} value={c.id}>{c.name}</option>
 ))}
 </select>
 </div>
 </div>
 </div>
 </div>

 {/* Login Credentials */}
 <div className="p-6 border border-slate-100 rounded-2xl relative">
 <span className="absolute -top-3 left-6 bg-white px-3 text-sm text-slate-800">
 Login Credentials
 </span>

 <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Password <span className="text-red-400">*</span>
 </label>
 <div className="relative">
 <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <input
 type={showPassword ? 'text' : 'password'}
 name="password"
 value={form.password}
 onChange={handleChange}
 placeholder="••••••••"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-10 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 <button
 type="button"
 onClick={() => setShowPassword(!showPassword)}
 className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
 >
 {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
 </button>
 </div>
 </div>

 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-1">
 Confirm Password <span className="text-red-400">*</span>
 </label>
 <div className="relative">
 <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300"size={16} />
 <input
 type={showConfirmPassword ? 'text' : 'password'}
 name="confirmPassword"
 value={form.confirmPassword}
 onChange={handleChange}
 placeholder="••••••••"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-xl py-2.5 pl-10 pr-10 text-xs focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 <button
 type="button"
 onClick={() => setShowConfirmPassword(!showConfirmPassword)}
 className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
 >
 {showConfirmPassword ? <EyeOff size={16} /> : <Eye size={16} />}
 </button>
 </div>
 </div>
 </div>
 </div>
 </form>
 </div>

 {/* Footer */}
 <div className="p-6 border-t border-slate-100 flex justify-end gap-3 shrink-0">
 <button
 type="button"
 onClick={handleClose}
 disabled={isLoading}
 className="px-6 py-2 rounded-full text-xs uppercase tracking-wide min-w-[100px] bg-slate-500 text-white hover:bg-slate-600 disabled:opacity-50 transition-all"
 >
 Close
 </button>
 <button
 type="button"
 onClick={(e) => handleSubmit(e)}
 disabled={isLoading}
 className="px-6 py-2 rounded-full text-xs uppercase tracking-wide min-w-[120px] bg-[#322d77] text-white hover:bg-brand-dark disabled:opacity-60 flex items-center justify-center gap-2 transition-all"
 >
 {isLoading ? (
 <>
 <Loader2 size={14} className="animate-spin"/>
 Registering...
 </>
 ) : (
 'Register'
 )}
 </button>
 </div>
 </>
 )}
 </motion.div>
 </div>
 );
};

