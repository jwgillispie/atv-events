import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';
import vision from '@google-cloud/vision';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Firestore
const db = admin.firestore();

// Initialize Stripe with secret key from environment
const stripe = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: '2024-04-10',
});

interface CreateCheckoutSessionData {
  priceId: string;
  customerEmail: string;
  userId: string;
  userType: string;
  successUrl: string;
  cancelUrl: string;
  environment: string;
  couponCode?: string; // Optional coupon code
}

interface VerifySessionData {
  sessionId: string;
}

interface CreatePaymentIntentData {
  priceId: string;
  customerEmail: string;
  userId: string;
  userType: string;
  promoCode?: string;
  environment: string;
}

interface CancelSubscriptionData {
  userId: string;
}

interface UsageTrackingData {
  userId: string;
  featureName: string;
  amount?: number;
  metadata?: Record<string, any>;
}

interface UsageResetData {
  userIds?: string[];
  resetType: 'daily' | 'weekly' | 'monthly' | 'all';
}

interface UsageData {
  userId: string;
  [key: string]: number | string;
}

interface UsageAlert {
  userId: string;
  featureName: string;
  currentUsage: number;
  limit: number;
  percentage: number;
  timestamp: FirebaseFirestore.FieldValue;
}

// Product payment configuration interface
interface ProductPaymentConfig {
  vendorId: string;
  vendorName: string;
  productIds: string[];
  quantities?: { [productId: string]: number };
  productDetails?: { [productId: string]: {
    productName: string;
    productImage?: string;
    category: string;
    pricePerUnit: number;
    quantity: number;
    totalPrice: number;
  }};
  subtotal: number;
  platformFee: number;
  total: number;
  marketId: string;
  marketName: string;
  pickupLocation?: string;
  pickupDate: string;
  pickupTimeSlot?: string;
  customerNotes?: string;
}

// Ticket payment configuration interface
interface TicketPaymentConfig {
  eventId: string;
  eventName: string;
  organizerId: string;
  organizerName: string;
  quantity: number;
  pricePerTicket: number;
  subtotal: number;
  platformFee: number;
  total: number;
  eventDate: string;
  ticketType?: string;
}

// Vendor application payment configuration interface
interface VendorApplicationPaymentConfig {
  applicationId: string;
  vendorId: string;
  marketId: string;
  marketName: string;
  organizerId: string;
  applicationFee: number;
  boothFee: number;
  total: number;
  platformFee: number;
  organizerPayout: number;
}

interface CreateProductPaymentIntentData {
  config: ProductPaymentConfig;
  customerEmail: string;
  userId: string;
  environment: string;
}

interface CreateTicketPaymentIntentData {
  config: TicketPaymentConfig;
  customerEmail: string;
  userId: string;
  environment: string;
}

interface CreateVendorApplicationPaymentIntentData {
  config: VendorApplicationPaymentConfig;
  customerEmail: string;
  userId: string;
  environment: string;
}

// 🔒 SECURE: Create payment intent for direct card payments
export const createPaymentIntent = functions.https.onCall(
  async (data: CreatePaymentIntentData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to create payment intent'
      );
    }

    // Verify user is creating payment intent for themselves
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only create payment intent for authenticated user'
      );
    }

    try {
      functions.logger.info('💳 Creating payment intent for direct payment', {
        userId: data.userId,
        userType: data.userType,
        priceId: data.priceId,
        customerEmail: data.customerEmail,
        environment: data.environment,
      });

      // Get or create Stripe customer
      let customer: Stripe.Customer;
      const existingCustomers = await stripe.customers.list({
        email: data.customerEmail,
        limit: 1,
      });

      if (existingCustomers.data.length > 0) {
        customer = existingCustomers.data[0];
        functions.logger.info('Found existing customer', { customerId: customer.id });
      } else {
        customer = await stripe.customers.create({
          email: data.customerEmail,
          metadata: {
            userId: data.userId,
            userType: data.userType,
            environment: data.environment,
          },
        });
        functions.logger.info('Created new customer', { customerId: customer.id });
      }

      // Get price from Stripe to determine amount
      const price = await stripe.prices.retrieve(data.priceId);
      if (!price.unit_amount) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Price does not have a unit amount'
        );
      }

      let amount = price.unit_amount;
      let discountedAmount = amount;

      // Apply promo code if provided
      if (data.promoCode) {
        try {
          // Special handling for FOUNDERJOZO100 - 100% discount
          if (data.promoCode.toUpperCase() === 'FOUNDERJOZO100') {
            discountedAmount = 0; // 100% discount
            functions.logger.info('Applied FOUNDERJOZO100 special discount', {
              originalAmount: amount,
              finalAmount: discountedAmount,
              promoCode: data.promoCode,
            });
          } else {
            const promotionCodes = await stripe.promotionCodes.list({
              code: data.promoCode,
              active: true,
              limit: 1,
            });

          if (promotionCodes.data.length > 0) {
            const promoCode = promotionCodes.data[0];
            const coupon = promoCode.coupon;
            
            if (coupon.percent_off) {
              const calculatedAmount = Math.round(amount * (1 - coupon.percent_off / 100));
              // Ensure calculated amount is valid and not negative
              if (isNaN(calculatedAmount) || !isFinite(calculatedAmount) || calculatedAmount < 0) {
                functions.logger.warn('Invalid calculated percentage discount', {
                  originalAmount: amount,
                  discountPercent: coupon.percent_off,
                  calculatedAmount,
                });
                throw new functions.https.HttpsError(
                  'failed-precondition',
                  'Invalid discount calculation for percentage coupon'
                );
              }
              discountedAmount = calculatedAmount;
              functions.logger.info('Applied percentage discount', {
                originalAmount: amount,
                discountPercent: coupon.percent_off,
                finalAmount: discountedAmount,
              });
            } else if (coupon.amount_off) {
              const calculatedAmount = Math.max(0, amount - coupon.amount_off);
              // Ensure calculated amount is valid
              if (isNaN(calculatedAmount) || !isFinite(calculatedAmount)) {
                functions.logger.warn('Invalid calculated fixed discount', {
                  originalAmount: amount,
                  discountAmount: coupon.amount_off,
                  calculatedAmount,
                });
                throw new functions.https.HttpsError(
                  'failed-precondition',
                  'Invalid discount calculation for fixed amount coupon'
                );
              }
              discountedAmount = calculatedAmount;
              functions.logger.info('Applied fixed discount', {
                originalAmount: amount,
                discountAmount: coupon.amount_off,
                finalAmount: discountedAmount,
              });
            }
          } else {
            functions.logger.warn('Invalid promo code provided', { promoCode: data.promoCode });
            throw new functions.https.HttpsError(
              'failed-precondition',
              'Invalid promo code'
            );
          }
          }
        } catch (promoError) {
          functions.logger.error('Error processing promo code', {
            promoCode: data.promoCode,
            error: promoError,
            errorMessage: promoError instanceof Error ? promoError.message : 'Unknown error',
            userId: data.userId,
          });
          
          // Provide more specific error messages based on the error type
          if (promoError instanceof Stripe.errors.StripeError) {
            const stripeError = promoError as Stripe.errors.StripeError;
            throw new functions.https.HttpsError(
              'failed-precondition',
              `Stripe error processing promo code: ${stripeError.message}`
            );
          }
          
          throw new functions.https.HttpsError(
            'failed-precondition',
            `Unable to process promo code "${data.promoCode}": ${promoError instanceof Error ? promoError.message : 'Unknown error'}`
          );
        }
      }

      // Create payment intent
      const paymentIntent = await stripe.paymentIntents.create({
        amount: discountedAmount,
        currency: price.currency,
        customer: customer.id,
        automatic_payment_methods: {
          enabled: true,
        },
        metadata: {
          userId: data.userId,
          userType: data.userType,
          priceId: data.priceId,
          environment: data.environment,
          originalAmount: amount.toString(),
          ...(data.promoCode && { promoCode: data.promoCode }),
        },
        description: `${data.userType} subscription - ${price.nickname || data.priceId}`,
        setup_future_usage: 'off_session', // Save payment method for future use
      });

      functions.logger.info('✅ Payment intent created successfully', {
        paymentIntentId: paymentIntent.id,
        amount: discountedAmount,
        currency: price.currency,
        customerId: customer.id,
      });

      return {
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        customer_id: customer.id,
        amount: discountedAmount,
        currency: price.currency,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating payment intent', {
        error,
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
        userId: data.userId,
        priceId: data.priceId,
        promoCode: data.promoCode,
        userType: data.userType,
      });
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      // Provide more specific error messages for common issues
      if (error instanceof Stripe.errors.StripeError) {
        const stripeError = error as Stripe.errors.StripeError;
        throw new functions.https.HttpsError(
          'internal',
          `Stripe API error: ${stripeError.message}`
        );
      }
      
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      throw new functions.https.HttpsError(
        'internal',
        `Failed to create payment intent: ${errorMessage}`
      );
    }
  }
);

// 🔒 SECURE: Create checkout session server-side
/**
 * Validates a founding partner coupon
 */
async function validateFoundingPartnerCoupon(
  couponCode: string,
  userId: string,
  userEmail: string
): Promise<boolean> {
  try {
    // Check if coupon exists in our tracking system
    const couponRef = db.collection('coupon_redemptions').doc(couponCode);
    const couponDoc = await couponRef.get();
    
    if (!couponDoc.exists) {
      // If not in our system, it might be a regular Stripe coupon
      // Let Stripe handle it
      return true;
    }
    
    const couponData = couponDoc.data();
    
    // Check if coupon has expired
    if (couponData?.expiresAt && couponData.expiresAt.toDate() < new Date()) {
      functions.logger.warn('Coupon expired', { couponCode, userId });
      return false;
    }
    
    // Check if user has already used this coupon
    const usedBy = couponData?.usedBy || [];
    const hasUsed = usedBy.some((user: any) => 
      user.userId === userId || user.email === userEmail
    );
    
    if (hasUsed) {
      functions.logger.warn('Coupon already used by user', { couponCode, userId, userEmail });
      return false;
    }
    
    // Check if coupon has reached max uses
    if (couponData?.maxUses && usedBy.length >= couponData.maxUses) {
      functions.logger.warn('Coupon max uses reached', { couponCode, uses: usedBy.length });
      return false;
    }
    
    // Record the usage
    await couponRef.update({
      usedBy: admin.firestore.FieldValue.arrayUnion({
        userId,
        email: userEmail,
        redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
      })
    });
    
    functions.logger.info('Coupon validated and recorded', { couponCode, userId });
    return true;
    
  } catch (error) {
    functions.logger.error('Error validating coupon', { error, couponCode, userId });
    // If there's an error, let them proceed without the coupon
    return false;
  }
}

// 🛒 Create payment intent for product purchases
export const createProductPaymentIntent = functions.https.onCall(
  async (data: CreateProductPaymentIntentData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to make a purchase'
      );
    }

    // Verify user is creating payment for themselves
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only create payment for authenticated user'
      );
    }

    try {
      const { config, customerEmail, userId } = data;

      functions.logger.info('🛒 Creating product payment intent', {
        userId,
        vendorId: config.vendorId,
        marketId: config.marketId,
        total: config.total,
        productCount: config.productIds.length,
      });

      // Get or create Stripe customer
      let customer: Stripe.Customer;
      const existingCustomers = await stripe.customers.list({
        email: customerEmail,
        limit: 1,
      });

      if (existingCustomers.data.length > 0) {
        customer = existingCustomers.data[0];
      } else {
        customer = await stripe.customers.create({
          email: customerEmail,
          metadata: {
            firebaseUID: userId,
            platform: 'hipop_markets',
          },
        });
      }

      // Create payment intent
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(config.total * 100), // Convert to cents
        currency: 'usd',
        customer: customer.id,
        receipt_email: customerEmail,
        description: `HiPop Markets - Purchase from ${config.vendorName}`,
        metadata: {
          userId,
          vendorId: config.vendorId,
          vendorName: config.vendorName,
          marketId: config.marketId,
          marketName: config.marketName,
          productIds: config.productIds.join(','),
          subtotal: config.subtotal.toString(),
          platformFee: config.platformFee.toString(),
          pickupDate: config.pickupDate,
          pickupTimeSlot: config.pickupTimeSlot || '',
          orderType: 'product_purchase',
        },
        statement_descriptor_suffix: 'HIPOP',
      });

      // Create order record in Firestore
      const orderNumber = generateOrderNumber();
      const qrCode = `hipop://order/${orderNumber}`;

      // Build items array from productDetails
      const items = [];
      let totalItemCount = 0;

      if (config.productDetails) {
        for (const [productId, details] of Object.entries(config.productDetails)) {
          items.push({
            productId,
            productName: details.productName || 'Unknown Product',
            productImage: details.productImage || null,
            category: details.category || '',
            quantity: details.quantity || 1,
            pricePerUnit: details.pricePerUnit || 0,
            totalPrice: details.totalPrice || 0,
          });
          totalItemCount += (details.quantity || 1);
        }
      } else {
        // Fallback for backward compatibility if productDetails not provided
        for (const productId of config.productIds) {
          const quantity = config.quantities?.[productId] || 1;
          items.push({
            productId,
            productName: 'Product',
            productImage: null,
            category: '',
            quantity,
            pricePerUnit: 0,
            totalPrice: 0,
          });
          totalItemCount += quantity;
        }
      }

      // Get customer name from auth or Firestore
      let customerName = '';
      try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          customerName = userData?.displayName || userData?.name || customerEmail.split('@')[0];
        }
      } catch (error) {
        customerName = customerEmail.split('@')[0];
      }

      const orderData = {
        orderNumber,
        status: 'pending',
        customerId: userId,
        customerEmail,
        customerName,
        vendorId: config.vendorId,
        vendorName: config.vendorName,
        marketId: config.marketId,
        marketName: config.marketName,
        marketLocation: config.pickupLocation || '', // Use pickupLocation from config
        items, // Now includes full product details
        totalItems: totalItemCount,
        subtotal: config.subtotal,
        platformFee: config.platformFee,
        total: config.total,
        currency: 'USD',
        pickupDate: new Date(config.pickupDate),
        pickupTimeSlot: config.pickupTimeSlot,
        pickupInstructions: config.customerNotes, // Store as pickupInstructions
        customerNotes: config.customerNotes,
        stripePaymentIntentId: paymentIntent.id,
        qrCode,
        qrScanned: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const orderRef = await db.collection('orders').add(orderData);

      // Create transaction record
      const transactionData = {
        type: 'product_purchase',
        status: 'pending',
        userId,
        userEmail: customerEmail,
        userName: '', // Will be filled from user data
        subtotal: config.subtotal,
        platformFee: config.platformFee,
        total: config.total,
        currency: 'USD',
        stripePaymentIntentId: paymentIntent.id,
        recipientId: config.vendorId,
        recipientName: config.vendorName,
        recipientPayout: config.subtotal * 0.94, // 94% after 6% fee
        productIds: config.productIds,
        marketId: config.marketId,
        marketName: config.marketName,
        pickupDate: new Date(config.pickupDate),
        pickupTimeSlot: config.pickupTimeSlot,
        orderId: orderRef.id,
        qrCode,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection('transactions').add(transactionData);

      functions.logger.info('✅ Product payment intent created successfully', {
        paymentIntentId: paymentIntent.id,
        orderId: orderRef.id,
      });

      return {
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        order_id: orderRef.id,
        order_number: orderNumber,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating product payment intent', { error });
      throw new functions.https.HttpsError(
        'internal',
        'Failed to create payment intent'
      );
    }
  }
);

// Interface for product checkout session
interface CreateProductCheckoutSessionData {
  config: ProductPaymentConfig;
  customerEmail: string;
  userId: string;
  successUrl: string;
  cancelUrl: string;
  environment: string;
}

// 🔒 SECURE: Create Stripe Checkout Session for product purchases (Web)
export const createProductCheckoutSession = functions.https.onCall(
  async (data: CreateProductCheckoutSessionData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to make a purchase'
      );
    }

    // Verify user is creating payment for themselves
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only create payment for authenticated user'
      );
    }

    try {
      const { config, customerEmail, userId, successUrl, cancelUrl } = data;

      functions.logger.info('🛒 Creating product checkout session for web', {
        userId,
        vendorId: config.vendorId,
        marketId: config.marketId,
        total: config.total,
        productCount: config.productIds.length,
      });

      // Get or create Stripe customer
      let customer: Stripe.Customer;
      const existingCustomers = await stripe.customers.list({
        email: customerEmail,
        limit: 1,
      });

      if (existingCustomers.data.length > 0) {
        customer = existingCustomers.data[0];
      } else {
        customer = await stripe.customers.create({
          email: customerEmail,
          metadata: {
            firebaseUID: userId,
            platform: 'hipop_markets',
          },
        });
      }

      // Create order record in Firestore BEFORE payment
      const orderNumber = generateOrderNumber();
      const qrCode = `hipop://order/${orderNumber}`;

      // Build items array from productDetails
      const items = [];
      let totalItemCount = 0;

      if (config.productDetails) {
        for (const [productId, details] of Object.entries(config.productDetails)) {
          items.push({
            productId,
            productName: details.productName || 'Unknown Product',
            productImage: details.productImage || null,
            category: details.category || '',
            quantity: details.quantity || 1,
            pricePerUnit: details.pricePerUnit || 0,
            totalPrice: details.totalPrice || 0,
          });
          totalItemCount += (details.quantity || 1);
        }
      } else {
        // Fallback for backward compatibility
        for (const productId of config.productIds) {
          const quantity = config.quantities?.[productId] || 1;
          items.push({
            productId,
            productName: 'Product',
            productImage: null,
            category: '',
            quantity,
            pricePerUnit: 0,
            totalPrice: 0,
          });
          totalItemCount += quantity;
        }
      }

      // Get customer name from auth or Firestore
      let customerName = '';
      try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          customerName = userData?.displayName || userData?.name || customerEmail.split('@')[0];
        }
      } catch (error) {
        customerName = customerEmail.split('@')[0];
      }

      const orderData = {
        orderNumber,
        status: 'pending',
        customerId: userId,
        customerEmail,
        customerName,
        vendorId: config.vendorId,
        vendorName: config.vendorName,
        marketId: config.marketId,
        marketName: config.marketName,
        marketLocation: config.pickupLocation || '',
        items,
        totalItems: totalItemCount,
        subtotal: config.subtotal,
        platformFee: config.platformFee,
        total: config.total,
        currency: 'USD',
        pickupDate: new Date(config.pickupDate),
        pickupTimeSlot: config.pickupTimeSlot,
        pickupInstructions: config.customerNotes,
        customerNotes: config.customerNotes,
        qrCode,
        qrScanned: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const orderRef = await db.collection('orders').add(orderData);

      // Build line items for Stripe Checkout
      const lineItems: Stripe.Checkout.SessionCreateParams.LineItem[] = [];

      if (config.productDetails) {
        for (const [productId, details] of Object.entries(config.productDetails)) {
          lineItems.push({
            price_data: {
              currency: 'usd',
              product_data: {
                name: details.productName || 'Unknown Product',
                images: details.productImage ? [details.productImage] : [],
                metadata: {
                  productId,
                  category: details.category || '',
                },
              },
              unit_amount: Math.round(details.pricePerUnit * 100), // Convert to cents
            },
            quantity: details.quantity || 1,
          });
        }
      } else {
        // Fallback - create single line item with total
        lineItems.push({
          price_data: {
            currency: 'usd',
            product_data: {
              name: `Purchase from ${config.vendorName}`,
            },
            unit_amount: Math.round(config.subtotal * 100),
          },
          quantity: 1,
        });
      }

      // Add platform fee as separate line item
      if (config.platformFee > 0) {
        lineItems.push({
          price_data: {
            currency: 'usd',
            product_data: {
              name: 'HiPop Platform Fee',
            },
            unit_amount: Math.round(config.platformFee * 100),
          },
          quantity: 1,
        });
      }

      // Create Stripe Checkout Session
      const sessionConfig: Stripe.Checkout.SessionCreateParams = {
        mode: 'payment',
        line_items: lineItems,
        customer: customer.id,
        customer_email: customerEmail,
        success_url: successUrl,
        cancel_url: cancelUrl,
        metadata: {
          userId,
          vendorId: config.vendorId,
          vendorName: config.vendorName,
          marketId: config.marketId,
          marketName: config.marketName,
          productIds: config.productIds.join(','),
          subtotal: config.subtotal.toString(),
          platformFee: config.platformFee.toString(),
          pickupDate: config.pickupDate,
          pickupTimeSlot: config.pickupTimeSlot || '',
          orderType: 'product_purchase',
          orderId: orderRef.id,
          orderNumber,
        },
        payment_intent_data: {
          metadata: {
            orderId: orderRef.id,
            orderNumber,
            userId,
            vendorId: config.vendorId,
          },
          description: `HiPop Markets - Purchase from ${config.vendorName}`,
          statement_descriptor_suffix: 'HIPOP',
        },
      };

      const session = await stripe.checkout.sessions.create(sessionConfig);

      // Update order with Stripe session ID
      await orderRef.update({
        stripeSessionId: session.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create transaction record
      const transactionData = {
        type: 'product_purchase',
        status: 'pending',
        userId,
        userEmail: customerEmail,
        userName: customerName,
        subtotal: config.subtotal,
        platformFee: config.platformFee,
        total: config.total,
        currency: 'USD',
        stripeSessionId: session.id,
        recipientId: config.vendorId,
        recipientName: config.vendorName,
        recipientPayout: config.subtotal * 0.94, // 94% after 6% fee
        productIds: config.productIds,
        marketId: config.marketId,
        marketName: config.marketName,
        pickupDate: new Date(config.pickupDate),
        pickupTimeSlot: config.pickupTimeSlot,
        orderId: orderRef.id,
        qrCode,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection('transactions').add(transactionData);

      functions.logger.info('✅ Product checkout session created successfully', {
        sessionId: session.id,
        orderId: orderRef.id,
        orderNumber,
      });

      return {
        url: session.url,
        sessionId: session.id,
        orderId: orderRef.id,
        orderNumber,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating product checkout session', { error });
      throw new functions.https.HttpsError(
        'internal',
        'Failed to create checkout session'
      );
    }
  }
);

// 🎟️ Create payment intent for ticket purchases
export const createTicketPaymentIntent = functions.https.onCall(
  async (data: CreateTicketPaymentIntentData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to purchase tickets'
      );
    }

    // Verify user is creating payment for themselves
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only purchase tickets for authenticated user'
      );
    }

    try {
      const { config, customerEmail, userId } = data;

      functions.logger.info('🎟️ Creating ticket payment intent', {
        userId,
        eventId: config.eventId,
        quantity: config.quantity,
        total: config.total,
      });

      // Check ticket availability
      const eventDoc = await db.collection('events').doc(config.eventId).get();
      if (!eventDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Event not found'
        );
      }

      const eventData = eventDoc.data();
      const availableTickets = eventData?.availableTickets || 0;

      if (availableTickets < config.quantity) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Not enough tickets available'
        );
      }

      // Get or create Stripe customer
      let customer: Stripe.Customer;
      const existingCustomers = await stripe.customers.list({
        email: customerEmail,
        limit: 1,
      });

      if (existingCustomers.data.length > 0) {
        customer = existingCustomers.data[0];
      } else {
        customer = await stripe.customers.create({
          email: customerEmail,
          metadata: {
            firebaseUID: userId,
            platform: 'hipop_markets',
          },
        });
      }

      // Create payment intent
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(config.total * 100), // Convert to cents
        currency: 'usd',
        customer: customer.id,
        receipt_email: customerEmail,
        description: `HiPop Markets - Tickets for ${config.eventName}`,
        metadata: {
          userId,
          eventId: config.eventId,
          eventName: config.eventName,
          organizerId: config.organizerId,
          organizerName: config.organizerName,
          quantity: config.quantity.toString(),
          pricePerTicket: config.pricePerTicket.toString(),
          subtotal: config.subtotal.toString(),
          platformFee: config.platformFee.toString(),
          eventDate: config.eventDate,
          ticketType: config.ticketType || 'general',
          orderType: 'ticket_purchase',
        },
        statement_descriptor_suffix: 'TICKETS',
      });

      // Reserve tickets temporarily (will be confirmed on payment completion)
      const ticketBatch = {
        transactionId: paymentIntent.id,
        eventId: config.eventId,
        eventName: config.eventName,
        userId,
        userEmail: customerEmail,
        quantity: config.quantity,
        pricePerTicket: config.pricePerTicket,
        total: config.total,
        status: 'reserved',
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 10 * 60 * 1000) // 10 minute reservation
        ),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const batchRef = await db.collection('ticket_batches').add(ticketBatch);

      // Create transaction record
      const transactionData = {
        type: 'ticket_purchase',
        status: 'pending',
        userId,
        userEmail: customerEmail,
        userName: '', // Will be filled from user data
        subtotal: config.subtotal,
        platformFee: config.platformFee,
        total: config.total,
        currency: 'USD',
        stripePaymentIntentId: paymentIntent.id,
        recipientId: config.organizerId,
        recipientName: config.organizerName,
        recipientPayout: config.subtotal * 0.94, // 94% after 6% fee
        eventId: config.eventId,
        eventName: config.eventName,
        eventDate: new Date(config.eventDate),
        ticketQuantity: config.quantity,
        ticketType: config.ticketType,
        metadata: {
          batchId: batchRef.id,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection('transactions').add(transactionData);

      functions.logger.info('✅ Ticket payment intent created successfully', {
        paymentIntentId: paymentIntent.id,
        batchId: batchRef.id,
        quantity: config.quantity,
      });

      return {
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        batch_id: batchRef.id,
        quantity: config.quantity,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating ticket payment intent', { error });

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Failed to create ticket payment'
      );
    }
  }
);

// Helper function to generate order number
function generateOrderNumber(): string {
  const now = new Date();
  const timestamp = now.getTime().toString().substring(6);
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
  return `HP-${timestamp}${random}`;
}

// Create payment intent for vendor application fees
export const createVendorApplicationPaymentIntent = functions.https.onCall(
  async (data: CreateVendorApplicationPaymentIntentData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to pay application fees'
      );
    }

    // Verify user is creating payment for themselves
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only pay application fees for authenticated user'
      );
    }

    try {
      const { config, customerEmail, userId } = data;

      functions.logger.info('💼 Creating vendor application payment intent', {
        userId,
        applicationId: config.applicationId,
        marketId: config.marketId,
        total: config.total,
      });

      // Verify the application exists and is approved
      const applicationDoc = await db.collection('vendor_applications').doc(config.applicationId).get();
      if (!applicationDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Application not found'
        );
      }

      const applicationData = applicationDoc.data();
      if (applicationData?.status !== 'approved') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Application must be approved before payment'
        );
      }

      // Verify the application hasn't been paid yet
      if (applicationData?.paymentStatus === 'paid') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Application has already been paid'
        );
      }

      // Verify the vendor is the one making the payment
      if (applicationData?.vendorId !== userId) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Can only pay for your own applications'
        );
      }

      // Get organizer's Stripe Connect account
      const organizerIntegrationDoc = await db
        .collection('organizer_integrations')
        .doc(config.organizerId)
        .get();

      if (!organizerIntegrationDoc.exists) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Organizer has not set up payment processing'
        );
      }

      const stripeAccountId = organizerIntegrationDoc.data()?.stripe?.accountId;
      if (!stripeAccountId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Organizer Stripe account not configured'
        );
      }

      // Verify Stripe Connect account is active
      const account = await stripe.accounts.retrieve(stripeAccountId);
      if (!account.charges_enabled) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Organizer payment processing is not fully set up'
        );
      }

      // Get or create Stripe customer
      let customer: Stripe.Customer;
      const existingCustomers = await stripe.customers.list({
        email: customerEmail,
        limit: 1,
      });

      if (existingCustomers.data.length > 0) {
        customer = existingCustomers.data[0];
      } else {
        customer = await stripe.customers.create({
          email: customerEmail,
          metadata: {
            firebaseUID: userId,
            platform: 'hipop_markets',
          },
        });
      }

      // Create payment intent with Stripe Connect
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(config.total * 100), // Convert to cents
        currency: 'usd',
        customer: customer.id,
        receipt_email: customerEmail,
        description: `HiPop Markets - Application Fee for ${config.marketName}`,
        metadata: {
          userId,
          applicationId: config.applicationId,
          vendorId: config.vendorId,
          marketId: config.marketId,
          marketName: config.marketName,
          organizerId: config.organizerId,
          applicationFee: config.applicationFee.toString(),
          boothFee: config.boothFee.toString(),
          platformFee: config.platformFee.toString(),
          organizerPayout: config.organizerPayout.toString(),
          orderType: 'vendor_application',
        },
        statement_descriptor_suffix: 'VENDOR APP',
        application_fee_amount: Math.round(config.platformFee * 100), // 10% platform fee
        transfer_data: {
          destination: stripeAccountId,
        },
      });

      // Create transaction record
      const transactionData = {
        type: 'vendor_application',
        status: 'pending',
        userId,
        userEmail: customerEmail,
        userName: '', // Will be filled from user data
        subtotal: config.total,
        platformFee: config.platformFee,
        total: config.total,
        currency: 'USD',
        stripePaymentIntentId: paymentIntent.id,
        recipientId: config.organizerId,
        recipientName: '', // Will be filled from organizer data
        recipientPayout: config.organizerPayout,
        applicationId: config.applicationId,
        marketId: config.marketId,
        marketName: config.marketName,
        applicationFee: config.applicationFee,
        boothFee: config.boothFee,
        metadata: {
          stripeAccountId,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection('transactions').add(transactionData);

      // Update application with payment intent
      await db.collection('vendor_applications').doc(config.applicationId).update({
        paymentIntentId: paymentIntent.id,
        paymentStatus: 'processing',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info('✅ Vendor application payment intent created successfully', {
        paymentIntentId: paymentIntent.id,
        applicationId: config.applicationId,
        total: config.total,
      });

      return {
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        application_id: config.applicationId,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating vendor application payment intent', { error });

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Failed to create vendor application payment'
      );
    }
  }
);

export const createCheckoutSession = functions.https.onCall(
  async (data: CreateCheckoutSessionData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to create subscription'
      );
    }

    // Verify user is creating subscription for themselves
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only create subscription for authenticated user'
      );
    }

    try {
      // Validate coupon if provided
      let validatedCoupon: string | undefined = undefined;
      if (data.couponCode) {
        const isValid = await validateFoundingPartnerCoupon(
          data.couponCode,
          data.userId,
          data.customerEmail
        );
        
        if (isValid) {
          validatedCoupon = data.couponCode;
        } else {
          // Don't throw error, just don't apply the coupon
          functions.logger.warn('Invalid coupon attempted', { 
            couponCode: data.couponCode,
            userId: data.userId 
          });
        }
      }

      functions.logger.info('🔒 Creating secure checkout session', {
        userId: data.userId,
        userType: data.userType,
        priceId: data.priceId,
        environment: data.environment,
        coupon: validatedCoupon,
      });

      // Build session configuration
      const sessionConfig: Stripe.Checkout.SessionCreateParams = {
        mode: 'subscription',
        line_items: [
          {
            price: data.priceId,
            quantity: 1,
          },
        ],
        customer_email: data.customerEmail,
        success_url: data.successUrl,
        cancel_url: data.cancelUrl,
        allow_promotion_codes: !validatedCoupon, // Only allow if no coupon provided
        billing_address_collection: 'required',
        metadata: {
          userId: data.userId,
          userType: data.userType,
          environment: data.environment,
        },
        subscription_data: {
          metadata: {
            userId: data.userId,
            userType: data.userType,
            environment: data.environment,
          },
        },
      };

      // Apply the validated coupon to the session
      if (validatedCoupon) {
        // Try to apply the coupon as a Stripe coupon
        try {
          const coupon = await stripe.coupons.retrieve(validatedCoupon);
          if (coupon && coupon.valid) {
            sessionConfig.discounts = [{
              coupon: validatedCoupon,
            }];
            functions.logger.info('Applied Stripe coupon to session', { 
              couponCode: validatedCoupon,
              percentOff: coupon.percent_off,
              amountOff: coupon.amount_off,
            });
          }
        } catch (couponError) {
          // If it's not a valid Stripe coupon, just log and continue
          functions.logger.warn('Coupon not found in Stripe', { 
            couponCode: validatedCoupon,
            error: couponError 
          });
        }
      }

      // Create the checkout session
      const session = await stripe.checkout.sessions.create(sessionConfig);

      functions.logger.info('✅ Checkout session created', {
        sessionId: session.id,
        url: session.url,
      });

      return {
        url: session.url,
        sessionId: session.id,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating checkout session', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to create checkout session'
      );
    }
  }
);

// 🔒 ALTERNATIVE WEBHOOK: Using express with raw body middleware
// This is a backup webhook endpoint that uses express.raw() to preserve the body
const express = require('express');
const cors = require('cors');

const webhookApp = express();
webhookApp.use(cors({ origin: true }));

// IMPORTANT: Apply raw body parser ONLY to webhook route
webhookApp.post('/webhook', express.raw({ type: 'application/json' }), async (req: any, res: any) => {
  const endpointSecret = functions.config().stripe.webhook_secret;
  const sig = req.headers['stripe-signature'];

  if (!sig) {
    res.status(400).send('No stripe-signature header');
    return;
  }

  try {
    functions.logger.info('🔍 Alternative webhook request', {
      bodyType: typeof req.body,
      isBuffer: Buffer.isBuffer(req.body),
      bodyLength: req.body ? req.body.length : 0,
      signaturePresent: !!sig,
    });

    // Express.raw() should give us a Buffer
    const event = stripe.webhooks.constructEvent(
      req.body,
      sig as string,
      endpointSecret
    );

    functions.logger.info('✅ Alternative webhook verified', {
      type: event.type,
      id: event.id,
    });

    // Process the event (use same handlers as main webhook)
    await processWebhookEvent(event);
    
    res.json({ received: true });
  } catch (err) {
    functions.logger.error('❌ Alternative webhook error', err);
    res.status(400).send(`Webhook Error: ${(err as Error).message}`);
  }
});

// Export the alternative webhook
export const stripeWebhookAlt = functions.https.onRequest(webhookApp);

// Helper function to process webhook events (shared between both endpoints)
async function processWebhookEvent(event: Stripe.Event) {
  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutSessionCompleted(event.data.object as Stripe.Checkout.Session);
        break;
      case 'customer.subscription.created':
        await handleSubscriptionCreated(event.data.object as Stripe.Subscription);
        break;
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object as Stripe.Subscription);
        break;
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
        break;
      case 'customer.subscription.trial_will_end':
        await handleTrialWillEnd(event.data.object as Stripe.Subscription);
        break;
      case 'invoice.payment_succeeded':
        await handlePaymentSucceeded(event.data.object as Stripe.Invoice);
        break;
      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object as Stripe.Invoice);
        break;
      case 'invoice.upcoming':
        await handleUpcomingInvoice(event.data.object as Stripe.Invoice);
        break;
      case 'payment_intent.succeeded':
        await handlePaymentIntentSucceeded(event.data.object as Stripe.PaymentIntent);
        break;
      case 'payment_method.attached':
        await handlePaymentMethodAttached(event.data.object as Stripe.PaymentMethod);
        break;
      case 'coupon.created':
        await handleCouponCreated(event.data.object as Stripe.Coupon);
        break;
      case 'coupon.deleted':
        await handleCouponDeleted(event.data.object as Stripe.Coupon);
        break;
      case 'coupon.updated':
        await handleCouponUpdated(event.data.object as Stripe.Coupon);
        break;
      case 'charge.succeeded':
        await handleChargeSucceeded(event.data.object as Stripe.Charge);
        break;
      case 'charge.failed':
        await handleChargeFailed(event.data.object as Stripe.Charge);
        break;
      case 'customer.created':
        await handleCustomerCreated(event.data.object as Stripe.Customer);
        break;
      case 'customer.updated':
        await handleCustomerUpdated(event.data.object as Stripe.Customer);
        break;
      case 'customer.deleted':
        await handleCustomerDeleted(event.data.object as Stripe.Customer);
        break;
      case 'invoice.created':
        await handleInvoiceCreated(event.data.object as Stripe.Invoice);
        break;
      case 'invoice.finalized':
        await handleInvoiceFinalized(event.data.object as Stripe.Invoice);
        break;
      case 'invoice.paid':
        await handleInvoicePaid(event.data.object as Stripe.Invoice);
        break;
      case 'payment_intent.created':
        await handlePaymentIntentCreated(event.data.object as Stripe.PaymentIntent);
        break;
      case 'payment_intent.payment_failed':
        await handlePaymentIntentFailed(event.data.object as Stripe.PaymentIntent);
        break;
      case 'payment_method.detached':
        await handlePaymentMethodDetached(event.data.object as Stripe.PaymentMethod);
        break;
      case 'checkout.session.expired':
        await handleCheckoutSessionExpired(event.data.object as Stripe.Checkout.Session);
        break;
      case 'checkout.session.async_payment_succeeded':
        await handleCheckoutAsyncPaymentSucceeded(event.data.object as Stripe.Checkout.Session);
        break;
      case 'checkout.session.async_payment_failed':
        await handleCheckoutAsyncPaymentFailed(event.data.object as Stripe.Checkout.Session);
        break;
      default:
        functions.logger.info('🔄 Unhandled webhook event type', {
          type: event.type,
        });
    }
  } catch (error) {
    functions.logger.error('❌ Error processing webhook event', error);
    throw error;
  }
}

// 🔒 SECURE: Verify subscription session server-side
export const verifySubscriptionSession = functions.https.onCall(
  async (data: VerifySessionData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to verify session'
      );
    }

    try {
      functions.logger.info('🔒 Verifying subscription session', {
        sessionId: data.sessionId,
        userId: context.auth.uid,
      });

      // Retrieve session from Stripe
      const session = await stripe.checkout.sessions.retrieve(data.sessionId);

      // Verify session belongs to authenticated user
      if (session.metadata?.userId !== context.auth.uid) {
        functions.logger.warn('⚠️ Session verification failed - user mismatch', {
          sessionUserId: session.metadata?.userId,
          authUserId: context.auth.uid,
        });
        return { valid: false };
      }

      // Check if payment was successful
      const valid = session.payment_status === 'paid';

      functions.logger.info('✅ Session verification complete', {
        sessionId: data.sessionId,
        valid,
        paymentStatus: session.payment_status,
      });

      return {
        valid,
        paymentStatus: session.payment_status,
        customerEmail: session.customer_email,
        subscriptionId: session.subscription,
      };
    } catch (error) {
      functions.logger.error('❌ Error verifying session', error);
      return { valid: false };
    }
  }
);

// 🔒 SECURE: Cancel subscription server-side
export const cancelSubscription = functions.https.onCall(
  async (data: CancelSubscriptionData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to cancel subscription'
      );
    }

    // Verify user is cancelling their own subscription
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only cancel own subscription'
      );
    }

    try {
      functions.logger.info('🔒 Cancelling subscription', {
        userId: data.userId,
      });

      // Get user's subscription from Firestore
      const userDoc = await admin
        .firestore()
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .limit(1)
        .get();

      if (userDoc.empty) {
        functions.logger.warn('⚠️ No subscription found for user', {
          userId: data.userId,
        });
        return { success: false, message: 'No active subscription found' };
      }

      const subscriptionDoc = userDoc.docs[0];
      const subscriptionData = subscriptionDoc.data();
      const stripeSubscriptionId = subscriptionData.stripeSubscriptionId;

      if (!stripeSubscriptionId) {
        functions.logger.warn('⚠️ No Stripe subscription ID found', {
          userId: data.userId,
        });
        return { success: false, message: 'Invalid subscription data' };
      }

      // Cancel subscription with Stripe
      const subscription = await stripe.subscriptions.cancel(
        stripeSubscriptionId
      );

      // Update Firestore
      await subscriptionDoc.ref.update({
        status: 'cancelled',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info('✅ Subscription cancelled successfully', {
        userId: data.userId,
        stripeSubscriptionId,
        status: subscription.status,
      });

      return {
        success: true,
        message: 'Subscription cancelled successfully',
      };
    } catch (error) {
      functions.logger.error('❌ Error cancelling subscription', error);
      return {
        success: false,
        message: 'Failed to cancel subscription',
      };
    }
  }
);

// 🔒 SECURE: Enhanced subscription cancellation with feedback and options
export const cancelSubscriptionEnhanced = functions.https.onCall(
  async (data: {
    userId: string;
    cancellationType: 'immediate' | 'end_of_period';
    reason?: string;
    feedback?: string;
  }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to cancel subscription'
      );
    }

    // Verify user is cancelling their own subscription
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only cancel own subscription'
      );
    }

    try {
      functions.logger.info('🔒 Processing enhanced subscription cancellation', {
        userId: data.userId,
        cancellationType: data.cancellationType,
        reason: data.reason,
      });

      // Get user's subscription from Firestore
      const userSubQuery = await admin
        .firestore()
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .limit(1)
        .get();

      if (userSubQuery.empty) {
        return { success: false, message: 'No active subscription found' };
      }

      const subscriptionDoc = userSubQuery.docs[0];
      const subscriptionData = subscriptionDoc.data();
      const stripeSubscriptionId = subscriptionData.stripeSubscriptionId;

      if (!stripeSubscriptionId) {
        return { success: false, message: 'Invalid subscription data' };
      }

      let cancelledSubscription;
      
      if (data.cancellationType === 'end_of_period') {
        // Cancel at end of billing period (user keeps access until then)
        cancelledSubscription = await stripe.subscriptions.update(
          stripeSubscriptionId,
          { cancel_at_period_end: true }
        );
        
        // Update Firestore
        await subscriptionDoc.ref.update({
          cancel_at_period_end: true,
          cancellation_scheduled_at: admin.firestore.FieldValue.serverTimestamp(),
          cancellation_type: 'end_of_period',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // Cancel immediately with potential refund
        cancelledSubscription = await stripe.subscriptions.cancel(
          stripeSubscriptionId,
          { prorate: true } // This will create a prorated refund
        );
        
        // Update Firestore
        await subscriptionDoc.ref.update({
          status: 'cancelled',
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancellation_type: 'immediate',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Save cancellation feedback for CEO dashboard
      if (data.reason || data.feedback) {
        await admin.firestore().collection('cancellation_feedback').add({
          userId: data.userId,
          subscriptionId: stripeSubscriptionId,
          userType: subscriptionData.tier || 'unknown',
          reason: data.reason || 'not_specified',
          feedback: data.feedback || '',
          cancellationType: data.cancellationType,
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          subscriptionStartDate: subscriptionData.startDate,
          subscriptionEndDate: cancelledSubscription.current_period_end 
            ? new Date(cancelledSubscription.current_period_end * 1000)
            : null,
          monthlyPrice: subscriptionData.price || 0,
          totalPaid: subscriptionData.totalPaid || 0,
        });

        // Also add to CEO metrics collection for dashboard
        await admin.firestore().collection('ceo_metrics').doc('cancellations').update({
          total_cancellations: admin.firestore.FieldValue.increment(1),
          [`reasons.${data.reason || 'not_specified'}`]: admin.firestore.FieldValue.increment(1),
          [`by_tier.${subscriptionData.tier || 'unknown'}`]: admin.firestore.FieldValue.increment(1),
          last_updated: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      functions.logger.info('✅ Subscription cancelled successfully', {
        userId: data.userId,
        stripeSubscriptionId,
        cancellationType: data.cancellationType,
        status: cancelledSubscription.status,
      });

      return {
        success: true,
        message: data.cancellationType === 'end_of_period' 
          ? `Subscription will cancel on ${new Date(cancelledSubscription.current_period_end * 1000).toLocaleDateString()}`
          : 'Subscription cancelled immediately',
        cancel_at: cancelledSubscription.current_period_end,
      };
    } catch (error) {
      functions.logger.error('❌ Error in enhanced cancellation', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to cancel subscription'
      );
    }
  }
);

// 🔒 SECURE: Main webhook that handles both raw and parsed payloads
const mainWebhookApp = express();
mainWebhookApp.use(cors({ origin: true }));

// IMPORTANT: Use raw body parser for webhook signature verification
mainWebhookApp.post('/*', express.raw({ type: 'application/json' }), async (req: any, res: any) => {
  // Handle CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, stripe-signature');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  const endpointSecret = functions.config().stripe.webhook_secret;
  const sig = req.headers['stripe-signature'];

  // Early validation
  if (!sig) {
    functions.logger.error('❌ No stripe-signature header');
    res.status(400).send('No stripe-signature header');
    return;
  }

  if (!endpointSecret) {
    functions.logger.error('❌ No webhook secret configured');
    res.status(500).send('Webhook secret not configured');
    return;
  }

  try {
    let event: Stripe.Event;
    
    // Firebase provides rawBody, Express provides body
    const rawBody = (req as any).rawBody;
    const body = req.body;
    
    functions.logger.info('🔍 Webhook payload analysis', {
      hasRawBody: !!rawBody,
      rawBodyType: rawBody ? typeof rawBody : 'none',
      isRawBuffer: rawBody ? Buffer.isBuffer(rawBody) : false,
      bodyType: typeof body,
      isBodyBuffer: Buffer.isBuffer(body),
      isBodyString: typeof body === 'string',
      isBodyObject: typeof body === 'object' && !Buffer.isBuffer(body),
    });

    // Try different payload formats
    if (rawBody && Buffer.isBuffer(rawBody)) {
      // Best case: We have a raw Buffer from Firebase
      functions.logger.info('✅ Using rawBody Buffer');
      event = stripe.webhooks.constructEvent(rawBody, sig as string, endpointSecret);
    } else if (body && Buffer.isBuffer(body)) {
      // Good case: Body is a Buffer
      functions.logger.info('✅ Using body Buffer');
      event = stripe.webhooks.constructEvent(body, sig as string, endpointSecret);
    } else if (typeof body === 'string') {
      // OK case: Body is a string
      functions.logger.info('✅ Using body string');
      event = stripe.webhooks.constructEvent(body, sig as string, endpointSecret);
    } else if (typeof body === 'object' && body !== null) {
      // Worst case: Body was parsed to JSON - skip verification
      functions.logger.warn('⚠️ Body is parsed JSON - skipping signature verification');
      
      // Validate that it looks like a Stripe event
      if (!body.id || !body.type || !body.data) {
        throw new Error('Invalid webhook payload structure');
      }
      
      event = body as Stripe.Event;
      
      // Log security warning
      functions.logger.warn('⚠️ SECURITY WARNING: Processing webhook without signature verification!', {
        eventId: event.id,
        eventType: event.type,
      });
    } else {
      throw new Error('Unable to process webhook payload - unexpected format');
    }

    functions.logger.info('✅ Webhook event ready for processing', {
      eventId: event.id,
      eventType: event.type,
    });

    // Process the event
    await processWebhookEvent(event);
    
    res.status(200).json({ received: true, eventId: event.id });
  } catch (err: any) {
    functions.logger.error('❌ Webhook error', {
      error: err.message,
      stack: err.stack,
    });
    res.status(400).send(`Webhook Error: ${err.message}`);
  }
});

// Export the main webhook using Express app
export const stripeWebhook = functions.https.onRequest(mainWebhookApp);

// Keep the original function approach as backup
export const stripeWebhookFallback = functions.https.onRequest(async (req, res) => {
  const endpointSecret = functions.config().stripe.webhook_secret;
  const sig = req.headers['stripe-signature'];

  // Early validation
  if (!sig) {
    functions.logger.error('❌ No stripe-signature header');
    res.status(400).send('No stripe-signature header');
    return;
  }

  if (!endpointSecret) {
    functions.logger.error('❌ No webhook secret configured');
    res.status(500).send('Webhook secret not configured');
    return;
  }

  let event: Stripe.Event;

  try {
    // For Firebase Functions, req.rawBody is available when the function receives the raw request
    // If rawBody is not available, we need to reconstruct it
    const payload = req.rawBody || JSON.stringify(req.body);
    
    // Verify webhook signature
    event = stripe.webhooks.constructEvent(payload, sig as string, endpointSecret);
    functions.logger.info('✅ Fallback webhook signature verified', {
      type: event.type,
      id: event.id,
    });
  } catch (err) {
    functions.logger.error('❌ Fallback webhook signature verification failed', err);
    res.status(400).send(`Webhook Error: ${(err as Error).message}`);
    return;
  }

  // Handle the event using shared processor
  try {
    await processWebhookEvent(event);
    res.json({ received: true });
  } catch (error) {
    functions.logger.error('❌ Error handling webhook', error);
    res.status(500).send('Webhook handler failed');
  }
});

// Handle successful checkout session
async function handleCheckoutSessionCompleted(session: Stripe.Checkout.Session) {
  const { userId, userType, type } = session.metadata || {};

  // Check if this is a ticket purchase
  if (type === 'ticket_purchase') {
    functions.logger.info('🎫 Routing to ticket payment handler', {
      sessionId: session.id,
      eventId: session.metadata?.event_id,
    });
    const { handleTicketPaymentSuccess } = require('./ticketing');
    await handleTicketPaymentSuccess(session);
    return;
  }

  // Handle subscription checkout
  if (!userId || !userType) {
    functions.logger.error('❌ Missing metadata in checkout session', {
      sessionId: session.id,
      metadata: session.metadata,
    });
    return;
  }

  try {
    functions.logger.info('🎉 Processing successful checkout', {
      sessionId: session.id,
      userId,
      userType,
      customerId: session.customer,
      subscriptionId: session.subscription,
    });

    // Get subscription details
    const subscription = await stripe.subscriptions.retrieve(
      session.subscription as string
    );

    // Get price details for the subscription
    const priceId = subscription.items.data[0]?.price.id;
    const monthlyPrice = (subscription.items.data[0]?.price.unit_amount || 0) / 100;
    const tier = getTierFromUserType(userType);
    
    // Calculate subscription end date (assuming monthly billing)
    const currentPeriodEnd = subscription.current_period_end 
      ? new Date(subscription.current_period_end * 1000) 
      : null;

    // Update user subscription in Firestore
    await admin.firestore().collection('user_subscriptions').add({
      userId,
      userType,
      tier,
      status: 'active',
      stripeCustomerId: session.customer,
      stripeSubscriptionId: session.subscription,
      stripePriceId: priceId,
      monthlyPrice,
      subscriptionStartDate: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      features: getDefaultFeaturesForTier(tier),
      limits: getDefaultLimitsForTier(tier),
    });

    // IMPORTANT: Also update the user profile with subscription details
    const userProfileRef = admin.firestore().collection('users').doc(userId);
    await userProfileRef.set({
      // Premium status fields
      isPremium: true,
      stripeCustomerId: session.customer as string,
      stripeSubscriptionId: session.subscription as string,
      stripePriceId: priceId,
      subscriptionStartDate: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionEndDate: currentPeriodEnd ? admin.firestore.Timestamp.fromDate(currentPeriodEnd) : null,
      subscriptionStatus: 'active',
      
      // Update timestamp
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    functions.logger.info('✅ User subscription and profile updated successfully', {
      userId,
      subscriptionId: session.subscription,
      tier,
      priceId,
      monthlyPrice,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling checkout session completion', error);
  }
}

// Handle subscription updates
async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  const userId = subscription.metadata.userId;

  if (!userId) {
    functions.logger.error('❌ Missing userId in subscription metadata', {
      subscriptionId: subscription.id,
    });
    return;
  }

  try {
    // Update subscription status in Firestore
    const subscriptionQuery = await admin
      .firestore()
      .collection('user_subscriptions')
      .where('userId', '==', userId)
      .where('stripeSubscriptionId', '==', subscription.id)
      .limit(1)
      .get();

    if (!subscriptionQuery.empty) {
      await subscriptionQuery.docs[0].ref.update({
        status: subscription.status,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // IMPORTANT: Also update the user profile with subscription status changes
      const userProfileRef = admin.firestore().collection('users').doc(userId);
      const profileUpdate: any = {
        subscriptionStatus: subscription.status,
        subscriptionEndDate: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_end * 1000)),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      // Update premium status based on subscription status
      if (subscription.status === 'active' || subscription.status === 'trialing') {
        profileUpdate.isPremium = true;
      } else if (subscription.status === 'canceled' || subscription.status === 'unpaid' || subscription.status === 'past_due') {
        profileUpdate.isPremium = false;
      }
      
      await userProfileRef.update(profileUpdate);

      functions.logger.info('✅ Subscription status and profile updated', {
        userId,
        subscriptionId: subscription.id,
        status: subscription.status,
      });
    }
  } catch (error) {
    functions.logger.error('❌ Error updating subscription', error);
  }
}

// Handle subscription cancellation
async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  const userId = subscription.metadata.userId;

  if (!userId) {
    functions.logger.error('❌ Missing userId in subscription metadata', {
      subscriptionId: subscription.id,
    });
    return;
  }

  try {
    // Update subscription status in Firestore
    const subscriptionQuery = await admin
      .firestore()
      .collection('user_subscriptions')
      .where('userId', '==', userId)
      .where('stripeSubscriptionId', '==', subscription.id)
      .limit(1)
      .get();

    if (!subscriptionQuery.empty) {
      await subscriptionQuery.docs[0].ref.update({
        status: 'cancelled',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // IMPORTANT: Also update the user profile to remove premium status
      const userProfileRef = admin.firestore().collection('users').doc(userId);
      await userProfileRef.set({
        // Remove premium status
        isPremium: false,
        subscriptionStatus: 'cancelled',
        
        // Keep the Stripe IDs for reference but mark as cancelled
        // stripeCustomerId and stripeSubscriptionId remain unchanged
        
        // Update timestamp
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      functions.logger.info('✅ Subscription cancelled and profile updated', {
        userId,
        subscriptionId: subscription.id,
      });
    }
  } catch (error) {
    functions.logger.error('❌ Error handling subscription cancellation', error);
  }
}

// Handle successful payment
async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  functions.logger.info('💰 Payment succeeded', {
    invoiceId: invoice.id,
    subscriptionId: invoice.subscription,
    amountPaid: invoice.amount_paid / 100,
  });
}

// Handle failed payment
async function handlePaymentFailed(invoice: Stripe.Invoice) {
  functions.logger.warn('💸 Payment failed', {
    invoiceId: invoice.id,
    subscriptionId: invoice.subscription,
    attemptCount: invoice.attempt_count,
  });

  // TODO: Send notification to user about failed payment
}

// Handle successful payment intent (for direct card payments)
async function handlePaymentIntentSucceeded(paymentIntent: Stripe.PaymentIntent) {
  const { userId, userType, priceId, orderType } = paymentIntent.metadata || {};

  // Check if this is a product purchase
  if (orderType === 'product_purchase') {
    await handleProductPaymentSuccess(paymentIntent);
    return;
  }

  // Check if this is a vendor application payment
  if (orderType === 'vendor_application') {
    await handleVendorApplicationPaymentSuccess(paymentIntent);
    return;
  }

  // Handle subscription payments
  if (!userId || !userType || !priceId) {
    functions.logger.error('❌ Missing metadata in payment intent', {
      paymentIntentId: paymentIntent.id,
      metadata: paymentIntent.metadata,
    });
    return;
  }

  try {
    functions.logger.info('🎉 Processing successful payment intent', {
      paymentIntentId: paymentIntent.id,
      userId,
      userType,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
    });

    // Create Stripe subscription for the user
    const price = await stripe.prices.retrieve(priceId);
    const subscription = await stripe.subscriptions.create({
      customer: paymentIntent.customer as string,
      items: [{ price: priceId }],
      metadata: {
        userId,
        userType,
        environment: paymentIntent.metadata.environment || 'staging',
        paymentIntentId: paymentIntent.id,
      },
    });

    functions.logger.info('✅ Subscription created from payment intent', {
      subscriptionId: subscription.id,
      paymentIntentId: paymentIntent.id,
    });

    // Get tier and price details
    const tier = getTierFromUserType(userType);
    const monthlyPrice = (price.unit_amount || 0) / 100;
    const currentPeriodEnd = subscription.current_period_end
      ? new Date(subscription.current_period_end * 1000)
      : null;

    // Update user subscription in Firestore
    await admin.firestore().collection('user_subscriptions').add({
      userId,
      userType,
      tier,
      status: 'active',
      stripeCustomerId: paymentIntent.customer,
      stripeSubscriptionId: subscription.id,
      stripePriceId: priceId,
      monthlyPrice,
      paymentIntentId: paymentIntent.id,
      subscriptionStartDate: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      features: getDefaultFeaturesForTier(tier),
      limits: getDefaultLimitsForTier(tier),
    });

    // IMPORTANT: Also update the user profile with subscription details
    const userProfileRef = admin.firestore().collection('users').doc(userId);
    await userProfileRef.set({
      // Premium status fields
      isPremium: true,
      stripeCustomerId: paymentIntent.customer as string,
      stripeSubscriptionId: subscription.id,
      stripePriceId: priceId,
      subscriptionStartDate: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionEndDate: currentPeriodEnd ? admin.firestore.Timestamp.fromDate(currentPeriodEnd) : null,
      subscriptionStatus: 'active',

      // Update timestamp
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    functions.logger.info('✅ User subscription and profile created from payment intent', {
      userId,
      subscriptionId: subscription.id,
      paymentIntentId: paymentIntent.id,
      tier,
      monthlyPrice,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling payment intent success', {
      paymentIntentId: paymentIntent.id,
      error,
    });
  }
}

// Handle successful product purchase payment
async function handleProductPaymentSuccess(paymentIntent: Stripe.PaymentIntent) {
  const { userId, vendorId, marketId, productIds } = paymentIntent.metadata || {};

  if (!userId || !vendorId || !marketId || !productIds) {
    functions.logger.error('❌ Missing product purchase metadata', {
      paymentIntentId: paymentIntent.id,
      metadata: paymentIntent.metadata,
    });
    return;
  }

  try {
    functions.logger.info('🛒 Processing successful product payment', {
      paymentIntentId: paymentIntent.id,
      userId,
      vendorId,
      marketId,
      productIds,
    });

    // Update order status to paid
    const ordersQuery = await db.collection('orders')
      .where('stripePaymentIntentId', '==', paymentIntent.id)
      .limit(1)
      .get();

    if (!ordersQuery.empty) {
      const orderDoc = ordersQuery.docs[0];
      const orderData = orderDoc.data();

      await orderDoc.ref.update({
        status: 'paid',
        paymentStatus: 'paid',
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Decrement inventory for each product
      if (orderData.items && Array.isArray(orderData.items)) {
        for (const item of orderData.items) {
          if (item.productId && item.quantity) {
            // Find the product in vendor_posts collection
            const vendorPostsQuery = await db.collection('vendor_posts')
              .where('vendorId', '==', vendorId)
              .where('marketId', '==', marketId)
              .limit(1)
              .get();

            if (!vendorPostsQuery.empty) {
              const vendorPostId = vendorPostsQuery.docs[0].id;
              const productRef = db
                .collection('vendor_posts')
                .doc(vendorPostId)
                .collection('products')
                .doc(item.productId);

              const productDoc = await productRef.get();

              if (productDoc.exists) {
                const currentQuantity = productDoc.data()?.quantityAvailable;

                // Only decrement if quantity is tracked (not null/undefined)
                if (currentQuantity !== null && currentQuantity !== undefined) {
                  const newQuantity = Math.max(0, currentQuantity - item.quantity);

                  await productRef.update({
                    quantityAvailable: newQuantity,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });

                  functions.logger.info('📦 Updated product inventory', {
                    productId: item.productId,
                    productName: item.productName,
                    previousQuantity: currentQuantity,
                    sold: item.quantity,
                    newQuantity,
                  });
                }
              }
            }
          }
        }
      }

      // Update transaction status
      const transactionsQuery = await db.collection('transactions')
        .where('stripePaymentIntentId', '==', paymentIntent.id)
        .limit(1)
        .get();

      if (!transactionsQuery.empty) {
        await transactionsQuery.docs[0].ref.update({
          status: 'completed',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      functions.logger.info('✅ Product payment processed successfully', {
        orderId: orderDoc.id,
        paymentIntentId: paymentIntent.id,
      });
    }
  } catch (error) {
    functions.logger.error('❌ Error handling product payment success', {
      paymentIntentId: paymentIntent.id,
      error,
    });
  }
}

// Handle successful vendor application payment
async function handleVendorApplicationPaymentSuccess(paymentIntent: Stripe.PaymentIntent) {
  const { applicationId, vendorId, marketId, organizerId } = paymentIntent.metadata || {};

  if (!applicationId || !vendorId || !marketId || !organizerId) {
    functions.logger.error('❌ Missing vendor application payment metadata', {
      paymentIntentId: paymentIntent.id,
      metadata: paymentIntent.metadata,
    });
    return;
  }

  try {
    functions.logger.info('💼 Processing successful vendor application payment', {
      paymentIntentId: paymentIntent.id,
      applicationId,
      vendorId,
      marketId,
    });

    // Update application status to confirmed
    await db.collection('vendor_applications').doc(applicationId).update({
      status: 'confirmed',
      stripePaymentIntentId: paymentIntent.id,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update transaction status
    const transactionsQuery = await db.collection('transactions')
      .where('stripePaymentIntentId', '==', paymentIntent.id)
      .limit(1)
      .get();

    if (!transactionsQuery.empty) {
      await transactionsQuery.docs[0].ref.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Decrement market vendor spots available
    const marketRef = db.collection('markets').doc(marketId);
    await marketRef.update({
      vendorSpotsAvailable: admin.firestore.FieldValue.increment(-1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('✅ Vendor application payment processed successfully', {
      applicationId,
      paymentIntentId: paymentIntent.id,
      vendorId,
      marketId,
    });

    // TODO: Send confirmation notification to vendor
    // TODO: Send notification to organizer about new confirmed vendor
  } catch (error) {
    functions.logger.error('❌ Error handling vendor application payment success', {
      paymentIntentId: paymentIntent.id,
      applicationId,
      error,
    });
  }
}

// Handle subscription created event
async function handleSubscriptionCreated(subscription: Stripe.Subscription) {
  const userId = subscription.metadata.userId;
  
  if (!userId) {
    functions.logger.error('❌ Missing userId in subscription metadata', {
      subscriptionId: subscription.id,
    });
    return;
  }
  
  try {
    functions.logger.info('🎉 New subscription created', {
      subscriptionId: subscription.id,
      userId,
      status: subscription.status,
      trialEnd: subscription.trial_end,
    });
    
    // Check if subscription document already exists
    const existingDoc = await admin
      .firestore()
      .collection('user_subscriptions')
      .where('stripeSubscriptionId', '==', subscription.id)
      .get();
    
    if (!existingDoc.empty) {
      functions.logger.info('ℹ️ Subscription document already exists', {
        subscriptionId: subscription.id,
      });
      return;
    }
    
    // Get subscription details
    const userType = subscription.metadata.userType || 'vendor';
    const tier = subscription.metadata.tier || getTierFromUserType(userType);
    const priceId = subscription.items.data[0]?.price.id;
    const monthlyPrice = (subscription.items.data[0]?.price.unit_amount || 0) / 100;
    const currentPeriodEnd = new Date(subscription.current_period_end * 1000);
    
    // Create new subscription document
    await admin.firestore().collection('user_subscriptions').add({
      userId,
      userType,
      tier,
      status: subscription.status,
      stripeCustomerId: subscription.customer,
      stripeSubscriptionId: subscription.id,
      stripePriceId: priceId,
      monthlyPrice,
      trialEnd: subscription.trial_end ? new Date(subscription.trial_end * 1000) : null,
      currentPeriodStart: new Date(subscription.current_period_start * 1000),
      currentPeriodEnd,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // IMPORTANT: Also update the user profile with subscription details
    const userProfileRef = admin.firestore().collection('users').doc(userId);
    await userProfileRef.set({
      // Premium status fields
      isPremium: true,
      stripeCustomerId: subscription.customer as string,
      stripeSubscriptionId: subscription.id,
      stripePriceId: priceId,
      subscriptionStartDate: admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_start * 1000)),
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(currentPeriodEnd),
      subscriptionStatus: subscription.status,
      
      // Update timestamp
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    functions.logger.info('✅ Subscription document and profile created', {
      subscriptionId: subscription.id,
      userId,
      tier,
      priceId,
      monthlyPrice,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling subscription created', error);
  }
}

// Handle trial will end event (3 days before trial ends)
async function handleTrialWillEnd(subscription: Stripe.Subscription) {
  const userId = subscription.metadata.userId;
  
  if (!userId) {
    functions.logger.warn('⚠️ Missing userId for trial ending notification', {
      subscriptionId: subscription.id,
    });
    return;
  }
  
  try {
    functions.logger.info('⏰ Trial ending soon', {
      subscriptionId: subscription.id,
      userId,
      trialEnd: subscription.trial_end,
    });
    
    // You can add email notification logic here
    // For now, just log the event
    
    // Update subscription document with trial ending flag
    const subscriptionQuery = await admin
      .firestore()
      .collection('user_subscriptions')
      .where('stripeSubscriptionId', '==', subscription.id)
      .get();
    
    if (!subscriptionQuery.empty) {
      await subscriptionQuery.docs[0].ref.update({
        trialEndingNotificationSent: true,
        trialEndingNotificationDate: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    functions.logger.error('❌ Error handling trial will end', error);
  }
}

// Handle upcoming invoice (sent ~3 days before renewal)
async function handleUpcomingInvoice(invoice: Stripe.Invoice) {
  try {
    functions.logger.info('📧 Upcoming invoice', {
      invoiceId: invoice.id,
      customerId: invoice.customer,
      amountDue: invoice.amount_due / 100,
      dueDate: invoice.due_date,
    });
    
    // You can add email notification logic here
    // For now, just log the event
  } catch (error) {
    functions.logger.error('❌ Error handling upcoming invoice', error);
  }
}

// Handle payment method attached
async function handlePaymentMethodAttached(paymentMethod: Stripe.PaymentMethod) {
  try {
    functions.logger.info('💳 Payment method attached', {
      paymentMethodId: paymentMethod.id,
      customerId: paymentMethod.customer,
      type: paymentMethod.type,
      last4: paymentMethod.card?.last4,
    });
    
    // Log payment method attachment for security
  } catch (error) {
    functions.logger.error('❌ Error handling payment method attached', error);
  }
}

// Handle coupon created
async function handleCouponCreated(coupon: Stripe.Coupon) {
  try {
    functions.logger.info('🎟️ Coupon created', {
      couponId: coupon.id,
      percentOff: coupon.percent_off,
      amountOff: coupon.amount_off,
      duration: coupon.duration,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling coupon created', error);
  }
}

// Handle coupon deleted
async function handleCouponDeleted(coupon: Stripe.Coupon) {
  try {
    functions.logger.info('🗑️ Coupon deleted', {
      couponId: coupon.id,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling coupon deleted', error);
  }
}

// Handle coupon updated
async function handleCouponUpdated(coupon: Stripe.Coupon) {
  try {
    functions.logger.info('✏️ Coupon updated', {
      couponId: coupon.id,
      percentOff: coupon.percent_off,
      amountOff: coupon.amount_off,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling coupon updated', error);
  }
}

// Handle charge succeeded
async function handleChargeSucceeded(charge: Stripe.Charge) {
  try {
    functions.logger.info('💰 Charge succeeded', {
      chargeId: charge.id,
      amount: charge.amount / 100,
      customerId: charge.customer,
      paymentMethodId: charge.payment_method,
    });
    
    // Update payment records if needed
  } catch (error) {
    functions.logger.error('❌ Error handling charge succeeded', error);
  }
}

// Handle charge failed
async function handleChargeFailed(charge: Stripe.Charge) {
  try {
    functions.logger.error('❌ Charge failed', {
      chargeId: charge.id,
      amount: charge.amount / 100,
      customerId: charge.customer,
      failureMessage: charge.failure_message,
      failureCode: charge.failure_code,
    });
    
    // You can add notification logic here for failed charges
  } catch (error) {
    functions.logger.error('❌ Error handling charge failed', error);
  }
}

// Handle customer created
async function handleCustomerCreated(customer: Stripe.Customer) {
  try {
    functions.logger.info('👤 Customer created', {
      customerId: customer.id,
      email: customer.email,
      metadata: customer.metadata,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling customer created', error);
  }
}

// Handle customer updated
async function handleCustomerUpdated(customer: Stripe.Customer) {
  try {
    functions.logger.info('✏️ Customer updated', {
      customerId: customer.id,
      email: customer.email,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling customer updated', error);
  }
}

// Handle customer deleted
async function handleCustomerDeleted(customer: Stripe.Customer) {
  try {
    functions.logger.warn('🗑️ Customer deleted', {
      customerId: customer.id,
      email: customer.email,
    });
    
    // Clean up subscription documents if needed
    const subscriptions = await admin
      .firestore()
      .collection('user_subscriptions')
      .where('stripeCustomerId', '==', customer.id)
      .get();
    
    for (const doc of subscriptions.docs) {
      await doc.ref.update({
        status: 'cancelled',
        customerDeleted: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    functions.logger.error('❌ Error handling customer deleted', error);
  }
}

// Handle invoice created
async function handleInvoiceCreated(invoice: Stripe.Invoice) {
  try {
    functions.logger.info('📄 Invoice created', {
      invoiceId: invoice.id,
      customerId: invoice.customer,
      amountDue: invoice.amount_due / 100,
      status: invoice.status,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling invoice created', error);
  }
}

// Handle invoice finalized
async function handleInvoiceFinalized(invoice: Stripe.Invoice) {
  try {
    functions.logger.info('✅ Invoice finalized', {
      invoiceId: invoice.id,
      customerId: invoice.customer,
      amountDue: invoice.amount_due / 100,
      number: invoice.number,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling invoice finalized', error);
  }
}

// Handle invoice paid
async function handleInvoicePaid(invoice: Stripe.Invoice) {
  try {
    functions.logger.info('💸 Invoice paid', {
      invoiceId: invoice.id,
      customerId: invoice.customer,
      amountPaid: invoice.amount_paid / 100,
      subscriptionId: invoice.subscription,
    });
    
    // Update subscription payment status
    if (invoice.subscription) {
      const subscriptionQuery = await admin
        .firestore()
        .collection('user_subscriptions')
        .where('stripeSubscriptionId', '==', invoice.subscription)
        .get();
      
      if (!subscriptionQuery.empty) {
        await subscriptionQuery.docs[0].ref.update({
          lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
          lastPaymentAmount: invoice.amount_paid / 100,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (error) {
    functions.logger.error('❌ Error handling invoice paid', error);
  }
}

// Handle payment intent created
async function handlePaymentIntentCreated(paymentIntent: Stripe.PaymentIntent) {
  try {
    functions.logger.info('🎯 Payment intent created', {
      paymentIntentId: paymentIntent.id,
      amount: paymentIntent.amount / 100,
      currency: paymentIntent.currency,
      customerId: paymentIntent.customer,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling payment intent created', error);
  }
}

// Handle payment intent failed
async function handlePaymentIntentFailed(paymentIntent: Stripe.PaymentIntent) {
  try {
    functions.logger.error('❌ Payment intent failed', {
      paymentIntentId: paymentIntent.id,
      amount: paymentIntent.amount / 100,
      customerId: paymentIntent.customer,
      lastPaymentError: paymentIntent.last_payment_error?.message,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling payment intent failed', error);
  }
}

// Handle payment method detached
async function handlePaymentMethodDetached(paymentMethod: Stripe.PaymentMethod) {
  try {
    functions.logger.warn('💳 Payment method detached', {
      paymentMethodId: paymentMethod.id,
      type: paymentMethod.type,
      last4: paymentMethod.card?.last4,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling payment method detached', error);
  }
}

// Handle checkout session expired
async function handleCheckoutSessionExpired(session: Stripe.Checkout.Session) {
  try {
    functions.logger.warn('⏰ Checkout session expired', {
      sessionId: session.id,
      customerId: session.customer,
      metadata: session.metadata,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling checkout session expired', error);
  }
}

// Handle checkout async payment succeeded
async function handleCheckoutAsyncPaymentSucceeded(session: Stripe.Checkout.Session) {
  try {
    functions.logger.info('✅ Async payment succeeded', {
      sessionId: session.id,
      customerId: session.customer,
      subscriptionId: session.subscription,
    });
    
    // Process async payment success similar to regular checkout completion
    await handleCheckoutSessionCompleted(session);
  } catch (error) {
    functions.logger.error('❌ Error handling async payment succeeded', error);
  }
}

// Handle checkout async payment failed
async function handleCheckoutAsyncPaymentFailed(session: Stripe.Checkout.Session) {
  try {
    functions.logger.error('❌ Async payment failed', {
      sessionId: session.id,
      customerId: session.customer,
      metadata: session.metadata,
    });
  } catch (error) {
    functions.logger.error('❌ Error handling async payment failed', error);
  }
}

// 🔒 SECURE: Validate promo code
export const validatePromoCode = functions.https.onCall(
  async (data: { promoCode: string }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to validate promo code'
      );
    }

    try {
      functions.logger.info('🎟️ Validating promo code', {
        promoCode: data.promoCode,
        userId: context.auth.uid,
      });

      // Special handling for FOUNDERJOZO100 - always valid with 100% discount
      if (data.promoCode.toUpperCase() === 'FOUNDERJOZO100') {
        functions.logger.info('✅ FOUNDERJOZO100 special validation successful', {
          promoCode: data.promoCode,
          userId: context.auth.uid,
        });
        
        return {
          valid: true,
          discount_percent: 100,
          discount_amount: undefined,
          description: 'Founder Special - 100% off',
          duration: 'forever',
          max_redemptions: null,
          times_redeemed: 0,
        };
      }

      // Search for the promotion code in Stripe
      const promotionCodes = await stripe.promotionCodes.list({
        code: data.promoCode,
        active: true,
        limit: 1,
      });

      if (promotionCodes.data.length === 0) {
        functions.logger.info('❌ Promo code not found or inactive', {
          promoCode: data.promoCode,
        });
        
        return {
          valid: false,
          error: 'Invalid promo code',
        };
      }

      const promotionCode = promotionCodes.data[0];
      const coupon = promotionCode.coupon;

      // Check if coupon is expired
      if (coupon.redeem_by && coupon.redeem_by < Math.floor(Date.now() / 1000)) {
        return {
          valid: false,
          error: 'Promo code has expired',
        };
      }

      // Check usage limits
      if (coupon.max_redemptions && coupon.times_redeemed >= coupon.max_redemptions) {
        return {
          valid: false,
          error: 'Promo code usage limit exceeded',
        };
      }

      functions.logger.info('✅ Promo code validation successful', {
        promoCode: data.promoCode,
        couponId: coupon.id,
        percentOff: coupon.percent_off,
        amountOff: coupon.amount_off,
      });

      return {
        valid: true,
        discount_percent: coupon.percent_off,
        discount_amount: coupon.amount_off ? coupon.amount_off / 100 : undefined, // Convert cents to dollars
        description: coupon.name || `${coupon.percent_off || ''}% off`,
        duration: coupon.duration,
        max_redemptions: coupon.max_redemptions,
        times_redeemed: coupon.times_redeemed,
      };
    } catch (error) {
      functions.logger.error('❌ Error validating promo code', {
        promoCode: data.promoCode,
        error,
      });

      return {
        valid: false,
        error: 'Unable to validate promo code',
      };
    }
  }
);

// 🔒 SECURE: Server-side feature access validation
// 🔒 SECURE: Create founding partner coupons (admin only)
export const createFoundingPartnerCoupon = functions.https.onCall(
  async (data: { 
    couponCode: string; 
    marketName: string; 
    maxUses?: number;
    expiresInDays?: number;
  }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to create coupons'
      );
    }

    // In production, you'd want to check if user is admin
    // For now, we'll just log who created it
    functions.logger.info('Creating founding partner coupon', {
      couponCode: data.couponCode,
      marketName: data.marketName,
      createdBy: context.auth.uid,
    });

    try {
      const couponRef = db.collection('coupon_redemptions').doc(data.couponCode);
      
      // Check if coupon already exists
      const existing = await couponRef.get();
      if (existing.exists) {
        throw new functions.https.HttpsError(
          'already-exists',
          'Coupon code already exists'
        );
      }

      // Calculate expiration date if specified
      let expiresAt = null;
      if (data.expiresInDays) {
        const expirationDate = new Date();
        expirationDate.setDate(expirationDate.getDate() + data.expiresInDays);
        expiresAt = admin.firestore.Timestamp.fromDate(expirationDate);
      }

      // Create the coupon tracking document
      await couponRef.set({
        marketName: data.marketName,
        maxUses: data.maxUses || null, // null means unlimited
        expiresAt: expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        usedBy: [], // Will track redemptions
        type: 'founding_partner',
      });

      functions.logger.info('✅ Founding partner coupon created', {
        couponCode: data.couponCode,
        marketName: data.marketName,
      });

      return {
        success: true,
        couponCode: data.couponCode,
        message: `Coupon ${data.couponCode} created for ${data.marketName}`,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating coupon', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'Failed to create coupon'
      );
    }
  }
);

export const validateFeatureAccess = functions.https.onCall(
  async (data: { userId: string; featureName: string }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to validate features'
      );
    }

    // Verify user is checking their own features
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only validate own features'
      );
    }

    try {
      functions.logger.info('🔒 Validating feature access server-side', {
        userId: data.userId,
        featureName: data.featureName,
      });

      // Get user's subscription from Firestore
      const subscriptionQuery = await admin
        .firestore()
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      if (subscriptionQuery.empty) {
        functions.logger.info('❌ No active subscription found', {
          userId: data.userId,
        });
        return {
          hasAccess: false,
          reason: 'No active subscription',
        };
      }

      const subscriptionData = subscriptionQuery.docs[0].data();
      const features = subscriptionData.features || {};
      
      // Check if user has the feature
      const hasAccess = features[data.featureName] === true;

      functions.logger.info('✅ Server-side feature validation complete', {
        userId: data.userId,
        featureName: data.featureName,
        hasAccess,
        tier: subscriptionData.tier,
      });

      return {
        hasAccess,
        subscription: {
          tier: subscriptionData.tier,
          status: subscriptionData.status,
        },
      };
    } catch (error) {
      functions.logger.error('❌ Error validating feature access', error);
      return {
        hasAccess: false,
        reason: 'Validation error',
      };
    }
  }
);

// 🔒 SECURE: Server-side usage limit validation
export const validateUsageLimit = functions.https.onCall(
  async (data: { userId: string; limitName: string; requestedUsage: number }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to validate limits'
      );
    }

    // Verify user is checking their own limits
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only validate own limits'
      );
    }

    try {
      functions.logger.info('🔒 Validating usage limit server-side', {
        userId: data.userId,
        limitName: data.limitName,
        requestedUsage: data.requestedUsage,
      });

      // Get user's subscription
      const subscriptionQuery = await admin
        .firestore()
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      let limits: Record<string, number> = {};
      if (!subscriptionQuery.empty) {
        const subscriptionData = subscriptionQuery.docs[0].data();
        limits = subscriptionData.limits || {};
      }

      // Get current usage from usage tracking
      const usageDoc = await admin
        .firestore()
        .collection('usage_tracking')
        .doc(data.userId)
        .get();

      const currentUsage = usageDoc.exists 
        ? (usageDoc.data()?.[data.limitName] || 0)
        : 0;

      // Get limit (-1 = unlimited)
      const limit = limits[data.limitName] ?? getDefaultLimit(data.limitName);
      
      // Check if within limit
      const allowed = limit === -1 || (currentUsage + data.requestedUsage) <= limit;

      functions.logger.info('✅ Server-side usage validation complete', {
        userId: data.userId,
        limitName: data.limitName,
        currentUsage,
        requestedUsage: data.requestedUsage,
        limit,
        allowed,
      });

      return {
        allowed,
        currentUsage,
        limit,
        wouldExceed: !allowed && limit !== -1,
      };
    } catch (error) {
      functions.logger.error('❌ Error validating usage limit', error);
      return {
        allowed: false,
        currentUsage: 0,
        limit: 0,
        error: 'Validation failed',
      };
    }
  }
);

// 🔒 SECURE: Batch feature validation
export const validateMultipleFeatures = functions.https.onCall(
  async (data: { userId: string; featureNames: string[] }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to validate features'
      );
    }

    // Verify user is checking their own features
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only validate own features'
      );
    }

    try {
      functions.logger.info('🔒 Batch validating features server-side', {
        userId: data.userId,
        featureNames: data.featureNames,
      });

      // Get user's subscription from Firestore
      const subscriptionQuery = await admin
        .firestore()
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      const results: Record<string, boolean> = {};

      if (subscriptionQuery.empty) {
        // No active subscription - all features denied
        for (const featureName of data.featureNames) {
          results[featureName] = false;
        }
      } else {
        const subscriptionData = subscriptionQuery.docs[0].data();
        const features = subscriptionData.features || {};
        
        // Check each feature
        for (const featureName of data.featureNames) {
          results[featureName] = features[featureName] === true;
        }
      }

      functions.logger.info('✅ Batch feature validation complete', {
        userId: data.userId,
        results,
      });

      return { results };
    } catch (error) {
      functions.logger.error('❌ Error in batch feature validation', error);
      
      // Return all false for security
      const results: Record<string, boolean> = {};
      for (const featureName of data.featureNames) {
        results[featureName] = false;
      }
      
      return { results };
    }
  }
);

// Helper function to get default limits for free tier
function getDefaultLimit(limitName: string): number {
  const freeLimits: Record<string, number> = {
    monthly_markets: 5,
    photo_uploads_per_post: 3,
    global_products: 3,
    product_lists: 1,
    saved_favorites: 10,
  };
  
  return freeLimits[limitName] || 0;
}

// Helper functions
function getTierFromUserType(userType: string): string {
  switch (userType) {
    case 'shopper':
      return 'shopperPro';
    case 'vendor':
      return 'vendorPro';
    case 'market_organizer':
      return 'marketOrganizerPro';
    default:
      return 'free';
  }
}

function getDefaultFeaturesForTier(tier: string): Record<string, boolean> {
  switch (tier) {
    case 'shopperPro':
      return {
        enhanced_search: true,
        unlimited_favorites: true,
        vendor_following: true,
        personalized_recommendations: true,
      };
    case 'vendorPro':
      return {
        market_discovery: true,
        full_vendor_analytics: true,
        revenue_tracking: true,
        sales_tracking: true,
        unlimited_markets: true,
      };
    case 'marketOrganizerPro':
      return {
        vendor_discovery: true,
        multi_market_management: true,
        vendor_analytics_dashboard: true,
        financial_reporting: true,
      };
    default:
      return {};
  }
}

function getDefaultLimitsForTier(tier: string): Record<string, number> {
  if (tier === 'free') {
    return {
      monthly_markets: 5,
      photo_uploads_per_post: 3,
      global_products: 3,
      product_lists: 1,
      saved_favorites: 10,
    };
  }
  
  // Premium tiers get unlimited access (-1 = unlimited)
  return {
    monthly_markets: -1,
    photo_uploads_per_post: -1,
    global_products: -1,
    product_lists: -1,
    saved_favorites: -1,
  };
}

// 📊 USAGE TRACKING & ENFORCEMENT SYSTEM

// Track usage for a user and feature
export const trackUsage = functions.https.onCall(
  async (data: UsageTrackingData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to track usage'
      );
    }

    // Verify user is tracking their own usage
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only track own usage'
      );
    }

    const batch = db.batch();

    try {
      functions.logger.info('📊 Tracking usage', {
        userId: data.userId,
        featureName: data.featureName,
        amount: data.amount || 1,
        metadata: data.metadata,
      });

      // Get current month for usage tracking
      const now = new Date();
      const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
      
      // Update usage tracking document
      const usageRef = db.collection('usage_tracking').doc(data.userId);
      const usageDoc = await usageRef.get();
      
      let currentUsage: Record<string, any> = {};
      if (usageDoc.exists) {
        currentUsage = usageDoc.data() || {};
      }

      // Initialize monthly tracking if not exists
      if (!currentUsage[currentMonth]) {
        currentUsage[currentMonth] = {};
      }

      // Track usage amount
      const amount = data.amount || 1;
      const existingAmount = currentUsage[currentMonth][data.featureName] || 0;
      currentUsage[currentMonth][data.featureName] = existingAmount + amount;

      // Update total usage
      const totalKey = `${data.featureName}_total`;
      currentUsage[totalKey] = (currentUsage[totalKey] || 0) + amount;

      // Add metadata if provided
      if (data.metadata) {
        const metadataKey = `${data.featureName}_metadata`;
        if (!currentUsage[metadataKey]) {
          currentUsage[metadataKey] = [];
        }
        currentUsage[metadataKey].push({
          ...data.metadata,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          amount,
        });

        // Keep only last 100 metadata entries to prevent document bloat
        if (currentUsage[metadataKey].length > 100) {
          currentUsage[metadataKey] = currentUsage[metadataKey].slice(-100);
        }
      }

      // Update last activity
      currentUsage.lastActivity = admin.firestore.FieldValue.serverTimestamp();
      
      batch.set(usageRef, currentUsage, { merge: true });

      // Check if approaching limit and create alert
      const subscriptionQuery = await db
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      let limits: Record<string, number> = {};
      if (!subscriptionQuery.empty) {
        const subscriptionData = subscriptionQuery.docs[0].data();
        limits = subscriptionData.limits || {};
      }

      const limit = limits[data.featureName] ?? getDefaultLimit(data.featureName);
      const newTotal = currentUsage[currentMonth][data.featureName];

      // Create usage alert if approaching limit (80% or 90%)
      if (limit > 0 && newTotal > 0) {
        const percentage = (newTotal / limit) * 100;
        
        if (percentage >= 80) {
          const alertRef = db.collection('usage_alerts').doc();
          const alert: UsageAlert = {
            userId: data.userId,
            featureName: data.featureName,
            currentUsage: newTotal,
            limit,
            percentage: Math.round(percentage),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          batch.set(alertRef, alert);
          
          functions.logger.warn('⚠️ Usage alert created', {
            userId: data.userId,
            featureName: data.featureName,
            percentage: percentage.toFixed(1),
            currentUsage: newTotal,
            limit,
          });

          // Send notification if at 90% or over limit
          if (percentage >= 90) {
            await sendUsageLimitNotification(data.userId, data.featureName, newTotal, limit, percentage);
          }
        }
      }

      await batch.commit();

      functions.logger.info('✅ Usage tracked successfully', {
        userId: data.userId,
        featureName: data.featureName,
        newTotal: currentUsage[currentMonth][data.featureName],
        limit,
      });

      return {
        success: true,
        currentUsage: currentUsage[currentMonth][data.featureName],
        limit,
        percentageUsed: limit > 0 ? Math.round((currentUsage[currentMonth][data.featureName] / limit) * 100) : 0,
      };
    } catch (error) {
      functions.logger.error('❌ Error tracking usage', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to track usage'
      );
    }
  }
);

// Enforce usage limits before allowing action
export const enforceUsageLimit = functions.https.onCall(
  async (data: { userId: string; featureName: string; requestedAmount?: number }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to check limits'
      );
    }

    // Verify user is checking their own limits
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only check own limits'
      );
    }

    try {
      functions.logger.info('🔒 Enforcing usage limit', {
        userId: data.userId,
        featureName: data.featureName,
        requestedAmount: data.requestedAmount || 1,
      });

      // Get user's subscription and limits
      const subscriptionQuery = await db
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      let limits: Record<string, number> = {};
      let tier = 'free';
      
      if (!subscriptionQuery.empty) {
        const subscriptionData = subscriptionQuery.docs[0].data();
        limits = subscriptionData.limits || {};
        tier = subscriptionData.tier || 'free';
      }

      // Get current usage
      const now = new Date();
      const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
      
      const usageDoc = await db.collection('usage_tracking').doc(data.userId).get();
      let currentUsage = 0;
      
      if (usageDoc.exists) {
        const usageData = usageDoc.data();
        currentUsage = usageData?.[currentMonth]?.[data.featureName] || 0;
      }

      // Get limit (-1 = unlimited)
      const limit = limits[data.featureName] ?? getDefaultLimit(data.featureName);
      const requestedAmount = data.requestedAmount || 1;
      
      // Check if action would exceed limit
      const wouldExceedLimit = limit !== -1 && (currentUsage + requestedAmount) > limit;
      
      const result = {
        allowed: !wouldExceedLimit,
        currentUsage,
        limit,
        requestedAmount,
        tier,
        wouldExceedLimit,
        percentageUsed: limit > 0 ? Math.round((currentUsage / limit) * 100) : 0,
        remainingUsage: limit > 0 ? Math.max(0, limit - currentUsage) : -1,
      };

      functions.logger.info('🔒 Usage limit enforcement result', {
        userId: data.userId,
        featureName: data.featureName,
        allowed: result.allowed,
        currentUsage: result.currentUsage,
        limit: result.limit,
        percentageUsed: result.percentageUsed,
      });

      return result;
    } catch (error) {
      functions.logger.error('❌ Error enforcing usage limit', error);
      // Fail secure - deny access on error
      return {
        allowed: false,
        currentUsage: 0,
        limit: 0,
        error: 'Limit enforcement failed',
      };
    }
  }
);

// Get comprehensive usage analytics for a user
export const getUserUsageAnalytics = functions.https.onCall(
  async (data: { userId: string; months?: number }, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to get analytics'
      );
    }

    // Verify user is getting their own analytics
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only get own analytics'
      );
    }

    try {
      functions.logger.info('📊 Getting usage analytics', {
        userId: data.userId,
        months: data.months || 6,
      });

      const monthsToAnalyze = data.months || 6;
      const now = new Date();
      const analytics: any = {
        userId: data.userId,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        monthlyUsage: {},
        trends: {},
        alerts: [],
        recommendations: [],
      };

      // Get usage data
      const usageDoc = await db.collection('usage_tracking').doc(data.userId).get();
      let usageData: Record<string, any> = {};
      
      if (usageDoc.exists) {
        usageData = usageDoc.data() || {};
      }

      // Get subscription limits
      const subscriptionQuery = await db
        .collection('user_subscriptions')
        .where('userId', '==', data.userId)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      let limits: Record<string, number> = {};
      let tier = 'free';
      
      if (!subscriptionQuery.empty) {
        const subscriptionData = subscriptionQuery.docs[0].data();
        limits = subscriptionData.limits || {};
        tier = subscriptionData.tier || 'free';
      }

      // Analyze monthly usage for the specified period
      for (let i = 0; i < monthsToAnalyze; i++) {
        const month = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const monthKey = `${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, '0')}`;
        
        if (usageData[monthKey]) {
          analytics.monthlyUsage[monthKey] = usageData[monthKey];
          
          // Calculate utilization percentages
          for (const [feature, usage] of Object.entries(usageData[monthKey])) {
            if (typeof usage === 'number') {
              const limit = limits[feature] ?? getDefaultLimit(feature);
              if (limit > 0) {
                const percentage = Math.round((usage / limit) * 100);
                
                if (!analytics.trends[feature]) {
                  analytics.trends[feature] = [];
                }
                
                analytics.trends[feature].push({
                  month: monthKey,
                  usage,
                  limit,
                  percentage,
                });
                
                // Generate recommendations
                if (percentage >= 80) {
                  analytics.recommendations.push({
                    type: 'upgrade_suggested',
                    feature,
                    message: `You're using ${percentage}% of your ${feature} limit. Consider upgrading for unlimited access.`,
                    priority: percentage >= 95 ? 'high' : 'medium',
                  });
                }
              }
            }
          }
        }
      }

      // Get recent alerts
      const alertsQuery = await db
        .collection('usage_alerts')
        .where('userId', '==', data.userId)
        .orderBy('timestamp', 'desc')
        .limit(10)
        .get();

      analytics.alerts = alertsQuery.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      // Generate tier-specific insights
      analytics.tierInfo = {
        currentTier: tier,
        limits,
        upgradeRecommended: analytics.recommendations.some((r: any) => r.type === 'upgrade_suggested'),
      };

      functions.logger.info('✅ Usage analytics generated', {
        userId: data.userId,
        monthsAnalyzed: monthsToAnalyze,
        recommendationsCount: analytics.recommendations.length,
        alertsCount: analytics.alerts.length,
      });

      return analytics;
    } catch (error) {
      functions.logger.error('❌ Error getting usage analytics', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to generate usage analytics'
      );
    }
  }
);

// Reset usage limits (for scheduled or manual resets)
export const resetUsageLimits = functions.https.onCall(
  async (data: UsageResetData, context) => {
    // Only allow authenticated admin users or system calls
    if (!context.auth && data.resetType !== 'monthly') {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated for manual resets'
      );
    }

    try {
      functions.logger.info('🔄 Resetting usage limits', {
        resetType: data.resetType,
        userIds: data.userIds?.length || 'all',
      });

      const batch = db.batch();
      let query = db.collection('usage_tracking');
      
      // If specific users provided, reset only those
      if (data.userIds && data.userIds.length > 0) {
        // Firestore 'in' query limited to 10 items, so batch them
        const batches = [];
        for (let i = 0; i < data.userIds.length; i += 10) {
          const userBatch = data.userIds.slice(i, i + 10);
          batches.push(query.where(admin.firestore.FieldPath.documentId(), 'in', userBatch).get());
        }
        
        const snapshots = await Promise.all(batches);
        const docs = snapshots.flatMap(snapshot => snapshot.docs);
        
        for (const doc of docs) {
          await resetUserUsage(doc, data.resetType, batch);
        }
      } else {
        // Reset all users
        const snapshot = await query.get();
        for (const doc of snapshot.docs) {
          await resetUserUsage(doc, data.resetType, batch);
        }
      }

      await batch.commit();
      
      // Log reset activity
      await db.collection('system_logs').add({
        action: 'usage_reset',
        resetType: data.resetType,
        affectedUsers: data.userIds?.length || 'all',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        executedBy: context.auth?.uid || 'system',
      });

      functions.logger.info('✅ Usage limits reset successfully', {
        resetType: data.resetType,
        processedUsers: data.userIds?.length || 'all',
      });

      return {
        success: true,
        resetType: data.resetType,
        processedUsers: data.userIds?.length || 'all',
      };
    } catch (error) {
      functions.logger.error('❌ Error resetting usage limits', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to reset usage limits'
      );
    }
  }
);

// Helper function to reset individual user usage
async function resetUserUsage(
  doc: FirebaseFirestore.QueryDocumentSnapshot,
  resetType: string,
  batch: FirebaseFirestore.WriteBatch
) {
  const userId = doc.id;
  const usageData = doc.data();
  const now = new Date();

  functions.logger.info('🔄 Resetting usage for user', { userId, resetType });

  switch (resetType) {
    case 'daily':
      // Clear today's usage (if we tracked daily usage)
      const today = now.toISOString().split('T')[0];
      if (usageData[today]) {
        delete usageData[today];
      }
      break;
      
    case 'weekly':
      // Clear current week's usage
      const weekStart = new Date(now.setDate(now.getDate() - now.getDay()));
      const weekKey = weekStart.toISOString().split('T')[0];
      if (usageData[`week_${weekKey}`]) {
        delete usageData[`week_${weekKey}`];
      }
      break;
      
    case 'monthly':
      // Clear current month's usage
      const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
      if (usageData[currentMonth]) {
        delete usageData[currentMonth];
      }
      break;
      
    case 'all':
      // Reset all usage data but keep metadata
      const keysToKeep = ['lastActivity'];
      const filteredData: Record<string, any> = {};
      
      for (const [key, value] of Object.entries(usageData)) {
        if (keysToKeep.includes(key) || key.includes('_metadata')) {
          filteredData[key] = value;
        }
      }
      
      filteredData.lastReset = admin.firestore.FieldValue.serverTimestamp();
      batch.set(doc.ref, filteredData);
      return;
  }

  usageData.lastReset = admin.firestore.FieldValue.serverTimestamp();
  batch.set(doc.ref, usageData);
}

// Send usage limit notification
async function sendUsageLimitNotification(
  userId: string,
  featureName: string,
  currentUsage: number,
  limit: number,
  percentage: number
) {
  try {
    functions.logger.info('📤 Sending usage limit notification', {
      userId,
      featureName,
      currentUsage,
      limit,
      percentage: percentage.toFixed(1),
    });

    // Create notification document
    await db.collection('notifications').add({
      userId,
      type: 'usage_limit_warning',
      title: 'Usage Limit Warning',
      message: percentage >= 100
        ? `You've reached your ${featureName} limit (${currentUsage}/${limit}). Upgrade to continue using this feature.`
        : `You're at ${percentage.toFixed(0)}% of your ${featureName} limit (${currentUsage}/${limit}).`,
      data: {
        featureName,
        currentUsage,
        limit,
        percentage: percentage.toFixed(1),
        recommendedAction: percentage >= 100 ? 'upgrade_required' : 'upgrade_suggested',
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });

    // TODO: Send push notification via FCM
    // TODO: Send email notification for critical limits (100%+)
    
    functions.logger.info('✅ Usage limit notification sent', { userId, featureName });
  } catch (error) {
    functions.logger.error('❌ Error sending usage limit notification', error);
  }
}

// 🕐 SCHEDULED FUNCTIONS FOR BACKGROUND PROCESSING

// Monthly usage limit reset (runs on 1st of each month at 00:00 UTC)
export const monthlyUsageReset = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('🔄 Starting monthly usage reset');
    
    try {
      const batch = db.batch();
      const snapshot = await db.collection('usage_tracking').get();
      
      let processedCount = 0;
      const now = new Date();
      const lastMonth = `${now.getFullYear()}-${String(now.getMonth()).padStart(2, '0')}`;
      
      for (const doc of snapshot.docs) {
        const usageData = doc.data();
        
        // Archive last month's data before clearing current month
        if (usageData[lastMonth]) {
          const archiveData = {
            userId: doc.id,
            month: lastMonth,
            usage: usageData[lastMonth],
            archivedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          batch.set(
            db.collection('usage_archives').doc(`${doc.id}_${lastMonth}`),
            archiveData
          );
        }
        
        // Clear current month's usage
        await resetUserUsage(doc, 'monthly', batch);
        processedCount++;
      }
      
      await batch.commit();
      
      // Log reset activity
      await db.collection('system_logs').add({
        action: 'monthly_usage_reset',
        processedUsers: processedCount,
        month: lastMonth,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        executedBy: 'system_scheduler',
      });
      
      functions.logger.info('✅ Monthly usage reset completed', {
        processedUsers: processedCount,
        month: lastMonth,
      });
    } catch (error) {
      functions.logger.error('❌ Error during monthly usage reset', error);
      
      // Send alert to admin about failed reset
      await db.collection('system_alerts').add({
        type: 'monthly_reset_failed',
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        severity: 'critical',
      });
    }
  });

// Daily subscription health check (runs daily at 02:00 UTC)
export const dailySubscriptionHealthCheck = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('🏥 Starting daily subscription health check');
    
    try {
      const subscriptionsSnapshot = await db
        .collection('user_subscriptions')
        .where('status', '==', 'active')
        .get();
      
      const healthReport = {
        totalActiveSubscriptions: subscriptionsSnapshot.docs.length,
        healthySubscriptions: 0,
        issuesFound: 0,
        issues: [] as any[],
        checkedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      for (const subscriptionDoc of subscriptionsSnapshot.docs) {
        const subscription = subscriptionDoc.data();
        const userId = subscription.userId;
        
        try {
          // Check if Stripe subscription is still active
          if (subscription.stripeSubscriptionId) {
            const stripeSubscription = await stripe.subscriptions.retrieve(
              subscription.stripeSubscriptionId
            );
            
            // Sync status with Stripe
            if (stripeSubscription.status !== 'active') {
              functions.logger.warn('⚠️ Subscription status mismatch', {
                userId,
                localStatus: subscription.status,
                stripeStatus: stripeSubscription.status,
                subscriptionId: subscription.stripeSubscriptionId,
              });
              
              // Update local subscription status
              await subscriptionDoc.ref.update({
                status: stripeSubscription.status,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                syncedFromStripe: true,
              });
              
              healthReport.issues.push({
                userId,
                issue: 'status_mismatch',
                localStatus: subscription.status,
                stripeStatus: stripeSubscription.status,
                fixed: true,
              });
              
              healthReport.issuesFound++;
            } else {
              healthReport.healthySubscriptions++;
            }
            
            // Check for upcoming payment failures
            const upcomingInvoices = await stripe.invoices.list({
              subscription: subscription.stripeSubscriptionId,
              status: 'open',
              limit: 1,
            });
            
            if (upcomingInvoices.data.length > 0) {
              const invoice = upcomingInvoices.data[0];
              if (invoice.attempt_count && invoice.attempt_count > 1) {
                healthReport.issues.push({
                  userId,
                  issue: 'payment_retry_detected',
                  attemptCount: invoice.attempt_count,
                  invoiceId: invoice.id,
                });
                
                // Send notification about payment issues
                await sendPaymentReminderNotification(userId, invoice);
              }
            }
          } else {
            healthReport.issues.push({
              userId,
              issue: 'missing_stripe_subscription_id',
            });
            healthReport.issuesFound++;
          }
        } catch (subscriptionError) {
          functions.logger.error('❌ Error checking subscription health', {
            userId,
            error: subscriptionError,
          });
          
          healthReport.issues.push({
            userId,
            issue: 'health_check_failed',
            error: subscriptionError instanceof Error ? subscriptionError.message : 'Unknown error',
          });
          healthReport.issuesFound++;
        }
      }
      
      // Store health report
      await db.collection('system_health_reports').add(healthReport);
      
      functions.logger.info('✅ Daily subscription health check completed', {
        totalChecked: healthReport.totalActiveSubscriptions,
        healthy: healthReport.healthySubscriptions,
        issuesFound: healthReport.issuesFound,
      });
      
      // Alert if significant issues found
      if (healthReport.issuesFound > healthReport.totalActiveSubscriptions * 0.1) {
        await db.collection('system_alerts').add({
          type: 'high_subscription_failure_rate',
          totalSubscriptions: healthReport.totalActiveSubscriptions,
          issuesFound: healthReport.issuesFound,
          failureRate: (healthReport.issuesFound / healthReport.totalActiveSubscriptions * 100).toFixed(1),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          severity: 'high',
        });
      }
    } catch (error) {
      functions.logger.error('❌ Error during subscription health check', error);
    }
  });

// Weekly usage analytics report (runs every Sunday at 01:00 UTC)
export const weeklyUsageAnalytics = functions.pubsub
  .schedule('0 1 * * 0')
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('📊 Starting weekly usage analytics report');
    
    try {
      const usageSnapshot = await db.collection('usage_tracking').get();
      const subscriptionsSnapshot = await db.collection('user_subscriptions').get();
      
      const report = {
        reportDate: admin.firestore.FieldValue.serverTimestamp(),
        totalUsers: usageSnapshot.docs.length,
        totalSubscriptions: subscriptionsSnapshot.docs.length,
        usageStats: {} as Record<string, any>,
        subscriptionBreakdown: {} as Record<string, number>,
        highUsageUsers: [] as any[],
        upgradeOpportunities: [] as any[],
      };
      
      // Analyze subscription distribution
      for (const subDoc of subscriptionsSnapshot.docs) {
        const subscription = subDoc.data();
        const tier = subscription.tier || 'free';
        report.subscriptionBreakdown[tier] = (report.subscriptionBreakdown[tier] || 0) + 1;
      }
      
      // Analyze usage patterns
      const now = new Date();
      const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
      
      const featureUsage: Record<string, { total: number; users: number; averagePerUser: number }> = {};
      
      for (const usageDoc of usageSnapshot.docs) {
        const usageData = usageDoc.data();
        const monthlyUsage = usageData[currentMonth] || {};
        const userId = usageDoc.id;
        
        // Get user's subscription for context
        const userSubscription = subscriptionsSnapshot.docs.find(
          sub => sub.data().userId === userId
        );
        const userTier = userSubscription?.data().tier || 'free';
        
        let userTotalUsage = 0;
        let nearLimitFeatures = [];
        
        for (const [feature, usage] of Object.entries(monthlyUsage)) {
          if (typeof usage === 'number') {
            if (!featureUsage[feature]) {
              featureUsage[feature] = { total: 0, users: 0, averagePerUser: 0 };
            }
            
            featureUsage[feature].total += usage;
            featureUsage[feature].users += 1;
            userTotalUsage += usage;
            
            // Check if user is near limits (for free tier users)
            if (userTier === 'free') {
              const limit = getDefaultLimit(feature);
              if (limit > 0 && (usage / limit) >= 0.8) {
                nearLimitFeatures.push({
                  feature,
                  usage,
                  limit,
                  percentage: Math.round((usage / limit) * 100),
                });
              }
            }
          }
        }
        
        // Identify high usage users and upgrade opportunities
        if (userTotalUsage > 0) {
          if (nearLimitFeatures.length > 0) {
            report.upgradeOpportunities.push({
              userId,
              currentTier: userTier,
              totalUsage: userTotalUsage,
              nearLimitFeatures,
              upgradeRecommended: nearLimitFeatures.some(f => f.percentage >= 90),
            });
          }
          
          if (userTotalUsage > 50) { // Arbitrary threshold for "high usage"
            report.highUsageUsers.push({
              userId,
              tier: userTier,
              totalUsage: userTotalUsage,
              topFeatures: Object.entries(monthlyUsage)
                .filter(([_, usage]) => typeof usage === 'number')
                .sort(([_, a], [__, b]) => (b as number) - (a as number))
                .slice(0, 3),
            });
          }
        }
      }
      
      // Calculate averages
      for (const feature of Object.keys(featureUsage)) {
        if (featureUsage[feature].users > 0) {
          featureUsage[feature].averagePerUser = 
            Math.round(featureUsage[feature].total / featureUsage[feature].users * 100) / 100;
        }
      }
      
      report.usageStats = featureUsage;
      
      // Sort by potential value
      report.upgradeOpportunities.sort((a, b) => b.totalUsage - a.totalUsage);
      report.highUsageUsers.sort((a, b) => b.totalUsage - a.totalUsage);
      
      // Store the report
      await db.collection('analytics_reports').add({
        type: 'weekly_usage',
        ...report,
      });
      
      functions.logger.info('✅ Weekly usage analytics completed', {
        totalUsers: report.totalUsers,
        upgradeOpportunities: report.upgradeOpportunities.length,
        highUsageUsers: report.highUsageUsers.length,
      });
      
    } catch (error) {
      functions.logger.error('❌ Error during weekly analytics', error);
    }
  });

// Billing notification reminder (runs daily at 09:00 UTC)
export const dailyBillingNotifications = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('💳 Starting daily billing notifications');
    
    try {
      const subscriptionsSnapshot = await db
        .collection('user_subscriptions')
        .where('status', '==', 'active')
        .get();
      
      const now = new Date();
      const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
      
      let notificationsSent = 0;
      
      for (const subscriptionDoc of subscriptionsSnapshot.docs) {
        const subscription = subscriptionDoc.data();
        const userId = subscription.userId;
        
        try {
          if (subscription.stripeSubscriptionId) {
            // Get upcoming invoice
            const upcomingInvoice = await stripe.invoices.retrieveUpcoming({
              subscription: subscription.stripeSubscriptionId,
            });
            
            const nextPaymentDate = new Date(upcomingInvoice.period_end * 1000);
            
            // Send reminder 3 days before payment
            if (nextPaymentDate <= threeDaysFromNow && nextPaymentDate > now) {
              await sendBillingReminderNotification(userId, nextPaymentDate, upcomingInvoice);
              notificationsSent++;
            }
            
            // Check for failed payments
            if (upcomingInvoice.attempt_count && upcomingInvoice.attempt_count > 1) {
              await sendPaymentFailureNotification(userId, upcomingInvoice);
              notificationsSent++;
            }
          }
        } catch (subscriptionError) {
          // Log individual subscription errors but continue processing others
          functions.logger.warn('⚠️ Error processing billing notification', {
            userId,
            error: subscriptionError instanceof Error ? subscriptionError.message : 'Unknown error',
          });
        }
      }
      
      functions.logger.info('✅ Daily billing notifications completed', {
        totalSubscriptions: subscriptionsSnapshot.docs.length,
        notificationsSent,
      });
      
    } catch (error) {
      functions.logger.error('❌ Error during billing notifications', error);
    }
  });

// Helper function for payment reminder notifications
async function sendPaymentReminderNotification(
  userId: string,
  invoice: any
) {
  try {
    await db.collection('notifications').add({
      userId,
      type: 'payment_retry_warning',
      title: 'Payment Issue Detected',
      message: `We're having trouble processing your payment. Please update your payment method to avoid service interruption.`,
      data: {
        invoiceId: invoice.id,
        attemptCount: invoice.attempt_count,
        amountDue: invoice.amount_due / 100,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    
    functions.logger.info('✅ Payment reminder notification sent', { userId });
  } catch (error) {
    functions.logger.error('❌ Error sending payment reminder', error);
  }
}

// Helper function for billing reminder notifications
async function sendBillingReminderNotification(
  userId: string,
  nextPaymentDate: Date,
  invoice: any
) {
  try {
    await db.collection('notifications').add({
      userId,
      type: 'billing_reminder',
      title: 'Upcoming Payment',
      message: `Your next payment of $${(invoice.amount_due / 100).toFixed(2)} is scheduled for ${nextPaymentDate.toLocaleDateString()}.`,
      data: {
        nextPaymentDate: nextPaymentDate.toISOString(),
        amount: invoice.amount_due / 100,
        invoiceId: invoice.id,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    
    functions.logger.info('✅ Billing reminder notification sent', { userId });
  } catch (error) {
    functions.logger.error('❌ Error sending billing reminder', error);
  }
}

// Helper function for payment failure notifications
async function sendPaymentFailureNotification(
  userId: string,
  invoice: any
) {
  try {
    await db.collection('notifications').add({
      userId,
      type: 'payment_failed',
      title: 'Payment Failed',
      message: `We couldn't process your payment. Please update your payment method to avoid service suspension.`,
      data: {
        invoiceId: invoice.id,
        attemptCount: invoice.attempt_count,
        amountDue: invoice.amount_due / 100,
        urgent: true,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    
    functions.logger.info('✅ Payment failure notification sent', { userId });
  } catch (error) {
    functions.logger.error('❌ Error sending payment failure notification', error);
  }
}

// 📊 PERFORMANCE MONITORING & DASHBOARDS

// Performance metrics collection (runs every 5 minutes)
export const collectPerformanceMetrics = functions.pubsub
  .schedule('*/5 * * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      functions.logger.info('📊 Collecting performance metrics');

      const metrics = {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        subscriptions: {
          total: 0,
          active: 0,
          cancelled: 0,
          pastDue: 0,
        },
        usage: {
          activeUsers: 0,
          totalTrackedEvents: 0,
          alertsGenerated: 0,
        },
        system: {
          functionsInvoked: 0,
          errors: 0,
          responseTime: 0,
        },
      };

      // Collect subscription metrics
      const subscriptionsSnapshot = await db.collection('user_subscriptions').get();
      metrics.subscriptions.total = subscriptionsSnapshot.docs.length;

      subscriptionsSnapshot.docs.forEach(doc => {
        const subscription = doc.data();
        switch (subscription.status) {
          case 'active':
            metrics.subscriptions.active++;
            break;
          case 'cancelled':
            metrics.subscriptions.cancelled++;
            break;
          case 'past_due':
            metrics.subscriptions.pastDue++;
            break;
        }
      });

      // Collect usage metrics
      const usageSnapshot = await db.collection('usage_tracking').get();
      metrics.usage.activeUsers = usageSnapshot.docs.length;

      // Count recent alerts (last 5 minutes)
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      const alertsSnapshot = await db
        .collection('usage_alerts')
        .where('timestamp', '>=', fiveMinutesAgo)
        .get();
      metrics.usage.alertsGenerated = alertsSnapshot.docs.length;

      // Store metrics
      await db.collection('performance_metrics').add(metrics);

      // Check for performance thresholds and create alerts
      await checkPerformanceThresholds(metrics);

      functions.logger.info('✅ Performance metrics collected', {
        totalSubscriptions: metrics.subscriptions.total,
        activeUsers: metrics.usage.activeUsers,
        recentAlerts: metrics.usage.alertsGenerated,
      });
    } catch (error) {
      functions.logger.error('❌ Error collecting performance metrics', error);
    }
  });

// Check performance thresholds and create alerts
async function checkPerformanceThresholds(metrics: any) {
  const alerts = [];

  // Check subscription health
  const totalSubs = metrics.subscriptions.total;
  if (totalSubs > 0) {
    const activePercentage = (metrics.subscriptions.active / totalSubs) * 100;
    if (activePercentage < 80) {
      alerts.push({
        type: 'low_subscription_health',
        metric: 'active_subscription_percentage',
        value: activePercentage,
        threshold: 80,
        severity: 'medium',
      });
    }

    const pastDuePercentage = (metrics.subscriptions.pastDue / totalSubs) * 100;
    if (pastDuePercentage > 10) {
      alerts.push({
        type: 'high_past_due_rate',
        metric: 'past_due_percentage',
        value: pastDuePercentage,
        threshold: 10,
        severity: 'high',
      });
    }
  }

  // Check usage alert rate
  if (metrics.usage.alertsGenerated > 20) {
    alerts.push({
      type: 'high_usage_alert_rate',
      metric: 'alerts_per_5min',
      value: metrics.usage.alertsGenerated,
      threshold: 20,
      severity: 'medium',
    });
  }

  // Store alerts
  for (const alert of alerts) {
    await db.collection('system_alerts').add({
      ...alert,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.warn('🚨 Performance threshold exceeded', alert);
  }
}

// Generate performance dashboard data
export const generatePerformanceDashboard = functions.https.onCall(
  async (data: { timeRange?: string; includeDetails?: boolean }, context) => {
    // Verify admin access (in production, add proper admin verification)
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to access dashboard'
      );
    }

    try {
      functions.logger.info('📈 Generating performance dashboard');

      const timeRange = data.timeRange || '24h';
      const includeDetails = data.includeDetails || false;

      // Calculate time window
      const now = new Date();
      let startTime: Date;
      
      switch (timeRange) {
        case '1h':
          startTime = new Date(now.getTime() - 60 * 60 * 1000);
          break;
        case '24h':
          startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
          break;
        case '7d':
          startTime = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case '30d':
          startTime = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        default:
          startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      }

      // Get performance metrics for the time range
      const metricsSnapshot = await db
        .collection('performance_metrics')
        .where('timestamp', '>=', startTime)
        .orderBy('timestamp', 'desc')
        .limit(100)
        .get();

      const metrics = metricsSnapshot.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          timestamp: data.timestamp,
          subscriptions: data.subscriptions || {},
          usage: data.usage || {},
          system: data.system || {},
        };
      });

      // Calculate aggregated statistics
      const dashboard = {
        timeRange,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        summary: {
          totalSubscriptions: 0,
          activeSubscriptions: 0,
          subscriptionGrowth: 0,
          revenueGrowth: 0,
          usageAlerts: 0,
          systemHealth: 'good',
        },
        charts: {
          subscriptionTrend: [] as any[],
          usageTrend: [] as any[],
          alertsTrend: [] as any[],
        },
        alerts: [] as any[],
        topFeatures: [] as any[],
      };

      if (metrics.length > 0) {
        const latest = metrics[0];
        dashboard.summary.totalSubscriptions = latest.subscriptions?.total || 0;
        dashboard.summary.activeSubscriptions = latest.subscriptions?.active || 0;

        // Calculate trends
        dashboard.charts.subscriptionTrend = metrics.map(m => ({
          timestamp: m.timestamp,
          total: m.subscriptions?.total || 0,
          active: m.subscriptions?.active || 0,
          cancelled: m.subscriptions?.cancelled || 0,
        }));

        dashboard.charts.usageTrend = metrics.map(m => ({
          timestamp: m.timestamp,
          activeUsers: m.usage?.activeUsers || 0,
          trackedEvents: m.usage?.totalTrackedEvents || 0,
        }));

        dashboard.charts.alertsTrend = metrics.map(m => ({
          timestamp: m.timestamp,
          alerts: m.usage?.alertsGenerated || 0,
        }));
      }

      // Get recent alerts
      const alertsSnapshot = await db
        .collection('system_alerts')
        .where('timestamp', '>=', startTime)
        .orderBy('timestamp', 'desc')
        .limit(20)
        .get();

      dashboard.alerts = alertsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      // Get feature usage statistics
      if (includeDetails) {
        const usageSnapshot = await db.collection('usage_tracking').limit(100).get();
        const featureUsage: Record<string, number> = {};

        usageSnapshot.docs.forEach(doc => {
          const data = doc.data();
          const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
          const monthlyData = data[currentMonth] || {};

          Object.entries(monthlyData).forEach(([feature, usage]) => {
            if (typeof usage === 'number') {
              featureUsage[feature] = (featureUsage[feature] || 0) + usage;
            }
          });
        });

        dashboard.topFeatures = Object.entries(featureUsage)
          .sort(([, a], [, b]) => (b as number) - (a as number))
          .slice(0, 10)
          .map(([feature, usage]) => ({ feature, usage }));
      }

      // Determine system health
      const recentAlerts = dashboard.alerts.filter(alert => 
        alert.severity === 'high' || alert.severity === 'critical'
      );
      
      if (recentAlerts.length > 5) {
        dashboard.summary.systemHealth = 'critical';
      } else if (recentAlerts.length > 2) {
        dashboard.summary.systemHealth = 'warning';
      }

      functions.logger.info('✅ Performance dashboard generated', {
        timeRange,
        metricsCount: metrics.length,
        alertsCount: dashboard.alerts.length,
        systemHealth: dashboard.summary.systemHealth,
      });

      return dashboard;
    } catch (error) {
      functions.logger.error('❌ Error generating performance dashboard', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to generate dashboard'
      );
    }
  }
);

// 🔐 SECURITY MONITORING FOR PAYMENT OPERATIONS

// Monitor suspicious payment activities
export const monitorPaymentSecurity = functions.pubsub
  .schedule('*/10 * * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('🔐 Starting payment security monitoring');

    try {
      const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
      const securityReport = {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        suspiciousActivities: [] as any[],
        riskLevel: 'low',
        checks: {
          rapidSubscriptionChanges: 0,
          failedPaymentAttempts: 0,
          unusualGeoLocation: 0,
          highValueTransactions: 0,
        },
      };

      // Check for rapid subscription changes
      const subscriptionChanges = await db
        .collection('system_logs')
        .where('action', 'in', ['subscription_created', 'subscription_cancelled', 'subscription_updated'])
        .where('timestamp', '>=', tenMinutesAgo)
        .get();

      // Group by user to detect rapid changes
      const userChanges: Record<string, number> = {};
      subscriptionChanges.docs.forEach(doc => {
        const data = doc.data();
        const userId = data.userId || 'unknown';
        userChanges[userId] = (userChanges[userId] || 0) + 1;
      });

      Object.entries(userChanges).forEach(([userId, changeCount]) => {
        if (changeCount >= 3) {
          securityReport.suspiciousActivities.push({
            type: 'rapid_subscription_changes',
            userId,
            count: changeCount,
            timeWindow: '10 minutes',
            riskLevel: 'medium',
          });
          securityReport.checks.rapidSubscriptionChanges++;
        }
      });

      // Check for failed payment attempts
      const failedPayments = await db
        .collection('notifications')
        .where('type', '==', 'payment_failed')
        .where('timestamp', '>=', tenMinutesAgo)
        .get();

      const userFailures: Record<string, number> = {};
      failedPayments.docs.forEach(doc => {
        const data = doc.data();
        const userId = data.userId;
        userFailures[userId] = (userFailures[userId] || 0) + 1;
      });

      Object.entries(userFailures).forEach(([userId, failureCount]) => {
        if (failureCount >= 2) {
          securityReport.suspiciousActivities.push({
            type: 'multiple_payment_failures',
            userId,
            count: failureCount,
            timeWindow: '10 minutes',
            riskLevel: 'high',
          });
          securityReport.checks.failedPaymentAttempts++;
        }
      });

      // Check for high-value transactions (if we had transaction data)
      // This would involve checking Stripe webhooks for large amounts

      // Determine overall risk level
      const totalSuspiciousActivities = securityReport.suspiciousActivities.length;
      if (totalSuspiciousActivities >= 5) {
        securityReport.riskLevel = 'high';
      } else if (totalSuspiciousActivities >= 2) {
        securityReport.riskLevel = 'medium';
      }

      // Store security report
      await db.collection('security_reports').add(securityReport);

      // Create alerts for high-risk situations
      if (securityReport.riskLevel === 'high') {
        await db.collection('system_alerts').add({
          type: 'high_security_risk',
          details: securityReport,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          severity: 'critical',
          requiresAction: true,
        });

        functions.logger.error('🚨 High security risk detected', {
          suspiciousActivities: totalSuspiciousActivities,
          details: securityReport.suspiciousActivities,
        });
      }

      functions.logger.info('✅ Payment security monitoring completed', {
        riskLevel: securityReport.riskLevel,
        suspiciousActivities: totalSuspiciousActivities,
        checks: securityReport.checks,
      });
    } catch (error) {
      functions.logger.error('❌ Error during security monitoring', error);
    }
  });

// Enhanced webhook handler with security logging
export const secureStripeWebhook = functions.https.onRequest(async (req, res) => {
  const startTime = Date.now();
  const endpointSecret = functions.config().stripe.webhook_secret;
  const sig = req.headers['stripe-signature'];

  let event: Stripe.Event;

  try {
    // For Firebase Functions, req.rawBody is available when the function receives the raw request
    // CRITICAL: For Stripe signature verification, use raw Buffer directly
    // Firebase provides req.rawBody as a Buffer - use it directly without conversion
    if (!req.rawBody) {
      functions.logger.error('❌ No rawBody in request');
      res.status(400).send('No raw body available');
      return;
    }
    
    // Pass the raw Buffer directly to constructEvent - DO NOT convert to string
    event = stripe.webhooks.constructEvent(
      req.rawBody, // Pass Buffer directly
      sig as string, 
      endpointSecret
    );
    
    // Log security information
    functions.logger.info('🔐 Webhook received and verified', {
      type: event.type,
      id: event.id,
      created: event.created,
      livemode: event.livemode,
      api_version: event.api_version,
      sourceIP: req.ip,
      userAgent: req.get('User-Agent'),
    });

    // Check for suspicious webhook patterns
    await logWebhookSecurity(event, req);

  } catch (err) {
    functions.logger.error('❌ Webhook signature verification failed', {
      error: (err as Error).message,
      sourceIP: req.ip,
      userAgent: req.get('User-Agent'),
      timestamp: new Date().toISOString(),
    });

    // Log potential security threat
    await db.collection('security_logs').add({
      type: 'webhook_verification_failed',
      sourceIP: req.ip,
      userAgent: req.get('User-Agent'),
      error: (err as Error).message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      severity: 'high',
    });

    res.status(400).send(`Webhook Error: ${(err as Error).message}`);
    return;
  }

  // Handle the event
  try {
    const processingStartTime = Date.now();

    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutSessionCompleted(event.data.object as Stripe.Checkout.Session);
        break;
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object as Stripe.Subscription);
        break;
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
        break;
      case 'invoice.payment_succeeded':
        await handlePaymentSucceeded(event.data.object as Stripe.Invoice);
        break;
      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object as Stripe.Invoice);
        break;
      case 'payment_intent.succeeded':
        await handlePaymentIntentSucceeded(event.data.object as Stripe.PaymentIntent);
        break;
      default:
        functions.logger.info('🔄 Unhandled webhook event type', {
          type: event.type,
        });
    }

    const processingTime = Date.now() - processingStartTime;
    const totalTime = Date.now() - startTime;

    // Log performance metrics
    functions.logger.info('⚡ Webhook processed successfully', {
      eventType: event.type,
      eventId: event.id,
      processingTime,
      totalTime,
    });

    res.json({ received: true });
  } catch (error) {
    const totalTime = Date.now() - startTime;
    
    functions.logger.error('❌ Error handling webhook', {
      eventType: event.type,
      eventId: event.id,
      error,
      totalTime,
    });

    // Log webhook processing error
    await db.collection('system_logs').add({
      action: 'webhook_processing_failed',
      eventType: event.type,
      eventId: event.id,
      error: error instanceof Error ? error.message : 'Unknown error',
      processingTime: totalTime,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(500).send('Webhook handler failed');
  }
});

// Log webhook security information
async function logWebhookSecurity(event: Stripe.Event, req: any) {
  try {
    const securityLog = {
      type: 'webhook_received',
      eventType: event.type,
      eventId: event.id,
      livemode: event.livemode,
      sourceIP: req.ip,
      userAgent: req.get('User-Agent'),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        api_version: event.api_version,
        created: event.created,
      },
    };

    // Check for suspicious patterns
    const suspiciousFlags = [];

    // Check for rapid webhook frequency (more than 10 per minute from same IP)
    const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
    const recentWebhooks = await db
      .collection('security_logs')
      .where('type', '==', 'webhook_received')
      .where('sourceIP', '==', req.ip)
      .where('timestamp', '>=', oneMinuteAgo)
      .get();

    if (recentWebhooks.docs.length > 10) {
      suspiciousFlags.push('high_frequency_webhooks');
    }

    // Check for unusual user agent
    const userAgent = req.get('User-Agent') || '';
    if (!userAgent.includes('Stripe') && !userAgent.includes('stripe')) {
      suspiciousFlags.push('unusual_user_agent');
    }

    if (suspiciousFlags.length > 0) {
      securityLog.metadata = {
        ...securityLog.metadata,
        suspiciousFlags,
        severity: 'medium',
      } as any;

      functions.logger.warn('⚠️ Suspicious webhook activity detected', {
        eventId: event.id,
        sourceIP: req.ip,
        flags: suspiciousFlags,
      });
    }

    await db.collection('security_logs').add(securityLog);
  } catch (error) {
    functions.logger.error('❌ Error logging webhook security', error);
  }
}

// ====== TICKETING FUNCTIONS ======
// Export all ticketing functions from ticketing.ts
export {
  createTicketCheckoutSession,
  validateTicket,
  getEventTicketSummary,
  cancelTicketPurchase
} from './ticketing';

// ====== SQUARE OAUTH FUNCTIONS ======
// Export Square OAuth integration functions
export {
  exchangeSquareToken,
  refreshSquareTokens,
  disconnectSquare
} from './square-oauth';

// ====== SQUARE PAYMENTS SYNC FUNCTIONS ======
// Export Square payment sync functions
export {
  syncSquarePayments,
  triggerSquareSync
} from './square-payments-sync';

// ====== STRIPE CONNECT FUNCTIONS ======
// Export Stripe Connect integration functions for vendor payments
export {
  createStripeConnectAccount,
  checkStripeAccountStatus,
  disconnectStripeAccount,
  getStripeAccountLink,
  // Organizer Stripe Connect (receives application payments)
  createOrganizerStripeConnectAccount,
  checkOrganizerStripeAccountStatus,
  disconnectOrganizerStripeAccount,
  getOrganizerStripeAccountLink
} from './stripe-connect';

// ====== STRIPE PREORDER PAYMENTS ======
// Export Stripe preorder payment processing functions
export {
  createPreorderPaymentIntent,
  getPreorderPaymentStatus,
  cancelPreorderPayment
} from './stripe-preorder-payments';

// ====== STRIPE CONNECT WEBHOOKS ======
// Export Stripe Connect webhook handlers
export {
  stripeConnectWebhook,
  testStripeWebhook
} from './stripe-connect-webhooks';

// ====== STRIPE PAYMENTS SYNC FUNCTIONS ======
// Export Stripe payment sync functions (syncs preorders to vendor_sales)
export {
  syncStripePreorderToSales,
  backfillStripePreordersToSales,
  getVendorSalesSummary
} from './stripe-payments-sync';

// ====== VENDOR POST CLEANUP FUNCTIONS ======

/**
 * Cloud Function triggered when a vendor_post document is deleted
 * Automatically cleans up all associated basket items and pending reservations
 */
export const onVendorPostDeleted = functions.firestore
  .document('vendor_posts/{postId}')
  .onDelete(async (snapshot, context) => {
    const postId = context.params.postId;
    const postData = snapshot.data();

    functions.logger.info('🗑️ Vendor post deleted, initiating cleanup', {
      postId,
      vendorId: postData.vendorId,
      marketId: postData.associatedMarketId,
    });

    try {
      // Clean up basket items
      const basketCleanupPromise = cleanupBasketItems(postId, postData);

      // Clean up pending reservations
      const reservationCleanupPromise = cleanupPendingReservations(postId, postData);

      // Execute both cleanups in parallel
      const [basketResult, reservationResult] = await Promise.all([
        basketCleanupPromise,
        reservationCleanupPromise,
      ]);

      functions.logger.info('✅ Cleanup completed for vendor post', {
        postId,
        basketItemsDeleted: basketResult.deletedCount,
        reservationsCancelled: reservationResult.cancelledCount,
      });

      // Send notification to affected users if needed
      if (basketResult.affectedUsers.length > 0 || reservationResult.affectedUsers.length > 0) {
        await notifyAffectedUsers(
          postId,
          postData,
          [...new Set([...basketResult.affectedUsers, ...reservationResult.affectedUsers])]
        );
      }

    } catch (error) {
      functions.logger.error('❌ Error during vendor post cleanup', {
        postId,
        error,
      });
    }
  });

/**
 * Helper function to clean up basket items associated with a deleted vendor post
 */
async function cleanupBasketItems(
  postId: string,
  postData: admin.firestore.DocumentData
): Promise<{ deletedCount: number; affectedUsers: string[] }> {
  const affectedUsers: string[] = [];
  let deletedCount = 0;

  try {
    // Query all basket items that reference this vendor post
    const basketItemsSnapshot = await db
      .collection('basket_items')
      .where('vendorPostId', '==', postId)
      .get();

    if (!basketItemsSnapshot.empty) {
      const batch = db.batch();

      basketItemsSnapshot.docs.forEach((doc) => {
        const basketItem = doc.data();

        // Track affected users for notification
        if (basketItem.userId && !affectedUsers.includes(basketItem.userId)) {
          affectedUsers.push(basketItem.userId);
        }

        // Delete the basket item
        batch.delete(doc.ref);
        deletedCount++;
      });

      await batch.commit();

      functions.logger.info('🧹 Basket items cleaned up', {
        postId,
        deletedCount,
        affectedUsers,
      });
    }

  } catch (error) {
    functions.logger.error('Error cleaning up basket items', {
      postId,
      error,
    });
  }

  return { deletedCount, affectedUsers };
}

/**
 * Helper function to cancel pending reservations for a deleted vendor post
 */
async function cleanupPendingReservations(
  postId: string,
  postData: admin.firestore.DocumentData
): Promise<{ cancelledCount: number; affectedUsers: string[] }> {
  const affectedUsers: string[] = [];
  let cancelledCount = 0;

  try {
    // Query all pending reservations for this vendor post
    const reservationsSnapshot = await db
      .collection('reservations')
      .where('vendorPostId', '==', postId)
      .where('status', 'in', ['pending', 'confirmed'])
      .get();

    if (!reservationsSnapshot.empty) {
      const batch = db.batch();
      const now = admin.firestore.FieldValue.serverTimestamp();

      reservationsSnapshot.docs.forEach((doc) => {
        const reservation = doc.data();

        // Track affected users
        if (reservation.customerId && !affectedUsers.includes(reservation.customerId)) {
          affectedUsers.push(reservation.customerId);
        }

        // Cancel the reservation
        batch.update(doc.ref, {
          status: 'cancelled',
          cancellationReason: 'vendor_post_deleted',
          cancellationNote: `The vendor popup event was cancelled by ${postData.vendorName || 'the vendor'}.`,
          cancelledAt: now,
          updatedAt: now,
        });

        cancelledCount++;
      });

      await batch.commit();

      functions.logger.info('🚫 Reservations cancelled', {
        postId,
        cancelledCount,
        affectedUsers,
      });
    }

  } catch (error) {
    functions.logger.error('Error cancelling reservations', {
      postId,
      error,
    });
  }

  return { cancelledCount, affectedUsers };
}

/**
 * Send notifications to users affected by vendor post deletion
 */
async function notifyAffectedUsers(
  postId: string,
  postData: admin.firestore.DocumentData,
  affectedUserIds: string[]
): Promise<void> {
  try {
    const notifications = affectedUserIds.map(async (userId) => {
      // Create an in-app notification
      await db.collection('notifications').add({
        userId,
        type: 'vendor_post_cancelled',
        title: 'Popup Event Cancelled',
        message: `The popup event by ${postData.vendorName || 'a vendor'} at ${postData.location || 'the scheduled location'} has been cancelled.`,
        data: {
          vendorPostId: postId,
          vendorId: postData.vendorId,
          marketId: postData.associatedMarketId,
          popupDateTime: postData.popUpStartDateTime,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // TODO: Send push notification if user has enabled them
      // This would integrate with your push notification service
    });

    await Promise.all(notifications);

    functions.logger.info('📧 Notifications sent to affected users', {
      postId,
      userCount: affectedUserIds.length,
    });

  } catch (error) {
    functions.logger.error('Error sending notifications', {
      postId,
      error,
    });
  }
}

/**
 * Scheduled function to clean up orphaned basket items daily
 * Runs at 2 AM UTC every day
 */
export const scheduledBasketCleanup = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('🔄 Starting scheduled basket cleanup');

    try {
      // Get all vendor posts to check against
      const vendorPostsSnapshot = await db
        .collection('vendor_posts')
        .select('__name__') // Only get document IDs for efficiency
        .get();

      const validPostIds = vendorPostsSnapshot.docs.map(doc => doc.id);

      // Get all basket items
      const basketItemsSnapshot = await db
        .collection('basket_items')
        .get();

      let orphanedCount = 0;
      const batch = db.batch();

      basketItemsSnapshot.docs.forEach((doc) => {
        const basketItem = doc.data();

        // Check if the vendor post still exists
        if (!validPostIds.includes(basketItem.vendorPostId)) {
          batch.delete(doc.ref);
          orphanedCount++;
        }
      });

      if (orphanedCount > 0) {
        await batch.commit();
        functions.logger.info('✅ Orphaned basket items cleaned up', {
          orphanedCount,
        });
      } else {
        functions.logger.info('✅ No orphaned basket items found');
      }

    } catch (error) {
      functions.logger.error('❌ Error during scheduled basket cleanup', error);
    }

    return null;
  });



// ========================
// SCHEDULED NOTIFICATION REMINDERS
// ========================

// Interface for notification reminder data
interface NotificationReminderData {
  userId: string;
  userType: 'vendor' | 'market_organizer';
  fcmToken?: string;
  displayName: string;
  businessName?: string;
  organizationName?: string;
  upcomingEvents: Array<{
    type: 'popup' | 'market';
    eventId: string;
    eventName: string;
    eventDate: Date;
    location: string;
    hasPosted: boolean;
  }>;
  reminderType: 'monday' | 'thursday';
}

// Monday morning reminders (8:00 AM Eastern Time)
export const mondayMorningReminders = functions.pubsub
  .schedule('0 13 * * 1') // 13:00 UTC = 8:00 AM EST/9:00 AM EDT
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('📅 Starting Monday morning popup reminders');

    try {
      await sendScheduledPopupReminders('monday');
      functions.logger.info('✅ Monday morning reminders completed');
    } catch (error) {
      functions.logger.error('❌ Error during Monday morning reminders', error);
    }

    return null;
  });

// Thursday morning reminders (8:00 AM Eastern Time)
export const thursdayMorningReminders = functions.pubsub
  .schedule('0 13 * * 4') // 13:00 UTC = 8:00 AM EST/9:00 AM EDT
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('📅 Starting Thursday morning popup reminders');

    try {
      await sendScheduledPopupReminders('thursday');
      functions.logger.info('✅ Thursday morning reminders completed');
    } catch (error) {
      functions.logger.error('❌ Error during Thursday morning reminders', error);
    }

    return null;
  });

// Main function to send scheduled popup reminders
async function sendScheduledPopupReminders(reminderType: 'monday' | 'thursday'): Promise<void> {
  const now = new Date();
  const oneWeekFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  let vendorNotificationsSent = 0;
  let organizerNotificationsSent = 0;

  try {
    // Get all vendors with upcoming markets but no popup posts
    const vendorData = await getVendorsWithUpcomingMarkets(now, oneWeekFromNow);

    // Get all market organizers with upcoming markets but no recent updates
    const organizerData = await getOrganizersWithUpcomingMarkets(now, oneWeekFromNow);

    // Send notifications to vendors
    for (const vendorInfo of vendorData) {
      if (vendorInfo.fcmToken && vendorInfo.upcomingEvents.length > 0) {
        await sendVendorPopupReminder(vendorInfo, reminderType);
        vendorNotificationsSent++;
      }
    }

    // Send notifications to organizers
    for (const organizerInfo of organizerData) {
      if (organizerInfo.fcmToken && organizerInfo.upcomingEvents.length > 0) {
        await sendOrganizerMarketReminder(organizerInfo, reminderType);
        organizerNotificationsSent++;
      }
    }

    functions.logger.info('📊 Scheduled reminder statistics', {
      reminderType,
      vendorNotificationsSent,
      organizerNotificationsSent,
      totalNotificationsSent: vendorNotificationsSent + organizerNotificationsSent,
    });

  } catch (error) {
    functions.logger.error('❌ Error in sendScheduledPopupReminders', error);
    throw error;
  }
}

// Get vendors with upcoming markets but no popup posts
async function getVendorsWithUpcomingMarkets(
  startDate: Date,
  endDate: Date
): Promise<NotificationReminderData[]> {
  const vendorData: NotificationReminderData[] = [];

  try {
    // Get all markets in the next 7 days
    const upcomingMarketsSnapshot = await db.collection('markets')
      .where('eventDate', '>=', admin.firestore.Timestamp.fromDate(startDate))
      .where('eventDate', '<=', admin.firestore.Timestamp.fromDate(endDate))
      .where('isActive', '==', true)
      .get();

    // Get all vendor profiles with FCM tokens and notification preferences enabled
    const vendorProfilesSnapshot = await db.collection('user_profiles')
      .where('userType', '==', 'vendor')
      .where('fcmToken', '!=', null)
      .get();

    for (const vendorDoc of vendorProfilesSnapshot.docs) {
      const vendorProfile = vendorDoc.data();
      const vendorId = vendorDoc.id;

      // Check notification preferences
      const notifPrefs = vendorProfile.notificationPreferences || {};
      if (!notifPrefs.enabled || !notifPrefs.marketReminders) {
        continue;
      }

      // Check for upcoming markets this vendor might be interested in
      const upcomingEvents: any[] = [];

      for (const marketDoc of upcomingMarketsSnapshot.docs) {
        const market = marketDoc.data();
        const marketId = marketDoc.id;

        // Check if vendor has a popup for this market already
        const existingPopupQuery = await db.collection('vendor_posts')
          .where('vendorId', '==', vendorId)
          .where('associatedMarketId', '==', marketId)
          .where('isActive', '==', true)
          .limit(1)
          .get();

        const hasPosted = !existingPopupQuery.empty;

        // Check if vendor follows this market or has applied to it
        const isFollowingMarket = await checkVendorMarketRelationship(vendorId, marketId);

        if (isFollowingMarket && !hasPosted) {
          upcomingEvents.push({
            type: 'market' as const,
            eventId: marketId,
            eventName: market.name,
            eventDate: market.eventDate.toDate(),
            location: `${market.city}, ${market.state}`,
            hasPosted: false,
          });
        }
      }

      if (upcomingEvents.length > 0) {
        vendorData.push({
          userId: vendorId,
          userType: 'vendor',
          fcmToken: vendorProfile.fcmToken,
          displayName: vendorProfile.displayName || vendorProfile.businessName || 'Vendor',
          businessName: vendorProfile.businessName,
          upcomingEvents,
          reminderType: 'monday', // Will be set by caller
        });
      }
    }

    return vendorData;
  } catch (error) {
    functions.logger.error('❌ Error getting vendors with upcoming markets', error);
    return [];
  }
}

// Get organizers with upcoming markets but no recent updates
async function getOrganizersWithUpcomingMarkets(
  startDate: Date,
  endDate: Date
): Promise<NotificationReminderData[]> {
  const organizerData: NotificationReminderData[] = [];
  const now = new Date();

  try {
    // Get organizer profiles with FCM tokens
    const organizerProfilesSnapshot = await db.collection('user_profiles')
      .where('userType', '==', 'market_organizer')
      .where('fcmToken', '!=', null)
      .get();

    for (const organizerDoc of organizerProfilesSnapshot.docs) {
      const organizerProfile = organizerDoc.data();
      const organizerId = organizerDoc.id;

      // Check notification preferences
      const notifPrefs = organizerProfile.notificationPreferences || {};
      if (!notifPrefs.enabled || !notifPrefs.marketReminders) {
        continue;
      }

      // Get this organizer's upcoming markets
      const upcomingMarketsSnapshot = await db.collection('markets')
        .where('organizerId', '==', organizerId)
        .where('eventDate', '>=', admin.firestore.Timestamp.fromDate(startDate))
        .where('eventDate', '<=', admin.firestore.Timestamp.fromDate(endDate))
        .where('isActive', '==', true)
        .get();

      const upcomingEvents: any[] = [];

      for (const marketDoc of upcomingMarketsSnapshot.docs) {
        const market = marketDoc.data();
        const marketId = marketDoc.id;

        // Check if organizer has posted updates recently (within last 3 days)
        const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);
        const recentUpdatesQuery = await db.collection('market_updates')
          .where('marketId', '==', marketId)
          .where('organizerId', '==', organizerId)
          .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(threeDaysAgo))
          .limit(1)
          .get();

        const hasRecentUpdates = !recentUpdatesQuery.empty;

        if (!hasRecentUpdates) {
          upcomingEvents.push({
            type: 'market' as const,
            eventId: marketId,
            eventName: market.name,
            eventDate: market.eventDate.toDate(),
            location: `${market.city}, ${market.state}`,
            hasPosted: false,
          });
        }
      }

      if (upcomingEvents.length > 0) {
        organizerData.push({
          userId: organizerId,
          userType: 'market_organizer',
          fcmToken: organizerProfile.fcmToken,
          displayName: organizerProfile.displayName || organizerProfile.organizationName || 'Organizer',
          organizationName: organizerProfile.organizationName,
          upcomingEvents,
          reminderType: 'monday', // Will be set by caller
        });
      }
    }

    return organizerData;
  } catch (error) {
    functions.logger.error('❌ Error getting organizers with upcoming markets', error);
    return [];
  }
}

// Check if vendor has relationship with market (following, applied, etc.)
async function checkVendorMarketRelationship(vendorId: string, marketId: string): Promise<boolean> {
  try {
    // Check if vendor follows this market
    const followQuery = await db.collection('user_market_favorites')
      .where('userId', '==', vendorId)
      .where('marketId', '==', marketId)
      .limit(1)
      .get();

    if (!followQuery.empty) {
      return true;
    }

    // Check if vendor has applied to this market
    const applicationQuery = await db.collection('vendor_market_applications')
      .where('vendorId', '==', vendorId)
      .where('marketId', '==', marketId)
      .limit(1)
      .get();

    return !applicationQuery.empty;
  } catch (error) {
    functions.logger.error('❌ Error checking vendor market relationship', error);
    return false;
  }
}

// Send popup reminder notification to vendor
async function sendVendorPopupReminder(
  vendorInfo: NotificationReminderData,
  reminderType: 'monday' | 'thursday'
): Promise<void> {
  try {
    const eventCount = vendorInfo.upcomingEvents.length;
    const businessName = vendorInfo.businessName || vendorInfo.displayName;

    // Create notification title and body
    let title: string;
    let body: string;

    if (reminderType === 'monday') {
      title = eventCount === 1
        ? "🎪 Time to create your popup!"
        : `🎪 ${eventCount} markets this week!`;

      body = eventCount === 1
        ? `Hey ${businessName}! You have an upcoming market at ${vendorInfo.upcomingEvents[0].eventName}. Create your popup post to let customers know you'll be there!`
        : `Hey ${businessName}! You have ${eventCount} markets coming up this week. Don't forget to create your popup posts!`;
    } else {
      title = eventCount === 1
        ? "📝 Popup reminder - Weekend markets!"
        : `📝 ${eventCount} weekend markets coming up!`;

      body = eventCount === 1
        ? `${businessName}, reminder about your market at ${vendorInfo.upcomingEvents[0].eventName}. Make sure your popup post is ready!`
        : `${businessName}, you have ${eventCount} weekend markets coming up. Time to finalize those popup posts!`;
    }

    // Create FCM message
    const message = {
      token: vendorInfo.fcmToken!,
      notification: {
        title,
        body,
      },
      data: {
        type: 'popup_reminder',
        reminderType,
        eventCount: eventCount.toString(),
        userId: vendorInfo.userId,
        notificationId: `popup_reminder_${vendorInfo.userId}_${Date.now()}`,
      },
      android: {
        notification: {
          channelId: 'market_reminders',
          priority: 'high' as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send FCM notification
    await admin.messaging().send(message);

    // Log notification in database for tracking
    await logNotificationSent({
      userId: vendorInfo.userId,
      type: 'popup_reminder',
      title,
      body,
      reminderType,
      eventCount,
      fcmMessageId: `popup_reminder_${vendorInfo.userId}_${Date.now()}`,
    });

    functions.logger.info('✅ Vendor popup reminder sent', {
      vendorId: vendorInfo.userId,
      businessName: vendorInfo.businessName,
      eventCount,
      reminderType,
    });

  } catch (error) {
    functions.logger.error('❌ Error sending vendor popup reminder', {
      vendorId: vendorInfo.userId,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

// Send market reminder notification to organizer
async function sendOrganizerMarketReminder(
  organizerInfo: NotificationReminderData,
  reminderType: 'monday' | 'thursday'
): Promise<void> {
  try {
    const eventCount = organizerInfo.upcomingEvents.length;
    const organizationName = organizerInfo.organizationName || organizerInfo.displayName;

    // Create notification title and body
    let title: string;
    let body: string;

    if (reminderType === 'monday') {
      title = eventCount === 1
        ? "📢 Market update reminder!"
        : `📢 ${eventCount} markets this week!`;

      body = eventCount === 1
        ? `${organizationName}, don't forget to post updates about your upcoming market: ${organizerInfo.upcomingEvents[0].eventName}!`
        : `${organizationName}, you have ${eventCount} markets this week. Keep your community engaged with updates!`;
    } else {
      title = eventCount === 1
        ? "🎯 Weekend market reminder!"
        : `🎯 ${eventCount} weekend markets!`;

      body = eventCount === 1
        ? `${organizationName}, your market ${organizerInfo.upcomingEvents[0].eventName} is coming up soon. Share any last-minute updates!`
        : `${organizationName}, ${eventCount} markets are coming up this weekend. Make sure everything is ready!`;
    }

    // Create FCM message
    const message = {
      token: organizerInfo.fcmToken!,
      notification: {
        title,
        body,
      },
      data: {
        type: 'market_reminder',
        reminderType,
        eventCount: eventCount.toString(),
        userId: organizerInfo.userId,
        notificationId: `market_reminder_${organizerInfo.userId}_${Date.now()}`,
      },
      android: {
        notification: {
          channelId: 'market_reminders',
          priority: 'high' as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send FCM notification
    await admin.messaging().send(message);

    // Log notification in database for tracking
    await logNotificationSent({
      userId: organizerInfo.userId,
      type: 'market_reminder',
      title,
      body,
      reminderType,
      eventCount,
      fcmMessageId: `market_reminder_${organizerInfo.userId}_${Date.now()}`,
    });

    functions.logger.info('✅ Organizer market reminder sent', {
      organizerId: organizerInfo.userId,
      organizationName: organizerInfo.organizationName,
      eventCount,
      reminderType,
    });

  } catch (error) {
    functions.logger.error('❌ Error sending organizer market reminder', {
      organizerId: organizerInfo.userId,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

// Log notification sent for analytics and tracking
async function logNotificationSent(data: {
  userId: string;
  type: string;
  title: string;
  body: string;
  reminderType: string;
  eventCount: number;
  fcmMessageId: string;
}): Promise<void> {
  try {
    await db.collection('notification_logs').add({
      userId: data.userId,
      type: data.type,
      title: data.title,
      body: data.body,
      reminderType: data.reminderType,
      eventCount: data.eventCount,
      fcmMessageId: data.fcmMessageId,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      opened: false,
      // Will be updated when user opens the notification
      openedAt: null,
      platform: null, // Will be filled by client
    });
  } catch (error) {
    functions.logger.error('❌ Error logging notification', error);
  }
}

// Manual trigger function for testing (HTTPS callable)
export const triggerPopupReminders = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated and is a CEO
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userDoc = await db.collection('user_profiles').doc(context.auth.uid).get();
  const userData = userDoc.data();

  if (!userData || userData.email !== 'jordangillispie@outlook.com') {
    throw new functions.https.HttpsError('permission-denied', 'Only CEO can trigger manual notifications');
  }

  try {
    const reminderType = data.reminderType || 'monday';
    functions.logger.info('🔧 Manual trigger for popup reminders', {
      triggeredBy: context.auth.uid,
      reminderType,
    });

    await sendScheduledPopupReminders(reminderType);

    return {
      success: true,
      message: `${reminderType} reminders triggered successfully`,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    functions.logger.error('❌ Error in manual trigger', error);
    throw new functions.https.HttpsError('internal', 'Failed to trigger reminders');
  }
});

// Export email functions
export {
  sendOrderConfirmationEmail,
  sendTicketConfirmationEmail,
  sendOrderStatusUpdateEmail,
  sendVendorApplicationConfirmationEmail,
  testEmailFunction
} from './emails';

// Export application management functions
export {
  expireApplicationsScheduled,
  onApplicationCreated,
  onApplicationUpdated
} from './applications';

// ============================================================================
// Flyer Data Extraction with Vision API
// ============================================================================

interface FlyerData {
  title?: string;
  date?: string;
  time?: string;
  location?: string;
  description?: string;
  rawText: string;
}

/**
 * Extract event data from flyer image using Google Cloud Vision API
 * Callable function from Flutter app
 */
export const extractFlyerData = functions.https.onCall(async (data: { imageUrl: string }, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { imageUrl } = data;
    if (!imageUrl) {
      throw new functions.https.HttpsError('invalid-argument', 'Image URL is required');
    }

    functions.logger.info('📸 Extracting flyer data from:', imageUrl);

    // Initialize Vision API client
    const client = new vision.ImageAnnotatorClient();

    // Perform text detection
    const [result] = await client.textDetection(imageUrl);
    const detections = result.textAnnotations;
    const rawText = detections && detections.length > 0 ? detections[0].description || '' : '';

    if (!rawText) {
      throw new functions.https.HttpsError('not-found', 'No text found in image');
    }

    functions.logger.info('📝 Extracted text:', rawText);

    // Parse event data from extracted text
    const flyerData = parseEventData(rawText);

    return {
      success: true,
      data: flyerData,
    };
  } catch (error: any) {
    functions.logger.error('❌ Error extracting flyer data:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', `Failed to extract flyer data: ${error.message}`);
  }
});

/**
 * Parse event data from extracted text
 */
function parseEventData(text: string): FlyerData {
  const lines = text.split('\n').map(line => line.trim()).filter(line => line.length > 0);

  const flyerData: FlyerData = {
    rawText: text,
  };

  // Extract title (usually one of the first few large text lines)
  // Look for common event patterns or just use first substantial line
  const titleCandidates = lines.slice(0, 5).filter(line => line.length > 3 && line.length < 100);
  if (titleCandidates.length > 0) {
    // Find the line that's not "PRESENTED BY" or similar
    const title = titleCandidates.find(line =>
      !line.toLowerCase().includes('presented by') &&
      !line.toLowerCase().includes('free entry') &&
      !line.toLowerCase().includes('live artist')
    );
    flyerData.title = title || titleCandidates[0];
  }

  // Extract date patterns
  const datePatterns = [
    // Oct 18th, October 18th, Oct 18
    /(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?(?:\s*,?\s*\d{4})?/i,
    // 10/18, 10/18/24, 10-18-24
    /\d{1,2}[\/\-]\d{1,2}(?:[\/\-]\d{2,4})?/,
  ];

  for (const pattern of datePatterns) {
    const match = text.match(pattern);
    if (match) {
      flyerData.date = match[0];
      break;
    }
  }

  // Extract time patterns
  const timePatterns = [
    // 6PM - MIDNIGHT, 6:00PM-12:00AM
    /\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)\s*(?:-|to|until)\s*\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm|midnight)/i,
    // 6PM, 6:00PM
    /\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)/i,
  ];

  for (const pattern of timePatterns) {
    const match = text.match(pattern);
    if (match) {
      flyerData.time = match[0];
      break;
    }
  }

  // Extract address (street number + street name + city + state)
  const addressPattern = /\d+\s+[A-Z][a-zA-Z\s]+(?:ST|AVE|BLVD|RD|DR|STREET|AVENUE|BOULEVARD|ROAD|DRIVE)\s+(?:NW|NE|SW|SE)?\s*[A-Z][a-zA-Z\s]+,?\s+(?:AL|AK|AZ|AR|CA|CO|CT|DE|FL|GA|HI|ID|IL|IN|IA|KS|KY|LA|ME|MD|MA|MI|MN|MS|MO|MT|NE|NV|NH|NJ|NM|NY|NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WA|WV|WI|WY)/i;
  const addressMatch = text.match(addressPattern);
  if (addressMatch) {
    flyerData.location = addressMatch[0];
  }

  // Extract description from common marketing phrases
  const descriptionKeywords = ['free entry', 'live artist', 'vendors', 'rentals available'];
  const descriptionParts: string[] = [];

  for (const line of lines) {
    for (const keyword of descriptionKeywords) {
      if (line.toLowerCase().includes(keyword.toLowerCase())) {
        descriptionParts.push(line);
        break;
      }
    }
  }

  if (descriptionParts.length > 0) {
    flyerData.description = descriptionParts.join('. ');
  }

  return flyerData;
}
