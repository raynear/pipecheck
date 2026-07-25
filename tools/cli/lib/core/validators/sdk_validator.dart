/// SDK 버전 검증 시스템.
///
/// Flutter와 Dart SDK 버전이 프로젝트 요구사항을 충족하는지 검증합니다.
/// 호환되지 않는 SDK 버전으로 인한 오류를 사전에 방지합니다.
///
/// ## 사용법
/// ```dart
/// final validator = SdkValidator();
///
/// // 전체 검증
/// await validator.validateAll();
///
/// // 개별 검증
/// await validator.validateFlutterVersion();
/// await validator.validateDartVersion();
/// ```
///
/// ## 최소 버전 요구사항
/// - Flutter SDK: 3.8.0 이상
/// - Dart SDK: 3.0.0 이상
library sdk_validator;

import 'dart:io';

import '../error_handler.dart';

/// SDK 버전 정보를 담는 클래스.
class SdkVersion {
  /// SDK 버전을 생성합니다.
  const SdkVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  /// 버전 문자열을 파싱하여 SdkVersion을 생성합니다.
  ///
  /// [versionString]은 "3.8.0" 또는 "3.8.0-dev.1" 형식이어야 합니다.
  /// 파싱에 실패하면 null을 반환합니다.
  static SdkVersion? tryParse(String versionString) {
    // 프리릴리즈 버전 제거 (예: 3.8.0-dev.1 -> 3.8.0)
    final cleanVersion = versionString.split('-').first.trim();
    final parts = cleanVersion.split('.');

    if (parts.length < 3) return null;

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);

    if (major == null || minor == null || patch == null) return null;

    return SdkVersion(major: major, minor: minor, patch: patch);
  }

  /// 주 버전 번호.
  final int major;

  /// 부 버전 번호.
  final int minor;

  /// 패치 버전 번호.
  final int patch;

  /// 이 버전이 [other] 버전 이상인지 확인합니다.
  bool isAtLeast(SdkVersion other) {
    if (major > other.major) return true;
    if (major < other.major) return false;

    if (minor > other.minor) return true;
    if (minor < other.minor) return false;

    return patch >= other.patch;
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SdkVersion &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// 프로세스 실행 결과를 담는 클래스.
///
/// [ProcessResult]와 동일한 인터페이스를 제공하지만,
/// 테스트에서 쉽게 생성할 수 있습니다.
class CommandResult {
  /// 명령 실행 결과를 생성합니다.
  const CommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  /// 종료 코드 (0: 성공, 그 외: 실패).
  final int exitCode;

  /// 표준 출력.
  final String stdout;

  /// 표준 에러 출력.
  final String stderr;
}

/// Flutter/Dart SDK 버전 검증기.
///
/// CLI 도구 실행 전 SDK 버전 호환성을 검증합니다.
///
/// ## 에러 처리
/// 버전 요구사항을 충족하지 않으면 [CliException]을 발생시킵니다.
/// 에러 메시지에는 현재 버전, 필요 버전, 업그레이드 명령이 포함됩니다.
class SdkValidator {
  /// 테스트용: 커스텀 프로세스 러너를 사용합니다.
  SdkValidator({ProcessRunner? processRunner})
      : _processRunner = processRunner ?? _defaultProcessRunner;

  /// 최소 Flutter SDK 버전.
  static const String minFlutterVersion = '3.8.0';

  /// 최소 Dart SDK 버전.
  static const String minDartVersion = '3.0.0';

  /// 최소 Flutter 버전을 [SdkVersion] 객체로 반환합니다.
  static SdkVersion get minFlutter =>
      SdkVersion.tryParse(minFlutterVersion) ??
      const SdkVersion(major: 3, minor: 8, patch: 0);

  /// 최소 Dart 버전을 [SdkVersion] 객체로 반환합니다.
  static SdkVersion get minDart =>
      SdkVersion.tryParse(minDartVersion) ??
      const SdkVersion(major: 3, minor: 0, patch: 0);

  final ProcessRunner _processRunner;

  static Future<CommandResult> _defaultProcessRunner(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }

  /// Flutter와 Dart SDK 버전을 모두 검증합니다.
  ///
  /// 두 SDK 모두 최소 버전 요구사항을 충족해야 합니다.
  /// 하나라도 실패하면 [CliException]이 발생합니다.
  Future<void> validateAll() async {
    await validateFlutterVersion();
    await validateDartVersion();
  }

  /// Flutter SDK 버전을 검증합니다.
  ///
  /// Flutter SDK 버전이 [minFlutterVersion] 이상인지 확인합니다.
  /// 버전 요구사항을 충족하지 않으면 [CliException]을 발생시킵니다.
  ///
  /// ## 발생 가능한 에러
  /// - Flutter가 설치되어 있지 않은 경우
  /// - Flutter 버전이 최소 요구사항보다 낮은 경우
  Future<void> validateFlutterVersion() async {
    final result = await _processRunner('flutter', ['--version']);

    if (result.exitCode != 0) {
      throw CliException(
        'Flutter SDK를 찾을 수 없습니다',
        solution: 'Flutter가 설치되어 있는지 확인하세요\n'
            'PATH 환경 변수에 Flutter가 포함되어 있는지 확인하세요\n'
            'flutter doctor 명령어로 설치 상태를 확인하세요',
        docsUrl: 'docs/troubleshooting.md#flutter-not-found',
      );
    }

    final output = result.stdout;
    final currentVersion = _parseFlutterVersion(output);

    if (currentVersion == null) {
      throw CliException(
        'Flutter 버전을 확인할 수 없습니다',
        solution: 'flutter --version 명령의 출력을 확인하세요\n'
            'Flutter가 올바르게 설치되어 있는지 확인하세요',
        docsUrl: 'docs/troubleshooting.md#flutter-version-parse-error',
      );
    }

    if (!currentVersion.isAtLeast(minFlutter)) {
      throw CliException(
        'Flutter SDK 버전이 너무 낮습니다\n\n'
        '현재 버전: $currentVersion\n'
        '필요 버전: $minFlutterVersion 이상',
        solution: 'flutter upgrade 명령을 실행하세요\n'
            '또는 flutter channel stable && flutter upgrade를 실행하세요',
        docsUrl: 'docs/troubleshooting.md#flutter-version',
      );
    }
  }

  /// Dart SDK 버전을 검증합니다.
  ///
  /// Dart SDK 버전이 [minDartVersion] 이상인지 확인합니다.
  /// 버전 요구사항을 충족하지 않으면 [CliException]을 발생시킵니다.
  ///
  /// ## 발생 가능한 에러
  /// - Dart가 설치되어 있지 않은 경우
  /// - Dart 버전이 최소 요구사항보다 낮은 경우
  Future<void> validateDartVersion() async {
    final result = await _processRunner('dart', ['--version']);

    if (result.exitCode != 0) {
      throw CliException(
        'Dart SDK를 찾을 수 없습니다',
        solution: 'Dart가 설치되어 있는지 확인하세요\n'
            'Flutter와 함께 설치된 경우 flutter doctor를 실행하세요\n'
            'PATH 환경 변수에 Dart가 포함되어 있는지 확인하세요',
        docsUrl: 'docs/troubleshooting.md#dart-not-found',
      );
    }

    // Dart --version은 stderr에 출력될 수 있음
    final output = result.stdout + result.stderr;
    final currentVersion = _parseDartVersion(output);

    if (currentVersion == null) {
      throw CliException(
        'Dart 버전을 확인할 수 없습니다',
        solution: 'dart --version 명령의 출력을 확인하세요\n'
            'Dart가 올바르게 설치되어 있는지 확인하세요',
        docsUrl: 'docs/troubleshooting.md#dart-version-parse-error',
      );
    }

    if (!currentVersion.isAtLeast(minDart)) {
      throw CliException(
        'Dart SDK 버전이 너무 낮습니다\n\n'
        '현재 버전: $currentVersion\n'
        '필요 버전: $minDartVersion 이상',
        solution: 'flutter upgrade 명령을 실행하세요 (Flutter와 함께 설치된 경우)\n'
            '또는 dart pub upgrade를 실행하세요',
        docsUrl: 'docs/troubleshooting.md#dart-version',
      );
    }
  }

  /// Flutter --version 출력에서 버전을 파싱합니다.
  ///
  /// 예시 출력:
  /// ```
  /// Flutter 3.16.0 • channel stable • https://github.com/flutter/flutter.git
  /// Framework • revision ...
  /// ```
  SdkVersion? _parseFlutterVersion(String output) {
    // "Flutter 3.16.0" 패턴 매칭
    final regex = RegExp(r'Flutter\s+(\d+\.\d+\.\d+)');
    final match = regex.firstMatch(output);

    if (match == null) return null;

    return SdkVersion.tryParse(match.group(1)!);
  }

  /// Dart --version 출력에서 버전을 파싱합니다.
  ///
  /// 예시 출력:
  /// ```
  /// Dart SDK version: 3.2.0 (stable) ...
  /// ```
  SdkVersion? _parseDartVersion(String output) {
    // "Dart SDK version: 3.2.0" 또는 "Dart 3.2.0" 패턴 매칭
    final regex = RegExp(r'Dart(?:\s+SDK\s+version:?)?\s+(\d+\.\d+\.\d+)');
    final match = regex.firstMatch(output);

    if (match == null) return null;

    return SdkVersion.tryParse(match.group(1)!);
  }
}

/// 프로세스 실행 함수 타입.
typedef ProcessRunner = Future<CommandResult> Function(
  String executable,
  List<String> arguments,
);
