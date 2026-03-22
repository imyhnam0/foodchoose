import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../utils/app_colors.dart';

class FinalResultScreen extends StatefulWidget {
  final String roomId;

  const FinalResultScreen({super.key, required this.roomId});

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  final _roomService = RoomService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room>(
      stream: _roomService.roomStream(widget.roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final room = snapshot.data!;
        final isCategoryStage = room.status == 'category_done';
        final isHost = room.hostId == _authService.userId;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      isCategoryStage ? '🍽️' : '🎉🎊🎉',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      isCategoryStage ? '오늘의 메뉴 카테고리' : '최종 음식점 결과',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      isCategoryStage ? '선택된 카테고리는...' : '최종 선택된 음식점은...',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 28,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            isCategoryStage
                                ? (room.selectedCategory ?? '?')
                                : (room.finalFood ?? '?'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isCategoryStage)
                    _buildCategoryActions(room)
                  else
                    _buildFinalActions(room, isHost),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryActions(Room room) {
    return Column(
      children: [
        const Text(
          '음식점도 고르시겠어요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: () async {
              await _roomService.startRestaurantInput(room.id);
              if (!mounted) return;
              context.go('/results/${room.id}');
            },
            child: const Text('네'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => context.go('/'),
            child: const Text('아니요, 홈으로 갈게요'),
          ),
        ),
      ],
    );
  }

  Widget _buildFinalActions(Room room, bool isHost) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('홈으로 가기'),
          ),
        ),
        if (room.decisionMethod == 'vote' && isHost) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () async {
                await _roomService.startRestaurantRevoteSelection(room.id);
                if (!mounted) return;
                context.go('/results/${room.id}');
              },
              child: const Text('재투표하기'),
            ),
          ),
        ],
      ],
    );
  }
}
