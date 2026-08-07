/**
 * Authentication Service
 * Handles API calls for authentication
 */

import { fetchWithAuth } from '../lib/fetchWithAuth';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export interface LoginResponse {
 success: boolean;
 message: string;
 data: {
 user: {
 id: string;
 name: string;
 email: string;
 role: 'ADMIN' | 'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY';
 phone_number?: string;
 needsPhone?: boolean;
 permissions?: string[];
 createdAt: string;
 updatedAt: string;
 };
 accessToken: string;
 refreshToken: string;
 };
 // top-level user alias for convenience
 user?: LoginResponse['data']['user'];
}

export interface RegisterData {
 name: string;
 email: string;
 password: string;
 phone_number: string; // WhatsApp number — required for new signups
}

export interface LoginData {
 // Either an email address OR a WhatsApp number, plus password.
 identifier: string;
 password: string;
}

export interface GoogleLoginData {
  credential: string;
}

export interface UpdateProfileData {
 name?: string;
 phone_number?: string;
 dob?: string;
 gender?: string;
 blood_group?: string;
}

class AuthService {
 async login(data: LoginData): Promise<LoginResponse> {
 try {
 const response = await fetch(`${API_BASE_URL}/auth/login`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 credentials: 'include',
 // portal 'main' tells the backend this is the public website, so administrator
 // accounts (ADMIN / COMPLEX_ADMIN) are rejected here — they use the admin portal.
 body: JSON.stringify({ ...data, portal: 'main' }),
 });

 const result = await response.json();
 if (!response.ok) throw new Error(result.message || 'Login failed');

 // Store tokens for cross-origin Bearer auth
 if (result.data?.accessToken) {
 localStorage.setItem('accessToken', result.data.accessToken);
 localStorage.setItem('refreshToken', result.data.refreshToken);
 }

 return { ...result, user: result.data?.user };
 } catch (error) {
 throw new Error(error instanceof Error ? error.message : 'Login failed');
 }
 }

 async googleLogin(data: GoogleLoginData): Promise<LoginResponse> {
  try {
    const response = await fetch(`${API_BASE_URL}/auth/google-login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      // Public website → administrators are not allowed to sign in here.
      body: JSON.stringify({ ...data, portal: 'main' }),
    });

    const result = await response.json();
    if (!response.ok) throw new Error(result.message || 'Google login failed');

    // Store tokens for cross-origin Bearer auth
    if (result.data?.accessToken) {
      localStorage.setItem('accessToken', result.data.accessToken);
      localStorage.setItem('refreshToken', result.data.refreshToken);
    }

    return { ...result, user: result.data?.user };
  } catch (error) {
    throw new Error(error instanceof Error ? error.message : 'Google login failed');
  }
}

 async register(data: RegisterData): Promise<LoginResponse> {
 try {
 const response = await fetch(`${API_BASE_URL}/auth/register`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 credentials: 'include',
 body: JSON.stringify(data),
 });

 const result = await response.json();
 if (!response.ok) throw new Error(result.message || 'Registration failed');

 // Store tokens for cross-origin Bearer auth
 if (result.data?.accessToken) {
 localStorage.setItem('accessToken', result.data.accessToken);
 localStorage.setItem('refreshToken', result.data.refreshToken);
 }

 return { ...result, user: result.data?.user };
 } catch (error) {
 throw new Error(error instanceof Error ? error.message : 'Registration failed');
 }
 }

 async logout(): Promise<void> {
   const refreshToken = localStorage.getItem('refreshToken');
   const url = `${API_BASE_URL}/auth/logout`;

   try {
     /**
      * IMPORTANT:
      * - Do NOT attach Authorization here. Some backends / CORS setups fail logout preflight
      *   when custom headers are present, which prevents cookie clearing.
      * - Always send credentials so the server can clear httpOnly cookies.
      */
     await fetch(url, {
       method: 'POST',
       headers: { 'Content-Type': 'application/json' },
       credentials: 'include',
       body: JSON.stringify(refreshToken ? { refreshToken } : {}),
     });
   } catch (error) {
     console.error('Logout error:', error);
     // Still proceed with local cleanup
   } finally {
     localStorage.removeItem('accessToken');
     localStorage.removeItem('refreshToken');
     localStorage.removeItem('user_permissions');
   }
 }

 async getProfile(): Promise<LoginResponse['user'] | null> {
 try {
 const response = await fetchWithAuth(`${API_BASE_URL}/auth/profile`);
 if (!response.ok) return null;
 const result = await response.json();
 return result.user;
 } catch (error) {
 console.error('Get profile error:', error);
 return null;
 }
 }

 // Update the current user's own profile (name, phone, dob, gender, blood group)
 async updateProfile(data: UpdateProfileData): Promise<{ success: boolean; message: string; user?: any }> {
 const response = await fetchWithAuth(`${API_BASE_URL}/auth/profile`, {
 method: 'PUT',
 body: JSON.stringify(data),
 });
 const result = await response.json();
 if (!response.ok) throw new Error(result.message || 'Failed to update profile');
 return result;
 }

 // Change the current user's password
 async changePassword(currentPassword: string, newPassword: string): Promise<{ success: boolean; message: string }> {
 const response = await fetchWithAuth(`${API_BASE_URL}/auth/change-password`, {
 method: 'PUT',
 body: JSON.stringify({ currentPassword, newPassword }),
 });
 const result = await response.json();
 if (!response.ok) throw new Error(result.message || 'Failed to change password');
 return result;
 }

 // Upload a new profile picture.
 // Uses a manual fetch (not fetchWithAuth) because FormData must NOT have a
 // JSON Content-Type — the browser sets the multipart boundary itself.
 async uploadProfilePicture(file: File): Promise<{ success: boolean; message: string; data?: { url: string } }> {
 const formData = new FormData();
 formData.append('profile_picture', file);

 const token = localStorage.getItem('accessToken');
 const headers: Record<string, string> = {};
 if (token) headers['Authorization'] = `Bearer ${token}`;

 const response = await fetch(`${API_BASE_URL}/auth/profile/picture`, {
 method: 'POST',
 headers,
 credentials: 'include',
 body: formData,
 });
 const result = await response.json();
 if (!response.ok) throw new Error(result.message || 'Failed to upload profile picture');
 return result;
 }

 // Role-based redirection URLs
 getDashboardUrl(role: string): string {
 console.log('🎡 getDashboardUrl called with role:', role);
 const adminPanelUrl = import.meta.env.VITE_ADMIN_PANEL_URL || 'http://localhost:5173';

 let dashboardUrl;
 switch (role.toUpperCase()) {
 case 'ADMIN':
 dashboardUrl = `${adminPanelUrl}/`;
 break;
 case 'USER':
 dashboardUrl = '/dashboard';
 break;
 case 'EMPLOYEE':
 dashboardUrl = `${adminPanelUrl}/employee-dashboard`;
 break;
 case 'COACH':
 dashboardUrl = `${adminPanelUrl}/coach-dashboard`;
 break;
 case 'SECURITY':
 dashboardUrl = `${adminPanelUrl}/security-dashboard`;
 break;
 default:
 dashboardUrl = '/dashboard';
 }

 console.log('🎯 getDashboardUrl returning:', dashboardUrl);
 return dashboardUrl;
 }

 // Check if user is authenticated
 async isAuthenticated(): Promise<boolean> {
 const user = await this.getProfile();
 return user !== null;
 }

 // Send forgot-password email
 async forgotPassword(email: string): Promise<{ success: boolean; message: string }> {
 try {
 const response = await fetch(`${API_BASE_URL}/auth/forgot-password`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({ email }),
 });
 const result = await response.json();
 // Backend always returns 200 to prevent user enumeration
 return { success: true, message: result.message || 'If an account with that email exists, a password reset link has been sent.' };
 } catch (error) {
 throw new Error(error instanceof Error ? error.message : 'Failed to send reset email');
 }
 }

 // Reset password using token from email link
 async resetPassword(token: string, newPassword: string): Promise<{ success: boolean; message: string }> {
 try {
 const response = await fetch(`${API_BASE_URL}/auth/reset-password`, {
 method: 'POST',
 headers: { 'Content-Type': 'application/json' },
 body: JSON.stringify({ token, newPassword }),
 });
 const result = await response.json();
 if (!response.ok) throw new Error(result.message || 'Password reset failed');
 return { success: true, message: result.message || 'Password reset successfully' };
 } catch (error) {
 throw new Error(error instanceof Error ? error.message : 'Password reset failed');
 }
 }
}

export const authService = new AuthService();

