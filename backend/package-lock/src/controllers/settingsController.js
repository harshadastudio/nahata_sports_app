const { Settings } = require('../models');
const { validatePhoneNumberOrThrow } = require('../utils/phoneValidation');

/**
 * Get all settings
 * @route GET /api/settings
 */
exports.getSettings = async (req, res) => {
  try {
    // Get the first (and only) settings record
    let settings = await Settings.findOne();
    
    // If no settings exist, create default settings
    if (!settings) {
      settings = await Settings.create({
        businessName: 'Nahata Sports Complex',
        location: 'Pune, Maharashtra',
        contactPhone: '9876543210',
        contactEmail: 'info@nahatasports.com',
        website: 'www.nahatasports.com',
        address: '123 Sports Complex Road, Pune - 411001, Maharashtra, India',
        defaultPrice: 1200.00,
        peakHourStart: '17:00:00',
        peakHourEnd: '22:00:00',
        peakHourMultiplier: 1.50,
        weekendMultiplier: 1.30,
        paymentGateway: 'stripe',
        whatsappApiKey: '',
        emailServiceProvider: 'sendgrid',
        emailApiKey: '',
        googleAnalyticsId: ''
      });
    }
    
    res.status(200).json({
      success: true,
      data: settings
    });
  } catch (error) {
    console.error('Error fetching settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch settings',
      error: error.message
    });
  }
};

/**
 * Get the public, storefront-safe subset of settings (no auth required).
 * @route GET /api/settings/public
 */
exports.getPublicSettings = async (req, res) => {
  try {
    const settings = await Settings.findOne();
    res.status(200).json({
      success: true,
      data: {
        businessName: settings?.businessName ?? 'Nahata Sports Complex',
        bookingSummaryBanner: settings?.bookingSummaryBanner ?? null,
        facebookUrl: settings?.facebookUrl ?? null,
        instagramUrl: settings?.instagramUrl ?? null,
        twitterUrl: settings?.twitterUrl ?? null,
      },
    });
  } catch (error) {
    console.error('Error fetching public settings:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch public settings' });
  }
};

/**
 * Update general settings
 * @route PUT /api/settings/general
 */
exports.updateGeneralSettings = async (req, res) => {
  try {
    const { businessName, location, contactPhone, contactEmail, website, address } = req.body;
    
    // Validate phone number if provided
    let cleanedPhone = contactPhone;
    if (contactPhone) {
      cleanedPhone = validatePhoneNumberOrThrow(contactPhone, 'Contact phone');
    }
    
    // Get or create settings
    let settings = await Settings.findOne();
    if (!settings) {
      settings = await Settings.create({});
    }
    
    // Update general settings
    await settings.update({
      businessName: businessName || settings.businessName,
      location: location || settings.location,
      contactPhone: cleanedPhone || settings.contactPhone,
      contactEmail: contactEmail || settings.contactEmail,
      website: website || settings.website,
      address: address || settings.address
    });
    
    res.status(200).json({
      success: true,
      message: 'General settings updated successfully',
      data: settings
    });
  } catch (error) {
    console.error('Error updating general settings:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'Failed to update general settings'
    });
  }
};

/**
 * Update pricing settings
 * @route PUT /api/settings/pricing
 */
exports.updatePricingSettings = async (req, res) => {
  try {
    const { 
      defaultPrice, 
      peakHourStart, 
      peakHourEnd, 
      peakHourMultiplier, 
      weekendMultiplier 
    } = req.body;
    
    // Get or create settings
    let settings = await Settings.findOne();
    if (!settings) {
      settings = await Settings.create({});
    }
    
    // Update pricing settings
    await settings.update({
      defaultPrice: defaultPrice !== undefined ? defaultPrice : settings.defaultPrice,
      peakHourStart: peakHourStart || settings.peakHourStart,
      peakHourEnd: peakHourEnd || settings.peakHourEnd,
      peakHourMultiplier: peakHourMultiplier !== undefined ? peakHourMultiplier : settings.peakHourMultiplier,
      weekendMultiplier: weekendMultiplier !== undefined ? weekendMultiplier : settings.weekendMultiplier
    });
    
    res.status(200).json({
      success: true,
      message: 'Pricing settings updated successfully',
      data: settings
    });
  } catch (error) {
    console.error('Error updating pricing settings:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'Failed to update pricing settings'
    });
  }
};

/**
 * Update integration settings
 * @route PUT /api/settings/integration
 */
exports.updateIntegrationSettings = async (req, res) => {
  try {
    const { 
      paymentGateway, 
      whatsappApiKey, 
      emailServiceProvider, 
      emailApiKey, 
      googleAnalyticsId 
    } = req.body;
    
    // Get or create settings
    let settings = await Settings.findOne();
    if (!settings) {
      settings = await Settings.create({});
    }
    
    // Update integration settings
    await settings.update({
      paymentGateway: paymentGateway || settings.paymentGateway,
      whatsappApiKey: whatsappApiKey !== undefined ? whatsappApiKey : settings.whatsappApiKey,
      emailServiceProvider: emailServiceProvider || settings.emailServiceProvider,
      emailApiKey: emailApiKey !== undefined ? emailApiKey : settings.emailApiKey,
      googleAnalyticsId: googleAnalyticsId !== undefined ? googleAnalyticsId : settings.googleAnalyticsId
    });
    
    res.status(200).json({
      success: true,
      message: 'Integration settings updated successfully',
      data: settings
    });
  } catch (error) {
    console.error('Error updating integration settings:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'Failed to update integration settings'
    });
  }
};

/**
 * Update social media links (footer)
 * @route PUT /api/settings/social
 */
exports.updateSocialSettings = async (req, res) => {
  try {
    const { facebookUrl, instagramUrl, twitterUrl } = req.body;

    // Get or create settings
    let settings = await Settings.findOne();
    if (!settings) {
      settings = await Settings.create({});
    }

    // Empty string clears the link; undefined leaves it unchanged.
    const normalize = (val, current) => {
      if (val === undefined) return current;
      const trimmed = String(val).trim();
      return trimmed === '' ? null : trimmed;
    };

    await settings.update({
      facebookUrl: normalize(facebookUrl, settings.facebookUrl),
      instagramUrl: normalize(instagramUrl, settings.instagramUrl),
      twitterUrl: normalize(twitterUrl, settings.twitterUrl),
    });

    res.status(200).json({
      success: true,
      message: 'Social links updated successfully',
      data: settings
    });
  } catch (error) {
    console.error('Error updating social links:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'Failed to update social links'
    });
  }
};

/**
 * Update all settings at once
 * @route PUT /api/settings
 */
exports.updateSettings = async (req, res) => {
  try {
    const updateData = req.body;
    
    // Validate phone number if provided
    if (updateData.contactPhone) {
      updateData.contactPhone = validatePhoneNumberOrThrow(updateData.contactPhone, 'Contact phone');
    }
    
    // Get or create settings
    let settings = await Settings.findOne();
    if (!settings) {
      settings = await Settings.create(updateData);
    } else {
      await settings.update(updateData);
    }
    
    res.status(200).json({
      success: true,
      message: 'Settings updated successfully',
      data: settings
    });
  } catch (error) {
    console.error('Error updating settings:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'Failed to update settings'
    });
  }
};
