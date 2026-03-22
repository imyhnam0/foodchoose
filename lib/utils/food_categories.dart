import '../models/preference.dart';

const List<String> kFoodCategories = [
  '버거',
  '치킨',
  '구이',
  '피자',
  '족발',
  '보쌈',
  '한식',
  '분식',
  '돈까스',
  '찜/탕',
  '중식',
  '일식',
  '회/해물',
  '양식',
  '커피/차',
  '디저트',
  '간식',
  '아시안',
  '샌드위치',
  '샐러드',
  '멕시칸',
  '도시락',
  '죽',
];

const int kWantWeight = 1;

class WeightedFoodResult {
  final String food;
  final int score;
  final int wantCount;
  final int dontWantCount;

  const WeightedFoodResult({
    required this.food,
    required this.score,
    required this.wantCount,
    required this.dontWantCount,
  });

  String get summary {
    if (dontWantCount == 0) {
      return '먹고 싶음 $wantCount명, 총점 $score점';
    }
    return '먹고 싶음 $wantCount명, 먹기 싫음 $dontWantCount명, 총점 $score점';
  }
}

WeightedFoodResult? calculateTopFood(List<Preference> preferences) {
  final scores = {for (final food in kFoodCategories) food: 0};
  final wants = {for (final food in kFoodCategories) food: 0};
  final blockedFoods = <String>{};

  for (final preference in preferences) {
    for (final food in preference.wantFoods.toSet()) {
      if (!scores.containsKey(food)) continue;
      scores[food] = scores[food]! + kWantWeight;
      wants[food] = wants[food]! + 1;
    }

    for (final food in preference.dontWantFoods.toSet()) {
      if (!scores.containsKey(food)) continue;
      blockedFoods.add(food);
    }
  }

  final candidates = kFoodCategories.where((food) {
    return !blockedFoods.contains(food) && wants[food]! > 0;
  }).toList();

  if (candidates.isEmpty) {
    return null;
  }

  final ranked = candidates
    ..sort((a, b) {
      final scoreCompare = scores[b]!.compareTo(scores[a]!);
      if (scoreCompare != 0) return scoreCompare;

      final wantCompare = wants[b]!.compareTo(wants[a]!);
      if (wantCompare != 0) return wantCompare;

      return kFoodCategories.indexOf(a).compareTo(kFoodCategories.indexOf(b));
    });

  final topFood = ranked.first;
  return WeightedFoodResult(
    food: topFood,
    score: scores[topFood]!,
    wantCount: wants[topFood]!,
    dontWantCount: 0,
  );
}
