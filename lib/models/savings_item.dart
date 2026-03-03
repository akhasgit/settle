import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsItem {
  final String id;
  final String name;
  final String? subtitle;
  final String? emoji;
  final String? imageUrl;
  final double amountNeeded;
  final double amountSaved;
  final String currency;
  final DateTime dateAdded;
  final DateTime deadline;
  final List<String> people;
  final DateTime? lastUpdated;

  SavingsItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.emoji,
    this.imageUrl,
    required this.amountNeeded,
    this.amountSaved = 0.0,
    required this.currency,
    required this.dateAdded,
    required this.deadline,
    this.people = const [],
    this.lastUpdated,
  });

  double get amountLeft => (amountNeeded - amountSaved).clamp(0.0, amountNeeded);
  double get progress => amountNeeded > 0 ? (amountSaved / amountNeeded).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => amountSaved >= amountNeeded;

  factory SavingsItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavingsItem(
      id: doc.id,
      name: data['name'] ?? '',
      subtitle: data['subtitle'],
      emoji: data['emoji'],
      imageUrl: data['imageUrl'],
      amountNeeded: (data['amountNeeded'] as num?)?.toDouble() ?? 0.0,
      amountSaved: (data['amountSaved'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] ?? 'SGD',
      dateAdded: (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      people: List<String>.from(data['people'] ?? []),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'subtitle': subtitle,
      'emoji': emoji,
      'imageUrl': imageUrl,
      'amountNeeded': amountNeeded,
      'amountSaved': amountSaved,
      'currency': currency,
      'dateAdded': Timestamp.fromDate(dateAdded),
      'deadline': Timestamp.fromDate(deadline),
      'people': people,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}
