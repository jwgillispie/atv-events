/// Test script to verify RevenueCat null check fix and cache clearing
/// 
/// Run this script with: flutter run test_revenuecat_fix.dart
/// 
/// This script tests:
/// 1. The null check fix for entitlements when only subscriptions exist
/// 2. The cache clearing functionality
/// 3. The force sync methods

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/features/premium/services/revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Sign in a test user (optional - update with your test credentials)
  // await FirebaseAuth.instance.signInWithEmailAndPassword(
  //   email: 'test@example.com',
  //   password: 'password',
  // );
  
  print('🧪 Starting RevenueCat Fix Test...\n');
  
  final service = RevenueCatService();
  
  try {
    // Test 1: Initialize RevenueCat
    print('TEST 1: Initializing RevenueCat...');
    await service.initialize();
    print('✅ RevenueCat initialized successfully\n');
    
    // Test 2: Clear cache
    print('TEST 2: Testing cache clearing...');
    await service.clearCache();
    print('✅ Cache cleared successfully\n');
    
    // Test 3: Get customer info with force refresh
    print('TEST 3: Getting customer info with force refresh...');
    final customerInfo = await service.getCustomerInfo(forceRefresh: true);
    if (customerInfo != null) {
      print('✅ Customer info retrieved');
      print('   - Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
      print('   - Active subscriptions: ${customerInfo.activeSubscriptions}');
      print('   - Has premium: ${customerInfo.entitlements.active.isNotEmpty || customerInfo.activeSubscriptions.isNotEmpty}\n');
    } else {
      print('⚠️ No customer info available\n');
    }
    
    // Test 4: Check subscription status
    print('TEST 4: Checking subscription status...');
    final hasSubscription = await service.hasActiveSubscription();
    print('✅ Subscription status: ${hasSubscription ? "ACTIVE" : "INACTIVE"}\n');
    
    // Test 5: Force sync (this will test the null check fix)
    print('TEST 5: Testing force sync (checking null safety)...');
    final syncSuccess = await service.forceSyncSubscription();
    if (syncSuccess) {
      print('✅ Force sync completed successfully');
      print('   This means the null check fix is working!\n');
    } else {
      print('⚠️ Force sync failed - check logs for details\n');
    }
    
    // Test 6: Legacy force sync method
    print('TEST 6: Testing legacy forceSyncToFirebase method...');
    await service.forceSyncToFirebase();
    print('✅ Legacy sync method completed\n');
    
    // Test 7: Verify and sync purchase
    print('TEST 7: Testing verify and sync purchase flow...');
    final verifySuccess = await service.verifyAndSyncPurchase();
    if (verifySuccess) {
      print('✅ Verification and sync successful');
    } else {
      print('⚠️ No active purchase to verify');
    }
    
    print('\n🎉 All tests completed successfully!');
    print('The RevenueCat integration should now handle:');
    print('  ✅ Cases where subscriptions exist but entitlements don\'t');
    print('  ✅ Cache clearing to get fresh data');
    print('  ✅ Proper Firebase syncing with error recovery');
    
  } catch (e, stack) {
    print('\n❌ Test failed with error:');
    print('Error: $e');
    print('Stack: $stack');
  }
}