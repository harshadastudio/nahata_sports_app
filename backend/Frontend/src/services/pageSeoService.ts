/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */
import axios from 'axios';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

// The public pages with managed SEO. book/coaching/events/blogs/contact/about
// are editable from the admin CMS; home uses the static fallback below (the CMS
// has no row for it, so getPageSeo() falls back gracefully on a 404).
export type PageSeoKey = 'home' | 'book' | 'coaching' | 'events' | 'blogs' | 'contact' | 'about';

export interface PageSeo {
  pageKey: PageSeoKey;
  metaTitle?: string | null;
  metaDescription?: string | null;
  metaKeywords?: string | null;
}

// Sensible client-side fallbacks used only if the API is unreachable, so the
// page still renders a meaningful <title> instead of the generic index.html one.
export const SEO_FALLBACKS: Record<PageSeoKey, PageSeo> = {
  home: {
    pageKey: 'home',
    metaTitle: 'Sports Complex in Pune | Book Badminton, Cricket Nets & Coaching | Nahata Sports',
    metaDescription: "Nahata Sports is Pune's premier sports complex offering badminton courts, cricket nets, basketball, yoga, dance, coaching programs, tournaments and online court booking.",
    metaKeywords: 'Sports Complex Pune, Sports Academy Pune, Court Booking Pune, Badminton Court Pune, Cricket Nets Pune, Basketball Court Pune',
  },
  book: {
    pageKey: 'book',
    metaTitle: 'Book a Court Online in Pune | Nahata Sports Complex',
    metaDescription: 'Book badminton courts, cricket nets, basketball and turf online at Nahata Sports Complex, Pune. Check live slot availability, pick your time and pay securely.',
    metaKeywords: 'Court Booking Pune, Book Badminton Court Pune, Cricket Net Booking Pune, Turf Booking Pune, Online Sports Booking Pune',
  },
  coaching: {
    pageKey: 'coaching',
    metaTitle: 'Sports Coaching in Pune | Badminton, Cricket, Basketball | Nahata Sports',
    metaDescription: 'Join professional sports coaching in Pune. Learn badminton, cricket, basketball, dance, yoga and gymnastics with experienced coaches at Nahata Sports.',
    metaKeywords: 'Sports Coaching Pune, Badminton Coaching Pune, Basketball Coaching Pune, Cricket Coaching Pune',
  },
  events: {
    pageKey: 'events',
    metaTitle: 'Sports Events & Tournaments in Pune | Nahata Sports',
    metaDescription: 'Discover upcoming sports tournaments, competitions, workshops and community events at Nahata Sports Pune.',
    metaKeywords: 'Sports Events Pune, Tournament Pune, Sports Competition Pune',
  },
  blogs: {
    pageKey: 'blogs',
    metaTitle: 'Sports Blogs | Fitness Tips & Training Guides | Nahata Sports',
    metaDescription: 'Read sports blogs, fitness tips, training guides, nutrition advice and coaching insights from Nahata Sports experts.',
    metaKeywords: 'Sports Blog, Fitness Blog, Badminton Tips, Cricket Tips',
  },
  contact: {
    pageKey: 'contact',
    metaTitle: 'Contact Nahata Sports | Sports Complex Pune',
    metaDescription: 'Contact Nahata Sports for court booking, coaching enquiries, sports events and membership. Visit our Pune sports complex today.',
    metaKeywords: 'Nahata Sports Contact, Sports Complex Pune Contact, Court Booking Contact',
  },
  about: {
    pageKey: 'about',
    metaTitle: "About Nahata Sports | Pune's Leading Sports Complex",
    metaDescription: 'Learn about Nahata Sports, our world-class sports facilities, expert coaching, modern infrastructure and our mission to build future champions.',
    metaKeywords: 'about Nahata Sports, sports complex Pune, sports academy Pune',
  },
};

// Pages that actually have an editable row in the admin CMS. Only these are
// fetched from /page-seo/:key; the rest (home) have no backend row, so
// requesting them returns a 400 ("Invalid page key") — we skip the call and
// use the static fallback directly to avoid that console/network noise.
// Must stay in sync with VALID_PAGE_KEYS in the API's pageSeoController.
const CMS_MANAGED: ReadonlySet<PageSeoKey> = new Set<PageSeoKey>(['book', 'coaching', 'events', 'blogs', 'contact', 'about']);

// Short-lived in-memory cache so rapid re-visits within a session don't refetch.
// It is deliberately time-boxed: this is CMS-managed content, and a permanent
// cache meant an admin's edit could never reach a tab that had already loaded
// the page — the stale value was served for the rest of the session.
const CACHE_TTL_MS = 30_000;
const cache = new Map<PageSeoKey, { value: PageSeo; at: number }>();

export async function getPageSeo(pageKey: PageSeoKey): Promise<PageSeo> {
  const hit = cache.get(pageKey);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.value;
  // Pages with no CMS row resolve straight to their static fallback.
  if (!CMS_MANAGED.has(pageKey)) return SEO_FALLBACKS[pageKey];
  try {
    const res = await axios.get(`${API_BASE_URL}/page-seo/${pageKey}`);
    const data: PageSeo = res.data?.data ?? SEO_FALLBACKS[pageKey];
    // Merge so any empty/null field falls back to a sensible default.
    const merged: PageSeo = {
      pageKey,
      metaTitle: data.metaTitle || SEO_FALLBACKS[pageKey].metaTitle,
      metaDescription: data.metaDescription || SEO_FALLBACKS[pageKey].metaDescription,
      metaKeywords: data.metaKeywords || SEO_FALLBACKS[pageKey].metaKeywords,
    };
    cache.set(pageKey, { value: merged, at: Date.now() });
    return merged;
  } catch {
    return SEO_FALLBACKS[pageKey];
  }
}
