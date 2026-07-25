import 'dart:io';
import 'package:path/path.dart' as path;

/// 프로젝트 루트 경로 반환
String getProjectRoot() {
  final scriptDir = path.dirname(Platform.script.toFilePath());
  return path.normalize(path.join(scriptDir, '..', '..', '..'));
}

/// AppFeatureConfig 파일 경로 반환
String getConfigFilePath() {
  return path.join(getProjectRoot(), 'app', 'lib', 'config', 'app_feature_config.dart');
}

/// Features 디렉토리 경로 반환
String getFeaturesDir() {
  return path.join(getProjectRoot(), 'app', 'lib', 'features');
}

/// Config 플래그 업데이트
Future<void> updateConfigFlag(String flagName, bool value) async {
  final configPath = getConfigFilePath();
  final configFile = File(configPath);

  if (!await configFile.exists()) {
    throw Exception('AppFeatureConfig not found at $configPath');
  }

  var content = await configFile.readAsString();

  // Match pattern: static bool flagName = true/false;
  // Also match: static const bool flagName = true/false;
  final regex = RegExp(
    r'(static\s+(?:const\s+)?bool\s+' + flagName + r'\s*=\s*)(true|false)',
    multiLine: true,
  );

  if (!regex.hasMatch(content)) {
    print('  Warning: Flag $flagName not found in config');
    return;
  }

  content = content.replaceAllMapped(regex, (match) {
    return '${match.group(1)}$value';
  });

  await configFile.writeAsString(content);
}

/// app_config.yaml의 `features:` 블록에 기능 플래그를 기록한다.
///
/// 이 값만이 부팅 후까지 살아남는 런타임 입력이다(`gen_env`가 `FF_*` 키로
/// 방출 → 앱이 부팅 시 적용). [updateConfigFlag]가 편집하는 `static bool`은
/// `disableAllFeatures()`가 부팅 시 덮어쓰므로 효과가 없다.
///
/// 동작:
/// - `features:` 블록에 `^(\s*)#?\s*<featureKey>:\s*(true|false)` 줄이 있으면
///   `  <featureKey>: <value>`로 치환한다(주석 해제 + 값 설정).
/// - 그런 줄이 없으면 `features:` 헤더 바로 다음 줄에 새로 삽입한다.
///
/// [featureKey]는 스네이크 CLI 인자(예: `ads`)이며 config_loader가 이를
/// `isAdsEnabled` 같은 필드명으로 매핑한다.
Future<void> updateAppConfigFeature(String featureKey, bool value) async {
  final appConfigPath = path.join(getProjectRoot(), 'app_config.yaml');
  final appConfigFile = File(appConfigPath);

  if (!await appConfigFile.exists()) {
    throw Exception('app_config.yaml not found at $appConfigPath');
  }

  final String content;
  try {
    content = await appConfigFile.readAsString();
  } catch (e) {
    throw Exception('Failed to read $appConfigPath: $e');
  }

  final updated = applyAppConfigFeature(content, featureKey, value);

  try {
    await appConfigFile.writeAsString(updated);
  } catch (e) {
    throw Exception('Failed to write $appConfigPath: $e');
  }
}

/// [updateAppConfigFeature]의 순수 문자열 변환 코어 (IO 없음 — 단위 테스트용).
///
/// [content]의 `features:` 블록에 `<featureKey>: <value>`를 반영한 새 문자열을
/// 반환한다. 입력은 변경하지 않는다(불변).
String applyAppConfigFeature(String content, String featureKey, bool value) {
  final lines = content.split('\n');

  // `features:` 헤더 줄 탐색 (들여쓰기 없는 최상위 키).
  final headerRegex = RegExp(r'^features:\s*$');
  final headerIndex = lines.indexWhere((line) => headerRegex.hasMatch(line));
  if (headerIndex == -1) {
    throw Exception('features: block header not found in app_config.yaml');
  }

  // 블록 범위 결정: 헤더 다음 줄부터, 다음 최상위 키(들여쓰기 없음 + 비어있지
  // 않음) 또는 파일 끝까지.
  var blockEnd = lines.length;
  for (var i = headerIndex + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;
    if (!RegExp(r'^\s').hasMatch(line)) {
      blockEnd = i;
      break;
    }
  }

  // 블록 안에서 키 줄 탐색 (주석 처리된 줄 포함).
  final keyRegex = RegExp(
    r'^(\s*)#?\s*' + RegExp.escape(featureKey) + r':\s*(true|false)\s*$',
  );
  final newLine = '  $featureKey: $value';

  final updated = [...lines];
  var matchedIndex = -1;
  for (var i = headerIndex + 1; i < blockEnd; i++) {
    if (keyRegex.hasMatch(lines[i])) {
      matchedIndex = i;
      break;
    }
  }

  if (matchedIndex != -1) {
    updated[matchedIndex] = newLine;
  } else {
    // 헤더 바로 다음 줄에 삽입.
    updated.insert(headerIndex + 1, newLine);
  }

  return updated.join('\n');
}

/// app_config.yaml 변경 후 런타임 env 산출물을 재생성한다.
///
/// `tools/cli/bin/gen_env.dart`를 spawn한다(bootstrap.runFeatureCli와 동일한
/// 스타일). gen_env가 `features:` 블록을 `FF_*` 키로 방출해야 토글이 실제로
/// 적용되므로, 실패 시 사용자에게 `./build` 수동 실행을 안내한다.
Future<void> regenerateEnv() async {
  try {
    final result = await Process.run(
      'dart',
      ['run', 'tools/cli/bin/gen_env.dart'],
      workingDirectory: getProjectRoot(),
    );
    if (result.exitCode != 0) {
      print('  Warning: env 재생성 실패 (exit ${result.exitCode}).');
      final stderrText = result.stderr.toString().trim();
      if (stderrText.isNotEmpty) {
        print('  $stderrText');
      }
      print('  플래그를 적용하려면 직접 "./build"를 실행하세요.');
      return;
    }
    print('  env 산출물 재생성 완료 (.env.debug/profile/release).');
  } catch (e) {
    print('  Warning: env 재생성을 실행하지 못했습니다: $e');
    print('  플래그를 적용하려면 직접 "./build"를 실행하세요.');
  }
}

/// snake_case로 변환
String toSnakeCase(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      )
      .replaceAll(RegExp(r'^_'), '')
      .replaceAll(RegExp(r'-'), '_')
      .toLowerCase();
}

/// PascalCase로 변환
String toPascalCase(String input) {
  return input
      .replaceAll(RegExp(r'[-_]'), ' ')
      .split(' ')
      .map((word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join();
}

/// camelCase로 변환
String toCamelCase(String input) {
  final pascal = toPascalCase(input);
  if (pascal.isEmpty) return pascal;
  return '${pascal[0].toLowerCase()}${pascal.substring(1)}';
}
