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
    // 참가자별 개별 데이터를 구성 (익명 번호로)
    final participantData = StringBuffer();
    for (var i = 0; i < prefs.length; i++) {
      final p = prefs[i];
      final wants = p.wantFoods.where((f) => f.trim().isNotEmpty).toList();
      final donts = p.dontWantFoods.where((f) => f.trim().isNotEmpty).toList();
      participantData.writeln('참가자${i + 1}:');
      participantData.writeln('  먹고 싶은 음식: ${wants.join(", ")}');
      if (donts.isNotEmpty) {
        participantData.writeln('  먹기 싫은 음식: ${donts.join(", ")}');
      }
    }

    final prompt =
        '''
당신은 음식 추천 AI입니다.
아래 참가자별 선호도를 분석해서 모두가 최대한 만족할 음식 3가지를 추천하세요.

[참가자별 선호 데이터]
전체 인원: ${prefs.length}명
$participantData
[분석 방법 — 반드시 아래 단계를 순서대로 따르세요]

1단계: 겹치는 메뉴 확인
- 2명 이상이 먹고 싶다고 고른 동일 메뉴가 있으면 우선 후보로 올립니다.

2단계: 거부 메뉴 제거
- 누구라도 "먹기 싫은 음식"에 넣은 메뉴는 후보에서 제외합니다.
- 해당 메뉴와 매우 유사한 계열(예: 회↔초밥)도 가급적 피합니다.

3단계: 취향 유형 분석 (후보가 부족할 때)
- 각 참가자가 고른 음식들의 공통 유형/카테고리를 파악합니다.
  (예: 치킨+떡볶이+라면 → "한식 분식류 선호", 파스타+피자 → "양식 선호")
- "이런 종류의 음식을 좋아하는 사람은 통계적으로 이런 음식도 좋아한다"는 관점에서
  모든 참가자의 취향 유형이 교차하는 메뉴를 찾아 추천합니다.

4단계: 최종 3개 선정
- 위 단계를 종합해 모두가 먹어도 불만이 적을 음식 3개를 확정합니다.
- 거부 메뉴와 겹치지 않는지 최종 확인합니다.

[출력 규칙]
- 추천 이유는 익명성을 유지하세요. "참가자1", "A님" 같은 표현 절대 금지.
- "여러 명이 원함", "분식 취향과 양식 취향의 접점" 같은 표현을 사용하세요.
- 각 reason은 25자 이내의 짧은 한 문장으로 작성하세요.

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

  String _sanitizeReason(String input) {
    var text = input.trim();
    text = text.replaceAll(RegExp(r'참가자\s*\d+'), '누군가');
    text = text.replaceAll(RegExp(r'참가자들?'), '여러 명');
    text = text.replaceAll(RegExp(r'[A-Z]\s*님'), '누군가');
    text = text.replaceAll(RegExp(r'\b\d+번\b'), '누군가');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    if (text.length > 28) {
      text = '${text.substring(0, 28).trim()}...';
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
