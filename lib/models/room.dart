import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String code;
  final String hostId;
  final String status; // 'waiting' | 'inputting' | 'recommending' | 'voting' | 'done'
  final DateTime createdAt;
  final int participantCount;
  final int submittedCount;
  final List<String> recommendations;
  final Map<String, String> recommendationReasons; // { '피자': '이유...' }
  final Map<String, int> votes;
  final String? finalFood;
  final String? decisionMethod; // 'vote' | 'random'
  final Map<String, String> participants; // { uid: nickname }

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.createdAt,
    required this.participantCount,
    required this.submittedCount,
    required this.recommendations,
    required this.recommendationReasons,
    required this.votes,
    this.finalFood,
    this.decisionMethod,
    this.participants = const {},
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Room(
      id: doc.id,
      code: data['code'] as String,
      hostId: data['hostId'] as String,
      status: data['status'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      participantCount: data['participantCount'] as int? ?? 0,
      submittedCount: data['submittedCount'] as int? ?? 0,
      recommendations: List<String>.from(data['recommendations'] ?? []),
      recommendationReasons: Map<String, String>.from(
          data['recommendationReasons'] ?? {}),
      votes: Map<String, int>.from(data['votes'] ?? {}),
      finalFood: data['finalFood'] as String?,
      decisionMethod: data['decisionMethod'] as String?,
      participants: Map<String, String>.from(data['participants'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'hostId': hostId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'participantCount': participantCount,
      'submittedCount': submittedCount,
      'recommendations': recommendations,
      'recommendationReasons': recommendationReasons,
      'votes': votes,
      'participants': participants,
      if (finalFood != null) 'finalFood': finalFood,
      if (decisionMethod != null) 'decisionMethod': decisionMethod,
    };
  }
}
