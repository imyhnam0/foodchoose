import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/gemini_service.dart';
import '../utils/app_colors.dart';

class WaitingScreen extends StatefulWidget {
  final String roomId;

  const WaitingScreen({super.key, required this.roomId});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with SingleTickerProviderStateMixin {
  final _roomService = RoomService();
  final _geminiService = GeminiService();
  bool _recommending = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추천 오류: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
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
              body:
                  Center(child: CircularProgressIndicator(color: AppColors.primary)));
        }
        final room = snapshot.data!;

        if (room.status == 'voting' || room.status == 'done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/${room.id}');
          });
        }

        final allSubmitted = room.submittedCount >= room.participantCount &&
            room.participantCount > 0;
        if (allSubmitted && room.status == 'inputting' && !_recommending) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _callGemini(room);
          });
        }

        final isRecommending = _recommending || room.status == 'recommending';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 중앙 일러스트 영역
                  _buildCenterIllustration(isRecommending),

                  const SizedBox(height: 40),

                  // 상태 텍스트
                  if (isRecommending) ...[
                    _buildRecommendingState(),
                  ] else ...[
                    _buildWaitingState(room),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterIllustration(bool isRecommending) {
    if (isRecommending) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 글로우 효과
            Container(
              width: 155,
              height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // 계란 모양
            ClipOval(
              child: Container(
                width: 108,
                height: 143,
                decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient,
                ),
                child: const Center(
                  child: Text('🍳', style: TextStyle(fontSize: 52)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(48),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: const Text('⏳', style: TextStyle(fontSize: 64)),
        ),
      ),
    );
  }

  Widget _buildRecommendingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '분석중...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '모두의 선호도를 바탕으로\n최선의 메뉴를 찾고 있어요 🔍',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        // AI 처리 중 인디케이터
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.secondaryMuted,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.secondary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.secondary.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Gemini AI 추천 생성 중...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingState(Room room) {
    final submitted = room.submittedCount;
    final total = room.participantCount;
    final ratio = total > 0 ? submitted / total : 0.0;

    return Column(
      children: [
        const Text(
          '친구들을 기다리는 중...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '모두가 선호도를 제출하면\n자동으로 AI 추천이 시작돼요!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),

        // 진행 상황 카드
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '제출 현황',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    '$submitted / $total명 완료',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 12,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              // 아바타 진행 표시
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final done = i < submitted;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: done ? AppColors.primary : AppColors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
