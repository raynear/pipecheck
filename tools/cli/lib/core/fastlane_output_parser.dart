import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'logger/cli_logger.dart';

/// Parses Fastlane output and extracts progress/error information.
class FastlaneOutputParser {
  /// Known Fastlane error patterns and user-friendly messages.
  static const _errorPatterns = <String, String>{
    'Could not find a matching code signing identity':
        '코드 서명 인증서를 찾을 수 없습니다. fastlane match를 실행하세요.',
    'No matching provisioning profiles found':
        '프로비저닝 프로파일을 찾을 수 없습니다. fastlane match를 실행하세요.',
    'Your Apple ID or password was entered incorrectly':
        'Apple ID 인증에 실패했습니다. 환경변수를 확인하세요.',
    'The request timed out': '네트워크 타임아웃. 인터넷 연결을 확인하세요.',
    'Error uploading ipa': 'IPA 업로드 실패. App Store Connect 상태를 확인하세요.',
    'error: exportArchive': '아카이브 내보내기 실패. 서명 설정을 확인하세요.',
    'ARCHIVE FAILED': '빌드 아카이브 실패.',
    'BUILD FAILED': '빌드 실패. 코드 오류를 확인하세요.',
    'Gradle build daemon disappeared unexpectedly':
        'Gradle 데몬 오류. `cd app/android && ./gradlew clean` 후 재시도하세요.',
    'No connected devices': '연결된 기기가 없습니다.',
    'ruby_error': 'Fastlane Ruby 오류가 발생했습니다.',
  };

  /// Run a Fastlane lane with streaming output and parse results.
  ///
  /// Returns the exit code from the Fastlane process.
  static Future<int> runLane({
    required String lane,
    required List<String> args,
    required String workingDirectory,
    required bool verbose,
    void Function(String line)? onProgress,
    Map<String, String>? environment,
  }) async {
    // [environment]는 부모 프로세스 환경에 병합/덮어쓰기된다
    // (includeParentEnvironment 기본 true). 예: SKIP_SCREENSHOTS=false 주입.
    final process = await Process.start(
      'bundle',
      ['exec', 'fastlane', lane, ...args],
      workingDirectory: workingDirectory,
      environment: environment,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdoutBuffer.writeln(line);
      if (verbose) {
        CliLogger.debug(line);
      }
      final progress = _extractProgress(line);
      if (progress != null && onProgress != null) {
        onProgress(progress);
      }
    }).asFuture<void>();

    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrBuffer.writeln(line);
      if (verbose) {
        CliLogger.debug('[stderr] $line');
      }
    }).asFuture<void>();

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);

    if (exitCode != 0) {
      final output = '$stdoutBuffer\n$stderrBuffer';
      final friendlyError = parseError(output);
      if (friendlyError != null) {
        CliLogger.error(friendlyError);
      } else {
        CliLogger.debug(output);
      }
    }

    return exitCode;
  }

  /// Extract progress from a Fastlane output line.
  static String? _extractProgress(String line) {
    // Fastlane step indicators
    if (line.contains('▸')) return line.trim();
    if (line.startsWith('---')) return null;

    // Fastlane lane switch
    final laneMatch = RegExp(r'--- Step: (.+) ---').firstMatch(line);
    if (laneMatch != null) return laneMatch.group(1);

    // Build progress
    if (line.contains('Compiling')) return line.trim();
    if (line.contains('Building')) return line.trim();
    if (line.contains('Signing')) return line.trim();
    if (line.contains('Uploading')) return line.trim();
    if (line.contains('Successfully')) return line.trim();

    return null;
  }

  /// Parse error output and return a user-friendly message.
  static String? parseError(String output) {
    for (final entry in _errorPatterns.entries) {
      if (output.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
