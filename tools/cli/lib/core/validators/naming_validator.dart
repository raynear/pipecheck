/// 네이밍 컨벤션 검증기.
///
/// 프로젝트 이름, 패키지 이름, 번들 ID 등의 형식을 검증하고
/// 다양한 케이스 변환 유틸리티를 제공합니다.
class NamingConventionValidator {
  /// 패키지 이름 검증.
  ///
  /// Dart 패키지 이름 규칙:
  /// - 소문자와 숫자만 사용
  /// - 언더스코어(_)로 단어 구분
  /// - 숫자로 시작 불가
  /// - 예약어 사용 불가
  static ValidationResult validatePackageName(String name) {
    if (name.isEmpty) {
      return ValidationResult(
        isValid: false,
        error: '패키지 이름이 비어있습니다',
        suggestion: '유효한 패키지 이름을 입력하세요 (예: my_app)',
      );
    }

    // 소문자, 숫자, 언더스코어만 허용
    final validPattern = RegExp(r'^[a-z][a-z0-9_]*$');
    if (!validPattern.hasMatch(name)) {
      return ValidationResult(
        isValid: false,
        error: '패키지 이름은 소문자로 시작하고, 소문자, 숫자, 언더스코어만 포함해야 합니다',
        suggestion: '추천: ${toSnakeCase(name)}',
      );
    }

    // 연속된 언더스코어 체크
    if (name.contains('__')) {
      return ValidationResult(
        isValid: false,
        error: '연속된 언더스코어는 사용할 수 없습니다',
        suggestion: '추천: ${name.replaceAll(RegExp(r'_+'), '_')}',
      );
    }

    // 언더스코어로 끝나는지 체크
    if (name.endsWith('_')) {
      return ValidationResult(
        isValid: false,
        error: '패키지 이름은 언더스코어로 끝날 수 없습니다',
        suggestion: '추천: ${name.substring(0, name.length - 1)}',
      );
    }

    // Dart 예약어 체크
    if (_dartReservedWords.contains(name)) {
      return ValidationResult(
        isValid: false,
        error: '"$name"은 Dart 예약어입니다',
        suggestion: '다른 이름을 사용하세요 (예: ${name}_app)',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// 번들 ID 검증.
  ///
  /// 역방향 도메인 형식:
  /// - 최소 2개의 세그먼트 (com.example)
  /// - 각 세그먼트는 소문자와 숫자만
  /// - 숫자로 시작하는 세그먼트 불가
  static ValidationResult validateBundleId(String bundleId) {
    if (bundleId.isEmpty) {
      return ValidationResult(
        isValid: false,
        error: '번들 ID가 비어있습니다',
        suggestion: '유효한 번들 ID를 입력하세요 (예: com.example.myapp)',
      );
    }

    final segments = bundleId.split('.');

    // 최소 2개 세그먼트
    if (segments.length < 2) {
      return ValidationResult(
        isValid: false,
        error: '번들 ID는 최소 2개의 세그먼트가 필요합니다 (예: com.example)',
        suggestion: '추천: com.$bundleId',
      );
    }

    // 각 세그먼트 검증
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      if (segment.isEmpty) {
        return ValidationResult(
          isValid: false,
          error: '빈 세그먼트가 있습니다',
          suggestion: '연속된 점(.)을 제거하세요',
        );
      }

      // 소문자, 숫자만 허용 (언더스코어 제외 - 플랫폼 호환성)
      final validPattern = RegExp(r'^[a-z][a-z0-9]*$');
      if (!validPattern.hasMatch(segment)) {
        return ValidationResult(
          isValid: false,
          error: '세그먼트 "$segment"가 유효하지 않습니다 (소문자로 시작, 소문자와 숫자만)',
          suggestion: '추천: ${segment.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
        );
      }

      // Java 예약어 체크 (Android 호환성)
      if (_javaReservedWords.contains(segment)) {
        return ValidationResult(
          isValid: false,
          error: '세그먼트 "$segment"는 Java 예약어입니다',
          suggestion: '다른 이름을 사용하세요',
        );
      }
    }

    return const ValidationResult(isValid: true);
  }

  /// 앱 이름 검증.
  ///
  /// 표시 이름 규칙:
  /// - 1-30자 사이
  /// - 한글, 영문, 숫자, 공백 허용
  /// - 특수문자 제한적 허용
  static ValidationResult validateAppName(String appName) {
    if (appName.isEmpty) {
      return ValidationResult(
        isValid: false,
        error: '앱 이름이 비어있습니다',
        suggestion: '1-30자 사이의 앱 이름을 입력하세요',
      );
    }

    if (appName.length > 30) {
      return ValidationResult(
        isValid: false,
        error: '앱 이름이 너무 깁니다 (최대 30자)',
        suggestion: '추천: ${appName.substring(0, 30)}',
      );
    }

    // 허용 문자: 한글, 영문, 숫자, 공백, 일부 특수문자
    final validPattern = RegExp(r'^[\w\sㄱ-ㅎㅏ-ㅣ가-힣\-\.]+$');
    if (!validPattern.hasMatch(appName)) {
      return ValidationResult(
        isValid: false,
        error: '앱 이름에 허용되지 않는 문자가 포함되어 있습니다',
        suggestion: '한글, 영문, 숫자, 공백, 하이픈, 점만 사용하세요',
      );
    }

    // 공백으로 시작하거나 끝나는지 체크
    if (appName.startsWith(' ') || appName.endsWith(' ')) {
      return ValidationResult(
        isValid: false,
        error: '앱 이름은 공백으로 시작하거나 끝날 수 없습니다',
        suggestion: '추천: ${appName.trim()}',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// iOS 네이밍 규칙 검증.
  ///
  /// iOS Bundle Identifier 규칙:
  /// - 역방향 DNS 형식
  /// - 각 세그먼트는 영문자로 시작
  /// - 하이픈 허용 (권장하지 않음)
  static ValidationResult validateiOSBundleId(String bundleId) {
    if (bundleId.isEmpty) {
      return ValidationResult(
        isValid: false,
        error: '번들 ID가 비어있습니다',
        suggestion: '유효한 번들 ID를 입력하세요 (예: com.example.myapp)',
      );
    }

    final segments = bundleId.split('.');

    // 최소 2개 세그먼트
    if (segments.length < 2) {
      return ValidationResult(
        isValid: false,
        error: '번들 ID는 최소 2개의 세그먼트가 필요합니다 (예: com.example)',
        suggestion: '추천: com.$bundleId',
      );
    }

    // 각 세그먼트 검증 (iOS는 하이픈 허용)
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      if (segment.isEmpty) {
        return ValidationResult(
          isValid: false,
          error: '빈 세그먼트가 있습니다',
          suggestion: '연속된 점(.)을 제거하세요',
        );
      }

      // iOS는 소문자, 숫자, 하이픈 허용
      final validPattern = RegExp(r'^[a-z][a-z0-9\-]*$');
      if (!validPattern.hasMatch(segment)) {
        return ValidationResult(
          isValid: false,
          error: '세그먼트 "$segment"가 유효하지 않습니다 (소문자로 시작, 소문자, 숫자, 하이픈만)',
          suggestion: '추천: ${segment.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '')}',
        );
      }
    }

    // 하이픈 사용 시 권장 사항 제공
    if (bundleId.contains('-')) {
      return ValidationResult(
        isValid: true,
        error: null,
        suggestion: '하이픈 대신 언더스코어 없이 연결된 단어 사용 권장',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Android 네이밍 규칙 검증.
  ///
  /// Android Application ID 규칙:
  /// - 역방향 DNS 형식
  /// - Java 패키지 이름 규칙 준수
  /// - 언더스코어 사용 가능
  static ValidationResult validateAndroidApplicationId(String applicationId) {
    if (applicationId.isEmpty) {
      return ValidationResult(
        isValid: false,
        error: 'Application ID가 비어있습니다',
        suggestion: '유효한 Application ID를 입력하세요 (예: com.example.my_app)',
      );
    }

    final segments = applicationId.split('.');

    if (segments.length < 2) {
      return ValidationResult(
        isValid: false,
        error: 'Application ID는 최소 2개의 세그먼트가 필요합니다',
        suggestion: '추천: com.$applicationId',
      );
    }

    for (final segment in segments) {
      if (segment.isEmpty) {
        return ValidationResult(
          isValid: false,
          error: '빈 세그먼트가 있습니다',
          suggestion: '연속된 점(.)을 제거하세요',
        );
      }

      // Android는 언더스코어 허용
      final validPattern = RegExp(r'^[a-z][a-z0-9_]*$');
      if (!validPattern.hasMatch(segment)) {
        return ValidationResult(
          isValid: false,
          error: '세그먼트 "$segment"가 유효하지 않습니다',
          suggestion: '소문자로 시작하고 소문자, 숫자, 언더스코어만 사용하세요',
        );
      }

      if (_javaReservedWords.contains(segment)) {
        return ValidationResult(
          isValid: false,
          error: '세그먼트 "$segment"는 Java 예약어입니다',
          suggestion: '다른 이름을 사용하세요',
        );
      }
    }

    return const ValidationResult(isValid: true);
  }

  /// 문자열을 camelCase로 변환.
  ///
  /// 예: "my_app_name" -> "myAppName"
  static String toCamelCase(String input) {
    if (input.isEmpty) return input;

    final words = _splitIntoWords(input);
    if (words.isEmpty) return input;

    return words.first.toLowerCase() +
        words.skip(1).map((w) => _capitalize(w)).join();
  }

  /// 문자열을 PascalCase로 변환.
  ///
  /// 예: "my_app_name" -> "MyAppName"
  static String toPascalCase(String input) {
    if (input.isEmpty) return input;

    final words = _splitIntoWords(input);
    return words.map((w) => _capitalize(w)).join();
  }

  /// 문자열을 snake_case로 변환.
  ///
  /// 예: "MyAppName" -> "my_app_name"
  static String toSnakeCase(String input) {
    if (input.isEmpty) return input;

    final words = _splitIntoWords(input);
    return words.map((w) => w.toLowerCase()).join('_');
  }

  /// 문자열을 kebab-case로 변환.
  ///
  /// 예: "MyAppName" -> "my-app-name"
  static String toKebabCase(String input) {
    if (input.isEmpty) return input;

    final words = _splitIntoWords(input);
    return words.map((w) => w.toLowerCase()).join('-');
  }

  /// 문자열을 CONSTANT_CASE로 변환.
  ///
  /// 예: "myAppName" -> "MY_APP_NAME"
  static String toConstantCase(String input) {
    if (input.isEmpty) return input;

    final words = _splitIntoWords(input);
    return words.map((w) => w.toUpperCase()).join('_');
  }

  /// 입력 문자열을 단어 목록으로 분리.
  static List<String> _splitIntoWords(String input) {
    // 언더스코어, 하이픈, 공백으로 먼저 분리
    var words = input
        .replaceAll(RegExp(r'[-_\s]+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

    // camelCase/PascalCase 분리
    final result = <String>[];
    for (final word in words) {
      // 대문자 앞에서 분리
      final camelSplit = word.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (m) => '${m.group(1)} ${m.group(2)}',
      );
      result.addAll(camelSplit.split(' ').where((w) => w.isNotEmpty));
    }

    return result;
  }

  /// 첫 글자를 대문자로 변환.
  static String _capitalize(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }

  /// Dart 예약어 목록.
  static const _dartReservedWords = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  /// Java 예약어 목록 (Android 호환성).
  static const _javaReservedWords = {
    'abstract',
    'assert',
    'boolean',
    'break',
    'byte',
    'case',
    'catch',
    'char',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'double',
    'else',
    'enum',
    'extends',
    'final',
    'finally',
    'float',
    'for',
    'goto',
    'if',
    'implements',
    'import',
    'instanceof',
    'int',
    'interface',
    'long',
    'native',
    'new',
    'package',
    'private',
    'protected',
    'public',
    'return',
    'short',
    'static',
    'strictfp',
    'super',
    'switch',
    'synchronized',
    'this',
    'throw',
    'throws',
    'transient',
    'try',
    'void',
    'volatile',
    'while',
  };
}

/// 검증 결과.
class ValidationResult {
  /// 생성자.
  const ValidationResult({
    required this.isValid,
    this.error,
    this.suggestion,
  });

  /// 유효 여부.
  final bool isValid;

  /// 오류 메시지.
  final String? error;

  /// 수정 제안.
  final String? suggestion;

  @override
  String toString() {
    if (isValid) {
      return 'ValidationResult(valid)';
    }
    return 'ValidationResult(invalid: $error, suggestion: $suggestion)';
  }
}
