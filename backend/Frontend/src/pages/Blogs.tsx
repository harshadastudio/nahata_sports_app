/** @license
 * SPDX-License-Identifier: Apache-2.0
 */
import { motion } from 'motion/react';
import { Calendar, ChevronRight, List, Search, ArrowRight, Loader2, AlertCircle } from 'lucide-react';
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
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

// Extract unique categories from blogs
const extractCategories = (blogs: BlogPost[]): string[] => {
 const categories = blogs.map(blog => blog.category).filter(Boolean);
 const uniqueCategories = Array.from(new Set(categories));
 return ['All Categories', ...uniqueCategories];
};

export const BlogsPage = () => {
 const [blogs, setBlogs] = useState<BlogPost[]>([]);
 const [loading, setLoading] = useState(true);
 const [error, setError] = useState<string | null>(null);
 const [selectedCategory, setSelectedCategory] = useState('All Categories');
 const [searchQuery, setSearchQuery] = useState('');
 const [currentPage, setCurrentPage] = useState(1);
 const [totalPages, setTotalPages] = useState(1);
 const navigate = useNavigate();

 // Fetch blogs from API
 useEffect(() => {
 const fetchBlogs = async () => {
 try {
 setLoading(true);
 setError(null);
 
 const params = new URLSearchParams({
 page: currentPage.toString(),
 limit: '8',
 status: 'published', // Only fetch published blogs
 });

 if (selectedCategory !== 'All Categories') {
 params.append('category', selectedCategory);
 }

 if (searchQuery) {
 params.append('search', searchQuery);
 }

 const response = await axios.get(`${API_BASE_URL}/blogs?${params.toString()}`);
 
 if (response.data.success) {
 setBlogs(response.data.data || []);
 if (response.data.pagination) {
 setTotalPages(response.data.pagination.totalPages || 1);
 }
 } else {
 setError('Failed to load blogs');
 }
 } catch (err: any) {
 console.error('Error fetching blogs:', err);
 setError(err.response?.data?.message || 'Failed to load blogs. Please try again later.');
 } finally {
 setLoading(false);
 }
 };

 fetchBlogs();
 }, [currentPage, selectedCategory, searchQuery]);

 // Get categories from fetched blogs
 const categories = extractCategories(blogs);

 // Format date
 const formatDate = (dateString?: string) => {
 if (!dateString) return 'N/A';
 const date = new Date(dateString);
 return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
 };

 // Return the uploaded image URL, or '' when there is none (placeholder shows)
 const getImageUrl = (blog: BlogPost) => {
 return blog.featuredImage || '';
 };

 // Handle search with debounce
 const handleSearch = (value: string) => {
 setSearchQuery(value);
 setCurrentPage(1); // Reset to first page on search
 };

 const handleReadMore = (blog: BlogPost) => {
 navigate(`/blogs/${blog.slug || blog.id}`);
 };

 return (
 <div className="pt-32 pb-20 bg-white min-h-screen">
 <div className="container-custom">
 <div className="flex flex-col md:flex-row justify-between items-end mb-12 gap-6">
 <div>
 <motion.h1
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 className="text-5xl md:text-6xl text-slate-900 tracking-tight uppercase leading-[0.9]"
 >
 Our <span className="text-brand-primary">Blogs</span>
 </motion.h1>
 <div className="w-16 h-1.5 bg-brand-primary mt-2 rounded-full"></div>
 </div>
 <div className="relative w-full max-w-xs">
 <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400"size={18} />
 <input
 type="text"
 placeholder="Search blogs..."
 value={searchQuery}
 onChange={(e) => handleSearch(e.target.value)}
 className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-3 pl-12 pr-4 focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary transition-all text-sm"
 />
 </div>
 </div>

 <div className="grid lg:grid-cols-12 gap-12">
 {/* Blog Content List */}
 <div className="lg:col-span-8">
 {loading ? (
 <div className="flex flex-col items-center justify-center py-20">
 <Loader2 size={48} className="animate-spin text-brand-primary mb-4"/>
 <p className="text-slate-500">Loading blogs...</p>
 </div>
 ) : error ? (
 <div className="flex flex-col items-center justify-center py-20 bg-red-50 rounded-3xl border border-red-100">
 <AlertCircle size={48} className="text-red-500 mb-4"/>
 <p className="text-red-600 mb-2">Error loading blogs</p>
 <p className="text-slate-500 text-sm">{error}</p>
 </div>
 ) : blogs.length === 0 ? (
 <div className="flex flex-col items-center justify-center py-20 bg-slate-50 rounded-3xl border border-slate-100">
 <AlertCircle size={48} className="text-slate-400 mb-4"/>
 <p className="text-slate-600 mb-2">No blogs found</p>
 <p className="text-slate-500 text-sm">Try adjusting your filters or search query</p>
 </div>
 ) : (
 <>
 <div className="grid sm:grid-cols-2 gap-8">
 {blogs.map((post, i) => (
 <motion.article
 key={post.id}
 initial={{ opacity: 0, y: 20 }}
 animate={{ opacity: 1, y: 0 }}
 transition={{ delay: i * 0.1 }}
 className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden flex flex-col group hover:shadow-xl hover:-translate-y-1 transition-all duration-300"
 >
 <div className="relative h-56 overflow-hidden">
 <SmartImage
 src={getImageUrl(post)}
 alt={post.title}
 className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
 />
 <div className="absolute top-4 left-4">
 <span className="bg-brand-primary text-white text-[10px] uppercase tracking-widest px-3 py-1.5 rounded-full shadow-lg">
 {post.category?.split(' & ')[0] || 'General'}
 </span>
 </div>
 </div>
 <div className="p-6 flex flex-col flex-1">
 <div className="flex items-center gap-2 text-slate-400 text-[10px] uppercase tracking-widest mb-4">
 <Calendar size={14} className="text-brand-primary"/>
 {formatDate(post.publishedAt || post.createdAt)}
 </div>
 <h3 className="text-lg text-slate-900 leading-snug mb-4 group-hover:text-brand-primary transition-colors line-clamp-2">
 {post.title}
 </h3>
 <p className="text-slate-500 text-sm leading-relaxed mb-6 flex-1 line-clamp-3">
 {post.excerpt || post.content?.substring(0, 150) + '...' || 'No description available'}
 </p>
 <button
 onClick={() => handleReadMore(post)}
 className="w-full py-3 bg-brand-primary hover:bg-brand-dark text-white text-xs uppercase tracking-widest rounded-xl transition-all shadow-md shadow-brand-primary/10 flex items-center justify-center gap-2"
 >
 Read More
 <ArrowRight size={14} />
 </button>
 </div>
 </motion.article>
 ))}
 </div>

 {/* Pagination */}
 {totalPages > 1 && (
 <div className="mt-16 flex justify-center">
 <div className="flex gap-2">
 {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
 <button
 key={page}
 onClick={() => setCurrentPage(page)}
 className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${
 currentPage === page
 ? 'bg-slate-900 text-white'
 : 'bg-slate-100 text-slate-500 hover:bg-brand-secondary hover:text-brand-primary'
 }`}
 >
 {page}
 </button>
 ))}
 {currentPage < totalPages && (
 <button
 onClick={() => setCurrentPage(currentPage + 1)}
 className="w-10 h-10 rounded-xl bg-slate-100 text-slate-500 hover:bg-brand-secondary hover:text-brand-primary transition-all flex items-center justify-center text-sm"
 >
 <ChevronRight size={18} />
 </button>
 )}
 </div>
 </div>
 )}
 </>
 )}
 </div>

 {/* Sidebar Categories */}
 <div className="lg:col-span-4">
 <div className="sticky top-28 space-y-8">
 <div className="bg-slate-50 rounded-[2.5rem] p-8 border border-slate-100">
 <h4 className="flex items-center gap-3 text-xl text-slate-900 uppercase tracking-tight mb-8 pb-4 border-b border-slate-200">
 <List size={22} className="text-brand-primary"/>
 Categories
 </h4>
 <div className="space-y-2">
 {categories.map((cat) => (
 <button
 key={cat}
 onClick={() => {
 setSelectedCategory(cat);
 setCurrentPage(1); // Reset to first page on category change
 }}
 className={`w-full text-left px-4 py-3 rounded-xl text-xs uppercase tracking-wider transition-all flex items-center justify-between group ${
 selectedCategory === cat
 ? 'bg-brand-primary text-white shadow-lg'
 : 'text-slate-500 hover:bg-white hover:text-brand-primary'
 }`}
 >
 <span className="flex items-center gap-2">
 <ChevronRight
 size={14}
 className={
 selectedCategory === cat
 ? 'text-white'
 : 'text-brand-primary transition-transform group-hover:translate-x-1'
 }
 />
 {cat}
 </span>
 </button>
 ))}
 </div>
 </div>
 </div>
 </div>
 </div>
      </div>
    </div>
  );
};
