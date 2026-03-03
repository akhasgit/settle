import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  /// Checks if a username is available.
  /// If [excludeUid] is set, the username is considered available when it belongs to that user (e.g. they're keeping their current username).
  Future<bool> isUsernameAvailable(String username, {String? excludeUid}) async {
    try {
      // Remove @ if present for query
      final cleanUsername = username.startsWith('@')
          ? username.substring(1)
          : username;

      if (cleanUsername.isEmpty) {
        return false;
      }

      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (querySnapshot.docs.isEmpty) return true;
      if (excludeUid != null && querySnapshot.docs.first.id == excludeUid) {
        return true; // Current user already has this username
      }
      return false;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

  /// Updates user document with name and username
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String username,
  }) async {
    try {
      // Remove @ if present
      final cleanUsername = username.startsWith('@') 
          ? username.substring(1) 
          : username;

      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'username': cleanUsername,
      });
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw 'Failed to update profile: $e';
    }
  }

  /// Creates a new user document in Firestore with the specified fields
  /// The document ID will be the user's UID
  Future<void> createUserDocument({
    required String uid,
    required String email,
    String? name,
    String? username,
  }) async {
    try {
      debugPrint('Attempting to create user document for UID: $uid');
      final userDoc = _firestore.collection('users').doc(uid);

      // Create the user document with all required fields
      // Using set with merge: false to create new document or overwrite if exists
      debugPrint('Creating user document with data...');
      
      // Clean username (remove @ if present)
      final cleanUsername = username != null && username.isNotEmpty
          ? (username.startsWith('@') ? username.substring(1) : username)
          : '';
      
      await userDoc.set({
        'uid': uid,
        'username': cleanUsername,
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

  /// Stream of user document for real-time profile updates
  Stream<DocumentSnapshot> userDocumentStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Uploads a profile image to Firebase Storage and returns the download URL
  Future<String> uploadProfileImage({
    required String uid,
    required File imageFile,
  }) async {
    try {
      final ext = imageFile.path.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)
          ? ext
          : 'jpg';
      final ref = _storage.ref().child('profile_images').child('$uid.$safeExt');
      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/$safeExt'),
      );
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      throw 'Failed to upload profile image: $e';
    }
  }

  /// Updates daily, weekly, and monthly budget on the user document
  Future<void> updateBudgets({
    required String uid,
    double? dailyBudget,
    double? weeklyBudget,
    double? monthlyBudget,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (dailyBudget != null) data['dailyBudget'] = dailyBudget;
      if (weeklyBudget != null) data['weeklyBudget'] = weeklyBudget;
      if (monthlyBudget != null) data['monthlyBudget'] = monthlyBudget;
      if (data.isEmpty) return;
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint('Error updating budgets: $e');
      throw 'Failed to update budgets: $e';
    }
  }

  /// Updates the user's profile image URL in Firestore
  Future<void> updateProfileImageUrl({
    required String uid,
    required String imageUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'profileImageUrl': imageUrl,
      });
    } catch (e) {
      debugPrint('Error updating profile image URL: $e');
      throw 'Failed to update profile image: $e';
    }
  }
}
