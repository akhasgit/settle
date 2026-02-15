import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserService() {
    // Configure Firestore settings for better connectivity
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      // Settings might already be configured, ignore error
      debugPrint('Firestore settings already configured or error: $e');
    }
  }

  /// Creates a new user document in Firestore with the specified fields
  /// The document ID will be the user's UID
  Future<void> createUserDocument({
    required String uid,
    required String email,
    String? name,
  }) async {
    try {
      debugPrint('Attempting to create user document for UID: $uid');
      final userDoc = _firestore.collection('users').doc(uid);

      // Create the user document with all required fields
      // Using set with merge: false to create new document or overwrite if exists
      debugPrint('Creating user document with data...');
      await userDoc.set({
        'uid': uid,
        'username': '', // null string as requested
        'name': name ?? '',
        'email': email,
        'dailyExpense': 0,
        'monthlyExpense': 0,
        'yearlyExpense': 0,
        'defaultCurrency': 'sgd',
        'dateCreated': FieldValue.serverTimestamp(),
        'isPremiumUser': false,
        'planDetail': 'free',
        'streakCount': 0,
        'daysMissed': 0,
      }, SetOptions(merge: false)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
            'Connection timeout. Please ensure:\n'
            '1. Firestore database is created in Firebase Console\n'
            '2. You have an active internet connection\n'
            '3. Firestore is enabled for your project',
          );
        },
      );
      
      debugPrint('User document created successfully for UID: $uid');
    } on TimeoutException catch (e) {
      debugPrint('Timeout creating user document: $e');
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('Firebase error creating user document: ${e.code} - ${e.message}');
      final errorMessage = e.code == 'unavailable' || e.code == 'unknown'
          ? 'Unable to connect to Firestore. Please ensure:\n'
            '1. Firestore database is created in Firebase Console (https://console.firebase.google.com/)\n'
            '2. You have an active internet connection\n'
            '3. Firestore is enabled for your project'
          : 'Failed to create user document: ${e.message ?? e.code}';
      throw errorMessage;
    } catch (e) {
      debugPrint('Unexpected error creating user document: $e');
      if (e.toString().contains('Unable to establish connection')) {
        throw 'Unable to connect to Firestore. Please ensure:\n'
            '1. Firestore database is created in Firebase Console\n'
            '2. You have an active internet connection\n'
            '3. Firestore is enabled for your project';
      }
      throw 'Failed to create user document: $e';
    }
  }

  /// Gets user document from Firestore
  Future<DocumentSnapshot> getUserDocument(String uid) async {
    try {
      return await _firestore.collection('users').doc(uid).get();
    } catch (e) {
      throw 'Failed to get user document: $e';
    }
  }
}
