import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../utils/app_colors.dart';

class HomeScreen extends StatefulWidget {
  final String? initialCode;

  const HomeScreen({super.key, this.initialCode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _roomService = RoomService();
  final _codeController = TextEditingController();
  bool _loading = false;

  Future<String?> _showNicknameDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierColor: const Color(0xFF202633).withOpacity(0.45),
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final trimmed = controller.text.trim();

            void submit() {
              if (trimmed.isNotEmpty) Navigator.of(dialogContext).pop(trimmed);
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF202633).withOpacity(0.18),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '어떤 이름으로\n들어갈까요?',
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF202633),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFEAE4DD)),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFDFA), Color(0xFFFFF4ED)],
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                autofocus: true,
                                maxLength: 10,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF202633),
                                ),
                                decoration: const InputDecoration(
                                  hintText: '예) 홍길동',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFC7CCD5),
                                    fontWeight: FontWeight.w800,
                                  ),
                                  counterText: '',
                                  border: InputBorder.none,
                                ),
                                onChanged: (_) => setDialogState(() {}),
                                onSubmitted: (_) => submit(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(null),
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                backgroundColor: const Color(0xFFF4F1EE),
                                foregroundColor: AppColors.muted,
                              ),
                              child: const Text(
                                '취소',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.headerGradient,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.28),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: FilledButton(
                                onPressed: trimmed.isEmpty ? null : submit,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  '입장하기',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinRoom());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final nickname = await _showNicknameDialog();
    if (nickname == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final user = await _authService.signInAnonymously();
      final room = await _roomService.createRoom(user.uid, nickname);
      if (mounted) context.go('/lobby/${room.id}?host=true');
    } catch (e) {
      if (mounted) {
        _showError('오류: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showError('6자리 코드를 입력해주세요');
      return;
    }
    final nickname = await _showNicknameDialog();
    if (nickname == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final user = await _authService.signInAnonymously();
      final room = await _roomService.findRoomByCode(code);
      if (room == null) {
        if (mounted) _showError('방을 찾을 수 없어요 🥲');
        return;
      }
      await _roomService.joinRoom(room.id, user.uid, nickname);
      if (mounted) context.go('/lobby/${room.id}');
    } catch (e) {
      if (mounted) _showError('오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildBackgroundGlow(),
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  children: [
                    _buildIntroSection(),
                    const SizedBox(height: 18),
                    _buildActionSection(),

                    if (_loading) ...[
                      const SizedBox(height: 28),
                      const CircularProgressIndicator(color: AppColors.primary),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return IgnorePointer(
      child: SizedBox(
        height: 0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -120,
              left: 40,
              right: 40,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.12),
                      blurRadius: 140,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    return _GlassSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'START',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '지금 바로 메뉴 정하기',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF202633),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'AI PICK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _GradientButton(
            gradient: AppColors.headerGradient,
            onPressed: _loading ? null : _createRoom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                const Text(
                  '방 만들기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Divider(thickness: 1, color: Color(0xFFE9E3DD)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '또는 코드로 입장',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(thickness: 1, color: Color(0xFFE9E3DD)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CodeInputField(controller: _codeController),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _loading ? null : _joinRoom,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF202633),
                backgroundColor: const Color(0xFFF8F5F2),
                side: const BorderSide(color: Color(0xFFD9DEE6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '입장하기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(
              child: _FeatureCard(
                imageAsset: 'assets/like.png',
                title: '먹고 싶은 음식',
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _FeatureCard(
                imageAsset: 'assets/hate.png',
                title: '먹기 싫은 음식',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF202633), Color(0xFF343B4F), Color(0xFFFF925B)],
            stops: [0.0, 0.46, 1.0],
          ),
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B2520).withOpacity(0.16),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -12,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '뭐 먹을건데',
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'AI가 모두의 먹고 싶은 것과 먹기 싫은 것을 분석해 최적의 메뉴를 추천해요.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xD9FFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        'assets/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 그라데이션 버튼 위젯
class _GradientButton extends StatelessWidget {
  final LinearGradient gradient;
  final VoidCallback? onPressed;
  final Widget child;

  const _GradientButton({
    required this.gradient,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: onPressed == null
                  ? LinearGradient(
                      colors: [Colors.grey[300]!, Colors.grey[400]!],
                    )
                  : gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: onPressed == null
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ── 코드 입력 필드 위젯
class _CodeInputField extends StatelessWidget {
  final TextEditingController controller;

  const _CodeInputField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAE4DD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        textAlign: TextAlign.center,
        maxLength: 6,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          UpperCaseTextFormatter(),
        ],
        style: const TextStyle(
          fontSize: 28,
          letterSpacing: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF202633),
        ),
        decoration: InputDecoration(
          hintText: 'ABC123',
          hintStyle: const TextStyle(
            color: Color(0xFFD1C7C0),
            letterSpacing: 10,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassSection({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF343B4F).withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String imageAsset;
  final String title;

  const _FeatureCard({required this.imageAsset, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.secondary.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF343B4F).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Image.asset(imageAsset, height: 68, fit: BoxFit.contain),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E241F),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step;
  final String emoji;
  final String title;
  final String description;

  const _StepTile({
    required this.step,
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE8E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E9),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF202633),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
