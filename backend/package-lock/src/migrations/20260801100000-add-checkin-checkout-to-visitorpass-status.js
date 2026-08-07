'use strict';

/**
 * Visitor pass check-in / check-out lifecycle.
 *
 * A visitor pass used to be single-use: the first scan flipped it to 'Used' and
 * that was the end of it. The gate now records both directions, so the status
 * enum gains two explicit states:
 *
 *   Active      → generated, nobody has entered yet (QR valid for entry)
 *   CheckedIn   → visitor scanned IN   (QR valid only for the exit scan)
 *   CheckedOut  → visitor scanned OUT  (QR permanently dead)
 *
 * The legacy 'Used' value is kept so existing rows stay readable — the service
 * treats 'Used' as 'CheckedIn'.
 *
 * NOTE: PostgreSQL's `ALTER TYPE ... ADD VALUE` cannot be used in the same
 * transaction that later references the new value, so this migration only
 * touches the enum — no data backfill here.
 */
module.exports = {
  async up(queryInterface) {
    const [rows] = await queryInterface.sequelize.query(`
      SELECT udt_name
      FROM information_schema.columns
      WHERE table_name = 'VisitorPasses' AND column_name = 'status'
    `);

    const enumName = rows?.[0]?.udt_name;
    // Column is a plain varchar (or missing) — nothing to alter.
    if (!enumName || !enumName.startsWith('enum_')) return;

    await queryInterface.sequelize.query(
      `ALTER TYPE "${enumName}" ADD VALUE IF NOT EXISTS 'CheckedIn';`
    );
    await queryInterface.sequelize.query(
      `ALTER TYPE "${enumName}" ADD VALUE IF NOT EXISTS 'CheckedOut';`
    );
  },

  async down() {
    // PostgreSQL cannot remove a value from an enum type. No-op.
  },
};
