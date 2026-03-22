import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String code;
  final String hostId;
  final String
  status; // 'waiting' | 'inputting' | 'category_done' | 'restaurant_inputting' | 'restaurant_voting' | 'restaurant_revote_select' | 'done'
  final DateTime createdAt;
  final int participantCount;
  final int submittedCount;
  final int restaurantSubmittedCount;
  final List<String> recommendations;
  final Map<String, String> recommendationReasons; // { '피자': '이유...' }
  final Map<String, int> votes;
  final int votedCount;
  final String? selectedCategory;
  final String? finalFood;
  final String? decisionMethod; // 'weighted' | 'vote' | 'random'
  final Map<String, String> participants; // { uid: nickname }

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.createdAt,
    required this.participantCount,
    required this.submittedCount,
    this.restaurantSubmittedCount = 0,
    required this.recommendations,
    required this.recommendationReasons,
    required this.votes,
    this.votedCount = 0,
    this.selectedCategory,
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
      restaurantSubmittedCount: data['restaurantSubmittedCount'] as int? ?? 0,
      recommendations: List<String>.from(data['recommendations'] ?? []),
      recommendationReasons: Map<String, String>.from(
        data['recommendationReasons'] ?? {},
      ),
      votes: Map<String, int>.from(data['votes'] ?? {}),
      votedCount: data['votedCount'] as int? ?? 0,
      selectedCategory: data['selectedCategory'] as String?,
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
      'restaurantSubmittedCount': restaurantSubmittedCount,
      'recommendations': recommendations,
      'recommendationReasons': recommendationReasons,
      'votes': votes,
      'votedCount': votedCount,
      'participants': participants,
      if (selectedCategory != null) 'selectedCategory': selectedCategory,
      if (finalFood != null) 'finalFood': finalFood,
      if (decisionMethod != null) 'decisionMethod': decisionMethod,
    };
  }
}
