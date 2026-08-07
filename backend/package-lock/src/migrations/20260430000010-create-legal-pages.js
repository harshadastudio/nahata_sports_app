'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('LegalPages', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      type: {
        type: Sequelize.ENUM('privacy', 'cancellation', 'disclaimer', 'terms'),
        allowNull: false,
        unique: true,
      },
      title: { type: Sequelize.STRING(255), allowNull: false },
      content: { type: Sequelize.TEXT('long'), allowNull: false },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
      createdAt: { allowNull: false, type: Sequelize.DATE },
    });

    // Seed default content for all 4 pages
    const now = new Date();
    await queryInterface.bulkInsert('LegalPages', [
      {
        type: 'privacy',
        title: 'Privacy Policy',
        content: 'At Nahata Sports, we take your privacy seriously. This policy describes how we collect, use, and protect your personal data.\n\n1. Information We Collect\nWe collect information you provide directly to us, such as when you create an account, make a booking, or contact us for support.\n\n2. How We Use Your Information\nWe use the information we collect to provide, maintain, and improve our services, process transactions, and send you related information.\n\n3. Data Protection\nWe implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.\n\n4. Contact Us\nIf you have any questions about this Privacy Policy, please contact us at info@nahatasports.com.',
        createdAt: now,
        updatedAt: now,
      },
      {
        type: 'cancellation',
        title: 'Cancellation Policy',
        content: 'Nahata Sports Complex maintains a strict cancellation policy to ensure fair access to all our facilities.\n\n1. Booking Cancellations\nOnce a booking is confirmed, cancellations must be made at least 24 hours in advance to receive a full refund.\n\n2. Late Cancellations\nCancellations made less than 24 hours before the scheduled time will forfeit 50% of the booking amount.\n\n3. No-Shows\nFailure to show up without prior cancellation will result in forfeiture of the full booking amount.\n\n4. Refund Processing\nApproved refunds will be processed within 5-7 business days to the original payment method.\n\n5. Special Circumstances\nIn case of extreme weather or facility unavailability, full refunds will be issued.',
        createdAt: now,
        updatedAt: now,
      },
      {
        type: 'disclaimer',
        title: 'Disclaimer',
        content: 'All information provided on the Nahata Sports Complex website or in any communication is for general informational purposes only.\n\n1. Accuracy of Information\nWhile every effort is made to ensure accuracy, Nahata Sports Complex makes no warranties or representations as to completeness, reliability, or accuracy of the information.\n\n2. Participation Risk\nParticipation in sports activities, coaching programs, or events is voluntary and entirely at your own risk. Nahata Sports Complex is not liable for any injuries sustained during activities.\n\n3. External Links\nOur website may contain links to external websites. We are not responsible for the content or privacy practices of those sites.\n\n4. Changes to Disclaimer\nWe reserve the right to modify this disclaimer at any time. Continued use of our services constitutes acceptance of any changes.',
        createdAt: now,
        updatedAt: now,
      },
      {
        type: 'terms',
        title: 'Terms & Conditions',
        content: 'Welcome to Nahata Sports Complex. By accessing our premises, booking facilities, or availing of any services, you agree to be bound by the following Terms & Conditions.\n\n1. General Rules of Conduct\n• All players must wear appropriate sports attire and non-marking sports shoes.\n• Loud shouting, aggressive behavior, or abusive language is strictly prohibited.\n• Smoking, tobacco, alcohol consumption, and illegal substances are strictly prohibited.\n\n2. Booking Terms\n• All bookings are subject to availability.\n• Payment must be completed to confirm a booking.\n• Nahata Sports Complex reserves the right to cancel bookings in case of facility maintenance.\n\n3. Liability\n• Nahata Sports Complex is not responsible for any loss, theft, or damage to personal belongings.\n• Users participate in all activities at their own risk.\n\n4. Amendments\nNahata Sports Complex reserves the right to amend these terms at any time. Continued use of our services constitutes acceptance of the updated terms.',
        createdAt: now,
        updatedAt: now,
      },
    ]);
  },
  async down(queryInterface) {
    await queryInterface.dropTable('LegalPages');
  },
};
