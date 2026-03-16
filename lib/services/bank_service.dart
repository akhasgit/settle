import 'package:cloud_firestore/cloud_firestore.dart';

class BankService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of active bank connections for the given user.
  Stream<List<Map<String, dynamic>>> getConnections(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('bankConnections')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Persists a new bank connection after the user completes the Finverse Link flow.
  Future<void> saveConnection({
    required String uid,
    required String connectionId,
    required String institutionName,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('bankConnections')
        .doc(connectionId)
        .set({
      'connectionId': connectionId,
      'institutionName': institutionName,
      'status': 'active',
      'connectedAt': FieldValue.serverTimestamp(),
      'lastSyncAt': null,
    });
  }

  /// Removes a bank connection (also revoke on Finverse side via your backend if needed).
  Future<void> disconnectBank(String uid, String connectionId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('bankConnections')
        .doc(connectionId)
        .delete();
  }
}
