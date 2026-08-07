'use strict';

const bcrypt = require('bcrypt');

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Hash passwords
    const saltRounds = 10;
    const adminPassword = await bcrypt.hash('Admin@123', saltRounds);
    const employeePassword = await bcrypt.hash('Employee@123', saltRounds);
    const coachPassword = await bcrypt.hash('Coach@123', saltRounds);
    const securityPassword = await bcrypt.hash('Security@123', saltRounds);
    const userPassword = await bcrypt.hash('User@123', saltRounds);

    // Insert demo users
    await queryInterface.bulkInsert('Users', [
      {
        name: 'Admin User',
        email: 'admin@nahatasports.com',
        password: adminPassword,
        role: 'ADMIN',
        phone_number: '+1234567890',
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'Employee User',
        email: 'employee@nahatasports.com',
        password: employeePassword,
        role: 'EMPLOYEE',
        phone_number: '+1234567891',
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'Coach User',
        email: 'coach@nahatasports.com',
        password: coachPassword,
        role: 'COACH',
        phone_number: '+1234567892',
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'Security User',
        email: 'security@nahatasports.com',
        password: securityPassword,
        role: 'SECURITY',
        phone_number: '+1234567893',
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
    ], {});

    console.log('✅ Demo users created successfully!');
    console.log('');
    console.log('📋 Login Credentials:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('ADMIN:    admin@nahatasports.com    / Admin@123');
    console.log('EMPLOYEE: employee@nahatasports.com / Employee@123');
    console.log('COACH:    coach@nahatasports.com    / Coach@123');
    console.log('SECURITY: security@nahatasports.com / Security@123');
    console.log('USER:     user@nahatasports.com     / User@123');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  },

  async down(queryInterface, Sequelize) {
    // Remove demo users
    await queryInterface.bulkDelete('Users', {
      email: {
        [Sequelize.Op.in]: [
          'admin@nahatasports.com',
          'employee@nahatasports.com',
          'coach@nahatasports.com',
          'security@nahatasports.com',
          'user@nahatasports.com'
        ]
      }
    }, {});

    console.log('✅ Demo users removed successfully!');
  }
};
