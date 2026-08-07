import React, { useEffect } from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';

/**
 * Guards all /dashboard/* routes.
 * - Loading: show spinner
 * - Not authenticated: redirect to /
 * - ADMIN role: redirect to localhost:5173 (admin panel)
 * - EMPLOYEE, COACH, SECURITY, USER roles: render child routes via <Outlet />
 */
export const ProtectedUserRoute: React.FC = () => {
 const { user, isAuthenticated, isLoading } = useAuth();

 // Handle ADMIN redirect with toast notification
 useEffect(() => {
 if (!isLoading && isAuthenticated && user?.role === 'ADMIN') {
 toast.error('Admin users should use the admin panel at localhost:5173', {
 duration: 5000,
 });
 }
 }, [isLoading, isAuthenticated, user?.role]);

 // Show loading spinner while authentication state is loading
 if (isLoading) {
 return (
 <div className="min-h-screen flex items-center justify-center bg-bg-main">
 <div className="flex flex-col items-center gap-4">
 <div className="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin"/>
 <p className="text-sm text-text-muted">Loading...</p>
 </div>
 </div>
 );
 }

 // Redirect unauthenticated users to home page
 if (!isAuthenticated || !user) {
 return <Navigate to="/"replace />;
 }

 // Redirect ADMIN users to admin panel
 if (user.role === 'ADMIN') {
 window.location.href = 'http://localhost:5173';
 return null;
 }

 // Allow operational roles: EMPLOYEE, COACH, SECURITY, USER
 const allowedRoles = ['EMPLOYEE', 'COACH', 'SECURITY', 'USER'];
 if (!allowedRoles.includes(user.role)) {
 return <Navigate to="/"replace />;
 }

 return <Outlet />;
};

export default ProtectedUserRoute;

