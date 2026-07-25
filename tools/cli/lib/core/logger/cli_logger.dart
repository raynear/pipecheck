/// 중앙 집중식 CLI 로깅 시스템.
///
/// 모든 CLI 도구의 로그를 통합 관리합니다.
/// 디버깅과 문제 해결을 위한 로그를 파일과 콘솔에 기록합니다.
///
/// ## 사용법
/// ```dart
/// // 초기화 (앱 시작 시)
/// await CliLogger.init(verbose: args['verbose']);
///
/// // 로깅
/// CliLogger.debug('상세한 디버깅 정보');
/// CliLogger.info('일반 정보 메시지');
/// CliLogger.warning('경고 메시지');
/// CliLogger.error('에러 메시지', stackTrace);
/// ```
///
/// ## 로그 레벨
/// | 레벨 | 콘솔 출력 | 파일 저장 | 용도 |
/// |------|----------|----------|------|
/// | DEBUG | --verbose 시에만 | 항상 | 상세 디버깅 정보 |
/// | INFO | 안 함 | 항상 | 일반 정보성 메시지 |
/// | WARNING | --verbose 시에만 | 항상 | 경고 메시지 |
/// | ERROR | 항상 | 항상 | 에러 메시지 |
///
/// ## 로그 파일
/// - 위치: `.boilerplate/logs/cli-YYYY-MM-DD.log`
/// - 형식: `[타임스탬프] [레벨] 메시지`
library cli_logger;

import 'dart:io';

/// 로그 레벨 정의.
///
/// 심각도 순서: DEBUG < INFO < WARNING < ERROR
enum LogLevel {
  /// 상세한 디버깅 정보.
  ///
  /// 개발 중 문제 해결에 유용한 상세 정보를 기록합니다.
  /// --verbose 플래그 사용 시에만 콘솔에 출력됩니다.
  debug('DEBUG'),

  /// 일반 정보성 메시지.
  ///
  /// 프로세스 진행 상황이나 주요 이벤트를 기록합니다.
  /// 콘솔에는 출력되지 않고 파일에만 저장됩니다.
  info('INFO'),

  /// 경고 메시지.
  ///
  /// 잠재적인 문제나 주의가 필요한 상황을 기록합니다.
  /// --verbose 플래그 사용 시에만 콘솔에 출력됩니다.
  warning('WARNING'),

  /// 에러 메시지.
  ///
  /// 오류 발생 시 에러 내용과 스택 트레이스를 기록합니다.
  /// 항상 콘솔에 출력됩니다.
  error('ERROR');

  const LogLevel(this.label);

  /// 로그 레벨 라벨 (DEBUG, INFO, WARNING, ERROR).
  final String label;
}

/// 중앙 집중식 CLI 로거.
///
/// 싱글톤 패턴으로 전역에서 접근 가능한 로깅 시스템을 제공합니다.
/// 모든 메서드는 static으로 제공되어 인스턴스 생성 없이 사용할 수 있습니다.
class CliLogger {
  CliLogger._();

  /// 로그 디렉토리 경로.
  static const String _logDirPath = '.boilerplate/logs';

  /// 현재 로그 파일.
  static File? _logFile;

  /// verbose 모드 여부.
  static bool _verbose = false;

  /// 초기화 여부.
  static bool _initialized = false;

  /// 콘솔 출력 함수 (테스트에서 오버라이드 가능).
  static void Function(String message) _printFunction = print;

  /// 현재 시간 함수 (테스트에서 오버라이드 가능).
  static DateTime Function() _nowFunction = () => DateTime.now();

  /// 초기화 여부 반환.
  static bool get isInitialized => _initialized;

  /// verbose 모드 여부 반환.
  static bool get isVerbose => _verbose;

  /// 현재 로그 파일 반환.
  static File? get logFile => _logFile;

  /// 로거를 초기화합니다.
  ///
  /// CLI 도구 시작 시 한 번 호출해야 합니다.
  /// 로그 디렉토리를 생성하고 오늘 날짜의 로그 파일을 설정합니다.
  ///
  /// [verbose]가 true이면 DEBUG, WARNING 레벨도 콘솔에 출력합니다.
  ///
  /// ```dart
  /// await CliLogger.init(verbose: args['verbose']);
  /// ```
  static Future<void> init({bool verbose = false}) async {
    _verbose = verbose;

    // 로그 디렉토리 생성
    final logDir = Directory(_logDirPath);
    if (!logDir.existsSync()) {
      await logDir.create(recursive: true);
    }

    // 오늘 날짜의 로그 파일 설정
    final now = _nowFunction();
    final dateStr = _formatDate(now);
    _logFile = File('$_logDirPath/cli-$dateStr.log');

    _initialized = true;

    debug('CliLogger 초기화 완료 (verbose: $verbose)');
  }

  /// 로거를 리셋합니다 (테스트용).
  static void reset() {
    _logFile = null;
    _verbose = false;
    _initialized = false;
    _printFunction = print;
    _nowFunction = () => DateTime.now();
  }

  /// 테스트용: 콘솔 출력 함수를 설정합니다.
  static void setTestPrintFunction(void Function(String) fn) {
    _printFunction = fn;
  }

  /// 테스트용: 현재 시간 함수를 설정합니다.
  static void setTestNowFunction(DateTime Function() fn) {
    _nowFunction = fn;
  }

  /// DEBUG 레벨 로그를 기록합니다.
  ///
  /// 상세한 디버깅 정보를 기록합니다.
  /// --verbose 플래그 사용 시에만 콘솔에 출력됩니다.
  ///
  /// ```dart
  /// CliLogger.debug('변수 값: $value');
  /// CliLogger.debug('함수 진입: processData()');
  /// ```
  static void debug(String message) {
    _log(LogLevel.debug, message);
  }

  /// INFO 레벨 로그를 기록합니다.
  ///
  /// 일반 정보성 메시지를 기록합니다.
  /// 콘솔에는 출력되지 않고 파일에만 저장됩니다.
  ///
  /// ```dart
  /// CliLogger.info('설정 파일 생성 완료');
  /// CliLogger.info('데이터 로딩 시작');
  /// ```
  static void info(String message) {
    _log(LogLevel.info, message);
  }

  /// WARNING 레벨 로그를 기록합니다.
  ///
  /// 경고 메시지를 기록합니다.
  /// --verbose 플래그 사용 시에만 콘솔에 출력됩니다.
  ///
  /// ```dart
  /// CliLogger.warning('기존 파일이 존재합니다');
  /// CliLogger.warning('권장하지 않는 설정값입니다');
  /// ```
  static void warning(String message) {
    _log(LogLevel.warning, message);
  }

  /// ERROR 레벨 로그를 기록합니다.
  ///
  /// 에러 메시지와 선택적으로 스택 트레이스를 기록합니다.
  /// 항상 콘솔에 출력됩니다.
  ///
  /// ```dart
  /// try {
  ///   // 작업
  /// } catch (e, stackTrace) {
  ///   CliLogger.error('파일 읽기 실패: $e', stackTrace);
  /// }
  /// ```
  static void error(String message, [StackTrace? stackTrace]) {
    _log(LogLevel.error, message, stackTrace);
  }

  /// 로그를 기록합니다.
  static void _log(LogLevel level, String message, [StackTrace? stackTrace]) {
    final now = _nowFunction();
    final timestamp = _formatTimestamp(now);
    final logLine = '[$timestamp] [${level.label}] $message';

    // 콘솔 출력 규칙
    final shouldPrintToConsole = switch (level) {
      LogLevel.debug => _verbose,
      LogLevel.info => false,
      LogLevel.warning => _verbose,
      LogLevel.error => true,
    };

    if (shouldPrintToConsole) {
      _printFunction(logLine);
      if (stackTrace != null && level == LogLevel.error) {
        _printFunction(stackTrace.toString());
      }
    }

    // 파일에 항상 저장
    _writeToFile(logLine, stackTrace);
  }

  /// 로그를 파일에 기록합니다.
  static void _writeToFile(String logLine, [StackTrace? stackTrace]) {
    if (_logFile == null) return;

    try {
      // 쓰기 시점에 로그 디렉토리 보장 (init 이후 cwd 변경/삭제에도 견고)
      _logFile!.parent.createSync(recursive: true);
      final buffer = StringBuffer()..writeln(logLine);
      if (stackTrace != null) {
        buffer.writeln(stackTrace);
      }
      _logFile!.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
      );
    } catch (e) {
      // 파일 쓰기 실패 시 콘솔에만 출력 (무한 루프 방지)
      _printFunction('[LOGGER ERROR] 로그 파일 쓰기 실패: $e');
    }
  }

  /// 날짜를 YYYY-MM-DD 형식으로 포맷합니다.
  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 타임스탬프를 YYYY-MM-DD HH:mm:ss 형식으로 포맷합니다.
  static String _formatTimestamp(DateTime date) {
    final datePart = _formatDate(date);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$datePart $hour:$minute:$second';
  }
}
