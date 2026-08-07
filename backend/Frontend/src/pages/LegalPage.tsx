/**
 * Shared legal page component for Privacy Policy, Cancellation Policy,
 * Disclaimer, and Terms & Conditions.
 */
import { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { Loader2, AlertCircle, Shield, FileX, Scale, FileCheck, Palmtree, Hammer } from 'lucide-react';

const API = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

type LegalType = 'privacy' | 'cancellation' | 'disclaimer' | 'terms' | 'holidays' | 'equipment';

const PAGE_META: Record<LegalType, { icon: React.ComponentType<{ size?: number; className?: string }>; color: string }> = {
 privacy: { icon: Shield, color: 'text-blue-600' },
 cancellation: { icon: FileX, color: 'text-orange-600' },
 disclaimer: { icon: Scale, color: 'text-purple-600' },
 terms: { icon: FileCheck, color: 'text-green-600' },
 holidays: { icon: Palmtree, color: 'text-teal-600' },
 equipment: { icon: Hammer, color: 'text-amber-600' },
};

interface LegalPageProps {
 type: LegalType;
}

export const LegalPage = ({ type }: LegalPageProps) => {
 const [title, setTitle] = useState('');
 const [content, setContent] = useState('');
 const [loading, setLoading] = useState(true);
 const [error, setError] = useState<string | null>(null);
 const [updatedAt, setUpdatedAt] = useState<string | null>(null);

 useEffect(() => {
 window.scrollTo(0, 0);
 fetch(`${API}/legal/${type}`)
 .then((r) => r.json())
 .then((json) => {
 if (json.success) {
 setTitle(json.data.title);
 setContent(json.data.content);
 setUpdatedAt(json.data.updatedAt ? new Date(json.data.updatedAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' }) : null);
 } else {
 setError(json.message || 'Failed to load page.');
 }
 })
 .catch(() => setError('Unable to load content. Please try again later.'))
 .finally(() => setLoading(false));
 }, [type]);

 const meta = PAGE_META[type];
 const IconComp = meta.icon;

 return (
 <div className="min-h-screen bg-slate-50 pt-32 pb-20">
 <div className="container-custom max-w-4xl">

 {/* Page header */}
 <motion.div
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 className="text-center mb-12"
 >
 <div className={`inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-white shadow-sm border border-slate-100 mb-6 ${meta.color}`}>
 <IconComp size={28} />
 </div>
 {loading ? (
 <div className="h-10 w-64 bg-slate-200 animate-pulse rounded-xl mx-auto"/>
 ) : (
 <h1 className="text-4xl text-slate-900 uppercase tracking-tight">{title}</h1>
 )}
 {updatedAt && !loading && (
 <p className="text-slate-400 text-sm mt-3">Last updated: {updatedAt}</p>
 )}
 </motion.div>

 {/* Content */}
 <motion.div
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 transition={{ delay: 0.1 }}
 className="bg-white rounded-3xl shadow-sm border border-slate-100 p-8 md:p-12"
 >
 {loading ? (
 <div className="flex items-center justify-center py-16 gap-3 text-slate-400">
 <Loader2 size={24} className="animate-spin"/>
 <span>Loading content...</span>
 </div>
 ) : error ? (
 <div className="flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 rounded-xl p-5">
 <AlertCircle size={20} className="shrink-0 mt-0.5"/>
 <span>{error}</span>
 </div>
 ) : (
 <div className="space-y-2">
 {content.split('\n').map((line, i) => {
 if (line.trim() === '') return <div key={i} className="h-3"/>;
 if (/^\d+\./.test(line.trim())) {
 return (
 <h3 key={i} className="text-base text-slate-800 mt-6 mb-2 uppercase tracking-tight">
 {line}
 </h3>
 );
 }
 if (line.trim().startsWith('•')) {
 return (
 <p key={i} className="text-slate-600 text-sm leading-relaxed pl-5 flex gap-2">
 <span className="text-brand-primary shrink-0 mt-1">•</span>
 <span>{line.replace(/^•\s*/, '')}</span>
 </p>
 );
 }
 return (
 <p key={i} className="text-slate-600 text-sm leading-relaxed">
 {line}
 </p>
 );
 })}
 </div>
 )}
 </motion.div>

 {/* Back link */}
 <div className="text-center mt-8">
 <a href="/"className="text-sm text-brand-primary hover:underline">
 ← Back to Home
 </a>
 </div>
 </div>
 </div>
 );
};

export default LegalPage;

