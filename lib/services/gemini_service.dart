import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/preference.dart';
import '../utils/constants.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: geminiApiKey,
    );
  }

  Future<({List<String> foods, Map<String, String> reasons})> recommendTop3(
    List<Preference> prefs,
  ) async {
    final wantCounts = <String, int>{};
    final dontWantCounts = <String, int>{};

    for (final p in prefs) {
      for (final food in p.wantFoods) {
        final normalized = food.trim();
        if (normalized.isEmpty) continue;
        wantCounts[normalized] = (wantCounts[normalized] ?? 0) + 1;
      }
      for (final food in p.dontWantFoods) {
        final normalized = food.trim();
        if (normalized.isEmpty) continue;
        dontWantCounts[normalized] = (dontWantCounts[normalized] ?? 0) + 1;
      }
    }

    final buffer = StringBuffer()
      ..writeln('전체 인원: ${prefs.length}명')
      ..writeln('먹고 싶다는 의견: ${_formatCountSummary(wantCounts)}')
      ..writeln('먹기 싫다는 의견: ${_formatCountSummary(dontWantCounts)}');

    final prompt =
        '''
당신은 음식 추천 AI 재미나이입니다.
아래 집계된 익명 선호도만 보고 모두가 만족할 음식 3가지를 추천하세요.

[익명 집계 데이터]
$buffer
[분석 지침]
- 여러 사람이 좋아한 메뉴와 피하고 싶어한 메뉴를 함께 고려하세요.
- 싫어한다는 의견이 많은 메뉴나 그와 가까운 계열은 피하세요.
- 추천 이유는 익명성이 드러나게 아주 짧게 쓰세요.
- 절대 "참가자 1", "참가자2", "A님", "누구가" 같은 식별 표현을 쓰지 마세요.
- "누군가 좋아함", "2명이 원함", "여러 명이 무난하게 먹기 좋음" 같은 표현만 사용하세요.
- 각 reason은 20자 안팎의 짧은 한 문장으로 작성하세요.

[출력 형식] JSON만 반환 (설명 없이):
{
  "recommendations": [
    {"food": "음식1", "reason": "짧은 익명 이유"},
    {"food": "음식2", "reason": "..."},
    {"food": "음식3", "reason": "..."}
  ]
}
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{}';

    final jsonStr = _extractJsonObject(text);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = decoded['recommendations'] as List<dynamic>;

    final foods = <String>[];
    final reasons = <String, String>{};
    for (final item in list.take(3)) {
      final food = item['food'] as String;
      final reason = _sanitizeReason(item['reason'] as String);
      foods.add(food);
      reasons[food] = reason;
    }

    return (foods: foods, reasons: reasons);
  }

  String _formatCountSummary(Map<String, int> counts) {
    if (counts.isEmpty) return '없음';

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).map((e) => '${e.key} ${e.value}명').join(', ');
  }

  String _sanitizeReason(String input) {
    var text = input.trim();
    text = text.replaceAll(RegExp(r'참가자\s*\d+'), '누군가');
    text = text.replaceAll(RegExp(r'참가자들?'), '여러 명');
    text = text.replaceAll(RegExp(r'[A-Z]\s*님'), '누군가');
    text = text.replaceAll(RegExp(r'\b\d+번\b'), '누군가');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    if (text.length > 24) {
      text = '${text.substring(0, 24).trim()}...';
    }

    if (text.isEmpty) {
      return '여러 명이 무난하게 먹기 좋아요.';
    }

    return text;
  }

  String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) return '{"recommendations":[]}';
    return text.substring(start, end + 1);
  }
}
