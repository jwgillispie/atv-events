#!/bin/bash

# Test Stripe Webhook Script
# This sends a test checkout.session.completed event to your webhook

WEBHOOK_URL="https://us-central1-hipop-markets-staging.cloudfunctions.net/stripeWebhook"
WEBHOOK_SECRET="whsec_bykZlcXMbIcfjWoBDe829HjruXEym99o"

# Create a test payload
TIMESTAMP=$(date +%s)
PAYLOAD='{
  "id": "evt_test_webhook_'$TIMESTAMP'",
  "object": "event",
  "api_version": "2023-10-16",
  "created": '$TIMESTAMP',
  "data": {
    "object": {
      "id": "cs_test_'$TIMESTAMP'",
      "object": "checkout.session",
      "amount_total": 1999,
      "currency": "usd",
      "customer": "cus_test_'$TIMESTAMP'",
      "customer_email": "test@example.com",
      "livemode": true,
      "metadata": {
        "userId": "test_user_'$TIMESTAMP'",
        "userType": "vendor"
      },
      "mode": "subscription",
      "payment_status": "paid",
      "status": "complete",
      "success_url": "https://hipop.app/success",
      "subscription": "sub_test_'$TIMESTAMP'"
    }
  },
  "livemode": true,
  "pending_webhooks": 1,
  "request": {
    "id": null,
    "idempotency_key": null
  },
  "type": "checkout.session.completed"
}'

# Generate signature (this is a simplified version for testing)
# In production, Stripe generates this using HMAC-SHA256
SIGNATURE="t=$TIMESTAMP,v1=test_signature,v0=test_signature"

echo "Sending test webhook to: $WEBHOOK_URL"
echo "Event type: checkout.session.completed"
echo "Test user ID: test_user_$TIMESTAMP"
echo "---"

# Send the webhook
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: $SIGNATURE" \
  -d "$PAYLOAD" \
  -w "\nHTTP Status: %{http_code}\n"

echo "---"
echo "Check Firebase Functions logs:"
echo "firebase functions:log --project hipop-markets-staging"