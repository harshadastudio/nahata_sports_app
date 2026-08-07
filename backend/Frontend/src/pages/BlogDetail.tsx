/** @license
 * SPDX-License-Identifier: Apache-2.0
 */
import { motion } from 'motion/react';
import { Calendar, ArrowLeft, Loader2, AlertCircle } from 'lucide-react';
import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import axios from 'axios';
import { SmartImage } from '../components/ui/SmartImage';

interface BlogPost {
 id: number;
 title: string;
 publishedAt?: string;
 createdAt?: string;
 excerpt: string;
 featuredImage?: string;
 category: string;
 content?: string;
 slug?: string;
}

const API_BASE_URL = `${(import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '')}`;

export const BlogDetailPage = () => {
 const { slug } = useParams<{ slug: string }>();
 const [blog, setBlog] = useState<BlogPost | null>(null);
 const [loading, setLoading] = useState(true);
 const [error, setError] = useState<string | null>(null);

 useEffect(() => {
 const fetchBlog = async () => {
 try {
 setLoading(true);
 setError(null);

 const response = await axios.get(`${API_BASE_URL}/blogs/slug/${slug}`);

 if (response.data.success) {
 setBlog(response.data.data);
 } else {
 setError('Failed to load blog');
 }
 } catch (err: any) {
 console.error('Error fetching blog:', err);
 setError(err.response?.data?.message || 'Blog not found.');
 } finally {
 setLoading(false);
 }
 };

 if (slug) fetchBlog();
 }, [slug]);

 // Format date
 const formatDate = (dateString?: string) => {
 if (!dateString) return 'N/A';
 const date = new Date(dateString);
 return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
 };

 return (
 <div className="pt-32 pb-20 bg-white min-h-screen">
 <div className="container-custom max-w-4xl">
 <Link
 to="/blogs"
 className="inline-flex items-center gap-2 text-slate-500 hover:text-brand-primary text-xs uppercase tracking-widest mb-8 transition-colors"
 >
 <ArrowLeft size={14} />
 Back to Blogs
 </Link>

 {loading ? (
 <div className="flex flex-col items-center justify-center py-20">
 <Loader2 size={48} className="animate-spin text-brand-primary mb-4"/>
 <p className="text-slate-500">Loading blog...</p>
 </div>
 ) : error ? (
 <div className="flex flex-col items-center justify-center py-20 bg-red-50 rounded-3xl border border-red-100">
 <AlertCircle size={48} className="text-red-500 mb-4"/>
 <p className="text-red-600 mb-2">Error loading blog</p>
 <p className="text-slate-500 text-sm">{error}</p>
 </div>
 ) : blog ? (
 <motion.article
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 >
 <div className="relative h-[320px] md:h-[420px] rounded-3xl overflow-hidden mb-8">
 <SmartImage
 src={blog.featuredImage || ''}
 alt={blog.title}
 className="w-full h-full object-cover"
 />
 <div className="absolute top-4 left-4">
 <span className="bg-brand-primary text-white text-[10px] uppercase tracking-widest px-3 py-1.5 rounded-full shadow-lg">
 {blog.category}
 </span>
 </div>
 </div>

 <div className="flex items-center gap-2 text-slate-400 text-xs uppercase tracking-widest mb-4">
 <Calendar size={16} className="text-brand-primary"/>
 {formatDate(blog.publishedAt || blog.createdAt)}
 </div>

 <h1 className="text-3xl md:text-5xl text-slate-900 tracking-tight leading-[1.1] mb-8">
 {blog.title}
 </h1>

 <div className="prose prose-slate max-w-none border-t border-slate-100 pt-8">
 {blog.excerpt && (
 <p className="text-slate-600 leading-relaxed text-lg font-medium mb-4">
 {blog.excerpt}
 </p>
 )}
 <div className="text-slate-500 leading-relaxed whitespace-pre-wrap">
 {blog.content || 'No detailed content available.'}
 </div>
 </div>
 </motion.article>
 ) : null}
 </div>
 </div>
 );
};
