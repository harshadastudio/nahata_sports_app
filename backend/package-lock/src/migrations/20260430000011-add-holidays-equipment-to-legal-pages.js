'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    // Add new enum values to the existing type
    await queryInterface.sequelize.query(`
      ALTER TYPE "enum_LegalPages_type" ADD VALUE IF NOT EXISTS 'holidays';
    `);
    await queryInterface.sequelize.query(`
      ALTER TYPE "enum_LegalPages_type" ADD VALUE IF NOT EXISTS 'equipment';
    `);

    // Seed default content for both new pages
    const now = new Date();
    await queryInterface.bulkInsert('LegalPages', [
      {
        type: 'holidays',
        title: 'Holiday Schedule',
        content: 'Nahata Sports Complex Holiday Schedule\n\nWe observe the following holidays throughout the year. Please plan your bookings accordingly.\n\n1. National Holidays\n• Republic Day – January 26\n• Independence Day – August 15\n• Gandhi Jayanti – October 2\n\n2. Festival Holidays\n• Diwali – As per Hindu calendar (2-3 days)\n• Holi – As per Hindu calendar (1 day)\n• Ganesh Chaturthi – As per Hindu calendar (1 day)\n• Eid – As per Islamic calendar\n• Christmas – December 25\n\n3. Facility Maintenance Breaks\n• Annual Maintenance: First week of June\n• Equipment Servicing: Last Monday of every month (6:00 AM – 10:00 AM)\n\n4. Special Closures\nOccasional closures may be announced for tournaments, special events, or emergency maintenance. Advance notice will be provided via WhatsApp and our website.\n\n5. Reduced Hours\nOn certain holidays, we may operate with reduced hours (8:00 AM – 6:00 PM). Check our website or contact us for specific dates.',
        createdAt: now,
        updatedAt: now,
      },
      {
        type: 'equipment',
        title: 'Equipment Rental',
        content: 'Nahata Sports Equipment Rental\n\nWe offer a wide range of sports equipment for rent to enhance your playing experience.\n\n1. Available Equipment\n• Badminton Rackets – ₹50/hour per racket\n• Cricket Batting Pads – ₹100/session\n• Cricket Helmet – ₹50/session\n• Cricket Gloves – ₹30/session\n• Basketball – ₹30/hour\n• Skating Gear (Helmet + Knee Pads + Elbow Pads) – ₹100/hour\n• Skating Shoes – ₹80/hour\n• Karate Uniform – ₹50/session\n\n2. Rental Terms\n• Equipment must be returned in the same condition as rented.\n• Damage or loss of equipment will be charged at replacement cost.\n• Equipment is available on a first-come, first-served basis.\n• Advance booking for equipment is recommended during peak hours.\n\n3. How to Rent\n• Visit the reception desk at least 15 minutes before your session.\n• Provide a valid ID proof as security deposit.\n• Pay the rental fee at the time of collection.\n\n4. Hygiene Policy\n• All equipment is sanitized after each use.\n• Personal protective equipment (helmets, gloves) is sanitized with UV light.\n\n5. Contact\nFor bulk equipment rental or special event requirements, contact us at info@nahatasports.com or call +91 98765 43210.',
        createdAt: now,
        updatedAt: now,
      },
    ]);
  },
  async down(queryInterface) {
    await queryInterface.bulkDelete('LegalPages', { type: ['holidays', 'equipment'] });
  },
};
