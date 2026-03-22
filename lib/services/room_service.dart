import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/preference.dart';

class RoomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _rooms => _db.collection('rooms');

  // 6자리 알파벳+숫자 코드 생성
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<Room> createRoom(String hostId, String nickname) async {
    final code = _generateCode();
    final docRef = _rooms.doc();
    final room = Room(
      id: docRef.id,
      code: code,
      hostId: hostId,
      status: 'waiting',
      createdAt: DateTime.now(),
      participantCount: 1,
      submittedCount: 0,
      restaurantSubmittedCount: 0,
      recommendations: [],
      recommendationReasons: {},
      votes: {},
      participants: {hostId: nickname},
    );
    await docRef.set(room.toMap());
    return room;
  }

  Future<Room?> findRoomByCode(String code) async {
    final snap = await _rooms
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Room.fromFirestore(snap.docs.first);
  }

  Future<void> joinRoom(String roomId, String userId, String nickname) async {
    await _rooms.doc(roomId).update({
      'participantCount': FieldValue.increment(1),
      'participants.$userId': nickname,
    });
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    await _db.runTransaction((transaction) async {
      final docRef = _rooms.doc(roomId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final count = (data['participantCount'] as num?)?.toInt() ?? 0;
      transaction.update(docRef, {
        'participantCount': count > 0 ? count - 1 : 0,
        'participants.$userId': FieldValue.delete(),
      });
    });
  }

  Future<void> deleteRoom(String roomId) async {
    await _rooms.doc(roomId).delete();
  }

  Stream<Room> roomStream(String roomId) {
    return _rooms.doc(roomId).snapshots().map(Room.fromFirestore);
  }

  Future<void> startRoom(String roomId) async {
    await _rooms.doc(roomId).update({'status': 'inputting'});
  }

  Future<void> submitPreference(
    String roomId,
    String anonymousId,
    List<String> wantFoods,
    List<String> dontWantFoods,
  ) async {
    final pref = Preference(
      anonymousId: anonymousId,
      wantFoods: wantFoods,
      dontWantFoods: dontWantFoods,
      submittedAt: DateTime.now(),
    );
    await _rooms
        .doc(roomId)
        .collection('preferences')
        .doc(anonymousId)
        .set(pref.toMap());
    await _rooms.doc(roomId).update({
      'submittedCount': FieldValue.increment(1),
    });
  }

  Future<List<Preference>> getPreferences(String roomId) async {
    final snap = await _rooms.doc(roomId).collection('preferences').get();
    return snap.docs.map(Preference.fromFirestore).toList();
  }

  Future<void> saveRecommendations(
    String roomId,
    List<String> recommendations,
    Map<String, String> reasons,
  ) async {
    final votesInit = {for (final f in recommendations) f: 0};
    await _rooms.doc(roomId).update({
      'status': 'voting',
      'recommendations': recommendations,
      'recommendationReasons': reasons,
      'votes': votesInit,
    });
  }

  Future<void> saveWeightedResult(
    String roomId,
    String food,
    String summary,
  ) async {
    await _rooms.doc(roomId).update({
      'status': 'category_done',
      'selectedCategory': food,
      'recommendations': [],
      'recommendationReasons': {'categorySummary': summary},
      'restaurantSubmittedCount': 0,
      'votes': {},
      'votedCount': 0,
      'decisionMethod': 'weighted',
      'finalFood': FieldValue.delete(),
    });
  }

  Future<void> restartPreferenceRound(String roomId, String message) async {
    final prefs = await _rooms.doc(roomId).collection('preferences').get();
    final batch = _db.batch();

    // 이전 선택을 저장 (재입력 시 비활성화용)
    final previousSelections = <String, List<String>>{};
    for (final pref in prefs.docs) {
      final data = pref.data();
      final allFoods = <String>[
        ...List<String>.from(data['wantFoods'] ?? []),
        ...List<String>.from(data['dontWantFoods'] ?? []),
      ];
      previousSelections[pref.id] = allFoods;
    }

    for (final pref in prefs.docs) {
      batch.delete(pref.reference);
    }

    batch.update(_rooms.doc(roomId), {
      'status': 'inputting',
      'submittedCount': 0,
      'recommendations': <String>[],
      'recommendationReasons': {'__systemMessage': message},
      'restaurantSubmittedCount': 0,
      'votes': <String, int>{},
      'votedCount': 0,
      'selectedCategory': FieldValue.delete(),
      'finalFood': FieldValue.delete(),
      'decisionMethod': FieldValue.delete(),
      'previousSelections': previousSelections,
    });

    await batch.commit();
  }

  Future<List<String>> getPreviousSelections(
    String roomId,
    String userId,
  ) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    final prev = data['previousSelections'] as Map<String, dynamic>?;
    if (prev == null || !prev.containsKey(userId)) return [];
    return List<String>.from(prev[userId] ?? []);
  }

  Future<void> startRestaurantInput(String roomId) async {
    await _rooms.doc(roomId).update({
      'status': 'restaurant_inputting',
      'restaurantSubmittedCount': 0,
      'recommendations': <String>[],
      'recommendationReasons': <String, String>{},
      'votes': <String, int>{},
      'votedCount': 0,
      'finalFood': FieldValue.delete(),
      'decisionMethod': FieldValue.delete(),
    });
  }

  Future<void> submitRestaurantSuggestions(
    String roomId,
    String userId,
    List<String> restaurants,
  ) async {
    await _rooms
        .doc(roomId)
        .collection('restaurantSuggestions')
        .doc(userId)
        .set({
          'restaurants': restaurants,
          'submittedAt': Timestamp.fromDate(DateTime.now()),
        });

    await _rooms.doc(roomId).update({
      'restaurantSubmittedCount': FieldValue.increment(1),
    });
  }

  Future<bool> hasSubmittedRestaurantSuggestions(
    String roomId,
    String userId,
  ) async {
    final doc = await _rooms
        .doc(roomId)
        .collection('restaurantSuggestions')
        .doc(userId)
        .get();
    return doc.exists;
  }

  Future<List<String>> getRestaurantCandidates(String roomId) async {
    final snap = await _rooms
        .doc(roomId)
        .collection('restaurantSuggestions')
        .get();
    final restaurants = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      for (final name in List<String>.from(data['restaurants'] ?? [])) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          restaurants.add(trimmed);
        }
      }
    }
    return restaurants.toList()..sort();
  }

  Future<void> saveRestaurantCandidates(
    String roomId,
    List<String> candidates,
  ) async {
    final votesInit = {for (final f in candidates) f: 0};
    await _rooms.doc(roomId).update({
      'status': 'restaurant_voting',
      'recommendations': candidates,
      'votes': votesInit,
      'votedCount': 0,
      'recommendationReasons': <String, String>{},
      'finalFood': FieldValue.delete(),
      'decisionMethod': FieldValue.delete(),
    });
  }

  Future<void> submitRestaurantVotes(
    String roomId,
    List<String> selectedFoods,
  ) async {
    final Map<String, dynamic> updates = {};
    for (final food in selectedFoods) {
      updates['votes.$food'] = FieldValue.increment(1);
    }
    updates['votedCount'] = FieldValue.increment(1);
    await _rooms.doc(roomId).update(updates);
  }

  Future<void> startRestaurantRevoteSelection(String roomId) async {
    await _rooms.doc(roomId).update({
      'status': 'restaurant_revote_select',
      'finalFood': FieldValue.delete(),
      'decisionMethod': FieldValue.delete(),
    });
  }

  Future<void> resetRestaurantVotes(String roomId, List<String> foods) async {
    final votesInit = {for (final f in foods) f: 0};
    await _rooms.doc(roomId).update({
      'status': 'restaurant_voting',
      'recommendations': foods,
      'votes': votesInit,
      'votedCount': 0,
      'finalFood': FieldValue.delete(),
      'decisionMethod': FieldValue.delete(),
    });
  }

  Future<void> submitVotes(String roomId, List<String> selectedFoods) async {
    final Map<String, dynamic> updates = {};
    for (final food in selectedFoods) {
      updates['votes.$food'] = FieldValue.increment(1);
    }
    updates['votedCount'] = FieldValue.increment(1);
    await _rooms.doc(roomId).update(updates);
  }

  Future<void> resetVotes(String roomId, List<String> foods) async {
    final votesInit = {for (final f in foods) f: 0};
    await _rooms.doc(roomId).update({'votes': votesInit, 'votedCount': 0});
  }

  Future<void> setFinalFood(String roomId, String food, String method) async {
    await _rooms.doc(roomId).update({
      'finalFood': food,
      'decisionMethod': method,
      'status': 'done',
    });
  }
}
