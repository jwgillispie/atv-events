"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendVendorApplicationConfirmationEmail = exports.sendEmailBlast = exports.testEmailFunction = exports.sendOrderStatusUpdateEmail = exports.sendTicketConfirmationEmail = exports.sendOrderConfirmationEmail = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const nodemailer = __importStar(require("nodemailer"));
// Initialize Firestore
const db = admin.firestore();
// Email configuration
const SUPPORT_EMAIL = 'hipopmarkets@gmail.com';
// Get the FROM email based on configuration
const getFromEmail = () => {
    const config = functions.config();
    if (config.sendgrid?.from_email) {
        const fromName = config.sendgrid.from_name || 'HiPop Markets';
        return `${fromName} <${config.sendgrid.from_email}>`;
    }
    if (config.gmail?.email) {
        return `HiPop Markets <${config.gmail.email}>`;
    }
    // Fallback
    return 'HiPop Markets <noreply@hipopmarkets.com>';
};
// Create reusable transporter using Gmail SMTP
// In production, use SendGrid, AWS SES, or Resend for better deliverability
const createTransporter = () => {
    const config = functions.config();
    // Try SendGrid first (recommended for production)
    if (config.sendgrid?.api_key) {
        console.log('Using SendGrid for email delivery');
        return nodemailer.createTransport({
            host: 'smtp.sendgrid.net',
            port: 587,
            secure: false,
            auth: {
                user: 'apikey',
                pass: config.sendgrid.api_key,
            },
        });
    }
    // Fall back to Gmail
    if (config.gmail?.email && config.gmail?.password) {
        console.log('Using Gmail for email delivery');
        return nodemailer.createTransport({
            service: 'gmail',
            auth: {
                user: config.gmail.email,
                pass: config.gmail.password,
            },
        });
    }
    // Legacy email config (deprecated)
    const emailConfig = config.email;
    if (emailConfig?.user && emailConfig?.password) {
        console.log('Using legacy Gmail config for email delivery');
        return nodemailer.createTransport({
            service: 'gmail',
            auth: {
                user: emailConfig.user,
                pass: emailConfig.password,
            },
        });
    }
    console.error('No email configuration found. Configure with either:');
    console.error('SendGrid: firebase functions:config:set sendgrid.api_key="SG.xxx" sendgrid.from_email="noreply@domain.com"');
    console.error('Gmail: firebase functions:config:set gmail.email="your@gmail.com" gmail.password="app-password"');
    return null;
};
// Email templates
const getOrderConfirmationTemplate = (order, qrCodeUrl) => {
    const pickupDate = new Date(order.pickupDate._seconds * 1000);
    const formattedDate = pickupDate.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Confirmation - HiPop Markets</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #2C3E50; margin: 0; padding: 0; background-color: #F5F6FA; }
        .container { max-width: 600px; margin: 0 auto; background: white; }
        .header { background: linear-gradient(135deg, #558B6E 0%, #88A09E 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; font-weight: 600; }
        .content { padding: 30px; }
        .order-box { background: #F8F9FA; border-radius: 12px; padding: 20px; margin: 20px 0; border: 1px solid #E5E7EB; }
        .order-number { color: #558B6E; font-size: 18px; font-weight: 600; }
        .qr-section { text-align: center; padding: 30px 0; }
        .qr-code { background: white; padding: 20px; border-radius: 12px; display: inline-block; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .items-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .items-table th { background: #558B6E; color: white; padding: 12px; text-align: left; }
        .items-table td { padding: 12px; border-bottom: 1px solid #E5E7EB; }
        .total-row { font-weight: 600; font-size: 18px; color: #558B6E; }
        .pickup-info { background: #FFF3CD; border: 1px solid #FFD700; border-radius: 8px; padding: 15px; margin: 20px 0; }
        .pickup-info h3 { margin-top: 0; color: #856404; }
        .button { display: inline-block; padding: 12px 30px; background: #558B6E; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 10px 0; }
        .footer { background: #2C3E50; color: white; padding: 30px; text-align: center; }
        .footer a { color: #88A09E; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🎉 Order Confirmed!</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.95;">Thank you for your purchase</p>
        </div>

        <div class="content">
          <div class="order-box">
            <div class="order-number">Order #${order.orderNumber}</div>
            <div style="color: #6B7280; margin-top: 5px;">Placed on ${new Date(order.createdAt._seconds * 1000).toLocaleString()}</div>
          </div>

          <div class="qr-section">
            <h2 style="color: #2C3E50; margin-bottom: 10px;">Your Pickup QR Code</h2>
            <p style="color: #6B7280; margin-bottom: 20px;">Show this code at pickup</p>
            <div class="qr-code">
              <img src="${qrCodeUrl}" alt="QR Code" width="200" height="200" />
              <p style="margin: 10px 0 0 0; font-size: 12px; color: #6B7280;">${order.qrCode}</p>
            </div>
          </div>

          <div class="pickup-info">
            <h3>📍 Pickup Information</h3>
            <p><strong>Vendor:</strong> ${order.vendorName}</p>
            <p><strong>Market:</strong> ${order.marketName}</p>
            <p><strong>Location:</strong> ${order.marketLocation}</p>
            <p><strong>Date:</strong> ${formattedDate}</p>
            ${order.pickupTimeSlot ? `<p><strong>Time:</strong> ${order.pickupTimeSlot}</p>` : ''}
            ${order.pickupInstructions ? `<p><strong>Instructions:</strong> ${order.pickupInstructions}</p>` : ''}
          </div>

          <h3 style="color: #2C3E50; margin-top: 30px;">Order Details</h3>
          <table class="items-table">
            <thead>
              <tr>
                <th>Item</th>
                <th style="text-align: center;">Qty</th>
                <th style="text-align: right;">Price</th>
              </tr>
            </thead>
            <tbody>
              ${order.items.map((item) => `
                <tr>
                  <td>${item.productName}</td>
                  <td style="text-align: center;">${item.quantity}</td>
                  <td style="text-align: right;">$${item.totalPrice.toFixed(2)}</td>
                </tr>
              `).join('')}
              <tr>
                <td colspan="2" style="text-align: right; padding-top: 10px;">Subtotal:</td>
                <td style="text-align: right; padding-top: 10px;">$${order.subtotal.toFixed(2)}</td>
              </tr>
              <tr>
                <td colspan="2" style="text-align: right;">Platform Fee:</td>
                <td style="text-align: right;">$${order.platformFee.toFixed(2)}</td>
              </tr>
              <tr class="total-row">
                <td colspan="2" style="text-align: right; padding-top: 10px; border-top: 2px solid #558B6E;">Total:</td>
                <td style="text-align: right; padding-top: 10px; border-top: 2px solid #558B6E;">$${order.total.toFixed(2)}</td>
              </tr>
            </tbody>
          </table>

          ${order.customerNotes ? `
            <div style="background: #F8F9FA; border-radius: 8px; padding: 15px; margin: 20px 0;">
              <h4 style="margin-top: 0; color: #2C3E50;">Your Notes:</h4>
              <p style="color: #6B7280; margin: 0;">${order.customerNotes}</p>
            </div>
          ` : ''}

          <div style="text-align: center; margin-top: 30px;">
            <a href="https://hipop-markets.web.app/order/${order.id}" class="button">View Order Details</a>
          </div>
        </div>

        <div class="footer">
          <p style="margin: 0 0 10px 0;">Questions about your order?</p>
          <p style="margin: 0 0 20px 0;">
            Contact vendor: <a href="mailto:${order.vendorEmail || SUPPORT_EMAIL}">${order.vendorName}</a>
          </p>
          <p style="margin: 0; font-size: 12px; opacity: 0.8;">
            © ${new Date().getFullYear()} HiPop Markets. All rights reserved.
          </p>
          <p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.8;">
            <a href="https://hipop-markets.web.app">Visit Website</a> |
            <a href="mailto:${SUPPORT_EMAIL}">Support</a>
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
};
const getVendorOrderNotificationTemplate = (order) => {
    const pickupDate = new Date(order.pickupDate._seconds * 1000);
    const formattedDate = pickupDate.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>New Order - HiPop Markets</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #2C3E50; margin: 0; padding: 0; background-color: #F5F6FA; }
        .container { max-width: 600px; margin: 0 auto; background: white; }
        .header { background: linear-gradient(135deg, #E8A87C 0%, #CD5120 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; font-weight: 600; }
        .content { padding: 30px; }
        .alert-box { background: #D4EDDA; border: 1px solid #28A745; border-radius: 8px; padding: 15px; margin: 20px 0; }
        .order-box { background: #F8F9FA; border-radius: 12px; padding: 20px; margin: 20px 0; border: 1px solid #E5E7EB; }
        .customer-info { background: #E8F4FD; border-radius: 8px; padding: 15px; margin: 20px 0; }
        .button { display: inline-block; padding: 12px 30px; background: #E8A87C; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 10px 0; }
        .items-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .items-table th { background: #E8A87C; color: white; padding: 12px; text-align: left; }
        .items-table td { padding: 12px; border-bottom: 1px solid #E5E7EB; }
        .revenue-box { background: #F0FDF4; border: 1px solid #22C55E; border-radius: 8px; padding: 20px; margin: 20px 0; text-align: center; }
        .footer { background: #2C3E50; color: white; padding: 30px; text-align: center; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🛍️ New Order Received!</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.95;">Order #${order.orderNumber}</p>
        </div>

        <div class="content">
          <div class="alert-box">
            <strong>Action Required:</strong> Please confirm this order in your vendor dashboard.
          </div>

          <div class="customer-info">
            <h3 style="margin-top: 0; color: #2C3E50;">Customer Information</h3>
            <p><strong>Name:</strong> ${order.customerName}</p>
            <p><strong>Email:</strong> ${order.customerEmail}</p>
            ${order.customerPhone ? `<p><strong>Phone:</strong> ${order.customerPhone}</p>` : ''}
          </div>

          <h3 style="color: #2C3E50;">Order Items</h3>
          <table class="items-table">
            <thead>
              <tr>
                <th>Item</th>
                <th style="text-align: center;">Qty</th>
                <th style="text-align: right;">Price</th>
              </tr>
            </thead>
            <tbody>
              ${order.items.map((item) => `
                <tr>
                  <td>${item.productName}</td>
                  <td style="text-align: center;">${item.quantity}</td>
                  <td style="text-align: right;">$${item.totalPrice.toFixed(2)}</td>
                </tr>
              `).join('')}
            </tbody>
          </table>

          ${order.customerNotes ? `
            <div style="background: #FFF3CD; border: 1px solid #FFD700; border-radius: 8px; padding: 15px; margin: 20px 0;">
              <h4 style="margin-top: 0; color: #856404;">Customer Notes:</h4>
              <p style="color: #856404; margin: 0;">${order.customerNotes}</p>
            </div>
          ` : ''}

          <div class="order-box">
            <h4 style="margin-top: 0; color: #2C3E50;">Pickup Details</h4>
            <p><strong>Market:</strong> ${order.marketName}</p>
            <p><strong>Location:</strong> ${order.marketLocation}</p>
            <p><strong>Date:</strong> ${formattedDate}</p>
            ${order.pickupTimeSlot ? `<p><strong>Time:</strong> ${order.pickupTimeSlot}</p>` : ''}
          </div>

          <div class="revenue-box">
            <h3 style="margin-top: 0; color: #22C55E;">Your Earnings</h3>
            <p style="font-size: 24px; font-weight: bold; color: #22C55E; margin: 10px 0;">
              $${(order.subtotal - order.platformFee).toFixed(2)}
            </p>
            <p style="font-size: 12px; color: #6B7280; margin: 0;">
              (Subtotal: $${order.subtotal.toFixed(2)} - Platform Fee: $${order.platformFee.toFixed(2)})
            </p>
          </div>

          <div style="text-align: center; margin-top: 30px;">
            <a href="https://hipop-markets.web.app/vendor/orders" class="button">View in Dashboard</a>
          </div>
        </div>

        <div class="footer">
          <p style="margin: 0 0 10px 0;">Need help with this order?</p>
          <p style="margin: 0 0 20px 0;">
            Contact support: <a href="mailto:${SUPPORT_EMAIL}" style="color: #E8A87C;">hipopmarkets@gmail.com</a>
          </p>
          <p style="margin: 0; font-size: 12px; opacity: 0.8;">
            © ${new Date().getFullYear()} HiPop Markets. All rights reserved.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
};
const getTicketConfirmationTemplate = (ticket, qrCodeUrl) => {
    const eventDate = ticket.eventStartDate ? new Date(ticket.eventStartDate._seconds * 1000) : null;
    const formattedDate = eventDate ? eventDate.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    }) : 'TBD';
    const formattedTime = eventDate ? eventDate.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit'
    }) : '';
    return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Ticket Confirmation - HiPop Markets</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #2C3E50; margin: 0; padding: 0; background-color: #F5F6FA; }
        .container { max-width: 600px; margin: 0 auto; background: white; }
        .header { background: linear-gradient(135deg, #704C5E 0%, #88A09E 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; font-weight: 600; }
        .content { padding: 30px; }
        .ticket-box { background: linear-gradient(135deg, #F8F9FA 0%, #E8F4FD 100%); border-radius: 16px; padding: 30px; margin: 20px 0; border: 2px dashed #88A09E; position: relative; }
        .ticket-box::before, .ticket-box::after { content: ''; position: absolute; width: 30px; height: 30px; background: white; border-radius: 50%; top: 50%; transform: translateY(-50%); }
        .ticket-box::before { left: -15px; }
        .ticket-box::after { right: -15px; }
        .qr-section { text-align: center; padding: 20px 0; }
        .qr-code { background: white; padding: 20px; border-radius: 12px; display: inline-block; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .event-details { margin: 20px 0; }
        .event-details p { margin: 10px 0; font-size: 16px; }
        .event-details strong { color: #704C5E; }
        .button { display: inline-block; padding: 12px 30px; background: #704C5E; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 10px 0; }
        .footer { background: #2C3E50; color: white; padding: 30px; text-align: center; }
        .footer a { color: #88A09E; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🎟️ Ticket Confirmed!</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.95;">Your ticket is ready</p>
        </div>

        <div class="content">
          <div class="ticket-box">
            <h2 style="text-align: center; color: #2C3E50; margin: 0 0 10px 0; font-size: 24px;">
              ${ticket.eventName}
            </h2>
            <p style="text-align: center; color: #704C5E; font-size: 18px; margin: 0;">
              ${ticket.ticketName}
            </p>

            <div class="qr-section">
              <div class="qr-code">
                <img src="${qrCodeUrl}" alt="Ticket QR Code" width="200" height="200" />
                <p style="margin: 10px 0 0 0; font-size: 12px; color: #6B7280;">${ticket.qrCode}</p>
              </div>
            </div>

            <div class="event-details">
              <p><strong>📅 Date:</strong> ${formattedDate}</p>
              ${formattedTime ? `<p><strong>🕐 Time:</strong> ${formattedTime}</p>` : ''}
              ${ticket.eventLocation ? `<p><strong>📍 Location:</strong> ${ticket.eventLocation}</p>` : ''}
              <p><strong>🎫 Quantity:</strong> ${ticket.quantity} ticket${ticket.quantity > 1 ? 's' : ''}</p>
              <p><strong>💰 Total Paid:</strong> $${ticket.totalAmount.toFixed(2)}</p>
            </div>

            <div style="background: #FFF3CD; border-radius: 8px; padding: 15px; margin-top: 20px;">
              <p style="margin: 0; color: #856404; font-size: 14px;">
                <strong>Important:</strong> Please save this email or take a screenshot of the QR code.
                You'll need to show it at the event entrance.
              </p>
            </div>
          </div>

          <div style="text-align: center; margin-top: 30px;">
            <a href="https://hipop-markets.web.app/tickets" class="button">View in App</a>
          </div>

          <div style="margin-top: 30px; padding: 20px; background: #F8F9FA; border-radius: 8px;">
            <h3 style="margin-top: 0; color: #2C3E50;">Event Guidelines</h3>
            <ul style="color: #6B7280; margin: 0; padding-left: 20px;">
              <li>Arrive 10-15 minutes before the event starts</li>
              <li>Have your QR code ready for scanning</li>
              <li>Check event updates in the app</li>
              <li>Contact the organizer for any special requirements</li>
            </ul>
          </div>
        </div>

        <div class="footer">
          <p style="margin: 0 0 10px 0;">Questions about your ticket?</p>
          <p style="margin: 0 0 20px 0;">
            Contact support: <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>
          </p>
          <p style="margin: 0; font-size: 12px; opacity: 0.8;">
            © ${new Date().getFullYear()} HiPop Markets. All rights reserved.
          </p>
          <p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.8;">
            <a href="https://hipop-markets.web.app">Visit Website</a>
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
};
// Generate QR code as base64 data URL
const QRCode = require('qrcode');
const generateQRCodeDataUrl = async (data) => {
    try {
        // Generate actual QR code as data URL
        const qrCodeDataUrl = await QRCode.toDataURL(data, {
            width: 200,
            margin: 2,
            color: {
                dark: '#2C3E50',
                light: '#FFFFFF', // White background
            },
        });
        return qrCodeDataUrl;
    }
    catch (error) {
        console.error('Error generating QR code:', error);
        // Return a placeholder if QR generation fails
        return `data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==`;
    }
};
// Send order confirmation email to customer
exports.sendOrderConfirmationEmail = functions.firestore
    .document('orders/{orderId}')
    .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;
    if (!order || order.status !== 'paid') {
        console.log('Order not paid or invalid, skipping email');
        return null;
    }
    const transporter = createTransporter();
    if (!transporter) {
        console.error('Email transporter not configured');
        return null;
    }
    try {
        // Generate QR code
        const qrCodeUrl = await generateQRCodeDataUrl(order.qrCode);
        // Send email to customer
        const customerMailOptions = {
            from: getFromEmail(),
            to: order.customerEmail,
            subject: `Order Confirmation #${order.orderNumber} - HiPop Markets`,
            html: getOrderConfirmationTemplate(order, qrCodeUrl),
        };
        await transporter.sendMail(customerMailOptions);
        console.log(`Order confirmation email sent to ${order.customerEmail}`);
        // Send notification to vendor
        const vendorMailOptions = {
            from: getFromEmail(),
            to: order.vendorEmail || SUPPORT_EMAIL,
            subject: `New Order #${order.orderNumber} - HiPop Markets`,
            html: getVendorOrderNotificationTemplate(order),
        };
        await transporter.sendMail(vendorMailOptions);
        console.log(`Vendor notification email sent for order ${orderId}`);
        // Update order with email sent status
        await snap.ref.update({
            emailSent: true,
            emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true, orderId };
    }
    catch (error) {
        console.error('Error sending order emails:', error);
        return { success: false, error: error.message };
    }
});
// Send ticket confirmation email
exports.sendTicketConfirmationEmail = functions.firestore
    .document('ticket_purchases/{purchaseId}')
    .onCreate(async (snap, context) => {
    const ticket = snap.data();
    const purchaseId = context.params.purchaseId;
    if (!ticket || ticket.status !== 'completed') {
        console.log('Ticket not completed or invalid, skipping email');
        return null;
    }
    const transporter = createTransporter();
    if (!transporter) {
        console.error('Email transporter not configured');
        return null;
    }
    try {
        // Generate QR code
        const qrCodeUrl = await generateQRCodeDataUrl(ticket.qrCode);
        // Get user email
        const userDoc = await db.collection('users').doc(ticket.userId).get();
        const userEmail = userDoc.data()?.email || ticket.customerEmail;
        if (!userEmail) {
            console.error('No email address found for ticket purchase');
            return null;
        }
        // Send email
        const mailOptions = {
            from: getFromEmail(),
            to: userEmail,
            subject: `Ticket Confirmation: ${ticket.eventName} - HiPop Markets`,
            html: getTicketConfirmationTemplate(ticket, qrCodeUrl),
        };
        await transporter.sendMail(mailOptions);
        console.log(`Ticket confirmation email sent to ${userEmail}`);
        // Update ticket with email sent status
        await snap.ref.update({
            emailSent: true,
            emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true, purchaseId };
    }
    catch (error) {
        console.error('Error sending ticket email:', error);
        return { success: false, error: error.message };
    }
});
// Send order status update email
exports.sendOrderStatusUpdateEmail = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;
    // Check if status changed
    if (before.status === after.status) {
        return null;
    }
    const transporter = createTransporter();
    if (!transporter) {
        console.error('Email transporter not configured');
        return null;
    }
    // Only send emails for certain status changes
    const notifiableStatuses = ['confirmed', 'preparing', 'ready_for_pickup', 'cancelled', 'refunded'];
    if (!notifiableStatuses.includes(after.status)) {
        return null;
    }
    try {
        let subject = '';
        let message = '';
        switch (after.status) {
            case 'confirmed':
                subject = `Order Confirmed #${after.orderNumber}`;
                message = 'Your order has been confirmed by the vendor and will be prepared for pickup.';
                break;
            case 'preparing':
                subject = `Order Being Prepared #${after.orderNumber}`;
                message = 'The vendor has started preparing your order.';
                break;
            case 'ready_for_pickup':
                subject = `Order Ready for Pickup #${after.orderNumber}`;
                message = 'Your order is ready! Please proceed to the pickup location with your QR code.';
                break;
            case 'cancelled':
                subject = `Order Cancelled #${after.orderNumber}`;
                message = 'Your order has been cancelled. If you paid, a refund will be processed shortly.';
                break;
            case 'refunded':
                subject = `Order Refunded #${after.orderNumber}`;
                message = 'Your order has been refunded. The amount will appear in your account within 3-5 business days.';
                break;
        }
        const mailOptions = {
            from: getFromEmail(),
            to: after.customerEmail,
            subject: `${subject} - HiPop Markets`,
            html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #558B6E;">Order Status Update</h2>
            <p>${message}</p>
            <div style="background: #F8F9FA; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <p><strong>Order:</strong> #${after.orderNumber}</p>
              <p><strong>Status:</strong> ${after.status.charAt(0).toUpperCase() + after.status.slice(1).replace('_', ' ')}</p>
              <p><strong>Vendor:</strong> ${after.vendorName}</p>
              <p><strong>Total:</strong> $${after.total.toFixed(2)}</p>
            </div>
            <p>
              <a href="https://hipop-markets.web.app/order/${orderId}"
                 style="display: inline-block; padding: 10px 20px; background: #558B6E; color: white; text-decoration: none; border-radius: 5px;">
                View Order Details
              </a>
            </p>
            <hr style="border: none; border-top: 1px solid #E5E7EB; margin: 30px 0;">
            <p style="color: #6B7280; font-size: 12px;">
              © ${new Date().getFullYear()} HiPop Markets. All rights reserved.
            </p>
          </div>
        `,
        };
        await transporter.sendMail(mailOptions);
        console.log(`Status update email sent for order ${orderId}`);
        return { success: true, orderId, status: after.status };
    }
    catch (error) {
        console.error('Error sending status update email:', error);
        return { success: false, error: error.message };
    }
});
// Manual email trigger for testing
exports.testEmailFunction = functions.https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
        res.status(405).send('Method not allowed');
        return;
    }
    const { type, email } = req.body;
    if (!type || !email) {
        res.status(400).send('Missing type or email parameter');
        return;
    }
    const transporter = createTransporter();
    if (!transporter) {
        res.status(500).send('Email transporter not configured');
        return;
    }
    try {
        let mailOptions;
        switch (type) {
            case 'test':
                mailOptions = {
                    from: getFromEmail(),
                    to: email,
                    subject: 'Test Email - HiPop Markets',
                    html: '<h1>Test Email</h1><p>If you received this, email configuration is working!</p>',
                };
                break;
            default:
                res.status(400).send('Invalid email type');
                return;
        }
        await transporter.sendMail(mailOptions);
        res.status(200).json({ success: true, message: 'Email sent successfully' });
    }
    catch (error) {
        console.error('Error sending test email:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});
// Generate branded email template with user-specific CTA
const getBrandedEmailTemplate = (messageBody, userType, userName) => {
    // Determine CTA based on user type
    let ctaText = '';
    let ctaLink = '';
    switch (userType) {
        case 'vendor':
            ctaText = 'View Your Dashboard';
            ctaLink = 'https://hipop-markets.web.app/vendor';
            break;
        case 'market_organizer':
            ctaText = 'Manage Your Markets';
            ctaLink = 'https://hipop-markets.web.app/organizer';
            break;
        case 'shopper':
        default:
            ctaText = 'Explore Popups';
            ctaLink = 'https://hipop-markets.web.app/shopper';
            break;
    }
    return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>HiPop Markets</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #2C3E50; margin: 0; padding: 0; background-color: #F5F6FA; }
        .container { max-width: 600px; margin: 0 auto; background: white; }
        .header { background: linear-gradient(135deg, #704C5E 0%, #558B6E 100%); color: white; padding: 40px 30px; text-align: center; }
        .logo { font-size: 36px; font-weight: bold; margin: 0; letter-spacing: 1px; }
        .tagline { margin: 10px 0 0 0; opacity: 0.95; font-size: 14px; }
        .content { padding: 40px 30px; }
        .message { color: #2C3E50; font-size: 16px; line-height: 1.8; }
        .cta-section { text-align: center; margin: 40px 0; }
        .cta-button { display: inline-block; padding: 16px 40px; background: linear-gradient(135deg, #E8A87C 0%, #CD5120 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; box-shadow: 0 4px 12px rgba(205, 81, 32, 0.3); transition: transform 0.2s; }
        .cta-button:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(205, 81, 32, 0.4); }
        .divider { border: none; border-top: 1px solid #E5E7EB; margin: 30px 0; }
        .footer { background: #2C3E50; color: white; padding: 30px; text-align: center; }
        .footer-links { margin: 20px 0; }
        .footer-links a { color: #88A09E; text-decoration: none; margin: 0 15px; font-size: 14px; }
        .footer-links a:hover { color: #E8A87C; }
        .footer-text { font-size: 12px; opacity: 0.8; margin: 10px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">HiPop Markets</div>
          <div class="tagline">Discover. Connect. Experience.</div>
        </div>

        <div class="content">
          ${userName ? `<p style="color: #2C3E50; font-size: 18px; margin-bottom: 20px;">Hi ${userName},</p>` : ''}

          <div class="message">
            ${messageBody.split('\n').map(paragraph => `<p>${paragraph}</p>`).join('')}
          </div>

          <div class="cta-section">
            <a href="${ctaLink}" class="cta-button">${ctaText}</a>
          </div>

          <hr class="divider">

          <p style="color: #6B7280; font-size: 14px; text-align: center; margin: 20px 0;">
            Thank you for being part of the HiPop Markets community!
          </p>
        </div>

        <div class="footer">
          <div class="footer-links">
            <a href="https://hipop-markets.web.app">Visit Website</a>
            <a href="https://hipop-markets.web.app/about">About Us</a>
            <a href="mailto:${SUPPORT_EMAIL}">Contact Support</a>
          </div>
          <div class="footer-text">
            © ${new Date().getFullYear()} HiPop Markets. All rights reserved.
          </div>
          <div class="footer-text">
            Connecting vendors, organizers, and shoppers across the United States
          </div>
        </div>
      </div>
    </body>
    </html>
  `;
};
// CEO Email Blast - Send bulk emails to users with branded template
exports.sendEmailBlast = functions.https.onCall(async (data, context) => {
    // Verify CEO authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const userId = context.auth.uid;
    // Verify CEO status
    const userDoc = await db.collection('user_profiles').doc(userId).get();
    const userData = userDoc.data();
    if (!userData || userData.email !== 'jordangillispie@outlook.com') {
        throw new functions.https.HttpsError('permission-denied', 'Only CEO can send email blasts');
    }
    const { subject, messageBody, recipients, fromName } = data;
    if (!subject || !messageBody || !recipients || !Array.isArray(recipients)) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    console.log(`📧 CEO Email Blast: Sending to ${recipients.length} recipients`);
    try {
        const transporter = createTransporter();
        if (!transporter) {
            throw new functions.https.HttpsError('failed-precondition', 'Email transporter not configured');
        }
        const from = fromName ? `${fromName} <${SUPPORT_EMAIL}>` : getFromEmail();
        // Send emails in batches to avoid rate limits
        const BATCH_SIZE = 50;
        let sentCount = 0;
        let failedCount = 0;
        for (let i = 0; i < recipients.length; i += BATCH_SIZE) {
            const batch = recipients.slice(i, i + BATCH_SIZE);
            const sendPromises = batch.map(async (recipient) => {
                try {
                    // Generate branded HTML with user-specific CTA
                    const email = typeof recipient === 'string' ? recipient : recipient.email;
                    const userType = typeof recipient === 'object' ? (recipient.userType || 'shopper') : 'shopper';
                    const userName = typeof recipient === 'object' ? (recipient.name || '') : '';
                    const brandedHtml = getBrandedEmailTemplate(messageBody, userType, userName);
                    await transporter.sendMail({
                        from,
                        to: email,
                        subject,
                        html: brandedHtml,
                    });
                    sentCount++;
                    return { email, success: true };
                }
                catch (error) {
                    const email = typeof recipient === 'string' ? recipient : recipient.email;
                    console.error(`Failed to send to ${email}:`, error.message);
                    failedCount++;
                    return { email, success: false, error: error.message };
                }
            });
            await Promise.all(sendPromises);
            // Small delay between batches to respect rate limits
            if (i + BATCH_SIZE < recipients.length) {
                await new Promise(resolve => setTimeout(resolve, 1000));
            }
        }
        console.log(`✅ Email blast complete: ${sentCount} sent, ${failedCount} failed`);
        return {
            success: true,
            sent: sentCount,
            failed: failedCount,
            total: recipients.length,
        };
    }
    catch (error) {
        console.error('Error sending email blast:', error);
        throw new functions.https.HttpsError('internal', `Failed to send email blast: ${error.message}`);
    }
});
// Template for vendor application confirmation email
const getVendorApplicationConfirmationTemplate = (application, marketName) => {
    return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Application Confirmed - HiPop Markets</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #2C3E50; margin: 0; padding: 0; background-color: #F5F6FA; }
        .container { max-width: 600px; margin: 0 auto; background: white; }
        .header { background: linear-gradient(135deg, #558B6E 0%, #88A09E 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; font-weight: 600; }
        .content { padding: 30px; }
        .success-box { background: linear-gradient(135deg, #D4EDDA 0%, #C3E6CB 100%); border-radius: 16px; padding: 30px; margin: 20px 0; text-align: center; border: 2px solid #28A745; }
        .success-icon { font-size: 64px; margin-bottom: 15px; }
        .amount-box { background: #F8F9FA; border-radius: 12px; padding: 20px; margin: 20px 0; }
        .amount-box h3 { margin: 0 0 15px 0; color: #2C3E50; }
        .fee-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #E9ECEF; }
        .fee-row:last-child { border-bottom: none; font-weight: bold; font-size: 18px; color: #558B6E; }
        .button { display: inline-block; padding: 12px 30px; background: #558B6E; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 10px 0; }
        .info-box { background: #FFF3CD; border-radius: 8px; padding: 15px; margin: 20px 0; border-left: 4px solid #FFC107; }
        .footer { background: #2C3E50; color: white; padding: 30px; text-align: center; }
        .footer a { color: #88A09E; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🎉 Spot Confirmed!</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.95;">Your vendor application has been paid</p>
        </div>

        <div class="content">
          <div class="success-box">
            <div class="success-icon">✅</div>
            <h2 style="color: #155724; margin: 0 0 10px 0;">Payment Successful</h2>
            <p style="color: #155724; margin: 0;">You're all set to sell at <strong>${marketName}</strong></p>
          </div>

          <div class="amount-box">
            <h3>Payment Summary</h3>
            <div class="fee-row">
              <span>Application Fee</span>
              <span>$${application.applicationFee.toFixed(2)}</span>
            </div>
            <div class="fee-row">
              <span>Booth Fee</span>
              <span>$${application.boothFee.toFixed(2)}</span>
            </div>
            <div class="fee-row">
              <span>Total Paid</span>
              <span>$${application.totalFee.toFixed(2)}</span>
            </div>
          </div>

          <div class="info-box">
            <p style="margin: 0 0 10px 0; font-weight: bold;">📋 Next Steps:</p>
            <ul style="margin: 10px 0; padding-left: 20px;">
              <li>Set up your product listings in the app</li>
              <li>Review the market's vendor guidelines</li>
              <li>Prepare your booth setup and inventory</li>
              <li>Contact the organizer if you have questions</li>
            </ul>
          </div>

          <div style="text-align: center; margin-top: 30px;">
            <a href="https://hipopmarkets.com/vendor/markets" class="button">View Your Markets</a>
          </div>

          <p style="margin-top: 30px; color: #6B7280; font-size: 14px; text-align: center;">
            A receipt has also been sent separately by Stripe. Keep it for your records.
          </p>
        </div>

        <div class="footer">
          <p style="margin: 0 0 10px 0;">Questions about your spot?</p>
          <p style="margin: 0 0 20px 0;">
            Contact support: <a href="mailto:hipopmarkets@gmail.com">hipopmarkets@gmail.com</a>
          </p>
          <p style="margin: 0; font-size: 12px; opacity: 0.8;">
            © ${new Date().getFullYear()} HiPop Markets. All rights reserved.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
};
// Send vendor application confirmation email when payment is confirmed
exports.sendVendorApplicationConfirmationEmail = functions.firestore
    .document('vendor_applications/{applicationId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const applicationId = context.params.applicationId;
    // Only send email when status changes to confirmed
    if (before.status !== 'confirmed' && after.status === 'confirmed') {
        console.log(`📧 Sending vendor application confirmation email for ${applicationId}`);
        const transporter = createTransporter();
        if (!transporter) {
            console.error('Email transporter not configured');
            return null;
        }
        try {
            // Get vendor email
            const vendorDoc = await db.collection('users').doc(after.vendorId).get();
            const vendorEmail = vendorDoc.data()?.email;
            if (!vendorEmail) {
                console.error('No email address found for vendor');
                return null;
            }
            // Send confirmation email to vendor
            const mailOptions = {
                from: getFromEmail(),
                to: vendorEmail,
                subject: `Application Confirmed: ${after.marketName} - HiPop Markets`,
                html: getVendorApplicationConfirmationTemplate(after, after.marketName),
            };
            await transporter.sendMail(mailOptions);
            console.log(`✅ Vendor application confirmation email sent to ${vendorEmail}`);
            // Update application with email sent status
            await change.after.ref.update({
                confirmationEmailSent: true,
                confirmationEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { success: true, applicationId };
        }
        catch (error) {
            console.error('Error sending vendor application confirmation email:', error);
            return { success: false, error: error.message };
        }
    }
    return null;
});
//# sourceMappingURL=emails.js.map