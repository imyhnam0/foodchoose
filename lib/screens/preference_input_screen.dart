import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';

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

  void _addTag(String text, List<String> list, TextEditingController controller) {
    final val = text.trim();
    if (val.isEmpty || list.contains(val)) return;
    setState(() => list.add(val));
    controller.clear();
  }

  void _removeTag(String tag, List<String> list) {
    setState(() => list.remove(tag));
  }

  Future<void> _submit() async {
    if (_wantFoods.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먹고 싶은 음식을 3개 이상 입력해주세요')),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Widget _tagChip(String label, List<String> list, Color color) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () => _removeTag(label, list),
      backgroundColor: color.withAlpha(30),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withAlpha(80)),
    );
  }

  Widget _tagInput({
    required String hint,
    required TextEditingController controller,
    required List<String> list,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (v) => _addTag(v, list, controller),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _addTag(controller.text, list, controller),
          icon: const Icon(Icons.add_circle),
          color: color,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE85D04),
        foregroundColor: Colors.white,
        title: const Text('음식 선호도 입력'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🙂 먹고 싶은 음식',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '최소 3개 입력해주세요',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _tagInput(
                hint: '예: 치킨, 피자...',
                controller: _wantController,
                list: _wantFoods,
                color: const Color(0xFFE85D04),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _wantFoods
                    .map((f) =>
                        _tagChip(f, _wantFoods, const Color(0xFFE85D04)))
                    .toList(),
              ),
              const SizedBox(height: 32),
              const Text(
                '😞 먹기 싫은 음식',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '선택사항이에요',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _tagInput(
                hint: '예: 초밥, 회...',
                controller: _dontWantController,
                list: _dontWantFoods,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _dontWantFoods
                    .map((f) => _tagChip(f, _dontWantFoods, Colors.blueGrey))
                    .toList(),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitted ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE85D04),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitted
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          '제출 (${_wantFoods.length}/3)',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
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
