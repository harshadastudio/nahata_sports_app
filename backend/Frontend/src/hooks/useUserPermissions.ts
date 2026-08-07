import { useState, useEffect, useRef } from 'react';
import { fetchWithAuth } from '../lib/fetchWithAuth';
import { useAuth } from '../contexts/AuthContext';

const STORAGE_KEY = 'user_permissions';
const _rawPermBase = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');
const API_BASE = _rawPermBase.endsWith('/api') ? _rawPermBase : `${_rawPermBase}/api`;
const FALLBACK_PERMISSIONS = ['user_dashboard', 'user_logout'];

/** How often (ms) to re-fetch permissions from the API while the user is logged in.
 *  This ensures admin permission changes are reflected without requiring re-login.
 *  Set to 30 seconds — adjust as needed. */
const POLL_INTERVAL_MS = 30_000;

interface UseUserPermissionsReturn {
  permissions: string[];
  hasPermission: (id: string) => boolean;
  isLoading: boolean;
  /** Call this to force an immediate re-fetch (e.g. after a role change). */
  refresh: () => void;
}

/**
 * Reads user permissions from the backend API (source of truth).
 *
 * Flow:
 *   1. Immediately render using localStorage cache so the sidebar doesn't flash.
 *   2. Always fetch fresh permissions from GET /api/permissions/:role on mount.
 *   3. Poll every POLL_INTERVAL_MS so admin changes are reflected in real time.
 *   4. Cache result in localStorage for offline resilience.
 */
export function useUserPermissions(): UseUserPermissionsReturn {
  const { user } = useAuth();

  // Initialise from localStorage so the sidebar renders immediately (no flash)
  const [permissions, setPermissions] = useState<string[]>(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return FALLBACK_PERMISSIONS;
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) && parsed.length > 0 ? parsed : FALLBACK_PERMISSIONS;
    } catch {
      return FALLBACK_PERMISSIONS;
    }
  });

  const [isLoading, setIsLoading] = useState(true);

  // Use a ref so the interval callback always has the latest `user` value
  const userRef = useRef(user);
  useEffect(() => {
    userRef.current = user;
  }, [user]);

  // Counter to trigger a manual refresh
  const [refreshTick, setRefreshTick] = useState(0);
  const refresh = () => setRefreshTick((t) => t + 1);

  // Fetch permissions from the API
  useEffect(() => {
    if (!user) {
      setIsLoading(false);
      return;
    }

    let cancelled = false;

    const fetchPermissions = async () => {
      try {
        // Map role to API endpoint format
        const roleParam = user.role === 'SECURITY' ? 'security_guard' : user.role.toLowerCase();

        const res = await fetchWithAuth(`${API_BASE}/permissions/${roleParam}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);

        const data = await res.json();

        if (data.success && Array.isArray(data.permissions) && !cancelled) {
          setPermissions(data.permissions);
          localStorage.setItem(STORAGE_KEY, JSON.stringify(data.permissions));
        }
      } catch (err) {
        console.warn('useUserPermissions: API unreachable, using localStorage cache:', err);
        // Already initialised from localStorage — nothing more to do
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    fetchPermissions();
    return () => {
      cancelled = true;
    };
    // refreshTick is intentionally included so manual refresh() calls re-fetch
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, refreshTick]);

  // Poll for permission changes so admin updates are reflected without re-login
  useEffect(() => {
    if (!user) return;

    const interval = setInterval(() => {
      setRefreshTick((t) => t + 1);
    }, POLL_INTERVAL_MS);

    return () => clearInterval(interval);
  }, [user]);

 // Also react to storage events (admin updates permissions in another tab on same origin)
 useEffect(() => {
    const handleStorage = (e: StorageEvent) => {
      if (e.key !== STORAGE_KEY) return;
      try {
        const parsed = e.newValue ? JSON.parse(e.newValue) : null;
        if (Array.isArray(parsed) && parsed.length > 0) {
          setPermissions(parsed);
        } else {
          setPermissions(FALLBACK_PERMISSIONS);
        }
      } catch {
        setPermissions(FALLBACK_PERMISSIONS);
      }
    };

    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

 const hasPermission = (id: string): boolean => permissions.includes(id);

  return { permissions, hasPermission, isLoading, refresh };
}

