'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class StudentBatches extends Model {
    static associate(models) {
      StudentBatches.belongsTo(models.Student, { foreignKey: 'studentId', as: 'student' });
      StudentBatches.belongsTo(models.Batch, { foreignKey: 'batchId', as: 'batch' });
      StudentBatches.belongsTo(models.User, { foreignKey: 'approvedBy', as: 'approver' });
      StudentBatches.belongsTo(models.User, { foreignKey: 'receivedBy', as: 'receiver' });
    }
  }

  StudentBatches.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    studentId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Students',
        key: 'id',
      },
    },
    batchId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Batches',
        key: 'id',
      },
    },
    enrollmentDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    // Date up to which THIS student's enrollment stays valid, as entered by the
    // coach on the fee record. Falls back to the batch end date when null.
    validTill: {
      type: DataTypes.DATEONLY,
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Completed', 'Dropped', 'Transferred', 'Suspended'),
      defaultValue: 'Active',
    },
    feesPaid: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    // --- Payment / approval fields absorbed from the former StudentProgram model ---
    // The Fees + Gate-Pass system is built on these columns.
    paymentStatus: {
      type: DataTypes.ENUM('Pending', 'Paid', 'Partial', 'Overdue'),
      defaultValue: 'Pending',
      allowNull: false,
    },
    amountPaid: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
      allowNull: false,
    },
    notes: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    approvalStatus: {
      type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
      defaultValue: 'Pending',
      allowNull: false,
    },
    approvedBy: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'Users', key: 'id' },
    },
    approvedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    // How the fee was collected, and which staff login (normally the coach)
    // recorded the collection. Separate from approvedBy/approvedAt, which
    // record the later admin/employee approval.
    paymentMode: {
      type: DataTypes.ENUM('Cash', 'UPI', 'Card', 'BankTransfer', 'Cheque', 'Other'),
      allowNull: true,
    },
    receivedBy: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'Users', key: 'id' },
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
    modelName: 'StudentBatches',
    tableName: 'StudentBatches',
  });

  return StudentBatches;
};
