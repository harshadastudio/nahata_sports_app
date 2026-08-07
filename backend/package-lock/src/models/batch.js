'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Batch extends Model {
    static associate(models) {
      Batch.belongsTo(models.Sport, { 
        foreignKey: 'sportId',
        as: 'sport'
      });
      Batch.belongsTo(models.Coach, { 
        foreignKey: 'coachId',
        as: 'coach'
      });
      Batch.belongsTo(models.SportComplex, { 
        foreignKey: 'sportComplexId',
        as: 'sportComplex'
      });
      Batch.belongsToMany(models.Student, { 
        through: 'StudentBatches', 
        foreignKey: 'batchId',
        as: 'students'
      });
      Batch.hasMany(models.Attendance, {
        foreignKey: 'batchId',
        as: 'attendances'
      });
    }

    // Instance method to check if batch is full
    isFull() {
      return this.currentStudents >= this.maxStudents;
    }

    // Instance method to get available slots
    getAvailableSlots() {
      return Math.max(0, this.maxStudents - this.currentStudents);
    }

    // Instance method to parse the days string into an array
    getDaysArray() {
      if (!this.days) return [];
      return this.days.split(',').map((day) => day.trim());
    }

    // Instance method to parse features
    getFeaturesArray() {
      if (!this.features) return [];
      try {
        return JSON.parse(this.features);
      } catch (error) {
        return [];
      }
    }
  }

  Batch.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    sportId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Sports',
        key: 'id',
      },
    },
    coachId: {
      type: DataTypes.INTEGER,
      references: {
        model: 'Coaches',
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
    },
    schedule: {
      type: DataTypes.STRING,
    },
    days: {
      type: DataTypes.STRING,
      comment: 'Comma-separated days: Mon,Wed,Fri',
    },
    startDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    endDate: {
      type: DataTypes.DATEONLY,
    },
    maxStudents: {
      type: DataTypes.INTEGER,
      defaultValue: 20,
    },
    currentStudents: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive', 'Completed', 'Cancelled'),
      defaultValue: 'Active',
    },
    fees: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    // --- Offering fields absorbed from the former Program model ---
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    ageGroup: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: 'e.g., 5-15 Years',
    },
    duration: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: 'e.g., 1 Month, 3 Months, 6 Months, Annual',
    },
    startTime: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    endTime: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    features: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'JSON array of batch features',
      get() {
        const rawValue = this.getDataValue('features');
        if (!rawValue) return [];
        try {
          return JSON.parse(rawValue);
        } catch (error) {
          return [];
        }
      },
      set(value) {
        if (Array.isArray(value)) {
          this.setDataValue('features', JSON.stringify(value));
        } else {
          this.setDataValue('features', value);
        }
      },
    },
    image: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    legacyProgramId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: 'Source Program id when this batch was migrated from a Program (temporary).',
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
    modelName: 'Batch',
    tableName: 'Batches',
  });
  
  return Batch;
};