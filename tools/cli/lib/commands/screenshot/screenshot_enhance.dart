import 'dart:convert';
import 'dart:io';

import '../../core/adlab_client.dart';
import 'screenshot_output.dart';

/// enhance 실행 결과 요약.
class EnhanceReport {
  int enhanced = 0;

  /// 생성 실패/크기 불일치/다운로드 실패로 원본을 유지한 파일 (outputDir 상대 경로).
  final failed = <String>[];

  /// 비전 저지를 끝내 통과 못 한 파일 — 목업은 `flagged/`로 격리하고 원본을
  /// 유지했다 (judge-pass ≠ ship-ready: 결함 가능 목업을 스토어로 보내지 않는다).
  final flagged = <String>[];
}

/// 캡처된 스크린샷을 adlab `store_screenshot` batch로 마케팅 목업화한다.
///
/// - 파일은 **제자리 덮어쓰기** → deliver/supply 업로드 경로 불변.
/// - 진짜 원본은 `<outputDir>/originals/`에 1회만 백업 — 재실행 시 백업본을
///   입력으로 써서 목업의 목업(재귀 목업)과 백업 유실을 막는다.
/// - 크기 그룹별(디바이스별)로 잡을 나눠 target_size = 원본 크기 → 스토어 스펙 유지.
///   다운로드한 목업의 실제 크기가 다르면 실패 처리 (서버는 리사이즈 실패를 삼킨다).
/// - 저지 미통과(flagged) 목업은 `<outputDir>/flagged/`로 격리, 원본 유지.
/// - 그룹/파일 단위 오류는 해당 항목만 실패 처리하고 나머지는 계속 (부분 성공).
class ScreenshotEnhancer {
  ScreenshotEnhancer._();

  static Future<EnhanceReport> enhance({
    required AdlabClient client,
    required String app,
    required String projectRoot,
    required String outputDir,
    String seed = '',
    required bool isVerbose,
  }) async {
    final report = EnhanceReport();
    final root = Directory('$projectRoot/$outputDir');
    final backupRoot = '${root.path}/originals';
    final flaggedRoot = '${root.path}/flagged';

    // (디렉토리, WxH) 단위로 그룹핑 — adlab batch는 잡당 target_size 하나.
    // 입력은 항상 진짜 원본(백업본이 있으면 백업본)이다.
    final groups = <String, List<_Shot>>{};
    if (!root.existsSync()) return report;
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      if (!f.path.toLowerCase().endsWith('.png')) continue;
      if (f.path.startsWith('$backupRoot/') ||
          f.path.startsWith('$flaggedRoot/')) {
        continue;
      }
      final rel = f.path.substring(root.path.length + 1);
      final backup = File('$backupRoot/$rel');
      final source = backup.existsSync() ? backup : f;
      final bytes = source.readAsBytesSync();
      final dim = ScreenshotOutput.readPngSizeBytes(bytes);
      if (dim == null) continue;
      final shot = _Shot(file: f, rel: rel, sourceBytes: bytes, dims: dim);
      groups
          .putIfAbsent('${f.parent.path}|${dim[0]}x${dim[1]}', () => [])
          .add(shot);
    }

    for (final entry in groups.entries) {
      final shots = entry.value..sort((a, b) => a.rel.compareTo(b.rel));
      final dims = shots.first.dims;
      final List<Map> results;
      final String jobId;
      try {
        jobId = await client.submitJob(
          app: app,
          assetType: 'store_screenshot',
          payload: {
            'batch': true,
            'names': [for (final s in shots) s.file.uri.pathSegments.last],
            'screenshots_b64': [
              for (final s in shots) base64Encode(s.sourceBytes),
            ],
            'seeds': seed.isEmpty ? <String>[] : [seed],
            'target_size': dims,
          },
        );
        if (isVerbose) {
          print('    adlab 잡 $jobId: ${shots.length}개 '
              '(${dims[0]}x${dims[1]})');
        }
        final job = await client.waitForJob(jobId);
        results = (job['results'] as List<dynamic>).cast<Map>();
      } catch (e) {
        // 그룹 단위 실패 — 다른 그룹은 계속 (부분 성공 허용).
        print('  ⚠️  adlab 잡 실패 (${dims[0]}x${dims[1]} 그룹): $e');
        report.failed.addAll([for (final s in shots) s.rel]);
        continue;
      }

      for (var i = 0; i < shots.length; i++) {
        final shot = shots[i];
        final result = i < results.length ? results[i] : null;
        if (result == null || (result['uri'] as String? ?? '').isEmpty) {
          report.failed.add(shot.rel);
          continue;
        }
        final List<int> bytes;
        try {
          bytes = await client.downloadResult(jobId, i);
        } catch (e) {
          print('  ⚠️  결과 다운로드 실패 (${shot.rel}): $e');
          report.failed.add(shot.rel);
          continue;
        }
        // 서버 _apply_target은 리사이즈 실패를 삼키므로 크기를 직접 검증한다.
        final gotDim = ScreenshotOutput.readPngSizeBytes(bytes);
        if (gotDim == null || gotDim[0] != dims[0] || gotDim[1] != dims[1]) {
          print('  ⚠️  목업 크기 불일치 (${shot.rel}: '
              '기대 ${dims[0]}x${dims[1]}, 실제 ${gotDim?.join('x')})');
          report.failed.add(shot.rel);
          continue;
        }
        final flaggedResult = result['flagged'];
        if (flaggedResult is List && flaggedResult.isNotEmpty) {
          // 결함 가능 목업은 스토어 경로에 두지 않고 격리 — 사람이 보고
          // 괜찮으면 수동으로 승격한다.
          File('$flaggedRoot/${shot.rel}')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes);
          report.flagged.add(shot.rel);
          continue;
        }
        // 진짜 원본 백업은 최초 1회만 (재실행이 원본을 덮지 않게).
        final backup = File('$backupRoot/${shot.rel}');
        if (!backup.existsSync()) {
          backup
            ..createSync(recursive: true)
            ..writeAsBytesSync(shot.sourceBytes);
        }
        shot.file.writeAsBytesSync(bytes);
        report.enhanced++;
      }
    }
    return report;
  }
}

class _Shot {
  _Shot({
    required this.file,
    required this.rel,
    required this.sourceBytes,
    required this.dims,
  });

  final File file;
  final String rel;
  final List<int> sourceBytes;
  final List<int> dims;
}
