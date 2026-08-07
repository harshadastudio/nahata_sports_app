import axios from 'axios';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export interface Blog {
 id: number;
 title: string;
 slug: string;
 content: string;
 excerpt?: string;
 category: string;
 tags?: string[];
 featuredImage?: string;
 authorId: number;
 status: 'draft' | 'published' | 'archived';
 publishedAt?: string;
 views: number;
 likes: number;
 metaTitle?: string;
 metaDescription?: string;
 metaKeywords?: string;
 createdAt: string;
 updatedAt: string;
 author?: {
 id: number;
 name: string;
 email: string;
 };
}

export interface BlogFilters {
 status?: string;
 category?: string;
 search?: string;
 page?: number;
 limit?: number;
}

export interface BlogResponse {
 success: boolean;
 data: Blog[];
 pagination: {
 currentPage: number;
 totalPages: number;
 totalCount: number;
 };
}

class BlogAPI {
 // Get all published blogs (for public frontend)
 async getPublishedBlogs(filters?: BlogFilters): Promise<BlogResponse> {
 const response = await axios.get(`${API_BASE_URL}/blogs`, {
 params: {
 ...filters,
 status: 'published', // Only fetch published blogs for public site
 },
 });
 return response.data;
 }

 // Get blog by slug
 async getBlogBySlug(slug: string): Promise<{ success: boolean; data: Blog }> {
 const response = await axios.get(`${API_BASE_URL}/blogs/slug/${slug}`);
 return response.data;
 }

 // Get popular blogs
 async getPopularBlogs(limit: number = 5): Promise<{ success: boolean; data: Blog[] }> {
 const response = await axios.get(`${API_BASE_URL}/blogs/popular`, {
 params: { limit },
 });
 return response.data;
 }

 // Get recent blogs
 async getRecentBlogs(limit: number = 5): Promise<{ success: boolean; data: Blog[] }> {
 const response = await axios.get(`${API_BASE_URL}/blogs/recent`, {
 params: { limit },
 });
 return response.data;
 }

 // Increment blog views
 async incrementViews(id: number): Promise<{ success: boolean; data: Blog }> {
 const response = await axios.post(`${API_BASE_URL}/blogs/${id}/views`);
 return response.data;
 }

 // Increment blog likes
 async incrementLikes(id: number): Promise<{ success: boolean; data: Blog }> {
 const response = await axios.post(`${API_BASE_URL}/blogs/${id}/likes`);
 return response.data;
 }
}

export default new BlogAPI();

