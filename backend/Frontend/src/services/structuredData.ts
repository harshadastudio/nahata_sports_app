/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Centralised JSON-LD structured-data builders for the public site.
 *
 * Each builder returns a plain object that is serialised into a
 * <script type="application/ld+json"> tag by the <Seo> component. Keeping
 * them here (rather than inline in pages) means the NAP — name, address,
 * phone — and the canonical site URL live in exactly one place.
 */

// Public-facing site origin. Overridable per-environment; defaults to the
// production domain (matches the info@nahatasports.com / api.nahatasports.com
// domain) so canonical URLs and schema @id values are stable in prod builds.
export const SITE_URL = (
  import.meta.env.VITE_SITE_URL || 'https://nahatasports.com'
).replace(/\/$/, '');

// Single source of truth for the business NAP used across LocalBusiness,
// Organization and SportsActivityLocation schema.
export const BUSINESS = {
  name: 'Nahata Sports',
  legalName: 'Nahata Sports Complex',
  description:
    "Pune's premier sports complex offering badminton courts, cricket nets, " +
    'basketball, yoga, dance, coaching programs, tournaments and online court booking.',
  url: SITE_URL,
  logo: `${SITE_URL}/nahata_logo.png`,
  telephone: '+91 98765 43210',
  email: 'info@nahatasports.com',
  streetAddress: 'Sinhagad Road, Near Pu La Deshpande Garden',
  addressLocality: 'Pune',
  addressRegion: 'Maharashtra',
  postalCode: '411030',
  addressCountry: 'IN',
  latitude: 18.4894,
  longitude: 73.8447,
  openingHours: 'Mo-Su 06:00-23:00',
  priceRange: '₹₹',
  sameAs: [] as string[], // populated from CMS social links if/when available
};

const postalAddress = {
  '@type': 'PostalAddress',
  streetAddress: BUSINESS.streetAddress,
  addressLocality: BUSINESS.addressLocality,
  addressRegion: BUSINESS.addressRegion,
  postalCode: BUSINESS.postalCode,
  addressCountry: BUSINESS.addressCountry,
};

const geo = {
  '@type': 'GeoCoordinates',
  latitude: BUSINESS.latitude,
  longitude: BUSINESS.longitude,
};

/** Organization schema — company-level identity for the brand. */
export function organizationSchema() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    '@id': `${SITE_URL}/#organization`,
    name: BUSINESS.name,
    legalName: BUSINESS.legalName,
    url: BUSINESS.url,
    logo: BUSINESS.logo,
    email: BUSINESS.email,
    telephone: BUSINESS.telephone,
    address: postalAddress,
    ...(BUSINESS.sameAs.length ? { sameAs: BUSINESS.sameAs } : {}),
  };
}

/** LocalBusiness schema — physical location, hours, contact. */
export function localBusinessSchema() {
  return {
    '@context': 'https://schema.org',
    '@type': 'LocalBusiness',
    '@id': `${SITE_URL}/#localbusiness`,
    name: BUSINESS.legalName,
    description: BUSINESS.description,
    url: BUSINESS.url,
    logo: BUSINESS.logo,
    image: BUSINESS.logo,
    telephone: BUSINESS.telephone,
    email: BUSINESS.email,
    priceRange: BUSINESS.priceRange,
    address: postalAddress,
    geo,
    openingHours: BUSINESS.openingHours,
    ...(BUSINESS.sameAs.length ? { sameAs: BUSINESS.sameAs } : {}),
  };
}

/**
 * SportsActivityLocation schema — the sports-venue specialisation Google uses
 * for facilities offering bookable sports activities.
 */
export function sportsActivityLocationSchema() {
  return {
    '@context': 'https://schema.org',
    '@type': 'SportsActivityLocation',
    '@id': `${SITE_URL}/#sportsactivitylocation`,
    name: BUSINESS.legalName,
    description: BUSINESS.description,
    url: BUSINESS.url,
    logo: BUSINESS.logo,
    image: BUSINESS.logo,
    telephone: BUSINESS.telephone,
    email: BUSINESS.email,
    priceRange: BUSINESS.priceRange,
    address: postalAddress,
    geo,
    openingHours: BUSINESS.openingHours,
    sport: ['Badminton', 'Cricket', 'Basketball', 'Yoga', 'Dance', 'Gymnastics'],
  };
}

export interface FaqItem {
  question: string;
  answer: string;
}

/** FAQPage schema from a list of Q&A pairs. */
export function faqSchema(faqs: FaqItem[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((f) => ({
      '@type': 'Question',
      name: f.question,
      acceptedAnswer: { '@type': 'Answer', text: f.answer },
    })),
  };
}

export interface BreadcrumbItem {
  /** Visible label, e.g. "About Us". */
  name: string;
  /** Site-relative path, e.g. "/about". Omit/empty for the current page leaf. */
  path?: string;
}

/**
 * BreadcrumbList schema. The first crumb is always Home; pass the trailing
 * crumbs (e.g. [{ name: 'About Us', path: '/about' }]).
 */
export function breadcrumbSchema(trail: BreadcrumbItem[]) {
  const items: BreadcrumbItem[] = [{ name: 'Home', path: '/' }, ...trail];
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: item.name,
      ...(item.path ? { item: `${SITE_URL}${item.path}` } : {}),
    })),
  };
}

/** Course schema for a coaching program offered by the academy. */
export function courseSchema(course: {
  name: string;
  description: string;
  url?: string;
}) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Course',
    name: course.name,
    description: course.description,
    ...(course.url ? { url: `${SITE_URL}${course.url}` } : {}),
    provider: {
      '@type': 'Organization',
      name: BUSINESS.legalName,
      sameAs: BUSINESS.url,
    },
  };
}

/** Event schema for a single sports event/tournament. */
export function eventSchema(event: {
  name: string;
  description?: string;
  startDate?: string;
  endDate?: string;
  url?: string;
  image?: string;
}) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Event',
    name: event.name,
    ...(event.description ? { description: event.description } : {}),
    ...(event.startDate ? { startDate: event.startDate } : {}),
    ...(event.endDate ? { endDate: event.endDate } : {}),
    ...(event.image ? { image: event.image } : {}),
    ...(event.url ? { url: `${SITE_URL}${event.url}` } : {}),
    eventAttendanceMode: 'https://schema.org/OfflineEventAttendanceMode',
    location: {
      '@type': 'Place',
      name: BUSINESS.legalName,
      address: postalAddress,
    },
    organizer: {
      '@type': 'Organization',
      name: BUSINESS.legalName,
      url: BUSINESS.url,
    },
  };
}

/** Blog schema for the blog listing page. */
export function blogSchema() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Blog',
    '@id': `${SITE_URL}/blogs#blog`,
    name: 'Nahata Sports Blog',
    description:
      'Sports blogs, fitness tips, training guides, nutrition advice and ' +
      'coaching insights from Nahata Sports experts.',
    url: `${SITE_URL}/blogs`,
    publisher: {
      '@type': 'Organization',
      name: BUSINESS.legalName,
      logo: { '@type': 'ImageObject', url: BUSINESS.logo },
    },
  };
}

// Canonical home-page FAQs, mirrored from the FAQ section's static fallback so
// the FAQPage schema renders rich results even before the /faqs API responds.
export const HOME_FAQS: FaqItem[] = [
  {
    question: 'Where is Nahata Sports located?',
    answer:
      'Nahata Sports Complex is located on Sinhagad Road, near Wadgaon Budruk, Pune — easily accessible from Narhe, Katraj, and Dhayari areas. We also have a second centre at Gangadham Chowk.',
  },
  {
    question: 'What are your operating hours?',
    answer:
      'We are open from 6:00 AM to 11:00 PM daily, including weekends and public holidays (subject to holiday schedule).',
  },
  {
    question: 'How do I book a court or turf?',
    answer:
      'You can book directly from our website — click "Book a Court", select your sport, court, date, and time slot, then pay securely online. You receive an instant QR entry pass.',
  },
  {
    question: 'Do you offer professional coaching?',
    answer:
      'Yes! We have certified coaches for Cricket, Basketball, Badminton, Skating, Karate, Fun Fitness, and Dance & Zumba for all age groups.',
  },
  {
    question: 'Can I cancel or reschedule my booking?',
    answer:
      'Cancellations made 24 hours before the slot are eligible for a full refund or credit. Please refer to our Cancellation Policy for complete details.',
  },
];

// Coaching programs offered, surfaced as Course schema on the coaching page.
const COACHING_COURSES = [
  { name: 'Badminton Coaching', description: 'Professional badminton coaching in Pune for all ages and skill levels.' },
  { name: 'Cricket Coaching', description: 'Cricket coaching with indoor nets and certified coaches in Pune.' },
  { name: 'Basketball Coaching', description: 'Basketball coaching and skill development programs in Pune.' },
  { name: 'Dance & Zumba', description: 'Dance and Zumba classes for fitness and fun at Nahata Sports, Pune.' },
  { name: 'Yoga', description: 'Yoga classes for flexibility, strength and wellbeing in Pune.' },
  { name: 'Gymnastics', description: 'Gymnastics coaching for children and beginners in Pune.' },
];

/** All structured data for the home page. */
export function homePageSchemas() {
  return [
    organizationSchema(),
    localBusinessSchema(),
    sportsActivityLocationSchema(),
    faqSchema(HOME_FAQS),
    breadcrumbSchema([]),
  ];
}

/** All structured data for the coaching page. */
export function coachingPageSchemas() {
  return [
    sportsActivityLocationSchema(),
    ...COACHING_COURSES.map((c) => courseSchema({ ...c, url: '/coaching' })),
    breadcrumbSchema([{ name: 'Sports Coaching', path: '/coaching' }]),
  ];
}

/** All structured data for the about page. */
export function aboutPageSchemas() {
  return [
    organizationSchema(),
    localBusinessSchema(),
    breadcrumbSchema([{ name: 'About Us', path: '/about' }]),
  ];
}

/** All structured data for the events page. */
export function eventsPageSchemas() {
  return [breadcrumbSchema([{ name: 'Events', path: '/events' }])];
}

/** All structured data for the blogs page. */
export function blogsPageSchemas() {
  return [blogSchema(), breadcrumbSchema([{ name: 'Blogs', path: '/blogs' }])];
}

/** All structured data for the contact page. */
export function contactPageSchemas() {
  return [
    localBusinessSchema(),
    contactPageSchema(),
    breadcrumbSchema([{ name: 'Contact Us', path: '/contacts' }]),
  ];
}

/** ContactPage schema for the contact page. */
export function contactPageSchema() {
  return {
    '@context': 'https://schema.org',
    '@type': 'ContactPage',
    name: 'Contact Nahata Sports',
    url: `${SITE_URL}/contacts`,
    description:
      'Contact Nahata Sports for court booking, coaching enquiries, sports ' +
      'events and membership.',
    mainEntity: {
      '@type': 'Organization',
      name: BUSINESS.legalName,
      telephone: BUSINESS.telephone,
      email: BUSINESS.email,
      address: postalAddress,
    },
  };
}
