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
    final buffer = StringBuffer();
    for (var i = 0; i < prefs.length; i++) {
      final p = prefs[i];
      final wantStr = p.wantFoods.isEmpty ? '없음' : p.wantFoods.join(', ');
      final dontStr =
          p.dontWantFoods.isEmpty ? '없음' : p.dontWantFoods.join(', ');
      buffer.writeln('참가자 ${i + 1}:');
      buffer.writeln('  먹고 싶은 음식: $wantStr');
      buffer.writeln('  먹기 싫은 음식: $dontStr');
    }

    final prompt = '''
당신은 음식 추천 AI 재미나이입니다.
각 참가자의 선호도를 아래와 같이 개별 분석한 뒤, 모두가 만족할 음식 3가지를 추천하세요.

[참가자별 선호도]
$buffer
[분석 지침]
- 각 참가자가 좋아하는 음식의 유형/카테고리(예: 분식류, 양식류)를 파악하세요.
- 싫어하는 음식이 있다면 해당 유형을 피하세요.
- 여러 참가자의 공통점을 찾아 모두가 만족할 3가지 음식을 선정하세요.

[출력 형식] JSON만 반환 (설명 없이):
{
  "recommendations": [
    {"food": "음식1", "reason": "참가자들의 선호를 분석해 선정한 이유 1~2문장"},
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
      final reason = item['reason'] as String;
      foods.add(food);
      reasons[food] = reason;
    }

    return (foods: foods, reasons: reasons);
  }

  String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) return '{"recommendations":[]}';
    return text.substring(start, end + 1);
  }
}
