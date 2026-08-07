'use strict';
const bcrypt = require('bcrypt');
const {
  Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class User extends Model {
    /**
     * Helper method for defining associations.
     * This method is not a part of Sequelize lifecycle.
     * The `models/index` file will call this method automatically.
     */
    static associate(models) {
      User.hasMany(models.RefreshToken, { foreignKey: 'userId', as: 'refreshTokens' });
      // The complex a COMPLEX_ADMIN is scoped to. NULL for ADMIN (super admin) and other roles.
      User.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }
  User.init({
    name: {
      type: DataTypes.STRING,
      allowNull: false
    },
    phone_number: {
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
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true
      }
    },
    password: {
      type: DataTypes.STRING,
      allowNull: true,
      validate: {
        len: [6, 100]
      }
    },
    googleId: {
      type: DataTypes.STRING,
      allowNull: true,
      unique: true
    },
    isGoogleUser: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    },
    role: {
      type: DataTypes.ENUM('ADMIN', 'USER', 'EMPLOYEE', 'COACH', 'SECURITY', 'COMPLEX_ADMIN'),
      allowNull: false,
      defaultValue: 'USER'
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      references: {
        model: 'SportComplexes',
        key: 'id'
      },
      comment: 'Home complex for a COMPLEX_ADMIN; NULL = super admin / global user'
    },
    total_bookings: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    membership_type: {
      type: DataTypes.ENUM('Basic', 'Premium', 'VIP', 'Corporate'),
      allowNull: true,
      defaultValue: null
    },
    status: {
      type: DataTypes.ENUM('Active', 'Blocked'),
      allowNull: false,
      defaultValue: 'Active'
    },
    join_date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    last_active: {
      type: DataTypes.DATEONLY,
      allowNull: true,
      defaultValue: null
    },
    avatar: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null
    },
    employee_id: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null
    },
    department: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null
    },
    assigned_sports: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: null
    },
    assigned_location: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null
    },
    permissions: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: null
    },
    staff_password_enc: {
      type: DataTypes.TEXT,
      allowNull: true,
      defaultValue: null,
      comment: 'AES-256-GCM encrypted admin-set password for staff logins (EMPLOYEE/SECURITY/COACH); admin-viewable. NULL = not stored.'
    },
    resetPasswordToken: {
      type: DataTypes.STRING,
      allowNull: true
    },
    resetPasswordExpires: {
      type: DataTypes.DATE,
      allowNull: true
    },
    isEmailVerified: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    },
    dob: {
      type: DataTypes.DATEONLY,
      allowNull: true,
      defaultValue: null
    },
    gender: {
      type: DataTypes.ENUM('Male', 'Female', 'Other'),
      allowNull: true,
      defaultValue: null
    },
    blood_group: {
      type: DataTypes.STRING(5),
      allowNull: true,
      defaultValue: null
    },
    // ── Phone login ────────────────────────────────────────────────────────
    // phone_number doubles as a login identifier. Uniqueness is enforced at the
    // service layer (see authService) — see the migration note on the DB
    // constraint. The three columns below are LEGACY: they belonged to the
    // removed WhatsApp OTP flow and are no longer read or written. They stay
    // declared only because the columns still exist in the database.
    phone_verified: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    },
    phone_verify_otp: {
      // sha256 of the current 6-digit OTP; never the plaintext code.
      type: DataTypes.STRING(64),
      allowNull: true,
      defaultValue: null
    },
    phone_verify_expiry: {
      type: DataTypes.DATE,
      allowNull: true,
      defaultValue: null
    }
  }, {
    sequelize,
    modelName: 'User',
    hooks: {
      beforeCreate: async (user) => {
        if (user.password) {
          user.password = await bcrypt.hash(user.password, 12);
        }
      },
      beforeUpdate: async (user) => {
        if (user.changed('password')) {
          user.password = await bcrypt.hash(user.password, 12);
        }
      }
    }
  });

  // Instance method to check password
  // User.prototype.comparePassword = async function(candidatePassword) {
  //   return await bcrypt.compare(candidatePassword, this.password);
  // };

  // In your User model - replace the existing comparePassword method

  User.prototype.comparePassword = async function (candidatePassword) {
    // PHP's password_hash() uses $2y$ prefix, Node bcrypt uses $2b$
    // They are identical algorithms — just normalize the prefix
    const hash = this.password.replace(/^\$2y\$/, '$2b$');
    return await bcrypt.compare(candidatePassword, hash);
  };

  return User;
};