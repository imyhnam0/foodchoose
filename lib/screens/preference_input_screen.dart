import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../utils/app_colors.dart';
import '../utils/food_categories.dart';

class PreferenceInputScreen extends StatefulWidget {
  final String roomId;

  const PreferenceInputScreen({super.key, required this.roomId});

  @override
  State<PreferenceInputScreen> createState() => _PreferenceInputScreenState();
}

class _PreferenceInputScreenState extends State<PreferenceInputScreen> {
  final _authService = AuthService();
  final _roomService = RoomService();

  final List<String> _wantFoods = [];
  final List<String> _dontWantFoods = [];
  bool _submitted = false;
  String? _systemMessage;

  static const _minWant = 1;

  @override
  void initState() {
    super.initState();
    _loadSystemMessage();
  }

  Future<void> _loadSystemMessage() async {
    try {
      final room = await _roomService.roomStream(widget.roomId).first;
      if (!mounted) return;
      setState(() {
        _systemMessage = room.recommendationReasons['__systemMessage'];
      });
    } catch (_) {}
  }

  void _toggleFood(String food, List<String> target, List<String> other) {
    setState(() {
      if (target.contains(food)) {
        target.remove(food);
      } else {
        target.add(food);
        other.remove(food);
      }
    });
  }

  Future<void> _exitRoom() async {
    if (_submitted) return;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('방에서 나갈까요?'),
          content: const Text('지금까지 선택한 내용은 저장되지 않아요.'),
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

    if (shouldLeave != true || !mounted) return;

    try {
      final room = await _roomService.roomStream(widget.roomId).first;
      final uid = _authService.userId;

      if (room.hostId == uid) {
        await _roomService.deleteRoom(room.id);
      } else if (uid != null) {
        await _roomService.leaveRoom(room.id, uid);
      }

      await _authService.signOut();
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('방을 나가지 못했어요: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_wantFoods.length < _minWant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('좋아하는 음식 카테고리를 1개 이상 선택해주세요'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      if (!mounted) return;
      setState(() => _submitted = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyToSubmit = _wantFoods.length >= _minWant;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    if (_systemMessage != null) ...[
                      _buildSystemMessage(),
                      const SizedBox(height: 16),
                    ],
                    _FoodSelectSection(
                      imageAsset: 'assets/like.png',
                      title: '좋아하는 음식',
                      subtitle: '원하는 카테고리를 모두 선택해주세요',
                      foods: _wantFoods,
                      themeColor: AppColors.mint,
                      bgColor: AppColors.mintMuted,
                      onTap: (food) =>
                          _toggleFood(food, _wantFoods, _dontWantFoods),
                    ),
                    const SizedBox(height: 16),
                    _FoodSelectSection(
                      imageAsset: 'assets/hate.png',
                      title: '싫어하는 음식',
                      subtitle: '빼고 싶은 카테고리를 선택해주세요',
                      foods: _dontWantFoods,
                      themeColor: AppColors.salmon,
                      bgColor: AppColors.salmonMuted,
                      onTap: (food) =>
                          _toggleFood(food, _dontWantFoods, _wantFoods),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildSubmitBar(readyToSubmit),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '음식 카테고리 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      '좋아하는 것과 싫어하는 것을 골라주세요',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _submitted ? null : _exitRoom,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.only(left: 4, right: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '방 나가기',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.salmonMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.salmon.withOpacity(0.25)),
      ),
      child: Text(
        _systemMessage!,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          height: 1.5,
        ),
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
                        colors: [Colors.grey[300]!, Colors.grey[350]!],
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: readyToSubmit && !_submitted
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
                child: _submitted
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        readyToSubmit
                            ? '선택 완료하고 제출하기'
                            : '좋아하는 음식 카테고리를 1개 이상 선택해주세요',
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
}

class _FoodSelectSection extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String subtitle;
  final List<String> foods;
  final Color themeColor;
  final Color bgColor;
  final ValueChanged<String> onTap;

  const _FoodSelectSection({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.foods,
    required this.themeColor,
    required this.bgColor,
    required this.onTap,
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
                child: Image.asset(
                  imageAsset,
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kFoodCategories.map((food) {
              final selected = foods.contains(food);
              return GestureDetector(
                onTap: () => onTap(food),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? themeColor : bgColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? themeColor
                          : themeColor.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    food,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : themeColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
