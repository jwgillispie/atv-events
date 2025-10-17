#!/bin/bash

# Firebase Rules Switcher Script
# Usage: ./switch_firebase_rules.sh [debug|production]

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [debug|production]"
    echo "  debug      - Switch to permissive debug rules (allows database cleaner)"
    echo "  production - Switch to secure production rules"
    exit 1
fi

MODE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔄 Switching Firebase rules to $MODE mode..."

case $MODE in
    debug)
        echo "⚠️  WARNING: Enabling DEBUG rules - very permissive!"
        echo "   These rules allow the debug database cleaner to work"
        echo "   NEVER use these rules in production!"
        
        # Copy debug rules to main rules file
        cp "$PROJECT_ROOT/Firestore.rules.debug" "$PROJECT_ROOT/Firestore.rules"
        
        # Deploy to Firebase
        cd "$PROJECT_ROOT"
        firebase deploy --only firestore:rules
        
        echo "✅ Debug rules deployed successfully!"
        echo "🗑️  You can now use the debug database cleaner"
        ;;
    production)
        echo "🔒 Switching to production rules..."
        
        # Copy production rules to main rules file
        cp "$PROJECT_ROOT/Firestore.rules.backup" "$PROJECT_ROOT/Firestore.rules"
        
        # Deploy to Firebase
        cd "$PROJECT_ROOT"
        firebase deploy --only firestore:rules
        
        echo "✅ Production rules deployed successfully!"
        echo "🔒 Database is now secured with proper rules"
        ;;
    *)
        echo "❌ Invalid mode: $MODE"
        echo "   Valid options: debug, production"
        exit 1
        ;;
esac

echo ""
echo "📊 Current rules status:"
echo "   Rules file: $PROJECT_ROOT/Firestore.rules"
echo "   Mode: $MODE"
echo "   Project: hipop-markets"
echo ""
echo "🔗 Firebase Console: https://console.firebase.google.com/project/hipop-markets/firestore/rules"