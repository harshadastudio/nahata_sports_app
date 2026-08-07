/**
 * Contact Us Service
 * Handles API calls for the contact form submission and contact information.
 */

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export interface ContactFormData {
 fullName: string;
 email: string;
 sportComplexId: number | '';
 subject: string;
 message: string;
}

export interface ContactFormResponse {
 success: boolean;
 message: string;
 data?: {
 referenceNumber: string;
 };
}

export interface ContactFormError {
 success: false;
 message: string;
 errors?: Array<{ field: string; message: string }>;
}

export interface ContactInfo {
 id: string;
 image?: string;
 address: string;
 phone: string;
 email: string;
 hours: string;
 description?: string;
 mapEmbedUrl: string | null;
 isActive: boolean;
 createdAt: string;
 updatedAt: string;
}

export interface ContactInfoResponse {
 success: boolean;
 data: {
 contactInfo: ContactInfo;
 };
}

class ContactService {
 async submitContactForm(data: ContactFormData): Promise<ContactFormResponse> {
 const response = await fetch(`${API_BASE_URL}/contact-us`, {
 method: 'POST',
 headers: {
 'Content-Type': 'application/json',
 },
 body: JSON.stringify(data),
 });

 const result = await response.json();

 if (!response.ok) {
 // Throw the full error payload so the caller can handle field-level errors
 throw result as ContactFormError;
 }

 return result as ContactFormResponse;
 }

 async getContactInfo(): Promise<ContactInfoResponse> {
 const response = await fetch(`${API_BASE_URL}/contact-us/info`, {
 method: 'GET',
 headers: {
 'Content-Type': 'application/json',
 },
 });

 const result = await response.json();

 if (!response.ok) {
 throw new Error(result.message || 'Failed to fetch contact information');
 }

 return result as ContactInfoResponse;
 }
}

export const contactService = new ContactService();


