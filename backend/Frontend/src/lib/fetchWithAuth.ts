/**
 * Authenticated fetch helper.
 * Reads the accessToken from localStorage and attaches it as a Bearer token.
 * On a 401 response, attempts a silent token refresh using the stored
 * refreshToken, then retries the original request once.
 * Falls back to credentials: 'include' for same-origin cookie-based auth.
 * Automatically handles token expiration by logging out the user.
 */
const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

let isRefreshing = false;
let refreshQueue: Array<(token: string | null) => void> = [];
// Prevent multiple simultaneous redirect-to-login calls
let isRedirecting = false;

function notifyQueue(token: string | null) {
  refreshQueue.forEach((cb) => cb(token));
  refreshQueue = [];
}

async function tryRefreshToken(): Promise<string | null> {
  // If a refresh is already in flight, queue up and wait for it
  if (isRefreshing) {
    return new Promise((resolve) => {
      refreshQueue.push(resolve);
    });
  }

  isRefreshing = true;
  try {
    const refreshToken = localStorage.getItem('refreshToken');
    if (!refreshToken) {
      notifyQueue(null);
      return null;
    }

    const res = await fetch(`${API_BASE}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ refreshToken }),
    });

    if (!res.ok) {
      // Refresh failed — clear tokens
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      notifyQueue(null);
      return null;
    }

    const data = await res.json();
    const newAccessToken: string = data.data?.accessToken ?? data.accessToken;
    const newRefreshToken: string = data.data?.refreshToken ?? data.refreshToken;

    if (newAccessToken) {
      localStorage.setItem('accessToken', newAccessToken);
      if (newRefreshToken) localStorage.setItem('refreshToken', newRefreshToken);
      notifyQueue(newAccessToken);
      return newAccessToken;
    }

    notifyQueue(null);
    return null;
  } catch {
    notifyQueue(null);
    return null;
  } finally {
    isRefreshing = false;
  }
}

export async function fetchWithAuth(url: string, options: RequestInit = {}): Promise<Response> {
  const token = localStorage.getItem('accessToken');

  const buildHeaders = (t: string | null) => {
    const headers = new Headers(options.headers);
    headers.set('Content-Type', headers.get('Content-Type') || 'application/json');
    if (t) headers.set('Authorization', `Bearer ${t}`);
    return headers;
  };

  // First attempt
  const res = await fetch(url, {
    ...options,
    headers: buildHeaders(token),
    credentials: 'include',
  });

  // If not 401, return as-is
  if (res.status !== 401) return res;

  // Try to refresh the token silently
  const newToken = await tryRefreshToken();

  if (!newToken) {
    // Only redirect to login if we're inside a dashboard route,
    // never from public pages — prevents infinite reload loops.
    if (
      typeof window !== 'undefined' &&
      !isRedirecting &&
      window.location.pathname.startsWith('/dashboard')
    ) {
      isRedirecting = true;
      // Clear any stale auth state before redirecting
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('user_permissions');
      window.location.href = '/';
    }
    return res; // return original 401 response
  }

  // Reset redirect guard on successful refresh
  isRedirecting = false;

  // Retry the original request with the new token
  return fetch(url, {
    ...options,
    headers: buildHeaders(newToken),
    credentials: 'include',
  });
}

