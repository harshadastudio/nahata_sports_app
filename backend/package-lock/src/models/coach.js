'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Coach extends Model {
    static associate(models) {
      // Coach belongs to a Sport (kept for backward compatibility)
      Coach.belongsTo(models.Sport, {
        foreignKey: 'sportId',
        as: 'sport'
      });
      
      // Coach can have many Batches
      Coach.hasMany(models.Batch, {
        foreignKey: 'coachId',
        as: 'Batches'
      });

      // Legacy alias kept so existing `includePrograms` / coach.programs
      // consumers keep working after Program was merged into Batch.
      Coach.hasMany(models.Batch, {
        foreignKey: 'coachId',
        as: 'programs'
      });
      
      // Many-to-Many: Coach can teach multiple Sports
      Coach.belongsToMany(models.Sport, {
        through: models.CoachSport,
        foreignKey: 'coachId',
        otherKey: 'sportId',
        as: 'sports'
      });

      // Each coach belongs to a single sports complex (per-complex admin scoping).
      Coach.belongsTo(models.SportComplex, {
        foreignKey: 'sportComplexId',
        as: 'sportComplex'
      });
    }
  }
  
  Coach.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        notEmpty: {
          msg: 'Coach name is required',
        },
      },
    },
    email: {
      type: DataTypes.STRING,
      allowNull: true,
      unique: true,
      validate: {
        isEmail: {
          msg: 'Must be a valid email address',
        },
      },
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
    sportId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'Sports',
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
      comment: 'The sports complex this coach belongs to',
    },
    ground: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: 'Ground/Complex location',
    },
    price: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      defaultValue: 0,
      comment: 'Coach price/fee',
    },
    availability: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: 'Comma-separated days: Monday,Tuesday,Wednesday',
    },
    certification: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Coach certifications and qualifications',
    },
    bio: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Coach biography',
    },
    image: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Coach profile image (base64 or URL)',
    },
    experience: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: 'Years of experience (e.g., "5 years", "10+ years")',
    },
    specialization: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Areas of specialization',
    },
    qualifications: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Additional qualifications',
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive'),
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
    modelName: 'Coach',
    tableName: 'Coaches',
    timestamps: true,
  });
  
  return Coach;
};
