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

  Future<Room> createRoom(String hostId) async {
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
      recommendations: [],
      recommendationReasons: {},
      votes: {},
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

  Future<void> joinRoom(String roomId) async {
    await _rooms.doc(roomId).update({
      'participantCount': FieldValue.increment(1),
    });
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
    final snap =
        await _rooms.doc(roomId).collection('preferences').get();
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

  Future<void> castVote(String roomId, String food) async {
    await _rooms.doc(roomId).update({
      'votes.$food': FieldValue.increment(1),
    });
  }

  Future<void> setFinalFood(
    String roomId,
    String food,
    String method,
  ) async {
    await _rooms.doc(roomId).update({
      'finalFood': food,
      'decisionMethod': method,
      'status': 'done',
    });
  }
}
