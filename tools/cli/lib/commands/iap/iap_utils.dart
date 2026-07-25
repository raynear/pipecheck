/// IAP 관련 유틸리티 함수.
library;

/// 상품 ID에서 Dart 상수명을 생성합니다.
///
/// 예: "com.example.app.coins_100" -> "coins100"
/// 예: "com.example.app.premium_monthly" -> "premiumMonthly"
String toConstantName(String productId) {
  // 마지막 점(.) 이후의 부분만 사용
  final lastPart = productId.contains('.')
      ? productId.substring(productId.lastIndexOf('.') + 1)
      : productId;

  // snake_case를 camelCase로 변환
  final parts = lastPart.split('_');
  final first = parts.first;
  final rest = parts.skip(1).map((part) {
    if (part.isEmpty) return '';
    return part[0].toUpperCase() + part.substring(1);
  });

  return first + rest.join();
}

/// 언어 코드를 Android 로케일 형식으로 변환합니다.
///
/// 예: "ko" -> "ko-KR", "en" -> "en-US", "ja" -> "ja-JP"
String toAndroidLocale(String langCode) {
  const localeMap = {
    'ko': 'ko-KR',
    'en': 'en-US',
    'ja': 'ja-JP',
    'zh': 'zh-CN',
    'de': 'de-DE',
    'fr': 'fr-FR',
    'es': 'es-ES',
    'pt': 'pt-BR',
  };
  return localeMap[langCode] ?? '$langCode-${langCode.toUpperCase()}';
}

/// 상품 ID에서 base plan ID를 추출합니다.
///
/// 예: "com.example.app.premium_monthly" -> "premium-monthly"
String extractBasePlanId(String productId) {
  final lastPart = productId.contains('.')
      ? productId.substring(productId.lastIndexOf('.') + 1)
      : productId;
  return lastPart.replaceAll('_', '-');
}
