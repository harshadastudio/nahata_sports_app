'use strict';

const { PageSeo } = require('../models');

// The fixed set of pages whose SEO is editable from the CMS.
// Order here matches the order the cards appear in the admin SEO Manager.
const VALID_PAGE_KEYS = ['book', 'coaching', 'events', 'blogs', 'contact', 'about'];

// ── GET /api/page-seo  — public: all page SEO rows ───────────────────────────
exports.getAllPageSeo = async (req, res) => {
  try {
    const pages = await PageSeo.findAll({ order: [['pageKey', 'ASC']] });
    res.json({ success: true, data: pages });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── GET /api/page-seo/:pageKey  — public: SEO for one page ───────────────────
exports.getPageSeoByKey = async (req, res) => {
  try {
    const { pageKey } = req.params;
    if (!VALID_PAGE_KEYS.includes(pageKey)) {
      return res.status(400).json({ success: false, message: `Invalid page key. Must be one of: ${VALID_PAGE_KEYS.join(', ')}` });
    }
    const page = await PageSeo.findOne({ where: { pageKey } });
    if (!page) {
      return res.status(404).json({ success: false, message: 'SEO settings not found for this page.' });
    }
    res.json({ success: true, data: page });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── PUT /api/page-seo/:pageKey  — admin: update (or create) SEO for one page ──
exports.upsertPageSeo = async (req, res) => {
  try {
    const { pageKey } = req.params;
    if (!VALID_PAGE_KEYS.includes(pageKey)) {
      return res.status(400).json({ success: false, message: `Invalid page key. Must be one of: ${VALID_PAGE_KEYS.join(', ')}` });
    }

    const { metaTitle, metaDescription, metaKeywords } = req.body;

    let page = await PageSeo.findOne({ where: { pageKey } });
    if (!page) {
      // Row is missing (e.g. a new page key seeded later) — create it.
      page = await PageSeo.create({
        pageKey,
        metaTitle: metaTitle ?? null,
        metaDescription: metaDescription ?? null,
        metaKeywords: metaKeywords ?? null,
      });
      return res.status(201).json({ success: true, message: 'SEO settings created.', data: page });
    }

    await page.update({
      metaTitle: metaTitle !== undefined ? metaTitle : page.metaTitle,
      metaDescription: metaDescription !== undefined ? metaDescription : page.metaDescription,
      metaKeywords: metaKeywords !== undefined ? metaKeywords : page.metaKeywords,
    });

    res.json({ success: true, message: 'SEO settings updated.', data: page });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
