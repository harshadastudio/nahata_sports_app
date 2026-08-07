const { sequelize } = require('../models');

(async () => {
  try {
    await sequelize.authenticate();
    const [r] = await sequelize.query(
      `SELECT t.typname, e.enumlabel 
       FROM pg_type t 
       JOIN pg_enum e ON t.oid = e.enumtypid 
       WHERE t.typname LIKE '%Courts%' OR t.typname LIKE '%courts%'
       ORDER BY t.typname, e.enumsortorder`
    );
    console.log('Courts-related enum values:');
    r.forEach(x => console.log(`  ${x.typname} → ${x.enumlabel}`));
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
