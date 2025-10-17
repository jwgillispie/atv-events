#!/bin/bash

echo "🔒 Restoring secure Firestore rules..."

# Check if backup exists
if [ -f "firestore.rules.backup_before_delete" ]; then
    echo "📋 Found backup file: firestore.rules.backup_before_delete"
    cp firestore.rules.backup_before_delete firestore.rules
    echo "✅ Rules restored from backup"
else
    echo "⚠️  No backup found, restoring from standard backup"
    if [ -f "firestore.rules.backup" ]; then
        cp firestore.rules.backup firestore.rules
        echo "✅ Rules restored from standard backup"
    else
        echo "❌ No backup files found!"
        echo "⚠️  Please manually restore your rules!"
        exit 1
    fi
fi

echo "🚀 Deploying secure rules to Firebase..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ Secure rules successfully deployed!"
    echo "🔒 Your Firestore is now protected again."
else
    echo "❌ Failed to deploy rules. Please check manually!"
    exit 1
fi