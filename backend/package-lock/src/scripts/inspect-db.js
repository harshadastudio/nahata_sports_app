const { sequelize, SportComplex, Court, Sport } = require('../models');

async function inspect() {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected to database');

    const complexes = await SportComplex.findAll();
    console.log('\n--- Sport Complexes in DB ---');
    complexes.forEach(c => {
      console.log(`ID: ${c.id} | Name: "${c.name}" | City: "${c.city}"`);
    });

    const courts = await Court.findAll({
      include: [{ model: Sport, attributes: ['name'] }]
    });
    console.log('\n--- Courts in DB ---');
    courts.forEach(crt => {
      console.log(`ID: ${crt.id} | Name: "${crt.name}" | Sport: "${crt.Sport?.name || 'N/A'}" | Complex ID: ${crt.sportComplexId}`);
    });

    process.exit(0);
  } catch (error) {
    console.error('❌ Error during inspection:', error);
    process.exit(1);
  }
}

inspect();
