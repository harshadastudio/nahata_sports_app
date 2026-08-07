'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Student extends Model {
    static associate(models) {
      Student.belongsTo(models.User, { foreignKey: 'userId', as: 'User' });
      Student.hasMany(models.Attendance, { foreignKey: 'studentId', as: 'attendances' });
      Student.hasMany(models.Performance, { foreignKey: 'studentId' });
      Student.belongsToMany(models.Batch, { through: 'StudentBatches', foreignKey: 'studentId' });
      Student.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }

  Student.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      unique: true,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
      comment: 'The complex the student registered with (home complex)',
    },
    parentName: {
      type: DataTypes.STRING,
    },
    parentPhone: {
      type: DataTypes.STRING,
      allowNull: true,
      validate: {
        is: {
          args: /^[0-9]{10}$/,
          msg: 'Parent phone number must be exactly 10 digits'
        },
        len: {
          args: [10, 10],
          msg: 'Parent phone number must be exactly 10 digits'
        }
      }
    },
    parentEmail: {
      type: DataTypes.STRING,
      validate: {
        isEmail: true,
      },
    },
    schoolName: {
      type: DataTypes.STRING,
    },
    grade: {
      type: DataTypes.STRING,
    },
    medicalConditions: {
      type: DataTypes.TEXT,
    },
    allergies: {
      type: DataTypes.TEXT,
    },
    previousExperience: {
      type: DataTypes.TEXT,
    },
    achievements: {
      type: DataTypes.TEXT,
    },
    enrollmentDate: {
      type: DataTypes.DATEONLY,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive', 'Graduated', 'Transferred'),
      defaultValue: 'Active',
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
    modelName: 'Student',
    tableName: 'Students',
  });
  
  return Student;
};