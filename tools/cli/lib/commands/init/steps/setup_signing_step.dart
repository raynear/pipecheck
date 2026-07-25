import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';
import 'package:boilerplate_cli/core/path_utils.dart';

/// Sets up code signing for iOS (Match) and Android (Keystore).
///
/// 반환값은 요약용 — Android 공용 keystore 검증 결과(존재+비밀번호)를 담는다.
/// iOS Match/Team은 부수효과로 처리한다.
Future<StepResult> setupSigningStep({
  required String projectRoot,
  required String appDir,
  required String fastlaneDir,
  required ConfigLoader config,
  required bool hasConfig,
  required bool verbose,
}) async {
  if (!hasConfig) {
    print('    -- 설정 파일 없음, 서명 설정 건너뛰기');
    return StepResult.skipped('설정 파일 없음');
  }

  await _setupIosMatch(
    fastlaneDir: fastlaneDir,
    config: config,
    verbose: verbose,
  );

  await _setIosDevelopmentTeam(
    appDir: appDir,
    config: config,
    verbose: verbose,
  );

  return _setupAndroidKeystore(
    projectRoot: projectRoot,
    appDir: appDir,
    config: config,
    verbose: verbose,
  );
}

/// 공용 Android keystore 검증 결과를 분류한다 (순수 함수, 테스트 가능).
///
/// 사용자는 모든 앱에 공용 keystore(`~/key.jks`, alias `android_signing_key`)를
/// 쓴다. 파일을 새로 만들거나 keystore를 열지 않고 존재+비밀번호 설정만 본다.
StepResult classifyKeystore({
  required String keystorePath,
  required bool exists,
  required bool hasStorePassword,
  required bool hasKeyPassword,
}) {
  if (keystorePath.isEmpty) {
    return StepResult.skipped('keystore 경로 미설정 (app_config.yaml '
        'signing.android.keystore_path)');
  }
  if (!exists) {
    return StepResult.skipped('keystore 파일 없음: $keystorePath — '
        'keytool -genkey -v -keystore $keystorePath -alias android_signing_key '
        '-keyalg RSA -keysize 2048 -validity 10000 로 생성 후 재실행');
  }
  if (!hasStorePassword || !hasKeyPassword) {
    return StepResult.skipped('keystore 비밀번호 미설정 '
        '(.env KEYSTORE_PASSWORD / KEY_PASSWORD)');
  }
  return StepResult(StepStatus.done, '공용 keystore 사용: $keystorePath');
}

Future<void> _setupIosMatch({
  required String fastlaneDir,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final matchGitUrl = config.matchGitUrl;
  if (matchGitUrl.isEmpty) {
    print('    iOS Match - match_git_url 미설정, 건너뛰기');
    return;
  }

  print('    iOS Match 설정 중...');

  final matchFile = File('$fastlaneDir/Matchfile');
  if (!matchFile.existsSync()) {
    final matchContent = '''
git_url("$matchGitUrl")
storage_mode("git")
type("appstore")
app_identifier(["${config.packageName}"])
team_id("${config.iosTeamId}")
''';
    await matchFile.writeAsString(matchContent);
    if (verbose) {
      CliLogger.debug('Matchfile 생성 완료');
    }
  }
  // MATCH_PASSWORD는 프로젝트 루트 .env에서 관리 (시크릿)
  print('    iOS Match 설정 완료');
}

/// pbxproj의 `DEVELOPMENT_TEAM`을 설정된 iOS 팀 ID로 교체한다 (B4).
///
/// 커밋된 템플릿은 빈 팀("")이라 저자 팀이 새 나가지 않는다 — 포크가 init을
/// 돌리면 이 단계가 자기 팀으로 채운다. `iosTeamId`가 비었거나 placeholder면
/// 건드리지 않는다(fastlane match가 빌드시 서명하므로 빈 값도 안전).
Future<void> _setIosDevelopmentTeam({
  required String appDir,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final teamId = config.iosTeamId;
  if (teamId.isEmpty || teamId.contains('XXXX')) {
    if (verbose) {
      CliLogger.debug('iOS team_id 미설정/placeholder — DEVELOPMENT_TEAM 유지');
    }
    return;
  }

  final pbxproj = File('$appDir/ios/Runner.xcodeproj/project.pbxproj');
  if (!pbxproj.existsSync()) return;

  final lines = pbxproj.readAsLinesSync();
  var changed = 0;
  // 각 DEVELOPMENT_TEAM 줄에서 `= <값>;`(줄 끝)만 교체. `[sdk=iphoneos*]`의
  // `=`를 건드리지 않도록 줄 끝에 앵커한 패턴을 쓴다.
  final valueAtEnd = RegExp(r'=\s*[^;=]*;\s*$');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('DEVELOPMENT_TEAM') &&
        valueAtEnd.hasMatch(lines[i])) {
      lines[i] = lines[i].replaceFirst(valueAtEnd, '= $teamId;');
      changed++;
    }
  }
  if (changed > 0) {
    await pbxproj.writeAsString('${lines.join('\n')}\n');
    print('    iOS DEVELOPMENT_TEAM 설정 완료 ($teamId, $changed곳)');
  }
}

Future<StepResult> _setupAndroidKeystore({
  required String projectRoot,
  required String appDir,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final keystorePath = config.keystorePath;

  // Read passwords from project root .env (secrets)
  final envFile = File('$projectRoot/.env');
  var keystorePassword = '';
  var keyPassword = '';
  if (envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      if (line.startsWith('KEYSTORE_PASSWORD=')) {
        keystorePassword =
            line.split('=').skip(1).join('=').replaceAll('"', '');
      } else if (line.startsWith('KEY_PASSWORD=')) {
        keyPassword = line.split('=').skip(1).join('=').replaceAll('"', '');
      }
    }
  }

  final keystoreFile = keystorePath.isEmpty
      ? null
      : File(expandUserPath(keystorePath, projectRoot: projectRoot));
  final exists = keystoreFile?.existsSync() ?? false;

  final result = classifyKeystore(
    keystorePath: keystorePath,
    exists: exists,
    hasStorePassword: keystorePassword.isNotEmpty,
    hasKeyPassword: keyPassword.isNotEmpty,
  );

  if (result.ok) {
    print('    Android 공용 keystore 사용: $keystorePath');
    final keyProperties = File('$appDir/android/key.properties');
    if (!keyProperties.existsSync()) {
      final content = '''
storePassword=$keystorePassword
keyPassword=$keyPassword
keyAlias=${config.keyAlias}
storeFile=${keystoreFile!.absolute.path}
''';
      await keyProperties.writeAsString(content);
      print('    Android key.properties 생성 완료');
    }
  } else {
    print('    Android Keystore - ${result.reason}');
  }

  return result;
}
