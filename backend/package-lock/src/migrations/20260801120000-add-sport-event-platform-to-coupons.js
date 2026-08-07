'use strict';

/**
 * Finer-grained coupon targeting.
 *
 *  - sportId      FK → Sports.id, nullable. Court coupons only: restrict the
 *                 coupon to a single sport inside the chosen complex.
 *                 NULL = every sport in scope.
 *  - eventPassId  FK → EventPasses.id, nullable. Event coupons only: restrict
 *                 the coupon to one event. NULL = all events.
 *  - platform     'All' | 'Web' | 'App'. Which client may redeem the coupon —
 *                 the website, the Android/iOS apps, or both.
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

    if (!desc.sportId) {
      await queryInterface.addColumn('Coupons', 'sportId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Sports', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
      console.log('✅ Added sportId column to Coupons table');
    } else {
      console.log('⏭️  Skipped: sportId column already exists');
    }

    if (!desc.eventPassId) {
      await queryInterface.addColumn('Coupons', 'eventPassId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'EventPasses', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
      console.log('✅ Added eventPassId column to Coupons table');
    } else {
      console.log('⏭️  Skipped: eventPassId column already exists');
    }

    if (!desc.platform) {
      await queryInterface.addColumn('Coupons', 'platform', {
        type: Sequelize.ENUM('All', 'Web', 'App'),
        allowNull: false,
        defaultValue: 'All',
      });
      console.log('✅ Added platform column to Coupons table');
    } else {
      console.log('⏭️  Skipped: platform column already exists');
    }
  },

  async down(queryInterface) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('Coupons')) return;

    const desc = await queryInterface.describeTable('Coupons');

    if (desc.sportId) await queryInterface.removeColumn('Coupons', 'sportId');
    if (desc.eventPassId) await queryInterface.removeColumn('Coupons', 'eventPassId');

    if (desc.platform) {
      await queryInterface.removeColumn('Coupons', 'platform');
      if (queryInterface.sequelize.getDialect() === 'postgres') {
        await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_Coupons_platform";');
      }
    }
  },
};
