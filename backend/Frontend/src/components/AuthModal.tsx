/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { motion, AnimatePresence } from 'motion/react';
import { X, Mail, Lock, User, ArrowRight, Phone, Eye, EyeOff, Loader2, ArrowLeft, CheckCircle } from 'lucide-react';
import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { authService, RegisterData } from '../services/authService';
import { Button } from './UI';
import { PhoneInput } from './PhoneInput';
import { GoogleLogin, GoogleOAuthProvider } from '@react-oauth/google';

/**
 * The Google Identity Services script is loaded by GoogleOAuthProvider. It is
 * mounted here rather than at the app root so anonymous visitors who never open
 * this dialog do not pay for ~97 KiB of third-party JS on first load.
 */
const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;

if (!GOOGLE_CLIENT_ID || GOOGLE_CLIENT_ID === 'your_google_client_id_here.apps.googleusercontent.com') {
 console.warn('⚠️ Google Client ID is not configured. Please set VITE_GOOGLE_CLIENT_ID in your .env file.');
}

interface AuthModalProps {
 isOpen: boolean;
 onClose: () => void;
 initialMode?: 'login' | 'signup';
}

type ModalView = 'login' | 'signup' | 'forgot-password';

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose, initialMode = 'login' }) => {
 const [view, setView] = useState<ModalView>('login');
 const [showPassword, setShowPassword] = useState(false);
 const [isLoading, setIsLoading] = useState(false);
 const [error, setError] = useState<string | null>(null);
 const [forgotSuccess, setForgotSuccess] = useState(false);
 const [formData, setFormData] = useState({
 name: '',
 email: '',
 password: '',
 phone_number: ''
 });
 const [forgotEmail, setForgotEmail] = useState('');

 const { login, googleLogin } = useAuth();

 useEffect(() => {
 setView(initialMode);
 }, [initialMode]);

 const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
 const { name, value } = e.target;
 setFormData(prev => ({ ...prev, [name]: value }));
 setError(null);
 };

 const handleSubmit = async (e: React.FormEvent) => {
 e.preventDefault();
 setIsLoading(true);
 setError(null);

 try {
 if (view === 'login') {
 // identifier = email OR WhatsApp number.
 await login(formData.email.trim(), formData.password);
 onClose();
 } else if (view === 'signup') {
 const phoneDigits = formData.phone_number.replace(/\D/g, '');
 if (!/^[6-9]\d{9}$/.test(phoneDigits)) {
 throw new Error('Please enter a valid 10-digit phone number (starting 6–9).');
 }
 const registerData: RegisterData = {
 name: formData.name,
 email: formData.email,
 password: formData.password,
 phone_number: phoneDigits
 };
 const result = await authService.register(registerData);
 if (result.success) {
  await login(formData.email.trim(), formData.password);
  onClose();
 }
 }
 } catch (error) {
 setError(error instanceof Error ? error.message : 'Authentication failed');
 } finally {
 setIsLoading(false);
 }
 };

 const handleForgotPassword = async (e: React.FormEvent) => {
 e.preventDefault();
 setIsLoading(true);
 setError(null);

 try {
 await authService.forgotPassword(forgotEmail);
 setForgotSuccess(true);
 } catch (error) {
 setError(error instanceof Error ? error.message : 'Failed to send reset email');
 } finally {
 setIsLoading(false);
 }
 };

 const resetForm = () => {
 setFormData({ name: '', email: '', password: '', phone_number: '' });
 setForgotEmail('');
 setError(null);
 setShowPassword(false);
 setForgotSuccess(false);
 };

 const switchView = (newView: ModalView) => {
 setView(newView);
 resetForm();
 };

 if (!isOpen) return null;

 return (
 <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
 <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
 <motion.div
 initial={{ opacity: 0 }}
 animate={{ opacity: 1 }}
 exit={{ opacity: 0 }}
 onClick={onClose}
 className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
 />
  <motion.div
  initial={{ opacity: 0, scale: 0.95, y: 20 }}
  animate={{ opacity: 1, scale: 1, y: 0 }}
  exit={{ opacity: 0, scale: 0.95, y: 20 }}
  className="relative bg-white w-full max-w-md rounded-[2.5rem] shadow-2xl overflow-y-auto max-h-[calc(100vh-2rem)] no-scrollbar"
  >
 <button
 onClick={onClose}
 className="absolute top-6 right-6 text-slate-400 hover:text-slate-600 transition-colors z-10"
 >
 <X size={24} />
 </button>

 <AnimatePresence mode="wait">
 {/* ── Forgot Password View ── */}
 {view === 'forgot-password' && (
 <motion.div
 key="forgot"
 initial={{ opacity: 0, x: 30 }}
 animate={{ opacity: 1, x: 0 }}
 exit={{ opacity: 0, x: -30 }}
 transition={{ duration: 0.2 }}
 className="p-8 md:p-12"
 >
 <button
 onClick={() => switchView('login')}
 className="flex items-center gap-1.5 text-slate-400 hover:text-slate-600 transition-colors mb-6 text-sm"
 >
 <ArrowLeft size={16} />
 Back to Login
 </button>

 {forgotSuccess ? (
 <div className="text-center py-4">
 <div className="flex justify-center mb-4">
 <CheckCircle size={56} className="text-green-500"/>
 </div>
 <h2 className="text-2xl text-slate-900 tracking-tighter uppercase mb-3">
 Check Your Email
 </h2>
 <p className="text-slate-500 text-sm leading-relaxed mb-6">
 If an account with <span className="text-slate-700">{forgotEmail}</span> exists, we've sent a password reset link. Check your inbox (and spam folder).
 </p>
 <p className="text-slate-400 text-xs">The link expires in 15 minutes.</p>
 <button
 onClick={() => switchView('login')}
 className="mt-8 text-brand-primary text-sm hover:underline"
 >
 Return to Login
 </button>
 </div>
 ) : (
 <>
 <div className="text-center mb-8">
 <h2 className="text-3xl text-slate-900 tracking-tighter uppercase mb-2">
 Forgot Password?
 </h2>
 <p className="text-slate-500 text-sm">
 Enter your email and we'll send you a reset link.
 </p>
 </div>

 {error && (
 <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl">
 <p className="text-red-600 text-sm">{error}</p>
 </div>
 )}

 <form className="space-y-4"onSubmit={handleForgotPassword}>
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-4">Email Address</label>
 <div className="relative">
 <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <input
 type="email"
 value={forgotEmail}
 onChange={e => { setForgotEmail(e.target.value); setError(null); }}
 placeholder="name@example.com"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-3.5 pl-12 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 </div>
 </div>

 <Button
 type="submit"
 className="w-full py-4 mt-4 uppercase tracking-widest"
 onClick={() => {}}
 >
 {isLoading ? (
 <>
 <Loader2 className="animate-spin"size={18} />
 Sending...
 </>
 ) : (
 <>
 Send Reset Link
 <ArrowRight size={18} />
 </>
 )}
 </Button>
 </form>
 </>
 )}
 </motion.div>
 )}

 {/* ── Login / Signup View ── */}
 {(view === 'login' || view === 'signup') && (
 <motion.div
 key={view}
 initial={{ opacity: 0, x: view === 'login' ? -30 : 30 }}
 animate={{ opacity: 1, x: 0 }}
 exit={{ opacity: 0, x: view === 'login' ? 30 : -30 }}
 transition={{ duration: 0.2 }}
 className="p-8 md:p-12"
 >
 <div className="text-center mb-8">
 <h2 className="text-3xl text-slate-900 tracking-tighter uppercase mb-2">
 {view === 'login' ? 'Welcome Back' : 'Join the Club'}
 </h2>
 <p className="text-slate-500 text-sm">
 {view === 'login' ? 'Login to manage your bookings' : 'Create an account to start playing'}
 </p>
 </div>

 {error && (
 <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl">
 <p className="text-red-600 text-sm">{error}</p>
 </div>
 )}

 <form className="space-y-4"onSubmit={handleSubmit}>
 {view === 'signup' && (
 <>
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-4">Full Name</label>
 <div className="relative">
 <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <input
 type="text"
 name="name"
 value={formData.name}
 onChange={handleInputChange}
 placeholder="John Doe"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-3.5 pl-12 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 </div>
 </div>
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-4">Phone Number</label>
 <div className="relative">
 <Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <span className="absolute left-11 top-1/2 -translate-y-1/2 text-sm text-slate-400 pointer-events-none">+91</span>
 <input
 type="tel"
 inputMode="numeric"
 name="phone_number"
 value={formData.phone_number}
 onChange={(e) => { setFormData(prev => ({ ...prev, phone_number: e.target.value.replace(/\D/g, '').slice(0, 10) })); setError(null); }}
 placeholder="98765 43210"
 required
 maxLength={10}
 className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-3.5 pl-[4.5rem] pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 </div>
 </div>
 </>
 )}

 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-4">
 {view === 'login' ? 'Email or Phone Number' : 'Email Address'}
 </label>
 <div className="relative">
 <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <input
 type={view === 'login' ? 'text' : 'email'}
 name="email"
 value={formData.email}
 onChange={handleInputChange}
 placeholder={view === 'login' ? 'name@example.com or 9876543210' : 'name@example.com'}
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-3.5 pl-12 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 </div>
 </div>

 <div className="space-y-1">
 <div className="flex items-center justify-between ml-4 mr-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest">Password</label>
 {view === 'login' && (
 <button
 type="button"
 onClick={() => switchView('forgot-password')}
 className="text-[10px] uppercase text-brand-primary tracking-widest hover:underline"
 >
 Forgot Password?
 </button>
 )}
 </div>
 <div className="relative">
 <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <input
 type={showPassword ? 'text' : 'password'}
 name="password"
 value={formData.password}
 onChange={handleInputChange}
 placeholder="••••••••"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-3.5 pl-12 pr-12 text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 <button
 type="button"
 onClick={() => setShowPassword(!showPassword)}
 className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
 >
 {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
 </button>
 </div>
 </div>

 <Button
 type="submit"
 className="w-full py-4 mt-4 uppercase tracking-widest"
 onClick={() => {}}
 >
 {isLoading ? (
 <>
 <Loader2 className="animate-spin"size={18} />
 {view === 'login' ? 'Signing In...' : 'Creating Account...'}
 </>
 ) : (
 <>
 {view === 'login' ? 'Sign In' : 'Create Account'}
 <ArrowRight size={18} />
 </>
 )}
 </Button>
 </form>

 <div className="mt-6">
  <div className="relative mb-6">
    <div className="absolute inset-0 flex items-center">
      <div className="w-full border-t border-slate-200"></div>
    </div>
    <div className="relative flex justify-center text-xs uppercase">
      <span className="bg-white px-4 text-slate-500 tracking-widest">Or continue with</span>
    </div>
  </div>

  <div className="flex justify-center">
    <GoogleLogin
      onSuccess={async (credentialResponse) => {
        if (credentialResponse.credential) {
          try {
            await googleLogin(credentialResponse.credential);
            onClose();
          } catch (err) {
            setError('Google Login failed. Please try again.');
          }
        }
      }}
      onError={() => {
        setError('Google Login failed. Please try again.');
      }}
      useOneTap
      theme="outline"
      shape="pill"
    />
  </div>
 </div>

 <div className="mt-8 text-center">
 <p className="text-slate-500 text-sm">
 {view === 'login' ?"Don't have an account?": 'Already have an account?'}
 <button
 onClick={() => switchView(view === 'login' ? 'signup' : 'login')}
 className="ml-2 text-brand-primary hover:underline"
 >
 {view === 'login' ? 'Sign Up' : 'Log In'}
 </button>
 </p>
 </div>
 </motion.div>
 )}
 </AnimatePresence>
 </motion.div>
 </div>
 </GoogleOAuthProvider>
 );
};

