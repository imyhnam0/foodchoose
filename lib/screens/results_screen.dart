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
  final _restaurantController = TextEditingController();

  final List<String> _restaurantInputs = [];
  final Set<String> _myVotes = {};
  final Set<String> _revoteSelections = {};

  bool _submittingRestaurants = false;
  bool _hasSubmittedRestaurants = false;
  bool _loadingRestaurantState = true;
  bool _voteSubmitted = false;
  bool _voteSubmitting = false;
  bool _buildingCandidates = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurantState();
  }

  Future<void> _loadRestaurantState() async {
    final userId = _authService.userId;
    if (userId == null) return;
    try {
      final submitted = await _roomService.hasSubmittedRestaurantSuggestions(
        widget.roomId,
        userId,
      );
      if (!mounted) return;
      setState(() {
        _hasSubmittedRestaurants = submitted;
        _loadingRestaurantState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRestaurantState = false);
    }
  }

  void _addRestaurant() {
    final value = _restaurantController.text.trim();
    if (value.isEmpty || _restaurantInputs.contains(value)) return;
    setState(() {
      _restaurantInputs.add(value);
      _restaurantController.clear();
    });
  }

  void _removeRestaurant(String value) {
    setState(() => _restaurantInputs.remove(value));
  }

  Future<void> _submitRestaurants() async {
    if (_restaurantInputs.isEmpty || _submittingRestaurants) return;
    final userId = _authService.userId;
    if (userId == null) return;

    setState(() => _submittingRestaurants = true);
    try {
      await _roomService.submitRestaurantSuggestions(
        widget.roomId,
        userId,
        _restaurantInputs,
      );
      if (!mounted) return;
      setState(() {
        _hasSubmittedRestaurants = true;
        _submittingRestaurants = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingRestaurants = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('음식점 제출 오류: $e')));
    }
  }

  Future<void> _buildCandidatesIfNeeded(Room room) async {
    if (_buildingCandidates) return;
    setState(() => _buildingCandidates = true);
    try {
      final candidates = await _roomService.getRestaurantCandidates(room.id);
      if (candidates.isEmpty) {
        await _roomService.startRestaurantInput(room.id);
      } else {
        await _roomService.saveRestaurantCandidates(room.id, candidates);
      }
    } finally {
      if (mounted) setState(() => _buildingCandidates = false);
    }
  }

  Future<void> _submitVotes(Room room) async {
    if (_voteSubmitted || _myVotes.isEmpty || _voteSubmitting) return;
    setState(() => _voteSubmitting = true);
    try {
      await _roomService.submitRestaurantVotes(room.id, _myVotes.toList());
      if (!mounted) return;
      setState(() {
        _voteSubmitted = true;
        _voteSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _voteSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('투표 저장 오류: $e')));
    }
  }

  Future<void> _pickRandom(Room room) async {
    final foods = room.recommendations;
    if (foods.isEmpty) return;
    final food = foods[Random().nextInt(foods.length)];
    await _roomService.setFinalFood(room.id, food, 'random');
  }

  Future<void> _finalizeVotes(Room room) async {
    if (room.votes.isEmpty) return;
    final winner = room.votes.entries.reduce((a, b) {
      return a.value >= b.value ? a : b;
    }).key;
    await _roomService.setFinalFood(room.id, winner, 'vote');
  }

  Future<void> _startRevote(Room room) async {
    if (room.recommendations.length < 2) return;
    setState(() {
      _revoteSelections
        ..clear()
        ..addAll(room.recommendations);
    });
    await _roomService.startRestaurantRevoteSelection(room.id);
  }

  Future<void> _confirmRevote(Room room) async {
    if (_revoteSelections.length < 2) return;
    await _roomService.resetRestaurantVotes(
      room.id,
      _revoteSelections.toList(),
    );
    if (!mounted) return;
    setState(() {
      _myVotes.clear();
      _voteSubmitted = false;
      _voteSubmitting = false;
      _revoteSelections.clear();
    });
  }

  @override
  void dispose() {
    _restaurantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room>(
      stream: _roomService.roomStream(widget.roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || _loadingRestaurantState) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final room = snapshot.data!;
        final isHost = room.hostId == _authService.userId;

        if (room.status == 'category_done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/final/${room.id}');
          });
        }

        if (room.status == 'done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/final/${room.id}');
          });
        }

        if (room.status == 'restaurant_inputting' &&
            room.restaurantSubmittedCount >= room.participantCount &&
            room.participantCount > 0 &&
            !_buildingCandidates) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _buildCandidatesIfNeeded(room);
          });
        }

        if (room.status == 'restaurant_voting' &&
            room.votedCount >= room.participantCount &&
            room.participantCount > 0 &&
            room.finalFood == null &&
            isHost) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _finalizeVotes(room);
          });
        }

        if (room.status == 'restaurant_inputting') {
          return _buildRestaurantInput(room);
        }

        if (room.status == 'restaurant_revote_select') {
          return _buildRevoteSelect(room, isHost);
        }

        return _buildRestaurantVoting(room, isHost);
      },
    );
  }

  Widget _buildRestaurantInput(Room room) {
    final submitted = room.restaurantSubmittedCount;
    final total = room.participantCount;
    final remaining = max(0, total - submitted);

    if (_hasSubmittedRestaurants) {
      return _buildWaitingShell(
        title: '음식점 입력 대기 중',
        message: '지금 $submitted명이 입력했고\n$remaining명이 더 입력해야 해요',
        submitted: submitted,
        total: total,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader('음식점 입력'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (room.selectedCategory != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '선택된 메뉴 카테고리: ${room.selectedCategory}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    const Text(
                      '먹고 싶은 음식점을 여러 개 입력해주세요',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _restaurantController,
                            decoration: InputDecoration(
                              hintText: '예: 교촌치킨 강남점',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onSubmitted: (_) => _addRestaurant(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _addRestaurant,
                          child: const Text('추가'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _restaurantInputs
                          .map(
                            (value) => Chip(
                              label: Text(value),
                              onDeleted: () => _removeRestaurant(value),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _submittingRestaurants || _restaurantInputs.isEmpty
                      ? null
                      : _submitRestaurants,
                  child: Text(_submittingRestaurants ? '제출 중...' : '제출하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantVoting(Room room, bool isHost) {
    final allVoted =
        room.participantCount > 0 && room.votedCount >= room.participantCount;

    if (_voteSubmitted && !allVoted) {
      return _buildWaitingShell(
        title: '투표 대기 중',
        message:
            '지금 ${room.votedCount}명이 투표했고\n${max(0, room.participantCount - room.votedCount)}명이 더 투표해야 해요',
        submitted: room.votedCount,
        total: room.participantCount,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader('음식점 후보'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (room.selectedCategory != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '메뉴 카테고리: ${room.selectedCategory}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ...room.recommendations.map((food) {
                    final selected = _myVotes.contains(food);
                    final count = room.votes[food] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        tileColor: Colors.white,
                        title: Text(
                          food,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: allVoted ? Text('$count표') : null,
                        trailing: !allVoted
                            ? Checkbox(
                                value: selected,
                                onChanged: _voteSubmitted
                                    ? null
                                    : (_) {
                                        setState(() {
                                          if (selected) {
                                            _myVotes.remove(food);
                                          } else {
                                            _myVotes.add(food);
                                          }
                                        });
                                      },
                              )
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  if (!allVoted)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _myVotes.isEmpty || _voteSubmitting
                            ? null
                            : () => _submitVotes(room),
                        child: Text(_voteSubmitting ? '투표 중...' : '투표 제출'),
                      ),
                    ),
                  if (isHost && !allVoted) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => _pickRandom(room),
                        child: const Text('랜덤으로 선택하기'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevoteSelect(Room room, bool isHost) {
    if (!isHost) {
      return _buildWaitingShell(
        title: '재투표 준비 중',
        message: '방장이 다시 투표할 음식점을 고르고 있어요',
        submitted: 0,
        total: 0,
        hideProgress: true,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader('재투표 후보 선택'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: room.recommendations.map((food) {
                  final selected = _revoteSelections.contains(food);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: (_) {
                        setState(() {
                          if (selected) {
                            _revoteSelections.remove(food);
                          } else {
                            _revoteSelections.add(food);
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      tileColor: Colors.white,
                      title: Text(
                        food,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _revoteSelections.length < 2
                      ? null
                      : () => _confirmRevote(room),
                  child: const Text('선택한 음식점으로 재투표'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingShell({
    required String title,
    required String message,
    required int submitted,
    required int total,
    bool hideProgress = false,
  }) {
    final progress = total > 0 ? submitted / total : 0.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              if (!hideProgress) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(value: progress, minHeight: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      color: AppColors.surface,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}
