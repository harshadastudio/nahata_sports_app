/**
 * Email Notification Service
 * Sends transactional emails for coaching enquiry events
 */

const nodemailer = require('nodemailer');
const axios = require('axios');

/**
 * Download a remote QR PNG and return it as a nodemailer inline attachment so
 * the QR renders reliably in the email body.
 *
 * Why: hotlinked external images (api.qrserver.com) often fail to display —
 * Gmail blocks remote images for spam/promo messages and proxies the rest, and
 * the QR host may be unreachable from the recipient's client. An inline (cid)
 * image is embedded in the message itself, so it always renders. Falls back to
 * the original remote URL if the download fails.
 *
 * @param {string} qrCodeUrl
 * @param {string} cid - content-id used in the <img src="cid:..."> reference
 * @returns {Promise<{ src: string, attachments: Array }>}
 */
const buildQrImage = async (qrCodeUrl, cid = 'qr-code') => {
  if (!qrCodeUrl) return { src: '', attachments: [] };
  try {
    const resp = await axios.get(qrCodeUrl, { responseType: 'arraybuffer', timeout: 10000 });
    return {
      src: `cid:${cid}`,
      attachments: [{
        filename: 'qr-code.png',
        content: Buffer.from(resp.data),
        contentType: 'image/png',
        cid,
      }],
    };
  } catch (err) {
    console.error('⚠️ [EmailService] QR download failed, using remote URL:', err.message);
    return { src: qrCodeUrl, attachments: [] };
  }
};

// Create reusable transporter
const createTransporter = () => {
  const port = parseInt(process.env.EMAIL_PORT || '465');
  // Use explicit EMAIL_SECURE if provided, otherwise infer from the port
  // (465 = implicit SSL/TLS, anything else = STARTTLS).
  const secure = process.env.EMAIL_SECURE
    ? process.env.EMAIL_SECURE === 'true'
    : port === 465;

  return nodemailer.createTransport({
    host: process.env.EMAIL_HOST || 'smtp.gmail.com',
    port,
    secure,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });
};

const FROM_ADDRESS = process.env.EMAIL_FROM || `Nahata Sports <${process.env.EMAIL_USER}>`;
const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:3000';
// Admin address that should be copied on booking confirmations.
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'nahatasports@gmail.com';

/**
 * Send email when a user submits a coaching enquiry
 */
exports.sendEnquirySubmittedEmail = async ({ to, name, programName, sportName, coachName, referenceNumber }) => {
  try {
    const transporter = createTransporter();

    const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme" content="light" />
        <title>Coaching Enquiry Received</title>
        <style>
          body { margin: 0; padding: 0; background: #eef1f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; }
          table { border-collapse: collapse; }
          .wrapper { width: 100%; background: #eef1f5; padding: 32px 16px; }
          .card { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 14px; border: 1px solid #e5e9f1; overflow: hidden; }
          .header { background-color: #0f172a; background-image: linear-gradient(135deg, #0f172a 0%, #1e2c44 100%); padding: 38px 40px 30px; text-align: center; }
          .eyebrow { font-size: 11px; font-weight: 700; letter-spacing: 3px; color: #8fa0bd; text-transform: uppercase; margin: 0; }
          .icon-circle { width: 46px; height: 46px; border-radius: 50%; background-color: #22c55e; color: #ffffff; font-size: 20px; font-weight: 700; line-height: 46px; text-align: center; margin: 18px auto 0; }
          .h1 { font-size: 21px; font-weight: 800; color: #ffffff; letter-spacing: -0.3px; margin: 16px 0 4px; }
          .header-sub { font-size: 13px; color: #94a3b8; margin: 0; }
          .accent { height: 3px; background-color: #d97706; background-image: linear-gradient(90deg, #f59e0b, #d97706); font-size: 0; line-height: 0; }
          .body { padding: 40px; }
          .greeting { font-size: 17px; font-weight: 700; color: #0f172a; margin: 0 0 12px; }
          .text { font-size: 14px; color: #5b6472; line-height: 1.7; margin: 0 0 26px; }
          .ref-card { background: #f8fafc; border: 1px solid #e5e9f1; border-radius: 12px; padding: 20px 24px; text-align: center; }
          .ref-label { font-size: 11px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.2px; margin: 0 0 8px; }
          .ref-number { font-size: 20px; font-weight: 800; color: #0f172a; letter-spacing: 1.5px; font-family: 'SFMono-Regular', Consolas, monospace; margin: 0; }
          .section-title { font-size: 11px; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.2px; margin: 0 0 14px; }
          .detail-table td { padding: 11px 0; border-bottom: 1px solid #eef1f5; font-size: 13px; }
          .detail-table tr:last-child td { border-bottom: none; }
          .detail-label { color: #64748b; font-weight: 500; }
          .detail-value { color: #0f172a; font-weight: 700; text-align: right; }
          .status-pill { display: inline-block; background: #eff6ff; color: #1d4ed8; font-size: 11px; font-weight: 700; padding: 3px 10px; border-radius: 20px; }
          .step-num { width: 26px; height: 26px; border-radius: 50%; border: 1.5px solid #0f172a; color: #0f172a; font-size: 11px; font-weight: 800; text-align: center; line-height: 23px; }
          .step-text { font-size: 13px; color: #5b6472; line-height: 1.55; }
          .btn-td { border-radius: 9px; background-color: #0f172a; }
          .btn { display: inline-block; padding: 14px 30px; font-size: 13px; font-weight: 700; color: #ffffff; text-decoration: none; letter-spacing: 0.3px; }
          .footer { background: #f8fafc; padding: 26px 40px; text-align: center; border-top: 1px solid #e5e9f1; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; line-height: 1.7; }
          @media (max-width: 480px) {
            .body, .header, .footer { padding-left: 24px !important; padding-right: 24px !important; }
          }
        </style>
      </head>
      <body>
        <div class="wrapper">
          <table role="presentation" class="card" width="100%" cellpadding="0" cellspacing="0">
            <tr><td class="header">
              <p class="eyebrow">Nahata Sports Complex</p>
              <div class="icon-circle">&#10003;</div>
              <p class="h1">Enquiry Received</p>
              <p class="header-sub">Professional Sports Coaching</p>
            </td></tr>
            <tr><td class="accent">&nbsp;</td></tr>
            <tr><td class="body">
              <p class="greeting">Hi ${name},</p>
              <p class="text">
                Thank you for your interest in our coaching program. We've received your enquiry and our team will review it shortly — here's a summary for your records.
              </p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 28px;">
                <tr><td class="ref-card">
                  <p class="ref-label">Your Reference Number</p>
                  <p class="ref-number">${referenceNumber}</p>
                </td></tr>
              </table>

              <p class="section-title">Enquiry Details</p>
              <table role="presentation" class="detail-table" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 28px;">
                <tr><td class="detail-label">Program</td><td class="detail-value">${programName || 'N/A'}</td></tr>
                ${sportName ? `<tr><td class="detail-label">Sport</td><td class="detail-value">${sportName}</td></tr>` : ''}
                ${coachName ? `<tr><td class="detail-label">Coach</td><td class="detail-value">${coachName}</td></tr>` : ''}
                <tr><td class="detail-label">Status</td><td class="detail-value"><span class="status-pill">Pending Review</span></td></tr>
              </table>

              <p class="section-title">What Happens Next</p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 30px;">
                <tr>
                  <td width="26" valign="top" style="padding-bottom: 16px;"><div class="step-num">1</div></td>
                  <td valign="top" style="padding-bottom: 16px; padding-left: 14px;"><div class="step-text">Our team reviews your enquiry, usually within 24 hours</div></td>
                </tr>
                <tr>
                  <td width="26" valign="top" style="padding-bottom: 16px;"><div class="step-num">2</div></td>
                  <td valign="top" style="padding-bottom: 16px; padding-left: 14px;"><div class="step-text">We contact you to confirm availability and details</div></td>
                </tr>
                <tr>
                  <td width="26" valign="top"><div class="step-num">3</div></td>
                  <td valign="top" style="padding-left: 14px;"><div class="step-text">Once approved, you'll receive a confirmation email with enrollment details</div></td>
                </tr>
              </table>

              <table role="presentation" cellpadding="0" cellspacing="0" align="center" style="margin: 0 auto 28px;">
                <tr><td class="btn-td"><a href="${FRONTEND_URL}/dashboard/coaching-enquiries" class="btn">Track Your Enquiry</a></td></tr>
              </table>

              <p class="text" style="margin-bottom: 0;">
                Questions? Just reply to this email — we're happy to help.
              </p>
            </td></tr>
            <tr><td class="footer">
              <p><strong>Nahata Sports Complex</strong> · This is an automated notification.</p>
              <p style="margin-top: 6px;">© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
            </td></tr>
          </table>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `[${referenceNumber}] Coaching Enquiry Received — Nahata Sports`,
      html,
    });

    console.log(`✅ [EmailService] Enquiry submitted email sent to ${to}`);
  } catch (error) {
    // Log but don't throw — email failure should not break the API response
    console.error(`❌ [EmailService] Failed to send enquiry submitted email:`, error.message);
  }
};

/**
 * Notify the assigned coach when a student submits a new enquiry for them.
 * Only called when an enquiry has a selected coach (coachId).
 */
exports.sendCoachNewEnquiryEmail = async ({ to, coachName, studentName, studentEmail, studentPhone, programName, sportName, message, referenceNumber }) => {
  try {
    const transporter = createTransporter();

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>New Coaching Enquiry</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #1e293b 0%, #334155 100%); padding: 40px 40px 32px; text-align: center; }
          .header h1 { color: #ffffff; font-size: 24px; font-weight: 800; margin: 0 0 8px; letter-spacing: -0.5px; }
          .header p { color: #94a3b8; font-size: 14px; margin: 0; }
          .badge { display: inline-block; background: #3b82f6; color: #fff; font-size: 11px; font-weight: 700; padding: 4px 12px; border-radius: 20px; letter-spacing: 0.5px; margin-top: 16px; }
          .body { padding: 40px; }
          .greeting { font-size: 18px; font-weight: 700; color: #1e293b; margin-bottom: 12px; }
          .text { font-size: 14px; color: #64748b; line-height: 1.7; margin-bottom: 24px; }
          .ref-box { background: #f1f5f9; border: 2px dashed #cbd5e1; border-radius: 12px; padding: 20px; text-align: center; margin-bottom: 28px; }
          .ref-label { font-size: 11px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px; }
          .ref-number { font-size: 22px; font-weight: 900; color: #1e293b; letter-spacing: 2px; }
          .details-card { background: #f8fafc; border-radius: 12px; padding: 24px; margin-bottom: 28px; }
          .details-card h3 { font-size: 12px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 16px; }
          .detail-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e2e8f0; }
          .detail-row:last-child { border-bottom: none; }
          .detail-label { font-size: 13px; color: #64748b; font-weight: 500; }
          .detail-value { font-size: 13px; color: #1e293b; font-weight: 700; }
          .message-card { background: #fffbeb; border: 1px solid #fde68a; border-radius: 12px; padding: 20px 24px; margin-bottom: 28px; }
          .message-card h3 { font-size: 12px; font-weight: 700; color: #b45309; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 8px; }
          .message-card p { font-size: 14px; color: #78350f; line-height: 1.6; margin: 0; }
          .cta-btn { display: block; background: #1e293b; color: #ffffff; text-decoration: none; text-align: center; padding: 14px 32px; border-radius: 10px; font-size: 13px; font-weight: 700; letter-spacing: 0.5px; margin-bottom: 28px; }
          .footer { background: #f8fafc; padding: 24px 40px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Nahata Sports</h1>
            <p>Professional Sports Coaching</p>
            <div class="badge">📩 New Enquiry Assigned</div>
          </div>
          <div class="body">
            <p class="greeting">Hi ${coachName || 'Coach'},</p>
            <p class="text">
              You have a new coaching enquiry. ${studentName || 'A student'} has expressed interest and is waiting to hear back. Please review the details below and follow up.
            </p>

            <div class="ref-box">
              <div class="ref-label">Reference Number</div>
              <div class="ref-number">${referenceNumber}</div>
            </div>

            <div class="details-card">
              <h3>Student Details</h3>
              <div class="detail-row">
                <span class="detail-label">Name</span>
                <span class="detail-value">${studentName || 'N/A'}</span>
              </div>
              ${studentPhone ? `<div class="detail-row"><span class="detail-label">Phone</span><span class="detail-value">${studentPhone}</span></div>` : ''}
              ${studentEmail ? `<div class="detail-row"><span class="detail-label">Email</span><span class="detail-value">${studentEmail}</span></div>` : ''}
              <div class="detail-row">
                <span class="detail-label">Program</span>
                <span class="detail-value">${programName || 'N/A'}</span>
              </div>
              ${sportName ? `<div class="detail-row"><span class="detail-label">Sport</span><span class="detail-value">${sportName}</span></div>` : ''}
            </div>

            ${message ? `
            <div class="message-card">
              <h3>Message from Student</h3>
              <p>${message}</p>
            </div>
            ` : ''}

            <a href="${FRONTEND_URL}/dashboard/coaching-enquiries" class="cta-btn">
              View Enquiry →
            </a>

            <p class="text" style="margin-bottom: 0;">
              Please reach out to the student at your earliest convenience.
            </p>
          </div>
          <div class="footer">
            <p>Nahata Sports Complex · This is an automated email, please do not reply directly.</p>
            <p style="margin-top: 8px;">© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `[${referenceNumber}] New Coaching Enquiry — ${studentName || 'Student'}`,
      html,
    });

    console.log(`✅ [EmailService] Coach new-enquiry email sent to ${to}`);
  } catch (error) {
    // Log but don't throw — email failure should not break the API response
    console.error(`❌ [EmailService] Failed to send coach new-enquiry email:`, error.message);
  }
};

/**
 * Send email when admin approves a coaching enquiry
 */
exports.sendEnquiryApprovedEmail = async ({ to, name, programName, sportName, coachName, coachPhone, coachEmail, referenceNumber, programPrice, programDuration }) => {
  try {
    const transporter = createTransporter();

    const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme" content="light" />
        <title>Coaching Enrollment Approved</title>
        <style>
          body { margin: 0; padding: 0; background: #eef1f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; }
          table { border-collapse: collapse; }
          .wrapper { width: 100%; background: #eef1f5; padding: 32px 16px; }
          .card { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 14px; border: 1px solid #e5e9f1; overflow: hidden; }
          .header { background-color: #15803d; background-image: linear-gradient(135deg, #15803d 0%, #16803e 100%); padding: 38px 40px 30px; text-align: center; }
          .eyebrow { font-size: 11px; font-weight: 700; letter-spacing: 3px; color: #bbf7d0; text-transform: uppercase; margin: 0; }
          .icon-circle { width: 46px; height: 46px; border-radius: 50%; background-color: #ffffff; color: #15803d; font-size: 20px; font-weight: 700; line-height: 46px; text-align: center; margin: 18px auto 0; }
          .h1 { font-size: 21px; font-weight: 800; color: #ffffff; letter-spacing: -0.3px; margin: 16px 0 4px; }
          .header-sub { font-size: 13px; color: #bbf7d0; margin: 0; }
          .accent { height: 3px; background-color: #d97706; background-image: linear-gradient(90deg, #f59e0b, #d97706); font-size: 0; line-height: 0; }
          .body { padding: 40px; }
          .greeting { font-size: 17px; font-weight: 700; color: #0f172a; margin: 0 0 20px; }
          .text { font-size: 14px; color: #5b6472; line-height: 1.7; margin: 0 0 26px; }
          .congrats-box { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 12px; padding: 16px 22px; text-align: center; margin-bottom: 26px; }
          .congrats-box p { font-size: 14px; font-weight: 700; color: #15803d; margin: 0; }
          .ref-card { background: #f8fafc; border: 1px solid #e5e9f1; border-radius: 12px; padding: 18px 24px; text-align: center; }
          .ref-label { font-size: 11px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.2px; margin: 0 0 6px; }
          .ref-number { font-size: 18px; font-weight: 800; color: #0f172a; letter-spacing: 1.5px; font-family: 'SFMono-Regular', Consolas, monospace; margin: 0; }
          .section-title { font-size: 11px; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.2px; margin: 0 0 14px; }
          .detail-table td { padding: 11px 0; border-bottom: 1px solid #eef1f5; font-size: 13px; }
          .detail-table tr:last-child td { border-bottom: none; }
          .detail-label { color: #64748b; font-weight: 500; }
          .detail-value { color: #0f172a; font-weight: 700; text-align: right; }
          .status-pill { display: inline-block; background: #f0fdf4; color: #15803d; font-size: 11px; font-weight: 700; padding: 3px 10px; border-radius: 20px; }
          .coach-card { background-color: #0f172a; border-radius: 12px; padding: 22px 24px; }
          .coach-label { font-size: 10px; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.3px; margin: 0 0 10px; }
          .coach-name { font-size: 16px; font-weight: 800; color: #ffffff; margin: 0 0 8px; }
          .coach-contact { font-size: 12px; color: #94a3b8; line-height: 1.8; }
          .coach-contact a { color: #94a3b8; text-decoration: none; }
          .btn-td { border-radius: 9px; background-color: #15803d; }
          .btn { display: inline-block; padding: 14px 30px; font-size: 13px; font-weight: 700; text-decoration: none; letter-spacing: 0.3px; color: #ffffff !important; }
          .footer { background: #f8fafc; padding: 26px 40px; text-align: center; border-top: 1px solid #e5e9f1; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; line-height: 1.7; }
          @media (max-width: 480px) {
            .body, .header, .footer { padding-left: 24px !important; padding-right: 24px !important; }
          }
        </style>
      </head>
      <body>
        <div class="wrapper">
          <table role="presentation" class="card" width="100%" cellpadding="0" cellspacing="0">
            <tr><td class="header">
              <p class="eyebrow">Nahata Sports Complex</p>
              <div class="icon-circle">&#10003;</div>
              <p class="h1">Enrollment Approved</p>
              <p class="header-sub">Professional Sports Coaching</p>
            </td></tr>
            <tr><td class="accent">&nbsp;</td></tr>
            <tr><td class="body">
              <p class="greeting">Congratulations, ${name}!</p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 20px;">
                <tr><td class="congrats-box">
                  <p>Your coaching enrollment has been approved — welcome to the team!</p>
                </td></tr>
              </table>

              <p class="text">
                We're excited to have you join our coaching program. Please find your enrollment details below.
              </p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 28px;">
                <tr><td class="ref-card">
                  <p class="ref-label">Reference Number</p>
                  <p class="ref-number">${referenceNumber}</p>
                </td></tr>
              </table>

              <p class="section-title">Enrollment Details</p>
              <table role="presentation" class="detail-table" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 28px;">
                <tr><td class="detail-label">Program</td><td class="detail-value">${programName || 'N/A'}</td></tr>
                ${sportName ? `<tr><td class="detail-label">Sport</td><td class="detail-value">${sportName}</td></tr>` : ''}
                ${programDuration ? `<tr><td class="detail-label">Duration</td><td class="detail-value">${programDuration}</td></tr>` : ''}
                ${programPrice ? `<tr><td class="detail-label">Monthly Fee</td><td class="detail-value" style="color:#15803d;">₹${programPrice}</td></tr>` : ''}
                <tr><td class="detail-label">Status</td><td class="detail-value"><span class="status-pill">Approved</span></td></tr>
              </table>

              ${coachName ? `
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 28px;">
                <tr><td class="coach-card">
                  <p class="coach-label">Your Coach</p>
                  <p class="coach-name">${coachName}</p>
                  <div class="coach-contact">
                    ${coachPhone ? `${coachPhone}` : ''}
                    ${coachPhone && coachEmail ? '&nbsp;&nbsp;·&nbsp;&nbsp;' : ''}
                    ${coachEmail ? `<a href="mailto:${coachEmail}">${coachEmail}</a>` : ''}
                  </div>
                </td></tr>
              </table>
              ` : ''}

              <table role="presentation" cellpadding="0" cellspacing="0" align="center" style="margin: 0 auto 28px;">
                <tr><td class="btn-td"><a href="${FRONTEND_URL}/dashboard/coaching-enquiries" class="btn" style="color:#ffffff;">View My Enrollment</a></td></tr>
              </table>

              <p class="text" style="margin-bottom: 0;">
                Please visit the sports complex to complete any remaining formalities. Our team will reach out to you with the schedule details.
              </p>
            </td></tr>
            <tr><td class="footer">
              <p><strong>Nahata Sports Complex</strong> · This is an automated notification.</p>
              <p style="margin-top: 6px;">© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
            </td></tr>
          </table>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `[${referenceNumber}] 🎉 Your Coaching Enrollment is Approved — Nahata Sports`,
      html,
    });

    console.log(`✅ [EmailService] Approval email sent to ${to}`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send approval email:`, error.message);
  }
};

/**
 * Send email when admin rejects a coaching enquiry
 */
exports.sendEnquiryRejectedEmail = async ({ to, name, programName, referenceNumber, reason }) => {
  try {
    const transporter = createTransporter();

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #1e293b 0%, #334155 100%); padding: 40px; text-align: center; }
          .header h1 { color: #ffffff; font-size: 24px; font-weight: 800; margin: 0 0 8px; }
          .header p { color: #94a3b8; font-size: 14px; margin: 0; }
          .body { padding: 40px; }
          .greeting { font-size: 18px; font-weight: 700; color: #1e293b; margin-bottom: 12px; }
          .text { font-size: 14px; color: #64748b; line-height: 1.7; margin-bottom: 24px; }
          .ref-box { background: #f1f5f9; border-radius: 10px; padding: 14px; text-align: center; margin-bottom: 24px; }
          .ref-label { font-size: 11px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; }
          .ref-number { font-size: 18px; font-weight: 900; color: #1e293b; }
          .cta-btn { display: block; background: #1e293b; color: #ffffff; text-decoration: none; text-align: center; padding: 14px 32px; border-radius: 10px; font-size: 13px; font-weight: 700; margin-bottom: 24px; }
          .footer { background: #f8fafc; padding: 24px 40px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Nahata Sports</h1>
            <p>Professional Sports Coaching</p>
          </div>
          <div class="body">
            <p class="greeting">Hi ${name},</p>
            <p class="text">
              Thank you for your interest in our <strong>${programName || 'coaching program'}</strong>. 
              Unfortunately, we are unable to process your enquiry at this time.
            </p>
            ${reason ? `<p class="text"><strong>Reason:</strong> ${reason}</p>` : ''}
            <div class="ref-box">
              <div class="ref-label">Reference</div>
              <div class="ref-number">${referenceNumber}</div>
            </div>
            <p class="text">
              We encourage you to explore our other programs or contact us directly for more information. We'd love to help you find the right fit.
            </p>
            <a href="${FRONTEND_URL}/coaching" class="cta-btn">Browse Other Programs →</a>
          </div>
          <div class="footer">
            <p>© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `[${referenceNumber}] Update on Your Coaching Enquiry — Nahata Sports`,
      html,
    });

    console.log(`✅ [EmailService] Rejection email sent to ${to}`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send rejection email:`, error.message);
  }
};

/**
 * Send confirmation email when user submits contact form
 */
exports.sendContactFormConfirmation = async ({ to, name, referenceNumber, subject }) => {
  try {
    const transporter = createTransporter();

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Contact Form Received</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #1e293b 0%, #334155 100%); padding: 40px 40px 32px; text-align: center; }
          .header h1 { color: #ffffff; font-size: 24px; font-weight: 800; margin: 0 0 8px; letter-spacing: -0.5px; }
          .header p { color: #94a3b8; font-size: 14px; margin: 0; }
          .badge { display: inline-block; background: #22c55e; color: #fff; font-size: 11px; font-weight: 700; padding: 4px 12px; border-radius: 20px; letter-spacing: 0.5px; margin-top: 16px; }
          .body { padding: 40px; }
          .greeting { font-size: 18px; font-weight: 700; color: #1e293b; margin-bottom: 12px; }
          .text { font-size: 14px; color: #64748b; line-height: 1.7; margin-bottom: 24px; }
          .ref-box { background: #f1f5f9; border: 2px dashed #cbd5e1; border-radius: 12px; padding: 20px; text-align: center; margin-bottom: 28px; }
          .ref-label { font-size: 11px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px; }
          .ref-number { font-size: 22px; font-weight: 900; color: #1e293b; letter-spacing: 2px; }
          .details-card { background: #f8fafc; border-radius: 12px; padding: 24px; margin-bottom: 28px; }
          .details-card h3 { font-size: 12px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 16px; }
          .detail-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e2e8f0; }
          .detail-row:last-child { border-bottom: none; }
          .detail-label { font-size: 13px; color: #64748b; font-weight: 500; }
          .detail-value { font-size: 13px; color: #1e293b; font-weight: 700; }
          .footer { background: #f8fafc; padding: 24px 40px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Nahata Sports</h1>
            <p>Professional Sports Complex</p>
            <div class="badge">✓ Message Received</div>
          </div>
          <div class="body">
            <p class="greeting">Hi ${name},</p>
            <p class="text">
              Thank you for contacting us! We've received your message and our team will get back to you within 24-48 hours.
            </p>

            <div class="ref-box">
              <div class="ref-label">Your Reference Number</div>
              <div class="ref-number">${referenceNumber}</div>
            </div>

            <div class="details-card">
              <h3>Message Details</h3>
              <div class="detail-row">
                <span class="detail-label">Subject</span>
                <span class="detail-value">${subject}</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">Status</span>
                <span class="detail-value" style="color: #3b82f6;">Under Review</span>
              </div>
            </div>

            <p class="text" style="margin-bottom: 0;">
              If you have any urgent queries, feel free to call us directly at our sports complex.
            </p>
          </div>
          <div class="footer">
            <p>Nahata Sports Complex · This is an automated email, please do not reply directly.</p>
            <p style="margin-top: 8px;">© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `[${referenceNumber}] We've Received Your Message — Nahata Sports`,
      html,
    });

    console.log(`✅ [EmailService] Contact form confirmation sent to ${to}`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send contact confirmation:`, error.message);
  }
};

module.exports.transporter = createTransporter();

/**
 * Send booking confirmation email with QR code after successful payment.
 *
 * @param {object} opts
 * @param {string} opts.to           - Recipient email
 * @param {string} opts.name         - User's name
 * @param {string} opts.passCode     - e.g. "BOOK-2026-000042"
 * @param {string} opts.qrCodeUrl    - QR image URL
 * @param {string} opts.sportName    - e.g. "Cricket"
 * @param {string} opts.courtName    - e.g. "Court A"
 * @param {string} opts.venueName    - e.g. "Nahata Sports Complex"
 * @param {string} opts.date         - "2026-05-10"
 * @param {string} opts.startTime    - "06:00:00"
 * @param {string} opts.endTime      - "07:00:00"
 * @param {number} opts.totalAmount  - e.g. 500
 * @param {number} opts.maxPersons   - e.g. 12 (court capacity)
 * @param {string} opts.bookingRef   - e.g. "#NSC-000042"
 */
/**
 * Email a visitor pass with its QR code (inline).
 * @param {object} o
 * @param {string} o.to          - recipient email
 * @param {string} o.name        - visitor / recipient name
 * @param {string} o.passCode    - pass number (e.g. VP-20260627-A3F9)
 * @param {string} o.qrCodeUrl   - QR image URL stored on the pass
 * @param {string} [o.purpose]   - visit purpose
 * @param {string} [o.complexName]
 * @param {Date|string} [o.validFrom]
 * @param {Date|string} [o.validUntil]
 */
exports.sendVisitorPassEmail = async ({ to, name, passCode, qrCodeUrl, purpose, complexName, validFrom, validUntil }) => {
  try {
    const transporter = createTransporter();
    const qr = await buildQrImage(qrCodeUrl, 'visitor-qr');
    const fmt = (d) => (d ? new Date(d).toLocaleString('en-IN') : '—');

    const html = `
      <!DOCTYPE html><html><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <style>
        body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f8fafc;margin:0;padding:0;}
        .container{max-width:600px;margin:40px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08);}
        .header{background:linear-gradient(135deg,#1e3a8a 0%,#2563eb 100%);padding:32px 40px;text-align:center;}
        .header h1{color:#fff;font-size:22px;font-weight:800;margin:0;} .header p{color:#bfdbfe;font-size:13px;margin:6px 0 0;}
        .body{padding:32px 40px;text-align:center;}
        .greeting{font-size:18px;font-weight:700;color:#1e293b;margin-bottom:6px;text-align:left;}
        .text{font-size:14px;color:#64748b;line-height:1.7;margin-bottom:18px;text-align:left;}
        .qr{margin:8px auto 18px;width:240px;height:240px;border:1px solid #e2e8f0;border-radius:12px;padding:10px;}
        .qr img{width:100%;height:100%;object-fit:contain;}
        .creds{background:#f1f5f9;border:1px solid #cbd5e1;border-radius:12px;padding:4px 20px;text-align:left;}
        .row{display:flex;justify-content:space-between;padding:11px 0;border-bottom:1px solid #e2e8f0;font-size:13px;} .row:last-child{border-bottom:none;}
        .label{color:#64748b;font-weight:600;} .value{color:#0f172a;font-weight:700;}
        .footer{background:#f8fafc;padding:22px 40px;text-align:center;border-top:1px solid #e2e8f0;} .footer p{font-size:12px;color:#94a3b8;margin:0;}
      </style></head>
      <body><div class="container">
        <div class="header"><h1>Nahata Sports</h1><p>Visitor Pass</p></div>
        <div class="body">
          <p class="greeting">Hello, ${name || 'Visitor'}!</p>
          <p class="text">Here is your visitor pass. Show this QR code at the gate for entry.</p>
          <div class="qr"><img src="${qr.src}" alt="Visitor Pass QR" /></div>
          <div class="creds">
            <div class="row"><span class="label">Pass Number</span><span class="value">${passCode}</span></div>
            ${purpose ? `<div class="row"><span class="label">Purpose</span><span class="value">${purpose}</span></div>` : ''}
            ${complexName ? `<div class="row"><span class="label">Complex</span><span class="value">${complexName}</span></div>` : ''}
            <div class="row"><span class="label">Valid From</span><span class="value">${fmt(validFrom)}</span></div>
            <div class="row"><span class="label">Valid Until</span><span class="value">${fmt(validUntil)}</span></div>
          </div>
        </div>
        <div class="footer"><p>Nahata Sports Complex · This pass is single-use and valid only for the holder.</p></div>
      </div></body></html>`;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `Your Nahata Sports Visitor Pass — ${passCode}`,
      html,
      attachments: qr.attachments,
    });
    console.log(`✅ [EmailService] Visitor pass email sent to ${to}`);
  } catch (error) {
    console.error('❌ [EmailService] Failed to send visitor pass email:', error.message);
    throw error;
  }
};

exports.sendBookingConfirmationEmail = async ({
  to, name, passCode, qrCodeUrl,
  sportName, courtName, venueName,
  date, startTime, endTime,
  totalAmount, maxPersons, bookingRef,
}) => {
  try {
    const transporter = createTransporter();

    // Format date "2026-05-10" → "10 May 2026"
    const fmtDate = (d) => {
      if (!d) return '';
      const dt = new Date(d + 'T00:00:00');
      return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    };

    // Format time "06:00:00" → "6:00 AM"
    const fmtTime = (t) => {
      if (!t) return '';
      const [h, m] = t.split(':').map(Number);
      const ampm = h >= 12 ? 'PM' : 'AM';
      const hour = h % 12 || 12;
      return `${hour}:${String(m).padStart(2, '0')} ${ampm}`;
    };

    const timeStr = `${fmtTime(startTime)} – ${fmtTime(endTime)}`;
    const capacityNote = maxPersons
      ? `This pass is valid for <strong>up to ${maxPersons} person${maxPersons > 1 ? 's' : ''}</strong>. You may share this QR with your group (max ${maxPersons}).`
      : 'Please present this QR code at the entry gate.';

    // Embed the QR inline so it always renders (no remote-image blocking).
    const qr = await buildQrImage(qrCodeUrl, 'booking-qr');

    const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme" content="light" />
        <title>Booking Confirmed — ${sportName}</title>
        <style>
          body { margin: 0; padding: 0; background: #eef1f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; }
          table { border-collapse: collapse; }
          .wrapper { width: 100%; background: #eef1f5; padding: 32px 16px; }
          .ticket { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e5e9f1; overflow: hidden; }
          .header { background-color: #0f172a; background-image: linear-gradient(135deg, #0f172a 0%, #1e2c44 100%); padding: 34px 36px 26px; text-align: center; }
          .header-logo { font-size: 11px; font-weight: 700; color: #8fa0bd; letter-spacing: 3px; text-transform: uppercase; margin: 0 0 12px; }
          .h1 { color: #ffffff; font-size: 21px; font-weight: 800; margin: 0 0 6px; letter-spacing: -0.4px; }
          .header p { color: #94a3b8; font-size: 13px; margin: 0; }
          .badge { display: inline-block; background-color: #16a34a; color: #fff; font-size: 10px; font-weight: 800; padding: 4px 14px; border-radius: 20px; letter-spacing: 1px; text-transform: uppercase; margin-top: 14px; }
          .accent { height: 3px; background-color: #d97706; background-image: linear-gradient(90deg, #f59e0b, #d97706); font-size: 0; line-height: 0; }
          .body { padding: 32px 36px; }
          .greeting { font-size: 16px; font-weight: 700; color: #0f172a; margin: 0 0 8px; }
          .sub { font-size: 13px; color: #5b6472; margin: 0 0 28px; line-height: 1.65; }
          .qr-card { background: #f8fafc; border: 1px solid #e5e9f1; border-radius: 14px; padding: 24px; text-align: center; margin-bottom: 24px; }
          .qr-card img { width: 190px; height: 190px; border: 1px solid #e5e9f1; border-radius: 12px; padding: 8px; background: #fff; }
          .pass-code { font-size: 14px; font-weight: 800; color: #0f172a; letter-spacing: 2px; margin-top: 14px; font-family: 'SFMono-Regular', Consolas, monospace; }
          .pass-hint { font-size: 11px; color: #94a3b8; margin-top: 4px; text-transform: uppercase; letter-spacing: 0.8px; }
          .section-title { font-size: 10px; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.5px; margin: 0 0 14px; }
          .detail-table td { padding: 9px 0; border-bottom: 1px solid #eef1f5; font-size: 12px; }
          .detail-table tr:last-child td { border-bottom: none; }
          .label { color: #64748b; font-weight: 500; }
          .value { color: #0f172a; font-weight: 800; text-align: right; }
          .callout { border-radius: 8px; padding: 13px 16px; font-size: 12px; line-height: 1.6; margin-bottom: 16px; }
          .callout-blue { background: #f5f9ff; border-left: 3px solid #2563eb; color: #1e3a5f; }
          .callout-amber { background: #fffbf0; border-left: 3px solid #d97706; color: #5c4108; }
          .footer { background: #f8fafc; padding: 22px 36px; text-align: center; border-top: 1px solid #e5e9f1; }
          .footer p { font-size: 11px; color: #94a3b8; margin: 0; line-height: 1.7; }
          @media (max-width: 480px) {
            .body, .header, .footer { padding-left: 22px !important; padding-right: 22px !important; }
          }
        </style>
      </head>
      <body>
        <div class="wrapper">
          <table role="presentation" class="ticket" width="100%" cellpadding="0" cellspacing="0">
            <tr><td class="header">
              <p class="header-logo">Nahata Sports Complex</p>
              <p class="h1">${sportName} Booking</p>
              <p>${courtName}${venueName ? ' · ' + venueName : ''}</p>
              <div class="badge">Booking Confirmed</div>
            </td></tr>
            <tr><td class="accent">&nbsp;</td></tr>
            <tr><td class="body">
              <p class="greeting">Hi ${name},</p>
              <p class="sub">
                Your court booking is confirmed and payment has been received. ${capacityNote}
              </p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 24px;">
                <tr><td class="qr-card">
                  <img src="${qr.src}" alt="Booking QR Code" width="190" height="190" />
                  <div class="pass-code">${passCode}</div>
                  <div class="pass-hint">Booking Pass Code</div>
                </td></tr>
              </table>

              <p class="section-title">Booking Details</p>
              <table role="presentation" class="detail-table" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 24px;">
                <tr><td class="label">Reference</td><td class="value" style="font-family:'SFMono-Regular',Consolas,monospace;">${bookingRef}</td></tr>
                <tr><td class="label">Sport</td><td class="value">${sportName}</td></tr>
                <tr><td class="label">Court</td><td class="value">${courtName}</td></tr>
                ${venueName ? `<tr><td class="label">Venue</td><td class="value">${venueName}</td></tr>` : ''}
                <tr><td class="label">Date</td><td class="value">${fmtDate(date)}</td></tr>
                <tr><td class="label">Time</td><td class="value">${timeStr}</td></tr>
                <tr><td class="label">Amount Paid</td><td class="value" style="color:#15803d;">₹${parseFloat(totalAmount || 0).toLocaleString('en-IN')}</td></tr>
                ${maxPersons ? `<tr><td class="label">Pass Valid For</td><td class="value" style="color:#1d4ed8;">${maxPersons} Person${maxPersons > 1 ? 's' : ''}</td></tr>` : ''}
              </table>

              ${maxPersons && maxPersons > 1 ? `
              <div class="callout callout-blue">
                <strong>Group Pass:</strong> This QR code is valid for up to <strong>${maxPersons} people</strong>. You may share this email with your group — each person is scanned in at the entry gate.
              </div>` : ''}

              <div class="callout callout-amber" style="margin-bottom: 0;">
                <strong>Please note:</strong> Arrive 10 minutes before your slot and present this QR code at the entry gate. The pass expires at the end of your booked time slot.
              </div>
            </td></tr>
            <tr><td class="footer">
              <p>Nahata Sports Complex · This is an automated email.</p>
              <p>© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
            </td></tr>
          </table>
        </div>
      </body>
      </html>
    `;

    const text =
`Booking Confirmed — ${sportName}

Hi ${name},
Your court booking is confirmed and payment received.

Pass Code: ${passCode}
Reference: ${bookingRef}
Sport: ${sportName}
Court: ${courtName}${venueName ? `\nVenue: ${venueName}` : ''}
Date: ${fmtDate(date)}
Time: ${timeStr}
Amount Paid: INR ${parseFloat(totalAmount || 0).toLocaleString('en-IN')}${maxPersons ? `\nPass valid for: ${maxPersons} person${maxPersons > 1 ? 's' : ''}` : ''}

Please arrive 10 minutes before your slot and present the QR code / pass code at the entry gate.

Nahata Sports Complex`;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      // Admin receives a copy of every booking confirmation (BCC keeps the
      // admin address hidden from the customer).
      ...(ADMIN_EMAIL ? { bcc: ADMIN_EMAIL } : {}),
      subject: `Booking Confirmed — ${sportName} | ${bookingRef} | ${passCode}`,
      text,
      html,
      attachments: qr.attachments,
    });

    console.log(`✅ [EmailService] Booking confirmation email sent to ${to}${ADMIN_EMAIL ? ` (bcc: ${ADMIN_EMAIL})` : ''} (${passCode})`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send booking confirmation email:`, error.message);
    // Non-blocking — don't throw
  }
};
/**
 * Notify a customer that their booking was moved to an equivalent court (auto
 * slot consolidation). Time, price and pass code are unchanged — only the court
 * label differs. Non-blocking.
 */
exports.sendBookingCourtReassignedEmail = async ({
  to, name, sportName, oldCourtName, newCourtName, venueName,
  date, startTime, endTime, passCode, qrCodeUrl, bookingRef,
}) => {
  try {
    const transporter = createTransporter();

    const fmtDate = (d) => {
      if (!d) return '';
      const dt = new Date(d + 'T00:00:00');
      return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    };
    const fmtTime = (t) => {
      if (!t) return '';
      const [h, m] = t.split(':').map(Number);
      const ampm = h >= 12 ? 'PM' : 'AM';
      const hour = h % 12 || 12;
      return `${hour}:${String(m).padStart(2, '0')} ${ampm}`;
    };
    const timeStr = `${fmtTime(startTime)} – ${fmtTime(endTime)}`;

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Court Updated — ${sportName}</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f1f5f9; margin: 0; padding: 0; }
          .wrapper { max-width: 520px; margin: 40px auto; }
          .ticket { background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 8px 32px rgba(0,0,0,0.10); }
          .header { background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); padding: 36px 36px 28px; text-align: center; }
          .header-logo { font-size: 13px; font-weight: 800; color: #94a3b8; letter-spacing: 3px; text-transform: uppercase; margin-bottom: 12px; }
          .header h1 { color: #ffffff; font-size: 22px; font-weight: 900; margin: 0 0 6px; letter-spacing: -0.5px; }
          .header p { color: #94a3b8; font-size: 13px; margin: 0; }
          .badge { display: inline-block; background: #3b82f6; color: #fff; font-size: 10px; font-weight: 800; padding: 4px 14px; border-radius: 20px; letter-spacing: 1px; text-transform: uppercase; margin-top: 14px; }
          .body { padding: 32px 36px; }
          .greeting { font-size: 16px; font-weight: 700; color: #1e293b; margin-bottom: 8px; }
          .sub { font-size: 13px; color: #64748b; margin-bottom: 24px; line-height: 1.6; }
          .court-change { background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 12px; padding: 18px 22px; text-align: center; margin-bottom: 24px; }
          .court-change .new { font-size: 22px; font-weight: 900; color: #1d4ed8; letter-spacing: -0.5px; }
          .court-change .old { font-size: 12px; color: #94a3b8; text-decoration: line-through; margin-top: 4px; }
          .details { background: #f8fafc; border-radius: 14px; padding: 20px 24px; margin-bottom: 24px; }
          .row { display: flex; justify-content: space-between; align-items: center; padding: 7px 0; border-bottom: 1px solid #e2e8f0; }
          .row:last-child { border-bottom: none; }
          .label { font-size: 12px; color: #64748b; font-weight: 500; }
          .value { font-size: 12px; color: #1e293b; font-weight: 800; text-align: right; }
          .notice { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px; padding: 14px 18px; font-size: 12px; color: #166534; line-height: 1.6; margin-bottom: 8px; }
          .footer { background: #f8fafc; padding: 20px 36px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 11px; color: #94a3b8; margin: 0; line-height: 1.7; }
        </style>
      </head>
      <body>
        <div class="wrapper">
          <div class="ticket">
            <div class="header">
              <div class="header-logo">Nahata Sports</div>
              <h1>Your Court Was Updated</h1>
              <p>${sportName}${venueName ? ' · ' + venueName : ''}</p>
              <div class="badge">Court Reassigned</div>
            </div>
            <div class="body">
              <p class="greeting">Hi ${name},</p>
              <p class="sub">
                To fit everyone in, we moved your ${sportName} booking to another court at the same venue.
                Your <strong>date, time, price and pass code are unchanged</strong> — only the court has changed.
              </p>
              <div class="court-change">
                <div class="new">${newCourtName}</div>
                ${oldCourtName ? `<div class="old">was ${oldCourtName}</div>` : ''}
              </div>
              <div class="details">
                <div class="row"><span class="label">Reference</span><span class="value" style="font-family:monospace;">${bookingRef}</span></div>
                <div class="row"><span class="label">Date</span><span class="value">${fmtDate(date)}</span></div>
                <div class="row"><span class="label">Time</span><span class="value">${timeStr}</span></div>
                ${passCode ? `<div class="row"><span class="label">Pass Code</span><span class="value" style="font-family:monospace;">${passCode}</span></div>` : ''}
              </div>
              <div class="notice">
                ✓ No action needed. Your existing pass${passCode ? ' / QR code' : ''} still works at the entry gate.
              </div>
            </div>
            <div class="footer">
              <p>Nahata Sports Complex · This is an automated email.</p>
              <p>© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
            </div>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `Court updated for your ${sportName} booking | ${bookingRef || ''}`.trim(),
      html,
    });

    console.log(`✅ [EmailService] Court-reassigned email sent to ${to} (${bookingRef})`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send court-reassigned email:`, error.message);
    // Non-blocking — don't throw
  }
};

exports.sendEventPassEmail = async ({
  to,
  name,
  eventTitle,
  passCode,
  qrCodeUrl,
  slotDate,
  slotName,
  passType,
  startTime,
  endTime,
  maxPersons,
}) => {
  try {
    const transporter = createTransporter();

    // Format date "2025-09-26" → "26 Sep 2025"
    const fmtDate = (d) => {
      if (!d) return '';
      const dt = new Date(d + 'T00:00:00');
      return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    };

    // Format time "18:30:00" → "6:30 PM"
    const fmtTime = (t) => {
      if (!t) return null;
      const [h, m] = t.split(':').map(Number);
      const ampm = h >= 12 ? 'PM' : 'AM';
      const hour = h % 12 || 12;
      return `${hour}:${String(m).padStart(2, '0')} ${ampm}`;
    };

    const timeStr =
      startTime && endTime
        ? `${fmtTime(startTime)} – ${fmtTime(endTime)}`
        : startTime
          ? fmtTime(startTime)
          : null;

    // Embed the QR inline so it always renders (no remote-image blocking).
    const qr = await buildQrImage(qrCodeUrl, 'event-qr');

    const capacityLine = maxPersons && maxPersons > 1
      ? `This pass is valid for <strong>up to ${maxPersons} people</strong>. You may share this email with your group.`
      : 'This pass is valid for one person only. Please do not share it.';

    const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme" content="light" />
        <title>Your Event Pass — ${eventTitle}</title>
        <style>
          body { margin: 0; padding: 0; background: #eef1f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; }
          table { border-collapse: collapse; }
          .wrapper { width: 100%; background: #eef1f5; padding: 32px 16px; }
          .ticket { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e5e9f1; overflow: hidden; }
          .header { background-color: #0f172a; background-image: linear-gradient(135deg, #0f172a 0%, #1e2c44 100%); padding: 34px 36px 26px; text-align: center; }
          .header-logo { font-size: 11px; font-weight: 700; color: #8fa0bd; letter-spacing: 3px; text-transform: uppercase; margin: 0 0 12px; }
          .h1 { color: #ffffff; font-size: 21px; font-weight: 800; margin: 0 0 6px; letter-spacing: -0.4px; }
          .header p { color: #94a3b8; font-size: 13px; margin: 0; }
          .badge { display: inline-block; background-color: #16a34a; color: #fff; font-size: 10px; font-weight: 800; padding: 4px 14px; border-radius: 20px; letter-spacing: 1px; text-transform: uppercase; margin-top: 14px; }
          .accent { height: 3px; background-color: #d97706; background-image: linear-gradient(90deg, #f59e0b, #d97706); font-size: 0; line-height: 0; }
          .body { padding: 32px 36px; }
          .greeting { font-size: 16px; font-weight: 700; color: #0f172a; margin: 0 0 8px; }
          .sub { font-size: 13px; color: #5b6472; margin: 0 0 28px; line-height: 1.65; }
          .qr-card { background: #f8fafc; border: 1px solid #e5e9f1; border-radius: 14px; padding: 24px; text-align: center; margin-bottom: 24px; }
          .qr-card img { width: 180px; height: 180px; border: 1px solid #e5e9f1; border-radius: 12px; padding: 8px; background: #fff; }
          .pass-code { font-size: 14px; font-weight: 800; color: #0f172a; letter-spacing: 2px; margin-top: 14px; font-family: 'SFMono-Regular', Consolas, monospace; }
          .pass-hint { font-size: 11px; color: #94a3b8; margin-top: 4px; text-transform: uppercase; letter-spacing: 0.8px; }
          .section-title { font-size: 10px; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.5px; margin: 0 0 14px; }
          .detail-table td { padding: 9px 0; border-bottom: 1px solid #eef1f5; font-size: 12px; }
          .detail-table tr:last-child td { border-bottom: none; }
          .label { color: #64748b; font-weight: 500; }
          .value { color: #0f172a; font-weight: 800; text-align: right; }
          .callout { border-radius: 8px; padding: 13px 16px; font-size: 12px; line-height: 1.6; }
          .callout-amber { background: #fffbf0; border-left: 3px solid #d97706; color: #5c4108; }
          .footer { background: #f8fafc; padding: 22px 36px; text-align: center; border-top: 1px solid #e5e9f1; }
          .footer p { font-size: 11px; color: #94a3b8; margin: 0; line-height: 1.7; }
          @media (max-width: 480px) {
            .body, .header, .footer { padding-left: 22px !important; padding-right: 22px !important; }
          }
        </style>
      </head>
      <body>
        <div class="wrapper">
          <table role="presentation" class="ticket" width="100%" cellpadding="0" cellspacing="0">
            <tr><td class="header">
              <p class="header-logo">Nahata Sports Complex</p>
              <p class="h1">${eventTitle}</p>
              <p>${slotName || passType || 'Event Pass'}</p>
              <div class="badge">Confirmed Pass</div>
            </td></tr>
            <tr><td class="accent">&nbsp;</td></tr>
            <tr><td class="body">
              <p class="greeting">Hi ${name},</p>
              <p class="sub">
                Your event pass is confirmed. Show the QR code below at the entry gate. ${capacityLine}
              </p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 24px;">
                <tr><td class="qr-card">
                  <img src="${qr.src}" alt="Event Pass QR Code" width="180" height="180" />
                  <div class="pass-code">${passCode}</div>
                  <div class="pass-hint">Event Pass Code</div>
                </td></tr>
              </table>

              <p class="section-title">Pass Details</p>
              <table role="presentation" class="detail-table" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 24px;">
                <tr><td class="label">Event</td><td class="value">${eventTitle}</td></tr>
                ${slotDate ? `<tr><td class="label">Date</td><td class="value">${fmtDate(slotDate)}</td></tr>` : ''}
                ${timeStr ? `<tr><td class="label">Time</td><td class="value">${timeStr}</td></tr>` : ''}
                ${passType ? `<tr><td class="label">Pass Type</td><td class="value">${passType}</td></tr>` : ''}
                <tr><td class="label">Pass Holder</td><td class="value">${name}</td></tr>
                ${maxPersons && maxPersons > 1 ? `<tr><td class="label">Valid For</td><td class="value" style="color:#15803d;">${maxPersons} Persons</td></tr>` : ''}
                <tr><td class="label">Pass Code</td><td class="value" style="font-family:'SFMono-Regular',Consolas,monospace; font-size:11px;">${passCode}</td></tr>
              </table>

              <div class="callout callout-amber">
                <strong>Please note:</strong> Present this QR code at the entry gate. ${maxPersons && maxPersons > 1 ? `Each person in your group is scanned in individually.` : `This pass cannot be transferred to another person.`}
              </div>
            </td></tr>
            <tr><td class="footer">
              <p>Nahata Sports Complex · This is an automated email.</p>
              <p>© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
            </td></tr>
          </table>
        </div>
      </body>
      </html>
    `;

    const text =
`Your Event Pass — ${eventTitle}

Hi ${name},
Your event pass is confirmed.

Pass Code: ${passCode}
Event: ${eventTitle}${slotDate ? `\nDate: ${fmtDate(slotDate)}` : ''}${timeStr ? `\nTime: ${timeStr}` : ''}${passType ? `\nPass Type: ${passType}` : ''}${maxPersons && maxPersons > 1 ? `\nValid for: ${maxPersons} persons` : ''}

Please present the QR code / pass code at the entry gate.

Nahata Sports Complex`;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `Your Event Pass — ${eventTitle} | ${passCode}`,
      text,
      html,
      attachments: qr.attachments,
    });

    console.log(`✅ [EmailService] Event pass email sent to ${to} (${passCode})`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send event pass email:`, error.message);
    throw error;
  }
};

/**
 * Send password reset email with reset link
 */
exports.sendPasswordResetEmail = async (email, resetToken) => {
  try {
    const transporter = createTransporter();
    const resetUrl = `${process.env.ADMIN_URL || 'http://localhost:5173'}/reset-password?token=${resetToken}`;

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Reset Your Password</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #1e293b 0%, #334155 100%); padding: 40px 40px 32px; text-align: center; }
          .header h1 { color: #ffffff; font-size: 24px; font-weight: 800; margin: 0 0 8px; letter-spacing: -0.5px; }
          .header p { color: #94a3b8; font-size: 14px; margin: 0; }
          .badge { display: inline-block; background: #f59e0b; color: #fff; font-size: 11px; font-weight: 700; padding: 4px 12px; border-radius: 20px; letter-spacing: 0.5px; margin-top: 16px; }
          .body { padding: 40px; }
          .greeting { font-size: 18px; font-weight: 700; color: #1e293b; margin-bottom: 12px; }
          .text { font-size: 14px; color: #64748b; line-height: 1.7; margin-bottom: 24px; }
          .cta-btn { display: block; background: #1e293b; color: #ffffff; text-decoration: none; text-align: center; padding: 14px 32px; border-radius: 10px; font-size: 13px; font-weight: 700; letter-spacing: 0.5px; margin-bottom: 28px; }
          .cta-btn:hover { background: #334155; }
          .link-box { background: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 10px; padding: 16px; margin-bottom: 24px; word-break: break-all; }
          .link-box p { font-size: 11px; color: #64748b; margin: 0 0 8px; font-weight: 600; }
          .link-box a { font-size: 12px; color: #3b82f6; text-decoration: none; }
          .notice { background: #fef9c3; border: 1px solid #fde047; border-radius: 10px; padding: 14px 18px; font-size: 12px; color: #713f12; line-height: 1.6; margin-bottom: 24px; }
          .footer { background: #f8fafc; padding: 24px 40px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Nahata Sports</h1>
            <p>Admin Portal</p>
            <div class="badge">🔐 Password Reset</div>
          </div>
          <div class="body">
            <p class="greeting">Password Reset Request</p>
            <p class="text">
              We received a request to reset your password for your Nahata Sports admin account. 
              Click the button below to create a new password.
            </p>

            <a href="${resetUrl}" class="cta-btn">
              Reset Password →
            </a>

            <div class="link-box">
              <p>Or copy and paste this link into your browser:</p>
              <a href="${resetUrl}">${resetUrl}</a>
            </div>

            <div class="notice">
              ⚠️ <strong>Important:</strong> This link will expire in 15 minutes for security reasons. 
              If you didn't request this password reset, please ignore this email.
            </p>

            <p class="text" style="margin-bottom: 0;">
              If you have any questions, please contact our support team.
            </p>
          </div>
          <div class="footer">
            <p>Nahata Sports Complex · This is an automated email, please do not reply directly.</p>
            <p style="margin-top: 8px;">© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to: email,
      subject: 'Reset Your Password — Nahata Sports Admin',
      html,
    });

    console.log(`✅ [EmailService] Password reset email sent to ${email}`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send password reset email:`, error.message);
    throw error;
  }
};

/**
 * Send user invitation email when admin creates a new user
 */
exports.sendUserInvitationEmail = async (email, setupToken, name) => {
  try {
    const transporter = createTransporter();
    const setupUrl = `${process.env.ADMIN_URL || 'http://localhost:5173'}/reset-password?token=${setupToken}`;

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Welcome to Nahata Sports</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #15803d 0%, #16a34a 100%); padding: 40px 40px 32px; text-align: center; }
          .header h1 { color: #ffffff; font-size: 24px; font-weight: 800; margin: 0 0 8px; letter-spacing: -0.5px; }
          .header p { color: #bbf7d0; font-size: 14px; margin: 0; }
          .badge { display: inline-block; background: #ffffff; color: #15803d; font-size: 11px; font-weight: 800; padding: 4px 14px; border-radius: 20px; letter-spacing: 0.5px; margin-top: 16px; }
          .body { padding: 40px; }
          .greeting { font-size: 18px; font-weight: 700; color: #1e293b; margin-bottom: 12px; }
          .text { font-size: 14px; color: #64748b; line-height: 1.7; margin-bottom: 24px; }
          .cta-btn { display: block; background: #15803d; color: #ffffff; text-decoration: none; text-align: center; padding: 14px 32px; border-radius: 10px; font-size: 13px; font-weight: 700; letter-spacing: 0.5px; margin-bottom: 28px; }
          .cta-btn:hover { background: #16a34a; }
          .link-box { background: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 10px; padding: 16px; margin-bottom: 24px; word-break: break-all; }
          .link-box p { font-size: 11px; color: #64748b; margin: 0 0 8px; font-weight: 600; }
          .link-box a { font-size: 12px; color: #3b82f6; text-decoration: none; }
          .notice { background: #fef9c3; border: 1px solid #fde047; border-radius: 10px; padding: 14px 18px; font-size: 12px; color: #713f12; line-height: 1.6; margin-bottom: 24px; }
          .footer { background: #f8fafc; padding: 24px 40px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Nahata Sports</h1>
            <p>Admin Portal</p>
            <div class="badge">🎉 Welcome!</div>
          </div>
          <div class="body">
            <p class="greeting">Welcome, ${name}!</p>
            <p class="text">
              Your account has been created for the Nahata Sports admin portal. 
              Click the button below to set your password and activate your account.
            </p>

            <a href="${setupUrl}" class="cta-btn">
              Set Your Password →
            </a>

            <div class="link-box">
              <p>Or copy and paste this link into your browser:</p>
              <a href="${setupUrl}">${setupUrl}</a>
            </div>

            <div class="notice">
              ⚠️ <strong>Important:</strong> This link will expire in 24 hours. 
              Please set your password as soon as possible to access your account.
            </div>

            <p class="text" style="margin-bottom: 0;">
              If you have any questions, please contact our support team.
            </p>
          </div>
          <div class="footer">
            <p>Nahata Sports Complex · This is an automated email, please do not reply directly.</p>
            <p style="margin-top: 8px;">© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to: email,
      subject: 'Welcome to Nahata Sports — Set Your Password',
      html,
    });

    console.log(`✅ [EmailService] User invitation email sent to ${email}`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send user invitation email:`, error.message);
    throw error;
  }
};

/**
 * Send login credentials to a newly-created staff account (Employee / Security / Coach).
 * The admin sets the password, so we email the actual credentials + login URL.
 *
 * @param {object} opts
 * @param {string} opts.to          - Recipient email
 * @param {string} opts.name        - Staff member's name
 * @param {string} opts.email       - Login email/username
 * @param {string} opts.password    - The password the admin assigned
 * @param {string} opts.role        - 'Employee' | 'Security' | 'Coach' (display label)
 * @param {string} [opts.complexName] - Assigned sports complex name
 * @param {string} [opts.loginUrl]  - Admin portal login URL
 */
exports.sendStaffCredentialsEmail = async ({ to, name, email, password, role, complexName, loginUrl, details = [] }) => {
  try {
    const transporter = createTransporter();
    const url = loginUrl || `${process.env.ADMIN_URL || 'http://localhost:5173'}/login`;

    // Extra rows captured on the Add form (phone, ID, department, shift, …).
    const escape = (v) => String(v == null ? '' : v)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const detailRows = (Array.isArray(details) ? details : [])
      .filter((d) => d && d.value != null && String(d.value).trim() !== '')
      .map((d) => `<div class="row"><span class="label">${escape(d.label)}:</span><span class="value plain">${escape(d.value)}</span></div>`)
      .join('');

    // Role/Complex live in the profile section alongside the rest of the details.
    const profileRows = `
      ${role ? `<div class="row"><span class="label">Role:</span><span class="value plain">${escape(role)}</span></div>` : ''}
      ${complexName ? `<div class="row"><span class="label">Complex:</span><span class="value plain">${escape(complexName)}</span></div>` : ''}
      ${detailRows}
    `.trim();

    const html = `
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f1f5f9; margin: 0; padding: 0; color: #0f172a; }
          .container { max-width: 600px; margin: 40px auto; background: #fff; border-radius: 16px; overflow: hidden; box-shadow: 0 6px 28px rgba(15,23,42,0.10); }
          .header { background: linear-gradient(135deg, #1e3a8a 0%, #2563eb 100%); padding: 40px; text-align: center; }
          .header h1 { color: #fff; font-size: 24px; font-weight: 800; margin: 0; letter-spacing: -0.3px; }
          .header p { color: #bfdbfe; font-size: 13px; margin: 8px 0 0; }
          .badge { display: inline-block; margin-top: 16px; background: rgba(255,255,255,0.15); color: #fff; font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; padding: 6px 14px; border-radius: 999px; }
          .body { padding: 36px 40px; }
          .greeting { font-size: 19px; font-weight: 800; color: #0f172a; margin: 0 0 10px; }
          .text { font-size: 14px; color: #475569; line-height: 1.7; margin: 0 0 26px; }
          .section-title { font-size: 12px; font-weight: 800; letter-spacing: 0.6px; text-transform: uppercase; color: #2563eb; margin: 0 0 10px; }
          .card { border: 1px solid #e2e8f0; border-radius: 12px; padding: 4px 20px; margin-bottom: 26px; }
          .card.creds { background: #eff6ff; border-color: #bfdbfe; }
          .card.profile { background: #f8fafc; }
          .row { display: flex; justify-content: space-between; align-items: center; gap: 16px; padding: 13px 0; border-bottom: 1px solid #e2e8f0; font-size: 13px; }
          .row:last-child { border-bottom: none; }
          .label { color: #64748b; font-weight: 600; white-space: nowrap; padding-right: 12px; }
          .value { color: #0f172a; font-weight: 700; font-family: 'Courier New', monospace; text-align: right; word-break: break-all; }
          .value.plain { font-family: inherit; }
          .cta-btn { display: block; background: #2563eb; color: #fff; text-decoration: none; text-align: center; padding: 15px 32px; border-radius: 10px; font-size: 13px; font-weight: 700; letter-spacing: 0.3px; margin-bottom: 26px; }
          .notice { background: #fef9c3; border: 1px solid #fde047; border-radius: 10px; padding: 14px 18px; font-size: 12px; color: #713f12; line-height: 1.6; }
          .footer { background: #f8fafc; padding: 24px 40px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 12px; color: #94a3b8; margin: 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Nahata Sports</h1>
            <p>Your ${escape(role)} account is ready</p>
            <span class="badge">${escape(role)} Account</span>
          </div>
          <div class="body">
            <p class="greeting">Welcome, ${escape(name)}! 👋</p>
            <p class="text">An account has been created for you on the <strong>Nahata Sports</strong> admin portal. Your login credentials and complete account details are below — please keep this email safe.</p>

            <p class="section-title">🔑 Login Credentials</p>
            <div class="card creds">
              <div class="row"><span class="label">Login Email:</span><span class="value">${escape(email)}</span></div>
              <div class="row"><span class="label">Password:</span><span class="value">${escape(password)}</span></div>
            </div>

            <a href="${url}" class="cta-btn">Log In to Your Account →</a>

            ${profileRows ? `
            <p class="section-title">📋 Your Details</p>
            <div class="card profile">
              ${profileRows}
            </div>` : ''}

            <div class="notice">🔒 <strong>Keep these credentials safe.</strong> Your password is managed by your administrator — if you need it changed or reset, please contact them.</div>
          </div>
          <div class="footer">
            <p>Nahata Sports Complex · Automated email, please do not reply.</p>
            <p style="margin-top: 8px;">© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `Your Nahata Sports ${role} account`,
      html,
    });

    console.log(`✅ [EmailService] Staff credentials email sent to ${to}`);
  } catch (error) {
    console.error(`❌ [EmailService] Failed to send staff credentials email:`, error.message);
    throw error;
  }
};

/**
 * Send welcome email when a new user/student self-registers
 *
 * @param {object} opts
 * @param {string} opts.to    - Recipient email
 * @param {string} opts.name  - User's name
 */
exports.sendWelcomeEmail = async ({ to, name }) => {
  try {
    const transporter = createTransporter();

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Welcome to Nahata Sports</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f1f5f9; margin: 0; padding: 0; }
          .wrapper { max-width: 520px; margin: 40px auto; }
          .card { background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 8px 32px rgba(0,0,0,0.10); }
          .header { background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); padding: 40px 36px 32px; text-align: center; }
          .header-logo { font-size: 13px; font-weight: 800; color: #94a3b8; letter-spacing: 3px; text-transform: uppercase; margin-bottom: 14px; }
          .header h1 { color: #ffffff; font-size: 26px; font-weight: 900; margin: 0 0 8px; letter-spacing: -0.5px; }
          .header p { color: #94a3b8; font-size: 14px; margin: 0; }
          .badge { display: inline-block; background: #22c55e; color: #fff; font-size: 11px; font-weight: 800; padding: 5px 16px; border-radius: 20px; letter-spacing: 1px; text-transform: uppercase; margin-top: 16px; }
          .body { padding: 36px 36px 28px; }
          .greeting { font-size: 18px; font-weight: 700; color: #1e293b; margin-bottom: 10px; }
          .text { font-size: 14px; color: #64748b; line-height: 1.75; margin-bottom: 28px; }
          .features { background: #f8fafc; border-radius: 14px; padding: 22px 24px; margin-bottom: 28px; }
          .features h3 { font-size: 11px; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: 1.5px; margin: 0 0 16px; }
          .feature-item { display: flex; align-items: flex-start; gap: 12px; margin-bottom: 12px; }
          .feature-item:last-child { margin-bottom: 0; }
          .feature-icon { font-size: 18px; flex-shrink: 0; margin-top: 1px; }
          .feature-text { font-size: 13px; color: #475569; line-height: 1.5; }
          .feature-text strong { color: #1e293b; }
          .cta-btn { display: block; background: linear-gradient(135deg, #1e293b 0%, #334155 100%); color: #ffffff; text-decoration: none; text-align: center; padding: 15px 32px; border-radius: 12px; font-size: 14px; font-weight: 700; letter-spacing: 0.5px; margin-bottom: 28px; }
          .divider { border: none; border-top: 1px solid #e2e8f0; margin: 0 0 24px; }
          .help-text { font-size: 12px; color: #94a3b8; text-align: center; line-height: 1.6; margin-bottom: 0; }
          .footer { background: #f8fafc; padding: 20px 36px; text-align: center; border-top: 1px solid #e2e8f0; }
          .footer p { font-size: 11px; color: #94a3b8; margin: 0; line-height: 1.7; }
        </style>
      </head>
      <body>
        <div class="wrapper">
          <div class="card">
            <div class="header">
              <div class="header-logo">Nahata Sports</div>
              <h1>Welcome Aboard! 🎉</h1>
              <p>Your account is ready to go</p>
              <div class="badge">✓ Registration Successful</div>
            </div>

            <div class="body">
              <p class="greeting">Hi ${name},</p>
              <p class="text">
                Welcome to <strong>Nahata Sports Complex</strong>! Your account has been created successfully.
                We're excited to have you as part of our sports community.
              </p>

              <div class="features">
                <h3>What you can do now</h3>
                <div class="feature-item">
                  <span class="feature-icon">🏟️</span>
                  <span class="feature-text"><strong>Book Courts</strong> — Reserve sports courts for cricket, badminton, football and more.</span>
                </div>
                <div class="feature-item">
                  <span class="feature-icon">🎓</span>
                  <span class="feature-text"><strong>Join Coaching Programs</strong> — Enroll in professional coaching sessions with our expert coaches.</span>
                </div>
                <div class="feature-item">
                  <span class="feature-icon">🎟️</span>
                  <span class="feature-text"><strong>Attend Events</strong> — Get passes for upcoming sports events and tournaments.</span>
                </div>
                <div class="feature-item">
                  <span class="feature-icon">📊</span>
                  <span class="feature-text"><strong>Track Your Activity</strong> — View your bookings, passes, and enrollment history in your dashboard.</span>
                </div>
              </div>

              <a href="${FRONTEND_URL}/dashboard" class="cta-btn">
                Go to My Dashboard →
              </a>

              <hr class="divider" />
              <p class="help-text">
                Need help? Contact us at our sports complex and our team will be happy to assist you.
              </p>
            </div>

            <div class="footer">
              <p>Nahata Sports Complex · This is an automated email.</p>
              <p>© ${new Date().getFullYear()} Nahata Sports. All rights reserved.</p>
            </div>
          </div>
        </div>
      </body>
      </html>
    `;

    await transporter.sendMail({
      from: FROM_ADDRESS,
      to,
      subject: `Welcome to Nahata Sports, ${name}! 🎉`,
      html,
    });

    console.log(`✅ [EmailService] Welcome email sent to ${to}`);
  } catch (error) {
    // Non-blocking — log but don't break registration
    console.error(`❌ [EmailService] Failed to send welcome email:`, error.message);
  }
};
