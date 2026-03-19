import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';

class ResultsScreen extends StatefulWidget {
  final String roomId;

  const ResultsScreen({super.key, required this.roomId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _authService = AuthService();
  final _roomService = RoomService();

  String? _myVote;
  bool _voted = false;

  Future<void> _vote(Room room, String food) async {
    if (_voted) return;
    setState(() {
      _myVote = food;
      _voted = true;
    });
    await _roomService.castVote(room.id, food);
  }

  Future<void> _pickRandom(Room room) async {
    final foods = room.recommendations;
    if (foods.isEmpty) return;
    final food = foods[Random().nextInt(foods.length)];
    await _roomService.setFinalFood(room.id, food, 'random');
  }

  Future<void> _finalizeVote(Room room) async {
    final votes = room.votes;
    if (votes.isEmpty) return;
    final winner =
        votes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    await _roomService.setFinalFood(room.id, winner, 'vote');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room>(
      stream: _roomService.roomStream(widget.roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final room = snapshot.data!;

        if (room.status == 'done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/final/${room.id}');
          });
        }

        final isHost = room.hostId == _authService.userId;
        final totalVotes =
            room.votes.values.fold(0, (a, b) => a + b);

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFFE85D04),
            foregroundColor: Colors.white,
            title: const Text('재미나이 추천 Top 3'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    '🤖 재미나이가 추천하는\n오늘의 음식!',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: room.recommendations.length,
                      itemBuilder: (context, i) {
                        final food = room.recommendations[i];
                        final voteCount = room.votes[food] ?? 0;
                        final medals = ['🥇', '🥈', '🥉'];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: _myVote == food ? 4 : 1,
                          color: _myVote == food
                              ? const Color(0xFFFFE0C8)
                              : Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            leading: Text(medals[i],
                                style: const TextStyle(fontSize: 28)),
                            title: Text(
                              food,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (room.recommendationReasons[food] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      room.recommendationReasons[food]!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ),
                                if (totalVotes > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('$voteCount표'),
                                  ),
                              ],
                            ),
                            trailing: !_voted
                                ? ElevatedButton(
                                    onPressed: () => _vote(room, food),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFE85D04),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: const Text('투표'),
                                  )
                                : _myVote == food
                                    ? const Icon(Icons.check_circle,
                                        color: Color(0xFFE85D04))
                                    : null,
                          ),
                        );
                      },
                    ),
                  ),
                  if (isHost) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _finalizeVote(room),
                            icon: const Icon(Icons.how_to_vote),
                            label: const Text('투표 결과 확정'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE85D04),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickRandom(room),
                            icon: const Text('🎲',
                                style: TextStyle(fontSize: 18)),
                            label: const Text('랜덤 뽑기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_voted)
                            const Text('원하는 음식에 투표해주세요!')
                          else
                            const Text('방장이 결과를 확정할 때까지 기다려주세요'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
