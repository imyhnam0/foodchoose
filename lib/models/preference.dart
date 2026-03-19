import 'package:cloud_firestore/cloud_firestore.dart';

class Preference {
  final String anonymousId;
  final List<String> wantFoods;
  final List<String> dontWantFoods;
  final DateTime submittedAt;

  const Preference({
    required this.anonymousId,
    required this.wantFoods,
    required this.dontWantFoods,
    required this.submittedAt,
  });

  factory Preference.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Preference(
      anonymousId: doc.id,
      wantFoods: List<String>.from(data['wantFoods'] ?? []),
      dontWantFoods: List<String>.from(data['dontWantFoods'] ?? []),
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wantFoods': wantFoods,
      'dontWantFoods': dontWantFoods,
      'submittedAt': Timestamp.fromDate(submittedAt),
    };
  }
}
