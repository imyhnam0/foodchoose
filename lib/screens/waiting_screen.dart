import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../utils/app_colors.dart';
import '../utils/food_categories.dart';

class WaitingScreen extends StatefulWidget {
  final String roomId;

  const WaitingScreen({super.key, required this.roomId});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with SingleTickerProviderStateMixin {
  final _roomService = RoomService();
  bool _calculating = false;
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

  Future<void> _calculateTopFood(Room room) async {
    if (_calculating) return;
    setState(() => _calculating = true);

    try {
      final prefs = await _roomService.getPreferences(room.id);
      final result = calculateTopFood(prefs);
      if (result == null) {
        await _roomService.restartPreferenceRound(
          room.id,
          '누군가 먹기 싫은 음식 때문에 후보가 남지 않았어요. 다시 골라주세요.',
        );
        if (mounted) setState(() => _calculating = false);
      } else {
        await _roomService.saveWeightedResult(
          room.id,
          result.food,
          result.summary,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('결과 계산 오류: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room>(
      stream: _roomService.roomStream(widget.roomId),
      builder: (context, snapshot) {
        if (snapshot.hasError || (!snapshot.hasData && snapshot.connectionState == ConnectionState.active)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final room = snapshot.data!;

        final shouldReturnToInput =
            room.status == 'inputting' &&
            room.submittedCount == 0 &&
            room.recommendationReasons.containsKey('__systemMessage') &&
            !_calculating;

        if (shouldReturnToInput) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/input/${room.id}');
          });
        }

        if (room.status == 'category_done' || room.status == 'done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/final/${room.id}');
          });
        }

        if (room.status == 'restaurant_inputting' ||
            room.status == 'restaurant_voting' ||
            room.status == 'restaurant_revote_select') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/${room.id}');
          });
        }

        final allSubmitted =
            room.submittedCount >= room.participantCount &&
            room.participantCount > 0;

        if (allSubmitted && room.status == 'inputting' && !_calculating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _calculateTopFood(room);
          });
        }

        final isCalculating = _calculating || allSubmitted;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _buildCenterIllustration(isCalculating)),
                  const SizedBox(height: 40),
                  if (isCalculating)
                    _buildCalculatingState()
                  else
                    _buildWaitingState(room),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterIllustration(bool isCalculating) {
    if (isCalculating) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
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

  Widget _buildCalculatingState() {
    return Column(
      children: [
        const Text(
          '결과 계산 중...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '모든 선택을 확인해서\n오늘의 메뉴를 정하고 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.6),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.secondaryMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                '카테고리 점수 집계 중...',
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
    final remaining = total > submitted ? total - submitted : 0;
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
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '지금 $submitted명이 골랐고\n${remaining}명이 더 골라야 해요',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '제출 현황',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    '$submitted / $total명 완료',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List.generate(total, (index) {
                  final done = index < submitted;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: done ? AppColors.primary : AppColors.border,
                      shape: BoxShape.circle,
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
