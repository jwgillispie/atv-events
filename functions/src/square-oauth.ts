import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import fetch from 'node-fetch';

/**
 * Square OAuth Integration
 * Handles OAuth token exchange and refresh for vendor Square accounts
 */

interface SquareTokenResponse {
  access_token: string;
  token_type: string;
  expires_at: string;
  merchant_id: string;
  refresh_token?: string;
  id_token?: string;
}

/**
 * Exchange Square OAuth authorization code for access token
 * Called from Flutter app after vendor authorizes in Square
 */
export const exchangeSquareToken = functions.https.onCall(async (data, context) => {
  console.log('🟦 [Square OAuth] Token exchange request received');

  // Verify authentication
  if (!context.auth) {
    console.error('❌ [Square OAuth] Unauthenticated request');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { code, state } = data;

  console.log(`🟦 [Square OAuth] User: ${userId}`);
  console.log(`🟦 [Square OAuth] Authorization code received: ${code?.substring(0, 10)}...`);

  // Validate required parameters
  if (!code) {
    console.error('❌ [Square OAuth] Missing authorization code');
    throw new functions.https.HttpsError('invalid-argument', 'Authorization code is required');
  }

  try {
    // Get Square credentials from Firebase config
    const squareConfig = functions.config().square;
    if (!squareConfig?.app_id || !squareConfig?.app_secret) {
      console.error('❌ [Square OAuth] Square credentials not configured');
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Square integration not configured. Please contact support.'
      );
    }

    console.log('🟦 [Square OAuth] Exchanging code for access token...');

    // Exchange authorization code for access token
    const tokenResponse = await fetch('https://connect.squareup.com/oauth2/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Square-Version': '2024-10-17',
      },
      body: JSON.stringify({
        client_id: squareConfig.app_id,
        client_secret: squareConfig.app_secret,
        code: code,
        grant_type: 'authorization_code',
      }),
    });

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      console.error('❌ [Square OAuth] Token exchange failed:', errorText);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to exchange authorization code: ${errorText}`
      );
    }

    const tokens: SquareTokenResponse = await tokenResponse.json() as SquareTokenResponse;
    console.log('✅ [Square OAuth] Token exchange successful');
    console.log(`🟦 [Square OAuth] Merchant ID: ${tokens.merchant_id}`);

    // Fetch merchant profile for additional details
    let merchantProfile: any = null;
    try {
      console.log('🟦 [Square OAuth] Fetching merchant profile...');
      const merchantResponse = await fetch('https://connect.squareup.com/v2/merchants', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${tokens.access_token}`,
          'Square-Version': '2024-10-17',
        },
      });

      if (merchantResponse.ok) {
        const merchantData: any = await merchantResponse.json();
        merchantProfile = merchantData.merchant;
        console.log(`✅ [Square OAuth] Merchant profile fetched: ${merchantProfile?.business_name}`);
      }
    } catch (error) {
      console.warn('⚠️ [Square OAuth] Could not fetch merchant profile:', error);
    }

    // Calculate token expiration timestamp
    const expiresAt = new Date(tokens.expires_at).getTime();
    const now = Date.now();
    const expiresInHours = Math.round((expiresAt - now) / (1000 * 60 * 60));

    console.log(`🟦 [Square OAuth] Token expires in ${expiresInHours} hours`);

    // Store Square integration data in Firestore
    const integrationData = {
      square: {
        merchantId: tokens.merchant_id,
        accessToken: tokens.access_token,
        refreshToken: tokens.refresh_token || null,
        expiresAt: expiresAt,
        connectedAt: admin.firestore.FieldValue.serverTimestamp(),
        businessName: merchantProfile?.business_name || null,
        country: merchantProfile?.country || null,
        currency: merchantProfile?.currency || null,
        status: merchantProfile?.status || 'ACTIVE',
      },
    };

    console.log('🟦 [Square OAuth] Storing integration data in Firestore...');

    await admin.firestore()
      .collection('vendor_integrations')
      .doc(userId)
      .set(integrationData, { merge: true });

    console.log('✅ [Square OAuth] Integration data stored successfully');

    // Return success response to Flutter app
    return {
      success: true,
      merchantId: tokens.merchant_id,
      businessName: merchantProfile?.business_name || null,
      expiresAt: expiresAt,
    };

  } catch (error: any) {
    console.error('❌ [Square OAuth] Error during token exchange:', error);

    // Re-throw Firebase errors as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Wrap other errors
    throw new functions.https.HttpsError(
      'internal',
      `Failed to connect Square account: ${error.message}`
    );
  }
});

/**
 * Refresh Square access token before expiration
 * Runs automatically via Cloud Scheduler
 */
export const refreshSquareTokens = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    console.log('🟦 [Square Token Refresh] Starting scheduled token refresh...');

    try {
      // Find all Square integrations expiring within 7 days
      const sevenDaysFromNow = Date.now() + (7 * 24 * 60 * 60 * 1000);

      const expiringSoonSnapshot = await admin.firestore()
        .collection('vendor_integrations')
        .where('square.expiresAt', '<', sevenDaysFromNow)
        .where('square.refreshToken', '!=', null)
        .get();

      console.log(`🟦 [Square Token Refresh] Found ${expiringSoonSnapshot.size} tokens to refresh`);

      if (expiringSoonSnapshot.empty) {
        console.log('✅ [Square Token Refresh] No tokens need refreshing');
        return null;
      }

      const squareConfig = functions.config().square;
      let successCount = 0;
      let failureCount = 0;

      // Refresh each token
      for (const doc of expiringSoonSnapshot.docs) {
        const vendorId = doc.id;
        const data = doc.data();
        const refreshToken = data.square?.refreshToken;

        if (!refreshToken) {
          console.warn(`⚠️ [Square Token Refresh] No refresh token for vendor ${vendorId}`);
          continue;
        }

        try {
          console.log(`🟦 [Square Token Refresh] Refreshing token for vendor ${vendorId}...`);

          const tokenResponse = await fetch('https://connect.squareup.com/oauth2/token', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Square-Version': '2024-10-17',
            },
            body: JSON.stringify({
              client_id: squareConfig.app_id,
              client_secret: squareConfig.app_secret,
              refresh_token: refreshToken,
              grant_type: 'refresh_token',
            }),
          });

          if (!tokenResponse.ok) {
            const errorText = await tokenResponse.text();
            console.error(`❌ [Square Token Refresh] Failed for vendor ${vendorId}:`, errorText);
            failureCount++;
            continue;
          }

          const newTokens: SquareTokenResponse = await tokenResponse.json() as SquareTokenResponse;
          const newExpiresAt = new Date(newTokens.expires_at).getTime();

          // Update with new tokens
          await doc.ref.update({
            'square.accessToken': newTokens.access_token,
            'square.expiresAt': newExpiresAt,
            'square.lastRefreshed': admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`✅ [Square Token Refresh] Token refreshed for vendor ${vendorId}`);
          successCount++;

        } catch (error) {
          console.error(`❌ [Square Token Refresh] Error refreshing token for vendor ${vendorId}:`, error);
          failureCount++;
        }
      }

      console.log(`✅ [Square Token Refresh] Complete: ${successCount} succeeded, ${failureCount} failed`);
      return null;

    } catch (error) {
      console.error('❌ [Square Token Refresh] Scheduled refresh failed:', error);
      return null;
    }
  });

/**
 * Disconnect Square integration
 * Revokes access token and removes stored data
 */
export const disconnectSquare = functions.https.onCall(async (data, context) => {
  console.log('🟦 [Square Disconnect] Disconnect request received');

  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  try {
    // Get current integration data
    const integrationDoc = await admin.firestore()
      .collection('vendor_integrations')
      .doc(userId)
      .get();

    if (!integrationDoc.exists) {
      console.log(`⚠️ [Square Disconnect] No integration found for user ${userId}`);
      return { success: true, message: 'No Square integration to disconnect' };
    }

    const data = integrationDoc.data();
    const accessToken = data?.square?.accessToken;

    // Revoke the access token with Square (optional but recommended)
    if (accessToken) {
      const squareConfig = functions.config().square;

      try {
        console.log('🟦 [Square Disconnect] Revoking access token with Square...');
        await fetch('https://connect.squareup.com/oauth2/revoke', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Square-Version': '2024-10-17',
          },
          body: JSON.stringify({
            client_id: squareConfig.app_id,
            access_token: accessToken,
          }),
        });
        console.log('✅ [Square Disconnect] Access token revoked with Square');
      } catch (error) {
        console.warn('⚠️ [Square Disconnect] Could not revoke token with Square:', error);
      }
    }

    // Remove Square data from Firestore
    await integrationDoc.ref.update({
      square: admin.firestore.FieldValue.delete(),
    });

    console.log(`✅ [Square Disconnect] Integration removed for user ${userId}`);

    return {
      success: true,
      message: 'Square account disconnected successfully',
    };

  } catch (error: any) {
    console.error('❌ [Square Disconnect] Error:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to disconnect Square: ${error.message}`
    );
  }
});
