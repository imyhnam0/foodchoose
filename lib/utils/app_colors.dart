import 'package:flutter/material.dart';

class AppColors {
  /// 주 강조색: 따뜻한 오렌지 — CTA 버튼, 주요 포인트
  static const Color primary = Color(0xFFFF6B35);

  /// 보조색도 주황 계열로 통일
  static const Color secondary = Color(0xFFFF8C69);

  /// 민트: 먹고 싶은 음식 (긍정)
  static const Color mint = Color(0xFF00B894);

  /// 살몬: 먹기 싫은 음식 (부정)
  static const Color salmon = Color(0xFFE17055);

  /// 앰버: 강조, 배지
  static const Color amber = Color(0xFFFDB74A);

  /// 따뜻한 크림 배경
  static const Color background = Color(0xFFFFF9F5);

  /// 카드/서피스 흰색
  static const Color surface = Color(0xFFFFFFFF);

  /// 기본 텍스트
  static const Color text = Color(0xFF2D3436);

  /// 보조 텍스트
  static const Color muted = Color(0xFF636E72);

  /// 테두리
  static const Color border = Color(0xFFDFE6E9);

  static final Color secondaryMuted = secondary.withOpacity(0.08);
  static final Color primaryMuted = primary.withOpacity(0.10);
  static final Color mintMuted = mint.withOpacity(0.12);
  static final Color salmonMuted = salmon.withOpacity(0.10);

  /// 그라데이션 — 홈 헤더
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B35), Color(0xFFFF8C69)],
  );

  /// 그라데이션 — 결과 화면용 오렌지
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A45), Color(0xFFFFA07A)],
  );

  /// 그라데이션 — 최종 결과 황금
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B35), Color(0xFFFDB74A)],
  );
}
