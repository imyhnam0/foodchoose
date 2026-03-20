import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../utils/app_colors.dart';

class PreferenceInputScreen extends StatefulWidget {
  final String roomId;

  const PreferenceInputScreen({super.key, required this.roomId});

  @override
  State<PreferenceInputScreen> createState() => _PreferenceInputScreenState();
}

class _PreferenceInputScreenState extends State<PreferenceInputScreen> {
  final _authService = AuthService();
  final _roomService = RoomService();

  final _wantController = TextEditingController();
  final _dontWantController = TextEditingController();

  final List<String> _wantFoods = [];
  final List<String> _dontWantFoods = [];
  bool _submitted = false;

  static const _minWant = 3;

  void _addTag(
      String text, List<String> list, TextEditingController controller) {
    final val = text.trim();
    if (val.isEmpty || list.contains(val)) return;
    setState(() => list.add(val));
    controller.clear();
  }

  void _removeTag(String tag, List<String> list) {
    setState(() => list.remove(tag));
  }

  Future<void> _submit() async {
    if (_wantFoods.length < _minWant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('먹고 싶은 음식을 3개 이상 입력해주세요 🙏'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    setState(() => _submitted = true);
    try {
      final userId = _authService.userId!;
      await _roomService.submitPreference(
        widget.roomId,
        userId,
        _wantFoods,
        _dontWantFoods,
      );
      if (mounted) context.go('/waiting/${widget.roomId}');
    } catch (e) {
      if (mounted) {
        setState(() => _submitted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_wantFoods.length / _minWant).clamp(0.0, 1.0);
    final readyToSubmit = _wantFoods.length >= _minWant;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 헤더
            _buildHeader(progress),

            // ── 스크롤 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    // 먹고 싶은 음식 섹션
                    _FoodInputSection(
                      emoji: '😋',
                      title: '먹고 싶은 음식',
                      subtitle: '최소 3개 입력해주세요',
                      hint: '치킨, 피자, 떡볶이...',
                      controller: _wantController,
                      foods: _wantFoods,
                      themeColor: AppColors.mint,
                      bgColor: AppColors.mintMuted,
                      onAdd: (v) =>
                          _addTag(v, _wantFoods, _wantController),
                      onRemove: (tag) => _removeTag(tag, _wantFoods),
                    ),

                    const SizedBox(height: 16),

                    // 먹기 싫은 음식 섹션
                    _FoodInputSection(
                      emoji: '🙅',
                      title: '먹기 싫은 음식',
                      subtitle: '선택사항이에요',
                      hint: '초밥, 회, 곱창...',
                      controller: _dontWantController,
                      foods: _dontWantFoods,
                      themeColor: AppColors.salmon,
                      bgColor: AppColors.salmonMuted,
                      onAdd: (v) =>
                          _addTag(v, _dontWantFoods, _dontWantController),
                      onRemove: (tag) =>
                          _removeTag(tag, _dontWantFoods),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── 하단 제출 버튼 (고정)
            _buildSubmitBar(readyToSubmit),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('🍴', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '음식 선호도 입력',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '솔직하게 입력할수록 추천이 정확해져요!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 진행도 바
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.mint),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_wantFoods.length}/$_minWant',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _wantFoods.length >= _minWant
                      ? AppColors.mint
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar(bool readyToSubmit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: (_submitted || !readyToSubmit) ? null : _submit,
            child: Ink(
              decoration: BoxDecoration(
                gradient: readyToSubmit && !_submitted
                    ? AppColors.headerGradient
                    : LinearGradient(
                        colors: [Colors.grey[300]!, Colors.grey[350]!]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: readyToSubmit && !_submitted
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: _submitted
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        readyToSubmit
                            ? '✅ 제출하기!'
                            : '먹고 싶은 음식을 ${_minWant - _wantFoods.length}개 더 입력해주세요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: readyToSubmit ? Colors.white : AppColors.muted,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wantController.dispose();
    _dontWantController.dispose();
    super.dispose();
  }
}

class _FoodInputSection extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String hint;
  final TextEditingController controller;
  final List<String> foods;
  final Color themeColor;
  final Color bgColor;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _FoodInputSection({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.controller,
    required this.foods,
    required this.themeColor,
    required this.bgColor,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: themeColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 입력 필드
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        TextStyle(color: AppColors.muted.withOpacity(0.6)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeColor, width: 2),
                    ),
                  ),
                  onSubmitted: onAdd,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onAdd(controller.text),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),

          if (foods.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: foods
                  .map((f) => _FoodChip(
                        label: f,
                        color: themeColor,
                        bgColor: bgColor,
                        onRemove: () => onRemove(f),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FoodChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onRemove;

  const _FoodChip({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: color),
          ),
        ],
      ),
    );
  }
}
