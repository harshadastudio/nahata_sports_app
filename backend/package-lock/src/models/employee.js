'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Employee extends Model {
    static associate(models) {
      // Employee belongs to User
      Employee.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
      // Employee belongs to a single sports complex (per-complex admin scoping)
      Employee.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }
  
  Employee.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
      comment: 'The sports complex this employee belongs to',
    },
    employeeId: {
      type: DataTypes.STRING,
      unique: true,
      allowNull: false,
    },
    department: {
      type: DataTypes.ENUM('Operations', 'Front Desk', 'Maintenance', 'Housekeeping', 'Accounts', 'Customer Service'),
      allowNull: false,
    },
    designation: {
      type: DataTypes.ENUM('Manager', 'Supervisor', 'Staff', 'Technician', 'Accountant', 'Receptionist'),
      allowNull: false,
    },
    joiningDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    salary: {
      type: DataTypes.DECIMAL(10, 2),
    },
    shift: {
      type: DataTypes.ENUM('Morning', 'Evening', 'Night', 'Rotational'),
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive', 'On Leave'),
      defaultValue: 'Active',
    },
    address: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    phone: {
      type: DataTypes.STRING,
      allowNull: true,
      validate: {
        is: {
          args: /^[0-9]{10}$/,
          msg: 'Phone number must be exactly 10 digits'
        },
        len: {
          args: [10, 10],
          msg: 'Phone number must be exactly 10 digits'
        }
      }
    },
    createdAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
    updatedAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
  }, {
    sequelize,
    modelName: 'Employee',
    tableName: 'Employees',
  });
  
  return Employee;
};
