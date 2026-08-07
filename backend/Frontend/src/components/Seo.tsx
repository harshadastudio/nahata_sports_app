/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */
import { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { getPageSeo, SEO_FALLBACKS, PageSeo as PageSeoData, PageSeoKey } from '../services/pageSeoService';
import { SITE_URL } from '../services/structuredData';

interface SeoProps {
  pageKey: PageSeoKey;
  /**
   * JSON-LD structured-data object(s) to inject for this page — e.g. the
   * Organization, LocalBusiness, FAQ or BreadcrumbList schema built via
   * ../services/structuredData. A single object or an array are both accepted.
   */
  structuredData?: object | object[];
  /**
   * Override the canonical URL path. Defaults to the current route's pathname,
   * which is correct for every static public page.
   */
  canonicalPath?: string;
}

/**
 * Injects CMS-managed SEO meta tags (title, description, keywords), Open Graph /
 * Twitter cards, a canonical URL and optional JSON-LD structured data for a
 * public page. Starts from the static fallback so a title is present on first
 * paint, then swaps in the admin-edited values once the API responds.
 *
 * These tags are rendered directly rather than through react-helmet-async:
 * React 19 hoists <title>, <meta> and <link> into <head> natively, and helmet
 * only supports React <= 18 (see its peerDependencies). Running both meant two
 * things managing the same tags, so the fallback -> CMS-value swap did not
 * reliably reach <head> and edits appeared not to apply.
 */
export const Seo = ({ pageKey, structuredData, canonicalPath }: SeoProps) => {
  const [seo, setSeo] = useState<PageSeoData>(SEO_FALLBACKS[pageKey]);
  const { pathname } = useLocation();

  useEffect(() => {
    let active = true;
    // Reset to this page's fallback immediately on key change.
    setSeo(SEO_FALLBACKS[pageKey]);
    getPageSeo(pageKey).then((data) => {
      if (active) setSeo(data);
    });
    return () => {
      active = false;
    };
  }, [pageKey]);

  const title = seo.metaTitle || SEO_FALLBACKS[pageKey].metaTitle || 'Nahata Sports Complex';
  const description = seo.metaDescription || SEO_FALLBACKS[pageKey].metaDescription || '';
  const keywords = seo.metaKeywords || SEO_FALLBACKS[pageKey].metaKeywords || '';
  const canonical = `${SITE_URL}${canonicalPath ?? pathname}`;

  // Normalise to an array so a single schema object is handled uniformly.
  const schemas = structuredData
    ? Array.isArray(structuredData)
      ? structuredData
      : [structuredData]
    : [];

  return (
    <>
      <title>{title}</title>
      {description && <meta name="description" content={description} />}
      {keywords && <meta name="keywords" content={keywords} />}
      <link rel="canonical" href={canonical} />
      {/* Open Graph mirrors title/description for richer link previews */}
      <meta property="og:title" content={title} />
      {description && <meta property="og:description" content={description} />}
      <meta property="og:type" content="website" />
      <meta property="og:url" content={canonical} />
      <meta property="og:site_name" content="Nahata Sports" />
      {/* Twitter card */}
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content={title} />
      {description && <meta name="twitter:description" content={description} />}
      {/* JSON-LD structured data. Not hoisted by React (only async scripts are),
          but JSON-LD is valid anywhere in the document — Google reads it either
          way. dangerouslySetInnerHTML keeps the JSON from being escaped. */}
      {schemas.map((schema, i) => (
        <script
          key={i}
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
        />
      ))}
    </>
  );
};
