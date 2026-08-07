/**
 * Authentication Context for Frontend
 * Manages user authentication state and provides auth methods
 */

import React, { createContext, useContext, useState, useEffect } from 'react';
import { authService } from '../services/authService';

interface User {
 id: string;
 name: string;
 email: string;
 role: 'ADMIN' | 'USER' | 'EMPLOYEE' | 'COACH' | 'SECURITY';
 status?: 'Active' | 'Blocked';
 phone_number?: string;
 needsPhone?: boolean;
 permissions?: string[];
 createdAt: string;
 updatedAt: string;
}

interface AuthContextType {
 user: User | null;
 isLoading: boolean;
 // identifier = email OR WhatsApp number. Returns the signed-in user.
 login: (identifier: string, password: string) => Promise<User | null>;
 googleLogin: (credential: string) => Promise<User | null>;
 logout: () => Promise<void>;
 isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Administrator roles are NOT allowed to sign in on the public website — they
// must use the separate Admin Portal.
const isAdminRole = (role?: string): boolean =>
 ['ADMIN', 'COMPLEX_ADMIN'].includes(String(role || '').toUpperCase());
const ADMIN_ONLY_MESSAGE =
 'Administrator accounts must log in through the Nahata Sports Admin Portal.';
const clearStoredTokens = () => {
 try {
 localStorage.removeItem('accessToken');
 localStorage.removeItem('refreshToken');
 } catch (_e) { /* localStorage unavailable */ }
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
 const [user, setUser] = useState<User | null>(null);
 const [isLoading, setIsLoading] = useState(true);

 useEffect(() => {
 const initializeAuth = async () => {
 try {
 // No stored access token → the visitor is anonymous. Skip the profile
 // fetch entirely; calling it without a token guarantees a 401 on every
 // public page load (and clutters the console/network for guests).
 if (!localStorage.getItem('accessToken')) {
 return;
 }
 // Fetch the profile once. A non-null profile means the user is authenticated,
 // so there's no need for a separate isAuthenticated() call — that fired a
 // second identical /auth/profile request, doubling the cold-connection cost
 // on every app load.
 const profile = await authService.getProfile();
 if (profile) {
 // Never keep an administrator signed in on the public website.
 if (isAdminRole(profile.role)) {
 clearStoredTokens();
 } else {
 setUser(profile);
 }
 }
 } catch (error) {
 console.error('Auth initialization error:', error);
 } finally {
 setIsLoading(false);
 }
 };

 initializeAuth();
 }, []);

 const login = async (identifier: string, password: string): Promise<User | null> => {
 setIsLoading(true);
 try {
 const result = await authService.login({ identifier, password });
 if (result.success) {
 const u = result.user ?? null;
 // Safety net: the backend already blocks admins on the website, but never
 // establish an admin session here even if one slips through.
 if (u && isAdminRole(u.role)) {
 clearStoredTokens();
 throw new Error(ADMIN_ONLY_MESSAGE);
 }
 setUser(u);
 return u;
 }
 return null;
 } catch (error) {
 console.error('Login error:', error);
 throw error;
 } finally {
 setIsLoading(false);
 }
 };

 const googleLogin = async (credential: string): Promise<User | null> => {
  setIsLoading(true);
  try {
    const result = await authService.googleLogin({ credential });
    if (result.success) {
      const u = result.user ?? null;
      // Administrators may not sign in on the public website (see login()).
      if (u && isAdminRole(u.role)) {
        clearStoredTokens();
        throw new Error(ADMIN_ONLY_MESSAGE);
      }
      setUser(u);
      return u;
    }
    return null;
  } catch (error) {
    console.error('Google login error:', error);
    throw error;
  } finally {
    setIsLoading(false);
  }
};

 const logout = async () => {
 setIsLoading(true);
 try {
 await authService.logout();
 setUser(null);
 } catch (error) {
 console.error('Logout error:', error);
 setUser(null);
 } finally {
 setIsLoading(false);
 }
 };

 const isAuthenticated = !!user;
 
 // Debug logging for auth state
 console.log('🔍 Auth State Debug:', {
 user: user ? { id: user.id, name: user.name, email: user.email, role: user.role } : null,
 isAuthenticated,
 isLoading
 });

 return (
 <AuthContext.Provider value={{
 user,
 isLoading,
 login,
 googleLogin,
 logout,
 isAuthenticated
 }}>
 {children}
 </AuthContext.Provider>
 );
};

export const useAuth = () => {
 const context = useContext(AuthContext);
 if (context === undefined) {
 throw new Error('useAuth must be used within an AuthProvider');
 }
 return context;
};

