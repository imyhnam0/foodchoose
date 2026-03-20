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
    final winner = votes.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
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

        final isHost = room.hostId == _authService.userId;
        final totalVotes = room.votes.values.fold(0, (a, b) => a + b);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── 헤더
                _buildHeader(),

                // ── 추천 카드 리스트
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    itemCount: room.recommendations.length,
                    itemBuilder: (context, i) {
                      final food = room.recommendations[i];
                      final voteCount = room.votes[food] ?? 0;
                      return _RecommendationCard(
                        rank: i,
                        food: food,
                        reason: room.recommendationReasons[food],
                        voteCount: voteCount,
                        totalVotes: totalVotes,
                        isMyVote: _myVote == food,
                        hasVoted: _voted,
                        onVote: _voted ? null : () => _vote(room, food),
                      );
                    },
                  ),
                ),

                // ── 하단 액션 (방장 전용 or 안내)
                _buildBottomBar(room, isHost, totalVotes),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🤖', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '재미나이 추천 Top 3 🎯',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '마음에 드는 메뉴에 투표해주세요!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Room room, bool isHost, int totalVotes) {
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
      child: isHost
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (totalVotes > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mint.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '현재 총 $totalVotes표 집계됨',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: '투표 결과 확정',
                        icon: '🗳️',
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
            )
          : Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.secondaryMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    !_voted
                        ? '👆 위에서 먹고 싶은 메뉴에 투표해주세요!'
                        : '방장이 결과를 확정할 때까지 기다려주세요 👀',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final int rank;
  final String food;
  final String? reason;
  final int voteCount;
  final int totalVotes;
  final bool isMyVote;
  final bool hasVoted;
  final VoidCallback? onVote;

  const _RecommendationCard({
    required this.rank,
    required this.food,
    required this.reason,
    required this.voteCount,
    required this.totalVotes,
    required this.isMyVote,
    required this.hasVoted,
    required this.onVote,
  });

  static const _rankConfig = [
    (emoji: '🥇', color: Color(0xFFFDB74A), bg: Color(0xFFFFF8E7)),
    (emoji: '🥈', color: Color(0xFF9E9E9E), bg: Color(0xFFF5F5F5)),
    (emoji: '🥉', color: Color(0xFFCD7F32), bg: Color(0xFFFDF3EB)),
  ];

  @override
  Widget build(BuildContext context) {
    final cfg = _rankConfig[rank];
    final voteRatio = totalVotes > 0 ? voteCount / totalVotes : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isMyVote ? cfg.bg : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMyVote ? cfg.color : AppColors.border,
          width: isMyVote ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMyVote ? cfg.color : Colors.black).withOpacity(
              isMyVote ? 0.15 : 0.04,
            ),
            blurRadius: isMyVote ? 14 : 6,
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
                      cfg.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 음식 이름
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

                // 투표 버튼 or 체크
                if (!hasVoted)
                  GestureDetector(
                    onTap: onVote,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.purpleGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        '투표',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else if (isMyVote)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: cfg.color,
                      size: 20,
                    ),
                  ),
              ],
            ),

            // 투표 진행도 (투표 데이터 있을 때만)
            if (totalVotes > 0) ...[
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
                        valueColor: AlwaysStoppedAnimation<Color>(cfg.color),
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
