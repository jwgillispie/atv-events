#!/bin/bash

echo "Reverting to staging configuration..."

# Restore staging config files from backup
cp .backup_staging_config/GoogleService-Info.plist.staging ios/Runner/GoogleService-Info.plist
cp .backup_staging_config/Info.plist.staging ios/Runner/Info.plist
cp .backup_staging_config/project.pbxproj.staging ios/Runner.xcodeproj/project.pbxproj

echo "✅ Reverted to staging configuration"
echo ""
echo "Next steps:"
echo "1. Run: flutter clean"
echo "2. Run: flutter pub get"
echo "3. Build the app again"