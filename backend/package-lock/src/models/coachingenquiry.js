module.exports = (sequelize, DataTypes) => {
  const CoachingEnquiry = sequelize.define('CoachingEnquiry', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    },
    batchId: {
      type: DataTypes.INTEGER,
      // Nullable until the Phase 5 migration backfills and enforces NOT NULL.
      allowNull: true,
      references: {
        model: 'Batches',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    },
    sportId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'Sports',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL'
    },
    coachId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'Coaches',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL'
    },
    studentId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'Students',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL',
      comment: 'Links to the Student record created when enquiry is approved'
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL',
      comment: 'The sports complex this coaching enquiry belongs to'
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        isEmail: true
      }
    },
    phone: {
      type: DataTypes.STRING,
      allowNull: false,
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
    message: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    referenceNumber: {
      type: DataTypes.STRING,
      allowNull: true,
      unique: true
    },
    status: {
      type: DataTypes.ENUM('Pending', 'Reviewed', 'Approved', 'Rejected', 'Contacted'),
      defaultValue: 'Pending',
      allowNull: false
    },
    createdAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    updatedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    deletedAt: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    tableName: 'CoachingEnquiries',
    timestamps: true,
    paranoid: true, // Enable soft deletes
    underscored: false
  });

  CoachingEnquiry.associate = (models) => {
    // Association with User
    CoachingEnquiry.belongsTo(models.User, {
      foreignKey: 'userId',
      as: 'user'
    });

    // Association with Batch (the offering the enquiry is for)
    CoachingEnquiry.belongsTo(models.Batch, {
      foreignKey: 'batchId',
      as: 'batch'
    });

    // Association with Sport
    CoachingEnquiry.belongsTo(models.Sport, {
      foreignKey: 'sportId',
      as: 'sport'
    });

    // Association with Coach
    CoachingEnquiry.belongsTo(models.Coach, {
      foreignKey: 'coachId',
      as: 'coach'
    });

    // Association with Student (created when enquiry is approved)
    CoachingEnquiry.belongsTo(models.Student, {
      foreignKey: 'studentId',
      as: 'student'
    });

    // Association with SportComplex (per-complex admin scoping)
    CoachingEnquiry.belongsTo(models.SportComplex, {
      foreignKey: 'sportComplexId',
      as: 'sportComplex'
    });
  };

  return CoachingEnquiry;
};
