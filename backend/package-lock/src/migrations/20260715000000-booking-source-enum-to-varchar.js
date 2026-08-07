'use strict';

/**
 * Bookings.bookingSource: ENUM → VARCHAR(50).
 *
 * Aggregators (KheloMore, Huddle, and future platforms) all resell the same
 * endpoints, and each one needs its own source label. As an ENUM, onboarding a
 * platform meant an ALTER TYPE + deploy before that partner could book at all —
 * miss it and every one of their inserts fails with "invalid input value for enum".
 * VARCHAR moves that list into the partner registry (src/config/partnerSources.js),
 * which validates the label in code, so a new platform is now env-only.
 *
 * Existing labels are preserved verbatim — the enum's text values cast straight
 * across, so no row changes meaning.
 *
 * @type {import('sequelize-cli').Migration}
 */

const ENUM_TYPE = 'enum_Bookings_bookingSource';
const LEGACY_LABELS = ['Direct', 'Playo', 'KheloMore', 'Website', 'MobileApp'];

module.exports = {
  async up(queryInterface) {
    const q = queryInterface.sequelize;
    await q.transaction(async (transaction) => {
      // The default is typed as the enum, so it must go before the type changes.
      await q.query(`ALTER TABLE "Bookings" ALTER COLUMN "bookingSource" DROP DEFAULT`, { transaction });
      await q.query(
        `ALTER TABLE "Bookings" ALTER COLUMN "bookingSource" TYPE VARCHAR(50) USING "bookingSource"::text`,
        { transaction },
      );
      await q.query(`ALTER TABLE "Bookings" ALTER COLUMN "bookingSource" SET DEFAULT 'Direct'`, { transaction });
      // Nothing references the enum type once the column is VARCHAR.
      await q.query(`DROP TYPE IF EXISTS "${ENUM_TYPE}"`, { transaction });
    });
    console.log('✅ Bookings.bookingSource is now VARCHAR(50) — new partners need no migration');
  },

  async down(queryInterface) {
    const q = queryInterface.sequelize;
    await q.transaction(async (transaction) => {
      const labels = LEGACY_LABELS.map((l) => `'${l}'`).join(', ');
      // Labels added after the widening (e.g. 'Huddle') cannot exist in the old
      // enum — fold them back to the aggregator they were split out of.
      await q.query(
        `UPDATE "Bookings" SET "bookingSource" = 'KheloMore' WHERE "bookingSource" NOT IN (${labels})`,
        { transaction },
      );
      await q.query(`ALTER TABLE "Bookings" ALTER COLUMN "bookingSource" DROP DEFAULT`, { transaction });
      await q.query(`DROP TYPE IF EXISTS "${ENUM_TYPE}"`, { transaction });
      await q.query(`CREATE TYPE "${ENUM_TYPE}" AS ENUM(${labels})`, { transaction });
      await q.query(
        `ALTER TABLE "Bookings" ALTER COLUMN "bookingSource" TYPE "${ENUM_TYPE}" USING "bookingSource"::"${ENUM_TYPE}"`,
        { transaction },
      );
      await q.query(`ALTER TABLE "Bookings" ALTER COLUMN "bookingSource" SET DEFAULT 'Direct'`, { transaction });
    });
  },
};
