import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

const stripe = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: '2024-04-10',
});

/**
 * Stripe Connect Express Integration
 * Handles vendor account creation, status checking, and management
 */

interface CreateConnectAccountData {
  email: string;
  businessType?: 'individual' | 'company';
}

interface AccountStatusResponse {
  connected: boolean;
  fullyVerified?: boolean;
  chargesEnabled?: boolean;
  payoutsEnabled?: boolean;
  detailsSubmitted?: boolean;
  currentRequirements?: string[];
  pendingVerification?: string[];
  businessName?: string;
  accountId?: string;
}

/**
 * Create Stripe Connect Express account for vendor
 * Called when vendor clicks "Connect Stripe" button in settings
 */
export const createStripeConnectAccount = functions.https.onCall(
  async (data: CreateConnectAccountData, context): Promise<{
    accountId: string;
    accountLink: string;
    isExisting: boolean;
  }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const vendorId = context.auth.uid;
    const { email, businessType = 'individual' } = data;

    try {
      console.log(`🟣 [Stripe Connect] Creating account for vendor ${vendorId}`);

      // Check if account already exists
      const integrationDoc = await admin.firestore()
        .collection('vendor_integrations')
        .doc(vendorId)
        .get();

      if (integrationDoc.exists && integrationDoc.data()?.stripe?.accountId) {
        // Return existing account link if setup incomplete
        const accountId = integrationDoc.data()!.stripe.accountId;
        console.log(`🟣 [Stripe Connect] Existing account found: ${accountId}`);

        const accountLink = await createAccountLink(accountId);

        return {
          accountId,
          accountLink: accountLink.url,
          isExisting: true,
        };
      }

      // Create new Express account
      console.log(`🟣 [Stripe Connect] Creating new Express account...`);
      const account = await stripe.accounts.create({
        type: 'express',
        country: 'US',
        email,
        business_type: businessType,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true }, // CRITICAL for receiving transfers
        },
        metadata: {
          vendorId,
          platform: 'hipop',
          createdAt: new Date().toISOString(),
        },
      });

      console.log(`🟣 [Stripe Connect] Account created: ${account.id}`);

      // Create account link for onboarding
      const accountLink = await createAccountLink(account.id);

      // Save to Firestore
      await admin.firestore()
        .collection('vendor_integrations')
        .doc(vendorId)
        .set({
          stripe: {
            accountId: account.id,
            status: 'onboarding_started',
            chargesEnabled: false,
            payoutsEnabled: false,
            detailsSubmitted: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        }, { merge: true });

      console.log(`✅ [Stripe Connect] Account setup initiated for ${vendorId}`);

      return {
        accountId: account.id,
        accountLink: accountLink.url,
        isExisting: false,
      };

    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error creating account:', error);
      console.error('❌ [Stripe Connect] Error type:', error.type);
      console.error('❌ [Stripe Connect] Error code:', error.code);
      console.error('❌ [Stripe Connect] Error message:', error.message);
      console.error('❌ [Stripe Connect] Error raw:', JSON.stringify(error.raw || error, null, 2));

      // Provide user-friendly error messages
      let userMessage = error.message;
      if (error.code === 'platform_not_enabled') {
        userMessage = 'Stripe Connect is not enabled on this account. Please contact support.';
      } else if (error.code === 'account_invalid') {
        userMessage = 'Unable to create Stripe account. Please check your Stripe Dashboard settings.';
      }

      throw new functions.https.HttpsError('internal', userMessage);
    }
  }
);

/**
 * Create AccountLink for onboarding/re-onboarding
 * Uses web redirect page that auto-opens the app via deep link
 */
async function createAccountLink(accountId: string): Promise<Stripe.AccountLink> {
  return await stripe.accountLinks.create({
    account: accountId,
    refresh_url: 'https://hipop-markets.web.app/stripe-redirect?role=vendor&status=refresh',
    return_url: 'https://hipop-markets.web.app/stripe-redirect?role=vendor&status=success',
    type: 'account_onboarding',
  });
}

/**
 * Check Stripe Connect account status
 * Used by widget to refresh verification progress
 */
export const checkStripeAccountStatus = functions.https.onCall(
  async (data, context): Promise<AccountStatusResponse> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const vendorId = context.auth.uid;

    try {
      const integrationDoc = await admin.firestore()
        .collection('vendor_integrations')
        .doc(vendorId)
        .get();

      if (!integrationDoc.exists || !integrationDoc.data()?.stripe?.accountId) {
        return { connected: false };
      }

      const accountId = integrationDoc.data()!.stripe.accountId;
      console.log(`🟣 [Stripe Connect] Checking status for account ${accountId}`);

      const account = await stripe.accounts.retrieve(accountId);

      // Determine if fully verified
      const isFullyVerified = account.charges_enabled && account.payouts_enabled;

      // Update Firestore with latest status
      await admin.firestore()
        .collection('vendor_integrations')
        .doc(vendorId)
        .update({
          'stripe.status': isFullyVerified ? 'active' : 'pending',
          'stripe.chargesEnabled': account.charges_enabled,
          'stripe.payoutsEnabled': account.payouts_enabled,
          'stripe.detailsSubmitted': account.details_submitted,
          'stripe.businessName': account.business_profile?.name || null,
          'stripe.currentRequirements': account.requirements?.currently_due || [],
          'stripe.lastChecked': admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`✅ [Stripe Connect] Status updated - Verified: ${isFullyVerified}`);

      return {
        connected: true,
        fullyVerified: isFullyVerified,
        chargesEnabled: account.charges_enabled,
        payoutsEnabled: account.payouts_enabled,
        detailsSubmitted: account.details_submitted,
        currentRequirements: account.requirements?.currently_due || [],
        pendingVerification: account.requirements?.pending_verification || [],
        businessName: account.business_profile?.name || undefined,
        accountId: account.id,
      };

    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error checking status:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

/**
 * Disconnect Stripe Connect account
 * Removes integration data from Firestore (does not delete Stripe account)
 */
export const disconnectStripeAccount = functions.https.onCall(
  async (data, context): Promise<{ success: boolean }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const vendorId = context.auth.uid;

    try {
      console.log(`🟣 [Stripe Connect] Disconnecting account for vendor ${vendorId}`);

      await admin.firestore()
        .collection('vendor_integrations')
        .doc(vendorId)
        .update({
          stripe: admin.firestore.FieldValue.delete(),
        });

      console.log(`✅ [Stripe Connect] Account disconnected for ${vendorId}`);

      return { success: true };
    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error disconnecting:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

/**
 * Get new account link (for re-onboarding)
 * Used when vendor needs to complete additional verification
 */
export const getStripeAccountLink = functions.https.onCall(
  async (data, context): Promise<{ accountLink: string }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const vendorId = context.auth.uid;

    try {
      const integrationDoc = await admin.firestore()
        .collection('vendor_integrations')
        .doc(vendorId)
        .get();

      if (!integrationDoc.exists || !integrationDoc.data()?.stripe?.accountId) {
        throw new functions.https.HttpsError('not-found', 'No Stripe account found');
      }

      const accountId = integrationDoc.data()!.stripe.accountId;
      const accountLink = await createAccountLink(accountId);

      return { accountLink: accountLink.url };

    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error creating account link:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

// ============================================================================
// ORGANIZER STRIPE CONNECT FUNCTIONS
// Mirror vendor implementation above for organizers to receive application payments
// ============================================================================

/**
 * Create AccountLink for organizer onboarding/re-onboarding
 * Uses web redirect page that auto-opens the app via deep link
 */
async function createOrganizerAccountLink(accountId: string): Promise<Stripe.AccountLink> {
  return await stripe.accountLinks.create({
    account: accountId,
    refresh_url: 'https://hipop-markets.web.app/stripe-redirect?role=organizer&status=refresh',
    return_url: 'https://hipop-markets.web.app/stripe-redirect?role=organizer&status=success',
    type: 'account_onboarding',
  });
}

/**
 * Create Stripe Connect Express account for organizer
 * Called when organizer clicks "Connect Stripe" button in settings
 */
export const createOrganizerStripeConnectAccount = functions.https.onCall(
  async (data: CreateConnectAccountData, context): Promise<{
    accountId: string;
    accountLink: string;
    isExisting: boolean;
  }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const organizerId = context.auth.uid;
    const { email, businessType = 'individual' } = data;

    try {
      console.log(`🟣 [Stripe Connect] Creating account for organizer ${organizerId}`);

      // Check if account already exists
      const integrationDoc = await admin.firestore()
        .collection('organizer_integrations')
        .doc(organizerId)
        .get();

      if (integrationDoc.exists && integrationDoc.data()?.stripe?.accountId) {
        // Return existing account link if setup incomplete
        const accountId = integrationDoc.data()!.stripe.accountId;
        console.log(`🟣 [Stripe Connect] Existing account found: ${accountId}`);

        const accountLink = await createOrganizerAccountLink(accountId);

        return {
          accountId,
          accountLink: accountLink.url,
          isExisting: true,
        };
      }

      // Create new Express account
      console.log(`🟣 [Stripe Connect] Creating new Express account...`);
      const account = await stripe.accounts.create({
        type: 'express',
        country: 'US',
        email,
        business_type: businessType,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true }, // CRITICAL for receiving transfers
        },
        metadata: {
          organizerId,
          platform: 'hipop',
          createdAt: new Date().toISOString(),
        },
      });

      console.log(`🟣 [Stripe Connect] Account created: ${account.id}`);

      // Create account link for onboarding
      const accountLink = await createOrganizerAccountLink(account.id);

      // Save to Firestore
      await admin.firestore()
        .collection('organizer_integrations')
        .doc(organizerId)
        .set({
          stripe: {
            accountId: account.id,
            status: 'onboarding_started',
            chargesEnabled: false,
            payoutsEnabled: false,
            detailsSubmitted: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        }, { merge: true });

      console.log(`✅ [Stripe Connect] Account setup initiated for organizer ${organizerId}`);

      return {
        accountId: account.id,
        accountLink: accountLink.url,
        isExisting: false,
      };

    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error creating organizer account:', error);
      console.error('❌ [Stripe Connect] Error type:', error.type);
      console.error('❌ [Stripe Connect] Error code:', error.code);
      console.error('❌ [Stripe Connect] Error message:', error.message);
      console.error('❌ [Stripe Connect] Error raw:', JSON.stringify(error.raw || error, null, 2));

      // Provide user-friendly error messages
      let userMessage = error.message;
      if (error.code === 'platform_not_enabled') {
        userMessage = 'Stripe Connect is not enabled on this account. Please contact support.';
      } else if (error.code === 'account_invalid') {
        userMessage = 'Unable to create Stripe account. Please check your Stripe Dashboard settings.';
      }

      throw new functions.https.HttpsError('internal', userMessage);
    }
  }
);

/**
 * Check Stripe Connect account status for organizer
 * Used by widget to refresh verification progress
 */
export const checkOrganizerStripeAccountStatus = functions.https.onCall(
  async (data, context): Promise<AccountStatusResponse> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const organizerId = context.auth.uid;

    try {
      const integrationDoc = await admin.firestore()
        .collection('organizer_integrations')
        .doc(organizerId)
        .get();

      if (!integrationDoc.exists || !integrationDoc.data()?.stripe?.accountId) {
        return { connected: false };
      }

      const accountId = integrationDoc.data()!.stripe.accountId;
      console.log(`🟣 [Stripe Connect] Checking status for organizer account ${accountId}`);

      const account = await stripe.accounts.retrieve(accountId);

      // Determine if fully verified
      const isFullyVerified = account.charges_enabled && account.payouts_enabled;

      // Update Firestore with latest status
      await admin.firestore()
        .collection('organizer_integrations')
        .doc(organizerId)
        .update({
          'stripe.status': isFullyVerified ? 'active' : 'pending',
          'stripe.chargesEnabled': account.charges_enabled,
          'stripe.payoutsEnabled': account.payouts_enabled,
          'stripe.detailsSubmitted': account.details_submitted,
          'stripe.businessName': account.business_profile?.name || null,
          'stripe.currentRequirements': account.requirements?.currently_due || [],
          'stripe.lastChecked': admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`✅ [Stripe Connect] Organizer status updated - Verified: ${isFullyVerified}`);

      return {
        connected: true,
        fullyVerified: isFullyVerified,
        chargesEnabled: account.charges_enabled,
        payoutsEnabled: account.payouts_enabled,
        detailsSubmitted: account.details_submitted,
        currentRequirements: account.requirements?.currently_due || [],
        pendingVerification: account.requirements?.pending_verification || [],
        businessName: account.business_profile?.name || undefined,
        accountId: account.id,
      };

    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error checking organizer status:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

/**
 * Disconnect Stripe Connect account for organizer
 * Removes integration data from Firestore (does not delete Stripe account)
 */
export const disconnectOrganizerStripeAccount = functions.https.onCall(
  async (data, context): Promise<{ success: boolean }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const organizerId = context.auth.uid;

    try {
      console.log(`🟣 [Stripe Connect] Disconnecting account for organizer ${organizerId}`);

      await admin.firestore()
        .collection('organizer_integrations')
        .doc(organizerId)
        .update({
          stripe: admin.firestore.FieldValue.delete(),
        });

      console.log(`✅ [Stripe Connect] Account disconnected for organizer ${organizerId}`);

      return { success: true };
    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error disconnecting organizer:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

/**
 * Get new account link for organizer (for re-onboarding)
 * Used when organizer needs to complete additional verification
 */
export const getOrganizerStripeAccountLink = functions.https.onCall(
  async (data, context): Promise<{ accountLink: string }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const organizerId = context.auth.uid;

    try {
      const integrationDoc = await admin.firestore()
        .collection('organizer_integrations')
        .doc(organizerId)
        .get();

      if (!integrationDoc.exists || !integrationDoc.data()?.stripe?.accountId) {
        throw new functions.https.HttpsError('not-found', 'No Stripe account found');
      }

      const accountId = integrationDoc.data()!.stripe.accountId;
      const accountLink = await createOrganizerAccountLink(accountId);

      return { accountLink: accountLink.url };

    } catch (error: any) {
      console.error('❌ [Stripe Connect] Error creating organizer account link:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);
