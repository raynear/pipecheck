import 'dart:io';

import '../../core/error_handler.dart';
import 'device_info.dart';

/// 스크린샷 출력 디렉토리 관리 및 결과 표시.
class ScreenshotOutput {
  ScreenshotOutput._();

  /// 캡처된 스크린샷의 픽셀 크기를 검증한다 (B5).
  ///
  /// 잘못된(작은) 시뮬레이터가 substring 매칭으로 바인딩되면 ASC가 거부하는
  /// 크기의 PNG가 나온다. 각 PNG의 IHDR에서 크기를 읽어:
  /// - 손상/0크기 → hard-fail
  /// - 짧은 변이 너무 작으면(<1000px) 경고 (잘못된 시뮬레이터 가능성)
  /// - PNG가 하나도 없으면 경고
  static void validateCapturedDimensions({
    required String projectRoot,
    required String outputDir,
    required bool isVerbose,
  }) {
    final root = Directory('$projectRoot/$outputDir');
    if (!root.existsSync()) {
      print('  ⚠️  스크린샷 출력 디렉토리가 없습니다: $outputDir');
      return;
    }
    final pngs = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList();
    if (pngs.isEmpty) {
      print('  ⚠️  캡처된 스크린샷(.png)이 없습니다 — 하니스 실행을 확인하세요.');
      return;
    }

    var warned = 0;
    for (final png in pngs) {
      final dim = readPngSize(png);
      final name = png.uri.pathSegments.last;
      if (dim == null || dim[0] == 0 || dim[1] == 0) {
        throw CliException(
          '손상된 스크린샷(크기 0): ${png.path}',
          solution: '하니스 캡처가 실패했습니다 — flutter drive 로그를 확인하세요.',
        );
      }
      final shortSide = dim[0] < dim[1] ? dim[0] : dim[1];
      if (isVerbose) {
        print('    $name: ${dim[0]}x${dim[1]}');
      }
      if (shortSide < 1000) {
        warned++;
        print('  ⚠️  $name: ${dim[0]}x${dim[1]} — ASC 최소 크기 미달 '
            '가능성(잘못된 시뮬레이터?).');
      }
    }
    if (warned == 0) {
      print('  ✓ 스크린샷 크기 검증 (${pngs.length}개)');
    }
  }

  /// PNG IHDR에서 `[width, height]`를 읽는다. 실패 시 null.
  static List<int>? readPngSize(File file) {
    try {
      final raf = file.openSync();
      try {
        return readPngSizeBytes(raf.readSync(24));
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }

  /// PNG 바이트의 IHDR에서 `[width, height]`를 읽는다. 실패 시 null.
  static List<int>? readPngSizeBytes(List<int> header) {
    if (header.length < 24) return null;
    // PNG 서명(8) + IHDR length(4) + "IHDR"(4) + width(4)@16 + height(4)@20
    int u32(int o) =>
        (header[o] << 24) |
        (header[o + 1] << 16) |
        (header[o + 2] << 8) |
        header[o + 3];
    return [u32(16), u32(20)];
  }

  /// 통합 테스트 파일 존재 여부를 확인합니다.
  static void validateTestFile(String appDir, String testFile, bool isVerbose) {
    final testFilePath = '$appDir/$testFile';
    final file = File(testFilePath);

    if (isVerbose) {
      print('    테스트 파일 확인 중: $testFilePath');
    }

    if (!file.existsSync()) {
      throw CliException(
        '통합 테스트 파일을 찾을 수 없습니다: $testFile',
        solution: '다음을 확인하세요:\n'
            '  1. test/screenshot/screenshot_driver.dart 파일이 존재하는지 확인\n'
            '  2. --test-file 옵션으로 올바른 경로를 지정\n'
            '  3. 프로젝트 루트에서 실행하고 있는지 확인',
        docsUrl: 'app/test/screenshot/README.md',
      );
    }

    // 하니스 드라이버 확인 (P1-17b 표준: test/screenshot/screenshot_driver.dart)
    final driverFile = File('$appDir/test/screenshot/screenshot_driver.dart');
    if (!driverFile.existsSync()) {
      if (isVerbose) {
        print('    ⚠ 하니스 드라이버가 없습니다. flutter drive 대신 flutter test를 사용합니다.');
      }
    }

    if (isVerbose) {
      print('    ✓ 테스트 파일 확인 완료');
    }
  }

  /// 출력 디렉토리를 생성합니다.
  ///
  /// 경로 SSOT (P1-17b): `<root>/<outputDir>/{platform}/{language}/` —
  /// 하니스 저장 레이아웃이자 iOS deliver `screenshots_path`
  /// (`<root>/screenshots/ios`)가 읽는 구조.
  static Future<void> createOutputDirectories({
    required String projectRoot,
    required String outputDir,
    required List<String> platforms,
    required List<String> languages,
    required bool isVerbose,
  }) async {
    final baseDir = '$projectRoot/$outputDir';

    for (final platform in platforms) {
      for (final language in languages) {
        final dir = Directory('$baseDir/$platform/$language');

        if (!dir.existsSync()) {
          await dir.create(recursive: true);
          if (isVerbose) {
            print('    생성: ${dir.path}');
          }
        }
      }
    }

    if (isVerbose) {
      print('    ✓ 출력 디렉토리 생성 완료');
    }
  }

  /// 디바이스가 없을 때 안내 메시지를 출력합니다.
  static void printNoDevicesInstructions({
    required List<String> requestedDevices,
    required List<DeviceInfo> availableDevices,
    required String platform,
  }) {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  ⚠️  요청된 디바이스를 찾을 수 없습니다');
    print('');
    print('  요청된 디바이스:');
    for (final device in requestedDevices) {
      print('    - $device');
    }
    print('');

    if (availableDevices.isNotEmpty) {
      print('  사용 가능한 디바이스:');
      for (final device in availableDevices) {
        print('    - ${device.name} (${device.id}) [${device.platform}]');
      }
      print('');
    }

    if (platform == 'ios' || platform == 'all') {
      print('  💡 iOS 시뮬레이터 설정:');
      print('     1. Xcode를 설치하세요');
      print('     2. Xcode > Preferences > Components에서 시뮬레이터를 다운로드하세요');
      print('     3. 시뮬레이터를 생성하세요:');
      print('        xcrun simctl create "iPhone 15 Pro Max" \\');
      print('          "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro-Max" \\');
      print('          "com.apple.CoreSimulator.SimRuntime.iOS-17-5"');
      print('');
    }

    if (platform == 'android' || platform == 'all') {
      print('  💡 Android 에뮬레이터 설정:');
      print('     1. Android Studio를 설치하세요');
      print('     2. AVD Manager에서 에뮬레이터를 생성하세요');
      print('     3. 또는 커맨드라인으로 생성:');
      print('        avdmanager create avd -n "Pixel_7" -k "system-images;android-34;google_apis;arm64-v8a"');
      print('');
    }

    print('  📋 사용 가능한 디바이스 확인:');
    print('     flutter devices');
    print('     xcrun simctl list devices available');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
  }

  /// 성공 메시지를 출력합니다.
  static void printSuccessMessage({
    required double elapsed,
    required String outputDir,
    required List<DeviceInfo> devices,
    required List<String> languages,
  }) {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  ✅ 스크린샷 캡처가 완료되었습니다!');
    print('');
    print('     소요 시간: ${elapsed.toStringAsFixed(1)}초');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  📌 캡처 요약:');
    print('');
    print('  • 디바이스: ${devices.length}개');
    for (final device in devices) {
      print('    - ${device.name} [${device.platform}]');
    }
    print('  • 언어: ${languages.join(', ')}');
    print('  • 출력 경로: $outputDir');
    print('');
    print('  📂 스크린샷 구조 (deliver가 읽는 레이아웃):');
    final platforms = devices.map((d) => d.platform).toSet();
    for (final platform in platforms) {
      for (final language in languages) {
        print('     $outputDir/$platform/$language/');
      }
    }
    print('');
    print('  💡 스크린샷을 App Store에 업로드하려면:');
    print('     cd fastlane && SKIP_SCREENSHOTS=false '
        'bundle exec fastlane upload_metadata_ios');
    print('');
  }
}
