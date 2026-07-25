import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate_cli/commands/screenshot/screenshot_enhance.dart';
import 'package:boilerplate_cli/core/adlab_client.dart';
import 'package:test/test.dart';

/// 최소 PNG: 시그니처(8) + IHDR length(4) + "IHDR"(4) + width(4) + height(4).
/// ScreenshotOutput.readPngSizeBytes가 읽는 앞 24바이트만 유효하면 된다.
List<int> fakePng(int w, int h, {String tag = ''}) {
  final b = BytesBuilder();
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  b.add([0, 0, 0, 13]);
  b.add(ascii.encode('IHDR'));
  b.add((ByteData(8)
        ..setUint32(0, w)
        ..setUint32(4, h))
      .buffer
      .asUint8List());
  b.add(utf8.encode(tag)); // 파일별 구분용
  return b.toBytes();
}

bool hasTag(List<int> bytes, String tag) =>
    utf8.decode(bytes.sublist(24), allowMalformed: true).contains(tag);

/// batch store_screenshot 계약을 재현하는 스텁 서버.
/// 각 이미지에 대해 target_size 크기의 "ENHANCED" 태그 PNG를 돌려준다.
class _StubAdlab {
  _StubAdlab({
    this.failNames = const {},
    this.flagNames = const {},
    this.wrongSizeNames = const {},
    this.dropLastResult = false,
    this.failSubmitCount = 0,
  });

  final Set<String> failNames;
  final Set<String> flagNames;

  /// target_size를 무시하고 10x10을 반환할 파일들 (서버 리사이즈 실패 재현).
  final Set<String> wrongSizeNames;

  /// results 배열을 하나 모자라게 반환 (방어 분기 검증).
  final bool dropLastResult;

  /// 앞에서 몇 번의 POST /jobs를 500으로 실패시킬지.
  int failSubmitCount;

  late HttpServer server;
  final jobRequests = <Map<String, dynamic>>[];
  final _jobResults = <String, List<Map<String, dynamic>>>{};
  final _jobBytes = <String, List<List<int>>>{};
  var _nextJob = 0;

  Future<String> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path;
      final res = req.response;
      if (req.method == 'POST' && path == '/jobs') {
        final body = jsonDecode(await utf8.decoder.bind(req).join())
            as Map<String, dynamic>;
        if (failSubmitCount > 0) {
          failSubmitCount--;
          res.statusCode = 500;
          res.write('boom');
          await res.close();
          return;
        }
        jobRequests.add(body);
        final jobId = 'job${_nextJob++}';
        final payload = body['payload'] as Map<String, dynamic>;
        final names = (payload['names'] as List).cast<String>();
        final target = (payload['target_size'] as List).cast<int>();
        final results = <Map<String, dynamic>>[];
        final bytes = <List<int>>[];
        for (var i = 0; i < names.length; i++) {
          if (failNames.contains(names[i])) {
            results.add({
              'uri': '',
              'error': 'generation_failed',
              'name': names[i],
            });
            bytes.add(const []);
          } else {
            final r = <String, dynamic>{
              'uri': '/out/$jobId/$i.png',
              'name': names[i],
            };
            if (flagNames.contains(names[i])) r['flagged'] = ['leak'];
            results.add(r);
            bytes.add(wrongSizeNames.contains(names[i])
                ? fakePng(10, 10, tag: 'ENHANCED')
                : fakePng(target[0], target[1], tag: 'ENHANCED'));
          }
        }
        if (dropLastResult && results.isNotEmpty) results.removeLast();
        _jobResults[jobId] = results;
        _jobBytes[jobId] = bytes;
        res.statusCode = 202;
        res.write(jsonEncode({'job_id': jobId}));
      } else if (RegExp(r'^/jobs/([^/]+)$').hasMatch(path)) {
        final id = path.split('/')[2];
        res.write(jsonEncode(
            {'id': id, 'status': 'done', 'results': _jobResults[id] ?? []}));
      } else if (RegExp(r'^/jobs/([^/]+)/result/(\d+)$').hasMatch(path)) {
        final parts = path.split('/');
        res.headers.contentType = ContentType.binary;
        res.add(_jobBytes[parts[2]]![int.parse(parts[4])]);
      } else if (path == '/health') {
        res.write(jsonEncode({'status': 'ok'}));
      } else {
        res.statusCode = 404;
      }
      await res.close();
    });
    return 'http://127.0.0.1:${server.port}';
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  late Directory tmp;
  late _StubAdlab stub;

  Future<AdlabClient> clientFor(_StubAdlab s) async => AdlabClient(
      baseUrl: await s.start(),
      pollInterval: const Duration(milliseconds: 5));

  File shot(String rel, List<int> bytes) {
    final f = File('${tmp.path}/screenshots/$rel')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return f;
  }

  Future<EnhanceReport> run(AdlabClient client, {String seed = ''}) =>
      ScreenshotEnhancer.enhance(
        client: client,
        app: 'myapp',
        projectRoot: tmp.path,
        outputDir: 'screenshots',
        seed: seed,
        isVerbose: false,
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('enhance_test');
  });

  tearDown(() async {
    await stub.stop();
    tmp.deleteSync(recursive: true);
  });

  test('enhances every png in place and backs up originals', () async {
    stub = _StubAdlab();
    final client = await clientFor(stub);
    final originalA = fakePng(1320, 2868, tag: 'a');
    shot('ios/en/01.png', originalA);
    shot('ios/en/02.png', fakePng(1320, 2868, tag: 'b'));

    final report = await run(client);

    expect(report.enhanced, 2);
    expect(report.failed, isEmpty);
    // 캡처 원본 백업
    expect(
        File('${tmp.path}/screenshots/originals/ios/en/01.png')
            .readAsBytesSync(),
        originalA);
    // 제자리 덮어쓰기 (업로드 경로 불변) + 목업 바이트로 교체됨
    final enhanced =
        File('${tmp.path}/screenshots/ios/en/01.png').readAsBytesSync();
    expect(hasTag(enhanced, 'ENHANCED'), isTrue);
    // target_size = 원본 크기 → 스토어 스펙 유지
    final payload = stub.jobRequests.single['payload'] as Map<String, dynamic>;
    expect(payload['batch'], true);
    expect(payload['target_size'], [1320, 2868]);
    expect(stub.jobRequests.single['asset_type'], 'store_screenshot');
  });

  test('groups by dimension — one batch job per size', () async {
    stub = _StubAdlab();
    final client = await clientFor(stub);
    shot('ios/en/phone.png', fakePng(1320, 2868));
    shot('ios/en/tablet.png', fakePng(2048, 2732));

    await run(client);

    expect(stub.jobRequests, hasLength(2));
    final sizes = stub.jobRequests
        .map((r) => (r['payload'] as Map)['target_size'])
        .toList();
    expect(
        sizes,
        containsAll([
          [1320, 2868],
          [2048, 2732],
        ]));
  });

  test('failed generation keeps the original file untouched', () async {
    stub = _StubAdlab(failNames: {'01.png'});
    final client = await clientFor(stub);
    final original = fakePng(1320, 2868, tag: 'keep-me');
    shot('ios/en/01.png', original);
    shot('ios/en/02.png', fakePng(1320, 2868));

    final report = await run(client);

    expect(report.enhanced, 1);
    expect(report.failed, ['ios/en/01.png']);
    expect(File('${tmp.path}/screenshots/ios/en/01.png').readAsBytesSync(),
        original);
  });

  test('wrong-dimension mockup is rejected, original kept', () async {
    stub = _StubAdlab(wrongSizeNames: {'01.png'});
    final client = await clientFor(stub);
    final original = fakePng(1320, 2868, tag: 'keep-me');
    shot('ios/en/01.png', original);

    final report = await run(client);

    expect(report.enhanced, 0);
    expect(report.failed, ['ios/en/01.png']);
    expect(File('${tmp.path}/screenshots/ios/en/01.png').readAsBytesSync(),
        original);
  });

  test('flagged mockup is quarantined to flagged/, original stays in place',
      () async {
    stub = _StubAdlab(flagNames: {'01.png'});
    final client = await clientFor(stub);
    final original = fakePng(1320, 2868, tag: 'orig');
    shot('ios/en/01.png', original);

    final report = await run(client);

    expect(report.enhanced, 0);
    expect(report.flagged, ['ios/en/01.png']);
    // 스토어 업로드 경로에는 원본이 그대로
    expect(File('${tmp.path}/screenshots/ios/en/01.png').readAsBytesSync(),
        original);
    // 목업은 격리 위치에
    final quarantined =
        File('${tmp.path}/screenshots/flagged/ios/en/01.png');
    expect(quarantined.existsSync(), isTrue);
    expect(hasTag(quarantined.readAsBytesSync(), 'ENHANCED'), isTrue);
  });

  test('re-run enhances from the backup and never clobbers the true original',
      () async {
    stub = _StubAdlab();
    final client = await clientFor(stub);
    final original = fakePng(1320, 2868, tag: 'true-original');
    shot('ios/en/01.png', original);

    await run(client); // 1차: 백업 생성 + 목업 덮어쓰기
    await run(client); // 2차: 파일은 이미 목업

    // 백업은 여전히 진짜 원본 (목업의 목업 방지의 핵심)
    expect(
        File('${tmp.path}/screenshots/originals/ios/en/01.png')
            .readAsBytesSync(),
        original);
    // 2차 잡의 입력도 진짜 원본이어야 한다 (현재 파일=목업이 아니라)
    final secondPayload =
        stub.jobRequests[1]['payload'] as Map<String, dynamic>;
    expect((secondPayload['screenshots_b64'] as List).single,
        base64Encode(original));
  });

  test('group-level submit failure fails that group but continues others',
      () async {
    stub = _StubAdlab(failSubmitCount: 1);
    final client = await clientFor(stub);
    final phoneOriginal = fakePng(1320, 2868, tag: 'phone');
    shot('ios/en/phone.png', phoneOriginal);
    shot('ios/en/tablet.png', fakePng(2048, 2732, tag: 'tablet'));

    final report = await run(client);

    // 한 그룹은 500으로 실패, 다른 그룹은 성공 (부분 성공)
    expect(report.enhanced, 1);
    expect(report.failed, hasLength(1));
  });

  test('missing trailing results are treated as failures', () async {
    stub = _StubAdlab(dropLastResult: true);
    final client = await clientFor(stub);
    shot('ios/en/01.png', fakePng(1320, 2868));
    shot('ios/en/02.png', fakePng(1320, 2868));

    final report = await run(client);

    expect(report.enhanced, 1);
    expect(report.failed, ['ios/en/02.png']);
  });

  test('re-run skips originals/ and flagged/ dirs (no recursive enhancement)',
      () async {
    stub = _StubAdlab();
    final client = await clientFor(stub);
    shot('ios/en/01.png', fakePng(1320, 2868));
    shot('originals/ios/en/01.png', fakePng(1320, 2868));
    shot('flagged/ios/en/01.png', fakePng(1320, 2868));

    await run(client);

    final names = ((stub.jobRequests.single['payload'] as Map)['names'] as List);
    expect(names, hasLength(1));
  });

  test('passes seed through to the batch payload', () async {
    stub = _StubAdlab();
    final client = await clientFor(stub);
    shot('ios/en/01.png', fakePng(1320, 2868));

    await run(client, seed: 'wood desk');

    final payload = stub.jobRequests.single['payload'] as Map<String, dynamic>;
    expect(payload['seeds'], ['wood desk']);
  });
}
