import React from 'react';
import { Navigate } from 'react-router-dom';
import { useUserPermissions } from '../hooks/useUserPermissions';
import { ShieldOff } from 'lucide-react';

interface PermissionGuardProps {
 permissionId?: string;
 /** Allow access if the user has ANY of these permissions (e.g. a page shared
  *  by two roles). Takes precedence over permissionId when provided. */
 anyOf?: string[];
 children: React.ReactNode;
 /** If true, shows an inline"Access Denied"message instead of redirecting */
 inline?: boolean;
}

/**
 * Wraps a dashboard page and blocks access if the required permission is missing.
 * Default: redirects to /dashboard.
 * With inline=true: renders an"Access Denied"card in place.
 */
export const PermissionGuard: React.FC<PermissionGuardProps> = ({
 permissionId,
 anyOf,
 children,
 inline = false,
}) => {
 const { hasPermission, isLoading } = useUserPermissions();

 const ids = anyOf && anyOf.length ? anyOf : permissionId ? [permissionId] : [];
 const allowed = ids.some((id) => hasPermission(id));

 // While permissions are still being fetched, don't bounce the user to the
 // dashboard — wait for the real permission set (prevents a false redirect on
 // first paint before the API/localStorage permissions have loaded).
 if (!allowed && isLoading) {
 return (
 <div className="flex items-center justify-center min-h-[60vh]">
 <div className="w-8 h-8 border-2 border-brand-primary border-t-transparent rounded-full animate-spin" />
 </div>
 );
 }

 if (!allowed) {
 if (inline) {
 return (
 <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
 <div className="w-16 h-16 bg-red-50 rounded-2xl flex items-center justify-center">
 <ShieldOff size={28} className="text-red-400"/>
 </div>
 <div className="text-center">
 <h2 className="text-lg text-text-dark">Access Denied</h2>
 <p className="text-sm text-text-muted mt-1">
 You don't have permission to view this module.
 </p>
 <p className="text-xs text-text-muted mt-1">
 Contact your admin to request access.
 </p>
 </div>
 </div>
 );
 }
 return <Navigate to="/dashboard"replace />;
 }

 return <>{children}</>;
};

export default PermissionGuard;

