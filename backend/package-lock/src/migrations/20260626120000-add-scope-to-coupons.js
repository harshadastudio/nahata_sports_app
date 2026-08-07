'use strict';

/**
 * Scope coupons to a booking type (Court / Event) and, for court coupons,
 * optionally to a single Sports Complex.
 *
 *  - appliesTo       'Court' | 'Event'  (required; existing rows default to 'Court')
 *  - sportComplexId  FK → SportComplexes.id, nullable
 *                    Only meaningful for Court coupons. NULL = all complexes.
 *
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('Coupons')) {
      console.log('⏭️  Skipped: Coupons table does not exist');
      return;
    }

    const desc = await queryInterface.describeTable('Coupons');

    if (!desc.appliesTo) {
      await queryInterface.addColumn('Coupons', 'appliesTo', {
        type: Sequelize.ENUM('Court', 'Event'),
        allowNull: false,
        defaultValue: 'Court',
      });
      console.log('✅ Added appliesTo column to Coupons table');
    } else {
      console.log('⏭️  Skipped: appliesTo column already exists');
    }

    if (!desc.sportComplexId) {
      await queryInterface.addColumn('Coupons', 'sportComplexId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'SportComplexes', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
      console.log('✅ Added sportComplexId column to Coupons table');
    } else {
      console.log('⏭️  Skipped: sportComplexId column already exists');
    }
  },

  async down(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('Coupons')) return;

    const desc = await queryInterface.describeTable('Coupons');

    if (desc.sportComplexId) {
      await queryInterface.removeColumn('Coupons', 'sportComplexId');
      console.log('✅ Removed sportComplexId column from Coupons table');
    }

    if (desc.appliesTo) {
      await queryInterface.removeColumn('Coupons', 'appliesTo');
      // Drop the ENUM type Postgres created for the column.
      if (queryInterface.sequelize.getDialect() === 'postgres') {
        await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_Coupons_appliesTo";');
      }
      console.log('✅ Removed appliesTo column from Coupons table');
    }
  },
};
