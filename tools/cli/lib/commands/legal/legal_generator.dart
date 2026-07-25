import 'dart:io';

import '../../core/logger/cli_logger.dart';
import '../../core/config_loader.dart';

/// 법적 문서 파일 생성 및 I/O 로직.

/// 시행일을 결정합니다.
///
/// [effectiveDateArg]가 주어지면 그대로 사용하고,
/// 없으면 오늘 날짜를 YYYY-MM-DD 형식으로 반환합니다.
String resolveEffectiveDate(String? effectiveDateArg) {
  if (effectiveDateArg != null && effectiveDateArg.isNotEmpty) {
    return effectiveDateArg;
  }
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// 설정 파일을 로드합니다.
Future<ConfigLoader?> loadConfig({
  required String projectRoot,
  required String configPath,
  required bool isVerbose,
}) async {
  final configFile = File('$projectRoot/$configPath');
  if (!configFile.existsSync()) {
    if (isVerbose) {
      CliLogger.debug('설정 파일을 찾을 수 없습니다: $configPath (기본값 사용)');
    }
    print('  [INFO] 설정 파일을 찾을 수 없습니다. 기본값을 사용합니다.');
    return null;
  }

  try {
    final loader = ConfigLoader('$projectRoot/$configPath');
    await loader.load();
    return loader;
  } catch (e) {
    if (isVerbose) {
      CliLogger.warning('설정 파일 로드 실패: $e (기본값 사용)');
    }
    print('  [WARNING] 설정 파일 로드 실패. 기본값을 사용합니다.');
    return null;
  }
}

/// 생성된 HTML 파일을 디스크에 저장합니다.
Future<List<String>> saveFiles({
  required String projectRoot,
  required String outputDir,
  required String privacyPolicyHtml,
  required String termsOfServiceHtml,
  required String legalIndexHtml,
  required bool isVerbose,
}) async {
  final directory = Directory('$projectRoot/$outputDir');
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
    if (isVerbose) {
      CliLogger.debug('디렉토리 생성: $outputDir');
    }
  }

  final privacyPath = '${directory.path}/privacy_policy.html';
  final termsPath = '${directory.path}/terms_of_service.html';
  final indexPath = '${directory.path}/index.html';

  await File(privacyPath).writeAsString(privacyPolicyHtml);
  await File(termsPath).writeAsString(termsOfServiceHtml);
  await File(indexPath).writeAsString(legalIndexHtml);

  if (isVerbose) {
    CliLogger.debug('파일 저장 완료: $privacyPath');
    CliLogger.debug('파일 저장 완료: $termsPath');
    CliLogger.debug('파일 저장 완료: $indexPath');
  }

  return [privacyPath, termsPath, indexPath];
}

/// 성공 메시지를 출력합니다.
void printSuccessMessage(double elapsed, List<String> savedFiles) {
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
  print('  법적 문서 생성이 완료되었습니다!');
  print('');
  print('     소요 시간: ${elapsed.toStringAsFixed(1)}초');
  print('');
  print('  생성된 파일:');
  for (final path in savedFiles) {
    print('     - $path');
  }
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
  print('  [TIP] Flutter에서 WebView로 표시하거나');
  print('     flutter_html 패키지를 사용하여 렌더링할 수 있습니다.');
  print('');
}
