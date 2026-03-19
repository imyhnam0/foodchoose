import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/gemini_service.dart';

class WaitingScreen extends StatefulWidget {
  final String roomId;

  const WaitingScreen({super.key, required this.roomId});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  final _roomService = RoomService();
  final _geminiService = GeminiService();
  bool _recommending = false;

  Future<void> _callGemini(Room room) async {
    if (_recommending) return;
    setState(() => _recommending = true);

    try {
      final prefs = await _roomService.getPreferences(room.id);
      final result = await _geminiService.recommendTop3(prefs);
      await _roomService.saveRecommendations(
          room.id, result.foods, result.reasons);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('추천 오류: $e')));
        setState(() => _recommending = false);
      }
    }
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

        // 투표 단계로 넘어가면 결과 화면으로 이동
        if (room.status == 'voting' || room.status == 'done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/${room.id}');
          });
        }

        // 모두 제출했고 추천 단계가 아닌 경우 Gemini 호출
        final allSubmitted = room.submittedCount >= room.participantCount &&
            room.participantCount > 0;
        if (allSubmitted && room.status == 'inputting' && !_recommending) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _callGemini(room);
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFFE85D04),
            foregroundColor: Colors.white,
            title: const Text('결과 기다리는 중'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🍳', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 24),
                  if (_recommending || room.status == 'recommending') ...[
                    const Text(
                      '재미나이가\n음식을 추천하고 있어요...',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                        color: Color(0xFFE85D04)),
                  ] else ...[
                    const Text(
                      '친구들이 선호도를\n입력하고 있어요',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: room.participantCount > 0
                            ? room.submittedCount / room.participantCount
                            : 0,
                        minHeight: 16,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE85D04)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${room.submittedCount} / ${room.participantCount}명 완료',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
