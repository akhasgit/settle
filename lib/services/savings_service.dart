import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/savings_item.dart';

class SavingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _savingsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('savings');

  Future<void> addSavingsItem(String uid, SavingsItem item) async {
    try {
      await _savingsRef(uid).add(item.toFirestore());
    } catch (e) {
      debugPrint('Error adding savings item: $e');
      rethrow;
    }
  }

  Future<void> updateSavingsItem(
      String uid, String itemId, Map<String, dynamic> data) async {
    try {
      data['lastUpdated'] = FieldValue.serverTimestamp();
      await _savingsRef(uid).doc(itemId).update(data);
    } catch (e) {
      debugPrint('Error updating savings item: $e');
      rethrow;
    }
  }

  /// Atomically add money to a savings item
  Future<void> addMoney(String uid, String itemId, double amount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _savingsRef(uid).doc(itemId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) throw Exception('Savings item not found');

        final currentSaved =
            ((doc.data() as Map<String, dynamic>)['amountSaved'] as num?)
                ?.toDouble() ??
                0.0;

        transaction.update(docRef, {
          'amountSaved': currentSaved + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Error adding money: $e');
      rethrow;
    }
  }

  Future<void> deleteSavingsItem(String uid, String itemId) async {
    try {
      await _savingsRef(uid).doc(itemId).delete();
    } catch (e) {
      debugPrint('Error deleting savings item: $e');
      rethrow;
    }
  }

  Stream<List<SavingsItem>> savingsStream(String uid) {
    return _savingsRef(uid)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavingsItem.fromFirestore(doc))
            .toList());
  }

  Stream<SavingsItem?> savingsItemStream(String uid, String itemId) {
    return _savingsRef(uid).doc(itemId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SavingsItem.fromFirestore(doc);
    });
  }

  Future<SavingsItem?> getSavingsItem(String uid, String itemId) async {
    final doc = await _savingsRef(uid).doc(itemId).get();
    if (!doc.exists) return null;
    return SavingsItem.fromFirestore(doc);
  }
}
