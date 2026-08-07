'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class PageSeo extends Model {
    static associate(models) {
      // No associations — standalone per-page SEO metadata.
    }
  }

  PageSeo.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    // Stable identifier for the public page this SEO belongs to.
    // One of: 'book' | 'coaching' | 'events' | 'blogs' | 'contact' | 'about'.
    // Free-form STRING (not an ENUM) so adding a page needs no migration — the
    // authoritative list is VALID_PAGE_KEYS in pageSeoController.
    pageKey: {
      type: DataTypes.STRING(50),
      allowNull: false,
      unique: true,
    },
    metaTitle: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    metaDescription: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    metaKeywords: {
      type: DataTypes.TEXT,
      allowNull: true,
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
    modelName: 'PageSeo',
    tableName: 'PageSeo',
    timestamps: true,
  });

  return PageSeo;
};
