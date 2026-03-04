import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final double amount;
  final String name;
  final String? tag;
  final String currency;
  final DateTime date;
  final DateTime createdAt;
  final List<String> splitWith;
  final String splitMode;
  final Map<String, double> customAmounts;
  final List<String> omittedUsernames;

  Expense({
    required this.id,
    required this.amount,
    required this.name,
    this.tag,
    required this.currency,
    required this.date,
    required this.createdAt,
    this.splitWith = const [],
    this.splitMode = 'equal',
    this.customAmounts = const {},
    this.omittedUsernames = const [],
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      name: data['name'] ?? '',
      tag: data['tag'],
      currency: data['currency'] ?? 'SGD',
      date: (data['date'] as Timestamp).toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      splitWith: List<String>.from(data['splitWith'] ?? []),
      splitMode: data['splitMode'] ?? 'equal',
      customAmounts: Map<String, double>.from(
        (data['customAmounts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      omittedUsernames: List<String>.from(data['omittedUsernames'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'name': name,
      'tag': tag,
      'currency': currency,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      'splitWith': splitWith,
      'splitMode': splitMode,
      'customAmounts': customAmounts,
      'omittedUsernames': omittedUsernames,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'name': name,
      'tag': tag,
      'currency': currency,
      'date': date.toIso8601String(),
      'splitWith': splitWith,
      'splitMode': splitMode,
      'customAmounts': customAmounts,
      'omittedUsernames': omittedUsernames,
    };
  }
}
