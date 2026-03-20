import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomService = RoomService();

    return StreamBuilder<Room>(
      stream: roomService.roomStream(widget.roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)));
        }
        final room = snapshot.data!;
        final isVote = room.decisionMethod == 'vote';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // 상단 축제 이모지
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: const Text(
                      '🎉🎊🎉',
                      style: TextStyle(fontSize: 48),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 서브타이틀
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      isVote ? '투표 결과로 결정됐어요!' : '🎲 랜덤으로 뽑혔어요!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: const Text(
                      '오늘의 메뉴는...',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 메인 음식 카드 (스케일 애니메이션)
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 28),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('🍽️', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 14),
                          Text(
                            room.finalFood ?? '?',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 결정 방식 배지
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isVote
                            ? AppColors.secondaryMuted
                            : AppColors.primaryMuted,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isVote
                              ? AppColors.secondary.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isVote ? '🗳️' : '🎲',
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            isVote ? '다수결 투표로 결정' : '랜덤 뽑기로 결정',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isVote
                                  ? AppColors.secondary
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 처음으로 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.go('/'),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppColors.headerGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '🏠 처음으로 돌아가기',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
