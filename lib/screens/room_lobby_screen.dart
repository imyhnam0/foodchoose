import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/app_colors.dart';

class RoomLobbyScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const RoomLobbyScreen({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  final _roomService = RoomService();
  final _authService = AuthService();

  void _share(String code) {
    final link = buildInviteLink(code);
    Share.share('🍽️ 뭐 먹을건데에 초대합니다!\n입장 코드: $code\n$link');
  }

  Future<void> _startRoom(String roomId) async {
    await _roomService.startRoom(roomId);
  }

  Future<void> _leaveRoom(Room room) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('방에서 나갈까요?'),
          content: Text(
            widget.isHost ? '방장이 나가면 현재 방이 종료돼요.' : '지금 나가면 로비에서 빠지게 돼요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('나가기'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) return;

    try {
      if (widget.isHost) {
        await _roomService.deleteRoom(room.id);
      } else {
        final uid = _authService.userId;
        if (uid != null) await _roomService.leaveRoom(room.id, uid);
      }
      await _authService.signOut();
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('방에서 나가지 못했어요: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

        if (room.status == 'inputting') {
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

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── 상단 헤더 (퍼플 그라데이션)
                _buildHeader(room),

                // ── 참가자 섹션
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParticipantSection(room),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── 하단 버튼
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildBottomAction(room),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Room room) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          // 상단 타이틀 바
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🍽️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      widget.isHost ? '방장' : '참가자',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 입장 코드 카드
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('코드가 복사되었어요! 👍'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.code,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.copy_rounded,
                    color: AppColors.secondary.withOpacity(0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '탭하면 복사돼요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // 공유 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _share(room.code),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('친구에게 링크 공유'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantSection(Room room) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Text('👥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '참가자 ${room.participantCount}명',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                room.participantCount >= 2 ? '시작 가능' : '1명 더 필요',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: room.participantCount >= 2
                      ? AppColors.mint
                      : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildParticipantList(room),
        if (room.participantCount < 2) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber.withOpacity(0.3)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParticipantList(Room room) {
    final myUid = _authService.userId;
    final entries = room.participants.entries.toList();
    // 방장이 항상 첫 번째
    entries.sort((a, b) {
      if (a.key == room.hostId) return -1;
      if (b.key == room.hostId) return 1;
      return 0;
    });

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: entries.map((entry) {
        final uid = entry.key;
        final name = entry.value;
        final isHost = uid == room.hostId;
        final isMe = uid == myUid;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary.withOpacity(0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe
                  ? AppColors.primary.withOpacity(0.4)
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isHost
                      ? AppColors.secondary.withOpacity(0.12)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isHost ? '👑' : '👤',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (isHost)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '방장',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              if (isMe && !isHost)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '나',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomAction(Room room) {
    final Widget primaryAction;

    if (widget.isHost) {
      final canStart = room.participantCount >= 2;
      primaryAction = SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canStart ? () => _startRoom(room.id) : null,
            child: Ink(
              decoration: BoxDecoration(
                gradient: canStart
                    ? AppColors.headerGradient
                    : LinearGradient(
                        colors: [Colors.grey[300]!, Colors.grey[350]!],
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: canStart
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  canStart ? '🚀 지금 시작하기!' : '2명 이상 모여야 시작해요',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: canStart ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      primaryAction = Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.secondaryMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
        ),
        child: Row(
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
              '방장이 시작할 때까지 기다려주세요 👀',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.secondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        primaryAction,
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _leaveRoom(room),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(widget.isHost ? '방 종료하고 나가기' : '방 나가기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
