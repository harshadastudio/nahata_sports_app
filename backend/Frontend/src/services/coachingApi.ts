/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import type { Sport, Coach, Batch, SportComplex } from '../types/coaching';

// coachingApi uses the base URL without /api since it appends /api/... paths itself
const _rawBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
const API_BASE_URL = _rawBase.endsWith('/api') ? _rawBase.slice(0, -4) : _rawBase;
const API_TIMEOUT = 30000; // 30 seconds

class CoachingApiService {
 private client: AxiosInstance;
 
 constructor() {
 this.client = axios.create({
 baseURL: API_BASE_URL,
 timeout: API_TIMEOUT,
 headers: {
 'Content-Type': 'application/json',
 },
 });
 
 // Response interceptor for error handling
 this.client.interceptors.response.use(
 (response) => response,
 (error: AxiosError) => this.handleError(error)
 );
 }
 
 // Sports API
 async getSports(ground?: string): Promise<Sport[]> {
 const params: any = {
 status: 'Active',
 showOnFrontend: 'true', // Only fetch sports shown on frontend
 limit: '100'
 };
 if (ground) {
 params.ground = ground;
 }
 
 console.log('🔍 [CoachingAPI] Fetching sports with params:', params);
 const response = await this.client.get('/api/sports', { params });
 console.log('✅ [CoachingAPI] Sports response:', response.data);
 
 // Handle response structure: { success, message, data: [...] }
 const data = response.data.data;
 console.log('📊 [CoachingAPI] Parsed sports data:', data);
 return Array.isArray(data) ? data : [];
 }
 
 // Coaches API
 async getCoaches(filters: {
 sportId?: number;
 ground?: string;
 status?: string;
 }): Promise<Coach[]> {
 console.log('🔍 [CoachingAPI] Fetching coaches with filters:', filters);
 const response = await this.client.get('/api/coaches', {
 params: {
 ...filters,
 status: filters.status || 'Active',
 }
 });
 console.log('✅ [CoachingAPI] Coaches response:', response.data);
 
 // Backend returns: { success: true, data: { coaches: [...], total, page, limit } }
 const responseData = response.data.data;
 
 // Handle nested structure - coaches are in data.coaches
 if (responseData && typeof responseData === 'object' && 'coaches' in responseData) {
 console.log('📊 [CoachingAPI] Parsed coaches (nested):', responseData.coaches);
 return Array.isArray(responseData.coaches) ? responseData.coaches : [];
 }
 
 // Fallback: if data is directly an array
 if (Array.isArray(responseData)) {
 console.log('📊 [CoachingAPI] Parsed coaches (direct array):', responseData);
 return responseData;
 }
 
 console.warn('⚠️ [CoachingAPI] No coaches found in response');
 return [];
 }
 
 // Batches API
 async getBatchesBySport(sportId: number, ground?: string): Promise<any[]> {
 const response = await this.client.get(`/api/batches/sport/${sportId}`, {
 params: ground ? { ground } : {},
 });
 const data = response.data.data || response.data;
 return Array.isArray(data) ? data : [];
 }

 // Sport Complexes API
 async getSportComplexes(): Promise<SportComplex[]> {
 console.log('🔍 [CoachingAPI] Fetching sport complexes...');
 const response = await this.client.get('/api/sports-complexes');
 console.log('✅ [CoachingAPI] Sport complexes response:', response.data);
 
 // Backend returns: { success: true, data: { sportsComplexes: [...], currentPage, totalPages, ... } }
 const responseData = response.data.data;
 console.log('📊 [CoachingAPI] Response data:', responseData);
 
 let data = [];
 if (responseData && typeof responseData === 'object') {
 // Check for sportsComplexes property (paginated response)
 if ('sportsComplexes' in responseData && Array.isArray(responseData.sportsComplexes)) {
 data = responseData.sportsComplexes;
 } 
 // Check if responseData itself is an array
 else if (Array.isArray(responseData)) {
 data = responseData;
 }
 }
 
 console.log('📊 [CoachingAPI] Parsed sport complexes:', data, 'Count:', data.length);
 return data;
 }
 
 // Error handler
 private handleError(error: AxiosError): Promise<never> {
 // Log detailed error for debugging
 console.error('[CoachingAPI Error]', {
 message: error.message,
 status: error.response?.status,
 data: error.response?.data,
 url: error.config?.url,
 });
 
 if (error.response) {
 // Server responded with error status
 const status = error.response.status;
 const message = (error.response.data as any)?.message || error.message;
 
 switch (status) {
 case 400:
 throw new Error(message || 'Invalid request. Please check your input and try again.');
 case 404:
 throw new Error('Resource not found. Please try again later.');
 case 500:
 throw new Error('Server error. Please try again later.');
 default:
 throw new Error(message || 'An error occurred. Please try again.');
 }
 } else if (error.request) {
 // Request made but no response
 throw new Error('Unable to connect to server. Please check your connection.');
 } else {
 // Error in request setup
 throw new Error(error.message || 'An unexpected error occurred.');
 }
 }
}

export const coachingApi = new CoachingApiService();

