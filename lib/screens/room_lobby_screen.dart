import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

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
    Share.share(
      '🍽️ 골라음식에 초대합니다!\n입장 코드: $code\n$link',
    );
  }

  Future<void> _startRoom(String roomId) async {
    await _roomService.startRoom(roomId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room>(
      stream: _roomService.roomStream(widget.roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final room = snapshot.data!;

        // 방장이 시작하면 모든 사용자를 입력 화면으로 이동
        if (room.status == 'inputting') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/input/${room.id}');
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFFE85D04),
            foregroundColor: Colors.white,
            title: const Text('대기실'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    '입장 코드',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: room.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('코드가 복사되었습니다')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFE85D04), width: 2),
                      ),
                      child: Text(
                        room.code,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 12,
                          color: Color(0xFFE85D04),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '탭하여 복사',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _share(room.code),
                      icon: const Icon(Icons.share),
                      label: const Text('링크로 초대'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE85D04),
                        side:
                            const BorderSide(color: Color(0xFFE85D04)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.people, color: Color(0xFFE85D04)),
                      const SizedBox(width: 8),
                      Text(
                        '참가자 ${room.participantCount}명',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: room.participantCount,
                      itemBuilder: (context, i) {
                        final isMe = i == 0 && widget.isHost ||
                            (!widget.isHost &&
                                i == room.participantCount - 1 &&
                                _authService.userId != null);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE85D04)
                                .withAlpha(50 + i * 30),
                            child: Text(
                              '👤',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          title: Text(
                            i == 0
                                ? '방장${isMe ? ' (나)' : ''}'
                                : '참가자 ${i + 1}${isMe ? ' (나)' : ''}',
                          ),
                        );
                      },
                    ),
                  ),
                  if (widget.isHost)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: room.participantCount < 2
                            ? null
                            : () => _startRoom(room.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE85D04),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          room.participantCount < 2 ? '2명 이상 필요해요' : '시작하기!',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE85D04),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('방장이 시작할 때까지 기다려주세요'),
                        ],
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
