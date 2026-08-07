const { sequelize } = require('../models');
const migration = require('../migrations/20260521120000-add-external-booking-ids.js');

async function run() {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected to database');

    const queryInterface = sequelize.getQueryInterface();
    await migration.up(queryInterface, sequelize.Sequelize);
    console.log('✅ Successfully applied external booking IDs migration');

    // Manually register it in SequelizeMeta
    await sequelize.query('INSERT INTO "SequelizeMeta" (name) VALUES (:name) ON CONFLICT (name) DO NOTHING', {
      replacements: { name: '20260521120000-add-external-booking-ids.js' },
      type: sequelize.QueryTypes.INSERT
    });
    console.log('✅ Registered migration in SequelizeMeta');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

run();
