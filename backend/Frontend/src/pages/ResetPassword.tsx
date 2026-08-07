/**
 * Reset Password Page
 * Handles the /reset-password?token=... route from the email link.
 */

import React, { useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { motion } from 'motion/react';
import { Lock, Eye, EyeOff, Loader2, CheckCircle, XCircle, ArrowRight } from 'lucide-react';
import { authService } from '../services/authService';
import { Button } from '../components/UI';

export const ResetPasswordPage: React.FC = () => {
 const [searchParams] = useSearchParams();
 const navigate = useNavigate();
 const token = searchParams.get('token') || '';

 const [password, setPassword] = useState('');
 const [confirmPassword, setConfirmPassword] = useState('');
 const [showPassword, setShowPassword] = useState(false);
 const [showConfirm, setShowConfirm] = useState(false);
 const [isLoading, setIsLoading] = useState(false);
 const [error, setError] = useState<string | null>(null);
 const [success, setSuccess] = useState(false);

 // No token in URL — show an error state
 if (!token) {
 return (
 <div className="min-h-screen flex items-center justify-center bg-slate-50 p-4">
 <motion.div
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 className="bg-white rounded-[2.5rem] shadow-2xl p-10 max-w-md w-full text-center"
 >
 <XCircle size={56} className="text-red-400 mx-auto mb-4"/>
 <h1 className="text-2xl text-slate-900 tracking-tighter uppercase mb-3">
 Invalid Link
 </h1>
 <p className="text-slate-500 text-sm mb-8">
 This password reset link is missing or invalid. Please request a new one.
 </p>
 <button
 onClick={() => navigate('/')}
 className="text-brand-primary text-sm hover:underline"
 >
 Go to Home
 </button>
 </motion.div>
 </div>
 );
 }

 const handleSubmit = async (e: React.FormEvent) => {
 e.preventDefault();
 setError(null);

 if (password.length < 6) {
 setError('Password must be at least 6 characters.');
 return;
 }
 if (password !== confirmPassword) {
 setError('Passwords do not match.');
 return;
 }

 setIsLoading(true);
 try {
 await authService.resetPassword(token, password);
 setSuccess(true);
 } catch (err) {
 setError(err instanceof Error ? err.message : 'Password reset failed. The link may have expired.');
 } finally {
 setIsLoading(false);
 }
 };

 return (
 <div className="min-h-screen flex items-center justify-center bg-slate-50 p-4">
 <motion.div
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 className="bg-white rounded-[2.5rem] shadow-2xl p-10 max-w-md w-full"
 >
 {success ? (
 <div className="text-center py-4">
 <CheckCircle size={56} className="text-green-500 mx-auto mb-4"/>
 <h1 className="text-2xl text-slate-900 tracking-tighter uppercase mb-3">
 Password Reset!
 </h1>
 <p className="text-slate-500 text-sm mb-8">
 Your password has been updated successfully. You can now log in with your new password.
 </p>
 <Button
 className="w-full py-4 uppercase tracking-widest"
 onClick={() => navigate('/')}
 >
 Go to Login
 <ArrowRight size={18} />
 </Button>
 </div>
 ) : (
 <>
 <div className="text-center mb-8">
 <h1 className="text-3xl text-slate-900 tracking-tighter uppercase mb-2">
 Reset Password
 </h1>
 <p className="text-slate-500 text-sm">
 Choose a strong new password for your account.
 </p>
 </div>

 {error && (
 <div className="mb-5 p-3 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
 <XCircle size={16} className="text-red-500 mt-0.5 shrink-0"/>
 <p className="text-red-600 text-sm">{error}</p>
 </div>
 )}

 <form className="space-y-4"onSubmit={handleSubmit}>
 {/* New Password */}
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-4">
 New Password
 </label>
 <div className="relative">
 <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <input
 type={showPassword ? 'text' : 'password'}
 value={password}
 onChange={e => { setPassword(e.target.value); setError(null); }}
 placeholder="Min. 6 characters"
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

 {/* Confirm Password */}
 <div className="space-y-1">
 <label className="text-[10px] uppercase text-slate-400 tracking-widest ml-4">
 Confirm Password
 </label>
 <div className="relative">
 <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <input
 type={showConfirm ? 'text' : 'password'}
 value={confirmPassword}
 onChange={e => { setConfirmPassword(e.target.value); setError(null); }}
 placeholder="Re-enter your password"
 required
 className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-3.5 pl-12 pr-12 text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all"
 />
 <button
 type="button"
 onClick={() => setShowConfirm(!showConfirm)}
 className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
 >
 {showConfirm ? <EyeOff size={18} /> : <Eye size={18} />}
 </button>
 </div>
 {/* Live match indicator */}
 {confirmPassword.length > 0 && (
 <p className={`text-xs ml-4 mt-1 ${password === confirmPassword ? 'text-green-500' : 'text-red-400'}`}>
 {password === confirmPassword ? '✓ Passwords match' : '✗ Passwords do not match'}
 </p>
 )}
 </div>

 <Button
 type="submit"
 className="w-full py-4 mt-4 uppercase tracking-widest"
 onClick={() => {}}
 >
 {isLoading ? (
 <>
 <Loader2 className="animate-spin"size={18} />
 Resetting...
 </>
 ) : (
 <>
 Reset Password
 <ArrowRight size={18} />
 </>
 )}
 </Button>
 </form>

 <div className="mt-6 text-center">
 <button
 onClick={() => navigate('/')}
 className="text-slate-400 text-sm hover:text-slate-600 transition-colors"
 >
 Back to Home
 </button>
 </div>
 </>
 )}
 </motion.div>
 </div>
 );
};

