import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../utils/app_colors.dart';

class ResultsScreen extends StatefulWidget {
  final String roomId;

  const ResultsScreen({super.key, required this.roomId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _authService = AuthService();
  final _roomService = RoomService();

  Set<String> _myVotes = {};
  bool _voteSubmitted = false;

  void _toggleVote(String food) {
    if (_voteSubmitted) return;
    setState(() {
      if (_myVotes.contains(food)) {
        _myVotes.remove(food);
      } else {
        _myVotes.add(food);
      }
    });
  }

  Future<void> _submitVotes(Room room) async {
    if (_voteSubmitted || _myVotes.isEmpty) return;
    setState(() => _voteSubmitted = true);
    await _roomService.submitVotes(room.id, _myVotes.toList());
  }

  Future<void> _resetVotes(Room room) async {
    await _roomService.resetVotes(room.id, room.recommendations);
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
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final room = snapshot.data!;

        if (room.status == 'done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/final/${room.id}');
          });
        }

        // 재투표 감지: votedCount가 0으로 리셋되면 로컬 상태도 초기화
        if (room.votedCount == 0 && _voteSubmitted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _myVotes = {};
                _voteSubmitted = false;
              });
            }
          });
        }

        final isHost = room.hostId == _authService.userId;
        final allVoted = room.votedCount >= room.participantCount &&
            room.participantCount > 0;

        // 투표 완료 후 대기 화면
        if (_voteSubmitted && !allVoted) {
          return _buildVoteWaitingScreen(room);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    itemCount: room.recommendations.length,
                    itemBuilder: (context, i) {
                      final food = room.recommendations[i];
                      final voteCount = room.votes[food] ?? 0;
                      final totalVotes =
                          room.votes.values.fold(0, (a, b) => a + b);
                      return _RecommendationCard(
                        rank: i,
                        food: food,
                        reason: room.recommendationReasons[food],
                        voteCount: voteCount,
                        totalVotes: totalVotes,
                        isSelected: _myVotes.contains(food),
                        hasSubmitted: _voteSubmitted,
                        showResults: allVoted,
                        onTap: _voteSubmitted ? null : () => _toggleVote(food),
                      );
                    },
                  ),
                ),
                _buildBottomBar(room, isHost, allVoted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoteWaitingScreen(Room room) {
    final remaining = room.participantCount - room.votedCount;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🗳️', style: TextStyle(fontSize: 52)),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                '투표 완료!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$remaining명이 더 투표해야 해요\n잠시만 기다려주세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                        Text(
                          '투표 현황',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          '${room.votedCount} / ${room.participantCount}명 완료',
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
                        value: room.participantCount > 0
                            ? room.votedCount / room.participantCount
                            : 0.0,
                        minHeight: 12,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(room.participantCount, (i) {
                        final done = i < room.votedCount;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: done
                                  ? AppColors.primary
                                  : AppColors.border,
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
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🍽️', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 추천 Top 3 🎯',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                '마음에 드는 메뉴를 선택해 투표해주세요!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Room room, bool isHost, bool allVoted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 투표 완료 버튼 (아직 미제출인 경우 모두에게 표시)
          if (!_voteSubmitted) ...[
            _buildSubmitVoteButton(room),
          ] else if (!isHost) ...[
            // 비방장: 대기 메시지
            _buildNonHostWaiting(room, allVoted),
          ],

          // 방장 전용 섹션
          if (isHost) ...[
            if (_voteSubmitted) const SizedBox(height: 10),
            _buildHostSection(room, allVoted),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitVoteButton(Room room) {
    final hasSelection = _myVotes.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: hasSelection ? AppColors.purpleGradient : null,
          color: hasSelection ? null : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(16),
          boxShadow: hasSelection
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: hasSelection ? () => _submitVotes(room) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            hasSelection
                ? '투표 완료 (${_myVotes.length}개 선택됨)'
                : '메뉴를 선택해주세요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: hasSelection ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNonHostWaiting(Room room, bool allVoted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: allVoted
            ? AppColors.mint.withOpacity(0.08)
            : AppColors.secondaryMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allVoted
              ? AppColors.mint.withOpacity(0.2)
              : AppColors.secondary.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            allVoted
                ? '✅ 모두 투표 완료! 방장이 결과를 확정할 거에요'
                : '투표 완료! ${room.votedCount}/${room.participantCount}명 완료 중...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: allVoted
                  ? AppColors.mint
                  : AppColors.secondary.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHostSection(Room room, bool allVoted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 투표 현황
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🗳️ ', style: TextStyle(fontSize: 14)),
              Text(
                allVoted
                    ? '모두 투표 완료! 결과를 확정해주세요'
                    : '${room.votedCount} / ${room.participantCount}명 투표 완료',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // 투표 완료 시: 결과 확정 + 랜덤 뽑기
        if (allVoted) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: '투표 결과 확정',
                  icon: '✅',
                  gradient: AppColors.purpleGradient,
                  onPressed: () => _finalizeVote(room),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: '랜덤 뽑기',
                  icon: '🎲',
                  gradient: AppColors.headerGradient,
                  onPressed: () => _pickRandom(room),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 10),

        // 재투표 버튼
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () => _resetVotes(room),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: Color(0xFFDDE1E7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Text('🔄', style: TextStyle(fontSize: 15)),
            label: const Text(
              '재투표',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final int rank;
  final String food;
  final String? reason;
  final int voteCount;
  final int totalVotes;
  final bool isSelected;
  final bool hasSubmitted;
  final bool showResults;
  final VoidCallback? onTap;

  const _RecommendationCard({
    required this.rank,
    required this.food,
    required this.reason,
    required this.voteCount,
    required this.totalVotes,
    required this.isSelected,
    required this.hasSubmitted,
    required this.showResults,
    required this.onTap,
  });

  static const _rankConfig = [
    (label: '1', color: Color(0xFFFDB74A), bg: Color(0xFFFFF8E7)),
    (label: '2', color: Color(0xFF9E9E9E), bg: Color(0xFFF5F5F5)),
    (label: '3', color: Color(0xFFCD7F32), bg: Color(0xFFFDF3EB)),
  ];

  @override
  Widget build(BuildContext context) {
    final cfg = _rankConfig[rank];
    final voteRatio = totalVotes > 0 ? voteCount / totalVotes : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isSelected ? cfg.bg : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? cfg.color : AppColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? cfg.color : Colors.black).withOpacity(
                isSelected ? 0.15 : 0.04,
              ),
              blurRadius: isSelected ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 순위 뱃지
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cfg.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cfg.color.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: cfg.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 음식 이름 + 이유
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        if (reason != null)
                          Text(
                            reason!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 체크박스 (회색 → 초록)
                  if (!hasSubmitted)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00B894)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00B894)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    )
                  else if (isSelected)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B894),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                ],
              ),

              // 투표 진행도 (모두 투표 완료 시에만 표시)
              if (showResults) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: voteRatio,
                          minHeight: 6,
                          backgroundColor: AppColors.border,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(cfg.color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$voteCount표',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cfg.color,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String icon;
  final LinearGradient gradient;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
