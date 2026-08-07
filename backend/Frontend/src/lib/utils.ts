import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
 return twMerge(clsx(inputs));
}

/**
 * Converts an image path/URL to a fully-qualified, safe URL.
 *
 * Handles three cases:
 * 1. Relative path (/uploads/sports/foo.jpg) → prefixes with API origin
 * 2. Stale localhost URL (http://localhost:5050/...) → rewrites to production API origin
 * 3. Already a valid absolute URL or base64 → returned as-is
 */
export function getImageUrl(path: string | null | undefined): string {
 if (!path) return '';
 if (path.startsWith('data:')) return path;

 // Derive the production API origin from the env var (strip /api suffix)
 const apiOrigin = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api')
 .replace(/\/api$/, '')
 .replace(/\/$/, '');

 // Rewrite stale localhost URLs that were saved before API_BASE_URL was configured
 if (path.startsWith('http://localhost') || path.startsWith('https://localhost')) {
 // Extract the path portion after the origin (e.g. /uploads/sports/foo.jpg)
 try {
 const url = new URL(path);
 return `${apiOrigin}${url.pathname}`;
 } catch {
 return path;
 }
 }

 // Relative path — prefix with API origin
 if (!path.startsWith('http')) {
 return `${apiOrigin}${path}`;
 }

 // Already a full non-localhost URL
 return path;
}

