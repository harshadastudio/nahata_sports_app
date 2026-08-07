'use strict';

/**
 * PageSeo — CMS-managed SEO metadata for the public marketing pages.
 * One row per page, keyed by a stable `pageKey` (events | blogs | contact | about).
 * The public frontend reads a row by key and injects the meta tags; the admin
 * panel edits them from the central "SEO Manager" CMS module.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('PageSeo', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      pageKey: { type: Sequelize.STRING(50), allowNull: false, unique: true },
      metaTitle: { type: Sequelize.STRING(255), allowNull: true },
      metaDescription: { type: Sequelize.TEXT, allowNull: true },
      metaKeywords: { type: Sequelize.TEXT, allowNull: true },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    const now = new Date();
    await queryInterface.bulkInsert('PageSeo', [
      {
        pageKey: 'events',
        metaTitle: 'Events & Tournaments | Nahata Sports Complex, Pune',
        metaDescription: 'Discover upcoming sports events, tournaments, and training camps at Nahata Sports Complex in Pune. Book your event pass today.',
        metaKeywords: 'sports events Pune, tournaments, Nahata Sports events, sports camps Pune',
        createdAt: now,
        updatedAt: now,
      },
      {
        pageKey: 'blogs',
        metaTitle: 'Blog | Nahata Sports Complex, Pune',
        metaDescription: 'Read the latest news, training tips, and stories from Nahata Sports Complex, Pune. Insights on Cricket, Badminton, Basketball, and more.',
        metaKeywords: 'sports blog, training tips, Nahata Sports news, Pune sports articles',
        createdAt: now,
        updatedAt: now,
      },
      {
        pageKey: 'contact',
        metaTitle: 'Contact Us | Nahata Sports Complex, Pune',
        metaDescription: 'Get in touch with Nahata Sports Complex, Pune. Reach us for bookings, coaching enquiries, memberships, and facility information.',
        metaKeywords: 'contact Nahata Sports, sports complex Pune contact, booking enquiry',
        createdAt: now,
        updatedAt: now,
      },
      {
        pageKey: 'about',
        metaTitle: 'About Us | Nahata Sports Complex, Pune',
        metaDescription: 'Learn about Nahata Sports Complex — premium sports facilities and professional coaching at Sinhagad Road and Gangadham Chowk, Pune.',
        metaKeywords: 'about Nahata Sports, sports complex Pune, sports academy Pune',
        createdAt: now,
        updatedAt: now,
      },
    ]);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('PageSeo');
  },
};
