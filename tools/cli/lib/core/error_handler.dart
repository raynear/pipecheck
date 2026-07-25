/// CLI 에러 처리 시스템.
///
/// 구조화된 에러 메시지를 제공하여 사용자가 문제를 쉽게 이해하고
/// 해결할 수 있도록 돕습니다.
///
/// ## 사용 예시
/// ```dart
/// throw CliException(
///   'Flutter SDK를 찾을 수 없습니다',
///   solution: 'Flutter가 설치되어 있는지 확인하세요\n'
///            'PATH 환경 변수에 Flutter가 포함되어 있는지 확인하세요',
///   docsUrl: 'docs/troubleshooting.md#flutter-not-found',
/// );
/// ```
library error_handler;

/// CLI 도구에서 발생하는 예외를 나타내는 클래스.
///
/// 사용자 친화적인 에러 메시지와 해결 방법을 제공합니다.
/// 모든 CLI 도구는 일반 [Exception] 대신 이 클래스를 사용해야 합니다.
class CliException implements Exception {
  /// 에러 메시지를 받아 CliException을 생성합니다.
  ///
  /// [message]는 필수이며, 에러의 원인을 설명합니다.
  /// [solution]은 선택적이며, 문제 해결 방법을 제공합니다.
  /// 여러 단계의 해결 방법은 줄바꿈(\n)으로 구분합니다.
  /// [docsUrl]은 선택적이며, 관련 문서의 경로를 제공합니다.
  /// [stackTrace]는 선택적이며, 디버깅을 위한 스택 트레이스를 포함합니다.
  CliException(
    this.message, {
    this.solution,
    this.docsUrl,
    this.stackTrace,
  });

  /// 에러 메시지.
  ///
  /// 사용자에게 표시되는 주요 에러 설명입니다.
  /// 한국어로 작성하며, 명확하고 간결하게 작성합니다.
  final String message;

  /// 해결 방법.
  ///
  /// 문제를 해결하기 위한 단계별 안내입니다.
  /// 여러 단계가 있는 경우 줄바꿈(\n)으로 구분합니다.
  /// 예: '플러터를 설치하세요\nPATH를 설정하세요'
  final String? solution;

  /// 관련 문서 URL.
  ///
  /// 더 자세한 정보를 제공하는 문서의 경로입니다.
  /// 예: 'docs/troubleshooting.md#flutter-not-found'
  final String? docsUrl;

  /// 스택 트레이스.
  ///
  /// 디버깅을 위한 상세한 호출 스택 정보입니다.
  /// --verbose 모드에서만 표시됩니다.
  final StackTrace? stackTrace;

  /// 에러 메시지를 형식화하여 반환합니다.
  ///
  /// 다음 형식으로 출력됩니다:
  /// ```
  /// [ERROR] 에러 메시지
  ///
  /// 💡 해결 방법:
  ///   1. 첫 번째 해결 단계
  ///   2. 두 번째 해결 단계
  ///
  /// 📚 관련 문서: 문서 경로
  /// ```
  ///
  /// [includeStackTrace]가 true이면 스택 트레이스도 포함됩니다.
  String formatError({bool includeStackTrace = false}) {
    final buffer = StringBuffer();

    // 에러 메시지 출력
    buffer.writeln('[ERROR] $message');

    // 해결 방법 출력 (있는 경우)
    if (solution != null && solution!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('💡 해결 방법:');
      final steps = solution!.split('\n');
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i].trim();
        if (step.isNotEmpty) {
          buffer.writeln('  ${i + 1}. $step');
        }
      }
    }

    // 문서 링크 출력 (있는 경우)
    if (docsUrl != null && docsUrl!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📚 관련 문서: $docsUrl');
    }

    // 스택 트레이스 출력 (요청된 경우)
    if (includeStackTrace && stackTrace != null) {
      buffer.writeln();
      buffer.writeln('📋 스택 트레이스:');
      buffer.writeln(stackTrace.toString());
    }

    return buffer.toString();
  }

  @override
  String toString() => 'CliException: $message';
}

/// 일반 예외를 CliException으로 변환하는 유틸리티 함수.
///
/// 예상치 못한 예외를 사용자 친화적인 형식으로 변환합니다.
CliException wrapException(Object error, [StackTrace? stackTrace]) {
  if (error is CliException) {
    return error;
  }

  return CliException(
    '예상치 못한 오류가 발생했습니다: ${error.toString()}',
    solution: '문제가 지속되면 개발자에게 문의하세요\n'
        '로그 파일을 확인하여 상세 정보를 확인하세요',
    stackTrace: stackTrace,
  );
}
