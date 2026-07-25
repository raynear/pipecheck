import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate_cli/commands/screenshot/screenshot_output.dart';
import 'package:boilerplate_cli/commands/screenshot/screenshot_smoke.dart';
import 'package:boilerplate_cli/core/adlab_client.dart';
import 'package:test/test.dart';

/// 24바이트 IHDR만 유효한 가짜 PNG (enhance는 크기만 readPngSizeBytes로 읽는다).
List<int> fakePng(int w, int h) {
  final b = BytesBuilder();
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  b.add([0, 0, 0, 13]);
  b.add(ascii.encode('IHDR'));
  b.add((ByteData(8)
        ..setUint32(0, w)
        ..setUint32(4, h))
      .buffer
      .asUint8List());
  b.add([0, 0, 0, 0]);
  return b.toBytes();
}

/// store_screenshot batch 계약을 재현하는 최소 스텁. target_size 크기의
/// 결과 PNG를 돌려준다 (wrongSize=true면 10x10, flag=true면 flagged 마킹).
class _StubAdlab {
  _StubAdlab({this.wrongSize = false, this.flag = false});

  final bool wrongSize;
  final bool flag;
  late HttpServer server;
  final _bytes = <String, List<List<int>>>{};

  Future<String> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path;
      final res = req.response;
      if (req.method == 'POST' && path == '/jobs') {
        final body = jsonDecode(await utf8.decoder.bind(req).join())
            as Map<String, dynamic>;
        final payload = body['payload'] as Map<String, dynamic>;
        final names = (payload['names'] as List).cast<String>();
        final target = (payload['target_size'] as List).cast<int>();
        _bytes['job0'] = [
          for (var i = 0; i < names.length; i++)
            wrongSize ? fakePng(10, 10) : fakePng(target[0], target[1]),
        ];
        res.statusCode = 202;
        res.write(jsonEncode({'job_id': 'job0'}));
      } else if (RegExp(r'^/jobs/([^/]+)$').hasMatch(path)) {
        // 결과는 제출 시 이미 만들어 뒀지만, 계약상 done + results를 돌려준다.
        res.write(jsonEncode({
          'id': 'job0',
          'status': 'done',
          'results': [
            for (var i = 0; i < (_bytes['job0']?.length ?? 0); i++)
              {
                'uri': '/out/job0/$i.png',
                'name': '$i',
                if (flag) 'flagged': ['leak'],
              }
          ],
        }));
      } else if (RegExp(r'^/jobs/([^/]+)/result/(\d+)$').hasMatch(path)) {
        final parts = path.split('/');
        res.headers.contentType = ContentType.binary;
        res.add(_bytes[parts[2]]![int.parse(parts[4])]);
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
  test('dummy PNG constant decodes to a 320x640 PNG', () {
    // enhance는 IHDR 크기로 그룹핑/target_size를 정한다 — 상수가 깨지면 스모크 무의미.
    final png = base64Decode(ScreenshotSmoke.dummyPngB64);
    expect(png.sublist(0, 8),
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(ScreenshotOutput.readPngSizeBytes(png), [320, 640]);
  });

  group('ScreenshotSmoke.run', () {
    late _StubAdlab stub;
    tearDown(() => stub.stop());

    Future<int> runAgainst(_StubAdlab s) async {
      stub = s;
      final client = AdlabClient(
          baseUrl: await s.start(),
          pollInterval: const Duration(milliseconds: 5));
      return ScreenshotSmoke.run(client: client, app: 'myapp', isVerbose: false);
    }

    test('PASS (exit 0) when the live path returns a correctly sized mockup',
        () async {
      expect(await runAgainst(_StubAdlab()), 0);
    });

    test('PASS (exit 0) when the mockup is flagged (gen+resize still worked)',
        () async {
      expect(await runAgainst(_StubAdlab(flag: true)), 0);
    });

    test('FAIL (exit 1) when the mockup size is wrong', () async {
      expect(await runAgainst(_StubAdlab(wrongSize: true)), 1);
    });
  });

  test('run returns 1 (FAIL) when the server is unreachable', () async {
    // 반드시 닫힌 포트로 — isUp이 false여야 한다.
    final dead = AdlabClient(baseUrl: 'http://127.0.0.1:1');
    expect(await ScreenshotSmoke.run(client: dead, app: 'x', isVerbose: false),
        1);
  });
}
