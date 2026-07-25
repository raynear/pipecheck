import 'dart:io';

import '../../core/error_handler.dart';
import '../../core/progress/progress_indicator.dart';
import 'device_info.dart';

/// 스크린샷 캡처 로직.
class ScreenshotCapture {
  ScreenshotCapture._();

  /// 스크린샷을 캡처합니다.
  static Future<void> captureScreenshots({
    required String appDir,
    required String projectRoot,
    required List<DeviceInfo> availableDevices,
    required List<String> languages,
    required String outputDir,
    required String testFile,
    required bool isVerbose,
  }) async {
    // 표준 드라이버 = 하니스의 screenshot_driver.dart (P1-17b).
    // (구 코드는 test_driver/integration_test.dart 부재로 항상
    //  flutter test 폴백 → 태그 스킵으로 산출물 0이었음)
    const driverRelPath = 'test/screenshot/screenshot_driver.dart';
    final hasDriverFile = File('$appDir/$driverRelPath').existsSync();

    // 출력 베이스 — platform/language 하위 구조는 하니스
    // (ScreenshotConfig + takeScreenshot)가 소유한다.
    // 최종: <root>/<outputDir>/{platform}/{language}/{name}.png
    // 디바이스별 구분이 필요하면 하니스에서 파일명 프리픽스로 처리할 것
    // (deliver는 locale 디렉토리 하위의 서브디렉토리를 읽지 않는다).
    final screenshotOutputBase = '$projectRoot/$outputDir';

    for (final device in availableDevices) {
      print('');
      print('  📱 디바이스: ${device.name} (${device.platform})');
      print('');

      // 시뮬레이터 부팅 (iOS)
      if (device.platform == 'ios' && device.state != 'Booted') {
        await _bootSimulator(device, isVerbose);
      }

      for (final language in languages) {
        print('    🌐 언어: $language');

        if (hasDriverFile) {
          // flutter drive 모드: 하니스 드라이버 사용
          await _runFlutterDrive(
            appDir: appDir,
            deviceId: device.id,
            testFile: testFile,
            driverFile: driverRelPath,
            language: language,
            outputDir: screenshotOutputBase,
            isVerbose: isVerbose,
          );
        } else {
          // flutter test 모드: integration_test 패키지 사용
          await _runFlutterTest(
            appDir: appDir,
            deviceId: device.id,
            testFile: testFile,
            language: language,
            outputDir: screenshotOutputBase,
            isVerbose: isVerbose,
          );
        }
      }
    }
  }

  /// iOS 시뮬레이터를 부팅합니다.
  static Future<void> _bootSimulator(
    DeviceInfo device,
    bool isVerbose,
  ) async {
    if (isVerbose) {
      print('    시뮬레이터 부팅 중: ${device.name}...');
    }

    final result = await Process.run(
      'xcrun',
      ['simctl', 'boot', device.id],
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      // 이미 부팅된 경우 무시
      if (!stderr.contains('current state: Booted')) {
        if (isVerbose) {
          print('    ⚠ 시뮬레이터 부팅 실패: $stderr');
        }
      }
    } else if (isVerbose) {
      print('    ✓ 시뮬레이터 부팅 완료');
    }
  }

  /// flutter drive 명령어를 실행합니다.
  static Future<void> _runFlutterDrive({
    required String appDir,
    required String deviceId,
    required String testFile,
    required String driverFile,
    required String language,
    required String outputDir,
    required bool isVerbose,
  }) async {
    final indicator = ProgressIndicator(
      message: '스크린샷 캡처 ($language)',
    );
    indicator.start();

    final result = await Process.run(
      'flutter',
      [
        'drive',
        '--driver=$driverFile',
        '--target=$testFile',
        '--device-id=$deviceId',
        '--dart-define=SCREENSHOT_MODE=true',
        '--dart-define=SCREENSHOT_LANGUAGE=$language',
        '--dart-define=SCREENSHOT_OUTPUT=$outputDir',
      ],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      // 테스트 teardown 실패(예: 위젯 debug invariant)여도 캡처 자체는
      // 성공했을 수 있다 — 산출물이 있으면 경고로 강등하고 계속한다.
      final captured = _countPngs(outputDir);
      if (captured > 0) {
        indicator.complete(
            '스크린샷 캡처 ($language) — 테스트는 실패했지만 PNG $captured개 생성됨 (경고)');
        if (isVerbose) {
          print('      ⚠ flutter drive exit ${result.exitCode} — '
              '테스트 후처리 실패로 추정, 산출물은 확인됨');
        }
        return;
      }

      indicator.fail('flutter drive 실행 실패');
      if (isVerbose) {
        print('');
        print('      stdout: ${result.stdout}');
        print('      stderr: ${result.stderr}');
      }
      throw CliException(
        'flutter drive 실행에 실패했습니다 (디바이스: $deviceId, 언어: $language)',
        solution: '다음을 확인하세요:\n'
            '  1. 시뮬레이터/에뮬레이터가 실행 중인지 확인\n'
            '  2. 테스트 파일이 올바른지 확인\n'
            '  3. --verbose 옵션으로 상세 로그를 확인',
      );
    }

    indicator.complete('스크린샷 캡처 ($language)');
  }

  /// 출력 베이스 아래의 PNG 산출물 개수.
  static int _countPngs(String dir) {
    final directory = Directory(dir);
    if (!directory.existsSync()) return 0;
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .length;
  }

  /// flutter test 명령어를 실행합니다.
  static Future<void> _runFlutterTest({
    required String appDir,
    required String deviceId,
    required String testFile,
    required String language,
    required String outputDir,
    required bool isVerbose,
  }) async {
    final indicator = ProgressIndicator(
      message: '스크린샷 캡처 ($language)',
    );
    indicator.start();

    final result = await Process.run(
      'flutter',
      [
        'test',
        testFile,
        '--device-id=$deviceId',
        // 스크린샷 테스트는 dart_test.yaml에서 기본 스킵(P0-9) —
        // 하니스 경유 실행에서만 명시적으로 푼다
        '--run-skipped',
        '--dart-define=SCREENSHOT_MODE=true',
        '--dart-define=SCREENSHOT_LANGUAGE=$language',
        '--dart-define=SCREENSHOT_OUTPUT=$outputDir',
      ],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      indicator.fail('flutter test 실행 실패');
      if (isVerbose) {
        print('');
        print('      stdout: ${result.stdout}');
        print('      stderr: ${result.stderr}');
      }
      throw CliException(
        'flutter test 실행에 실패했습니다 (디바이스: $deviceId, 언어: $language)',
        solution: '다음을 확인하세요:\n'
            '  1. 시뮬레이터/에뮬레이터가 실행 중인지 확인\n'
            '  2. 테스트 파일이 올바른지 확인\n'
            '  3. --verbose 옵션으로 상세 로그를 확인',
      );
    }

    indicator.complete('스크린샷 캡처 ($language)');
  }
}
