import 'dart:convert';
import 'dart:io';

import '../../core/error_handler.dart';
import 'device_info.dart';
import 'screenshot_output.dart';

/// 디바이스 검색 및 매칭 로직.
class DeviceDiscovery {
  DeviceDiscovery._();

  /// 사용 가능한 디바이스 목록을 조회합니다.
  static Future<List<DeviceInfo>> getAvailableDevices({
    required String platform,
    required List<String> requestedDevices,
    required bool isVerbose,
    bool allowMissing = false,
  }) async {
    final availableDevices = <DeviceInfo>[];

    // iOS 시뮬레이터 조회
    if (platform == 'ios' || platform == 'all') {
      final iosDevices = await _getIosSimulators(isVerbose);
      availableDevices.addAll(iosDevices);
    }

    // Android 에뮬레이터 조회
    if (platform == 'android' || platform == 'all') {
      final androidDevices = await _getAndroidEmulators(isVerbose);
      availableDevices.addAll(androidDevices);
    }

    // flutter devices 명령어로 추가 디바이스 확인
    final flutterDevices = await _getFlutterDevices(isVerbose);
    for (final device in flutterDevices) {
      final alreadyExists = availableDevices.any((d) => d.id == device.id);
      if (!alreadyExists) {
        availableDevices.add(device);
      }
    }

    // 요청된 디바이스와 매칭
    final matchedDevices = <DeviceInfo>[];
    final unmatchedDevices = <String>[];

    for (final requested in requestedDevices) {
      final match = _findMatchingDevice(requested, availableDevices);
      if (match != null) {
        matchedDevices.add(match);
      } else {
        unmatchedDevices.add(requested);
      }
    }

    if (isVerbose) {
      print('    사용 가능한 디바이스: ${availableDevices.length}개');
      for (final device in availableDevices) {
        print('      - ${device.name} (${device.id}) [${device.platform}]');
      }
    }

    if (matchedDevices.isEmpty) {
      ScreenshotOutput.printNoDevicesInstructions(
        requestedDevices: requestedDevices,
        availableDevices: availableDevices,
        platform: platform,
      );

      throw CliException(
        '요청된 디바이스를 찾을 수 없습니다',
        solution: '다음을 확인하세요:\n'
            '  1. Xcode 또는 Android Studio가 설치되어 있는지 확인\n'
            '  2. 시뮬레이터/에뮬레이터가 사용 가능한지 확인\n'
            '  3. --devices 옵션으로 디바이스 이름을 정확히 지정\n'
            '  4. flutter devices 명령어로 사용 가능한 디바이스를 확인',
      );
    }

    if (unmatchedDevices.isNotEmpty) {
      // 요청한 디바이스(= ASC 필수 사이즈 슬롯)가 없으면 스크린샷 세트가
      // 불완전해진다 — 과거에는 경고만 찍고 진행해 iPad 슬롯이 조용히
      // 누락됐다. 기본은 hard-fail, 의도적 부분 캡처는 --allow-missing-devices.
      if (!allowMissing) {
        throw CliException(
          '요청한 디바이스를 찾을 수 없습니다: ${unmatchedDevices.join(', ')}',
          solution: '해당 사이즈 슬롯이 비면 스토어 스크린샷 세트가 불완전해집니다.\n'
              '  1. Xcode > Settings > Platforms에서 시뮬레이터를 설치하거나\n'
              '  2. --devices로 설치된 시뮬레이터 이름을 정확히 지정하거나\n'
              '  3. 의도적 부분 캡처면 --allow-missing-devices를 사용하세요.',
        );
      }
      print('');
      print('  ⚠️  일부 디바이스를 찾을 수 없습니다 (--allow-missing-devices):');
      for (final device in unmatchedDevices) {
        print('     - $device');
      }
      print('');
    }

    return matchedDevices;
  }

  /// iOS 시뮬레이터 목록을 조회합니다.
  static Future<List<DeviceInfo>> _getIosSimulators(bool isVerbose) async {
    try {
      final result = await Process.run(
        'xcrun',
        ['simctl', 'list', 'devices', 'available', '--json'],
      );

      if (result.exitCode != 0) {
        if (isVerbose) {
          print('    ⚠ iOS 시뮬레이터 조회 실패 (Xcode가 설치되지 않았을 수 있습니다)');
        }
        return [];
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final devicesMap = json['devices'] as Map<String, dynamic>? ?? {};
      final devices = <DeviceInfo>[];

      for (final entry in devicesMap.entries) {
        final runtime = entry.key;
        // iOS 런타임만 필터링
        if (!runtime.contains('iOS') && !runtime.contains('iPadOS')) {
          continue;
        }

        final deviceList = entry.value as List<dynamic>;
        for (final device in deviceList) {
          final deviceMap = device as Map<String, dynamic>;
          final state = deviceMap['state'] as String? ?? '';
          final isAvailable = deviceMap['isAvailable'] as bool? ?? false;

          if (isAvailable) {
            devices.add(DeviceInfo(
              id: deviceMap['udid'] as String? ?? '',
              name: deviceMap['name'] as String? ?? '',
              platform: 'ios',
              state: state,
            ));
          }
        }
      }

      return devices;
    } catch (e) {
      if (isVerbose) {
        print('    ⚠ iOS 시뮬레이터 조회 중 오류: $e');
      }
      return [];
    }
  }

  /// Android 에뮬레이터 목록을 조회합니다.
  static Future<List<DeviceInfo>> _getAndroidEmulators(bool isVerbose) async {
    try {
      final result = await Process.run(
        'emulator',
        ['-list-avds'],
      );

      if (result.exitCode != 0) {
        if (isVerbose) {
          print('    ⚠ Android 에뮬레이터 조회 실패');
        }
        return [];
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty) return [];

      final devices = output.split('\n').where((l) => l.trim().isNotEmpty).map((name) {
        final trimmedName = name.trim();
        return DeviceInfo(
          id: trimmedName,
          name: trimmedName,
          platform: 'android',
          state: 'available',
        );
      }).toList();

      return devices;
    } catch (e) {
      if (isVerbose) {
        print('    ⚠ Android 에뮬레이터 조회 중 오류: $e');
      }
      return [];
    }
  }

  /// flutter devices 명령어로 디바이스 목록을 조회합니다.
  static Future<List<DeviceInfo>> _getFlutterDevices(bool isVerbose) async {
    try {
      final result = await Process.run(
        'flutter',
        ['devices', '--machine'],
      );

      if (result.exitCode != 0) {
        if (isVerbose) {
          print('    ⚠ flutter devices 조회 실패');
        }
        return [];
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty) return [];

      final json = jsonDecode(output) as List<dynamic>;
      final devices = <DeviceInfo>[];

      for (final device in json) {
        final deviceMap = device as Map<String, dynamic>;
        final targetPlatform =
            deviceMap['targetPlatform'] as String? ?? '';

        String platform;
        if (targetPlatform.contains('ios') ||
            targetPlatform.contains('darwin')) {
          platform = 'ios';
        } else if (targetPlatform.contains('android')) {
          platform = 'android';
        } else {
          continue;
        }

        devices.add(DeviceInfo(
          id: deviceMap['id'] as String? ?? '',
          name: deviceMap['name'] as String? ?? '',
          platform: platform,
          state: 'connected',
        ));
      }

      return devices;
    } catch (e) {
      if (isVerbose) {
        print('    ⚠ flutter devices 조회 중 오류: $e');
      }
      return [];
    }
  }

  /// 요청된 디바이스 이름과 일치하는 디바이스를 찾습니다.
  static DeviceInfo? _findMatchingDevice(
    String requestedName,
    List<DeviceInfo> availableDevices,
  ) {
    final lowerRequested = requestedName.toLowerCase();

    // 정확한 이름 매칭
    for (final device in availableDevices) {
      if (device.name.toLowerCase() == lowerRequested) {
        return device;
      }
    }

    // 부분 매칭
    for (final device in availableDevices) {
      if (device.name.toLowerCase().contains(lowerRequested) ||
          lowerRequested.contains(device.name.toLowerCase())) {
        return device;
      }
    }

    // ID 매칭
    for (final device in availableDevices) {
      if (device.id.toLowerCase() == lowerRequested) {
        return device;
      }
    }

    return null;
  }
}
