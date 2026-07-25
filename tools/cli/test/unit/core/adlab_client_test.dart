import 'dart:convert';
import 'dart:io';

import 'package:boilerplate_cli/core/adlab_client.dart';
import 'package:boilerplate_cli/core/error_handler.dart';
import 'package:test/test.dart';

/// 인메모리 adlab 서버 스텁 — 계약(POST /jobs → 202 {job_id},
/// GET /jobs/{id} → {status, results}, GET /jobs/{id}/result/{i} → bytes,
/// GET /health)만 재현한다.
class _StubAdlab {
  _StubAdlab({
    this.pendingPolls = 0,
    this.failJob = false,
    this.submitStatus = 202,
    this.emptyResults = false,
  });

  /// done 전에 pending을 몇 번 응답할지 (폴링 검증용).
  final int pendingPolls;
  final bool failJob;

  /// POST /jobs 응답 코드 (비정상 응답 검증용).
  final int submitStatus;

  /// done인데 results가 빈 경우 (provider 전멸 재현).
  final bool emptyResults;

  late HttpServer server;
  Map<String, dynamic>? lastJobRequest;
  int polls = 0;
  List<Map<String, dynamic>> results = [
    {'uri': '/out/j1/gem.png', 'seed': 'gem'},
  ];
  List<int> resultBytes = utf8.encode('ENHANCED');

  Future<String> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path;
      final res = req.response;
      if (req.method == 'POST' && path == '/jobs') {
        lastJobRequest =
            jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        res.statusCode = submitStatus;
        res.write(submitStatus == 202
            ? jsonEncode({'job_id': 'j1'})
            : jsonEncode({'detail': 'rejected'}));
      } else if (path == '/jobs/j1') {
        polls++;
        final status = failJob
            ? 'failed'
            : (polls <= pendingPolls ? 'pending' : 'done');
        res.write(jsonEncode({
          'id': 'j1',
          'status': status,
          'error': failJob ? 'all providers failed' : null,
          'results': status == 'done' && !emptyResults ? results : [],
        }));
      } else if (path.startsWith('/jobs/j1/result/')) {
        res.headers.contentType = ContentType.binary;
        res.add(resultBytes);
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
  group('AdlabClient', () {
    test('submitJob posts app/asset_type/payload and returns job id', () async {
      final stub = _StubAdlab();
      final url = await stub.start();
      final client = AdlabClient(baseUrl: url);
      final jobId = await client.submitJob(
        app: 'myapp',
        assetType: 'app_icon',
        payload: {'seeds': ['gem']},
      );
      expect(jobId, 'j1');
      expect(stub.lastJobRequest!['app'], 'myapp');
      expect(stub.lastJobRequest!['asset_type'], 'app_icon');
      expect(stub.lastJobRequest!['payload'], {'seeds': ['gem']});
      await stub.stop();
    });

    test('waitForJob polls until done', () async {
      final stub = _StubAdlab(pendingPolls: 2);
      final url = await stub.start();
      final client = AdlabClient(
          baseUrl: url, pollInterval: const Duration(milliseconds: 5));
      final job = await client.waitForJob('j1');
      expect(job['status'], 'done');
      expect(stub.polls, greaterThanOrEqualTo(3));
      await stub.stop();
    });

    test('waitForJob throws CliException on failed job', () async {
      final stub = _StubAdlab(failJob: true);
      final url = await stub.start();
      final client = AdlabClient(
          baseUrl: url, pollInterval: const Duration(milliseconds: 5));
      await expectLater(
          client.waitForJob('j1'), throwsA(isA<CliException>()));
      await stub.stop();
    });

    test('waitForJob times out with CliException', () async {
      final stub = _StubAdlab(pendingPolls: 1000000);
      final url = await stub.start();
      final client = AdlabClient(
          baseUrl: url,
          pollInterval: const Duration(milliseconds: 5),
          timeout: const Duration(milliseconds: 30));
      await expectLater(
          client.waitForJob('j1'), throwsA(isA<CliException>()));
      await stub.stop();
    });

    test('downloadResult returns raw bytes', () async {
      final stub = _StubAdlab();
      final url = await stub.start();
      final client = AdlabClient(baseUrl: url);
      final bytes = await client.downloadResult('j1', 0);
      expect(utf8.decode(bytes), 'ENHANCED');
      await stub.stop();
    });

    test('isUp true against live server, false against dead port', () async {
      final stub = _StubAdlab();
      final url = await stub.start();
      expect(await AdlabClient(baseUrl: url).isUp(), isTrue);
      await stub.stop();
      expect(await AdlabClient(baseUrl: url).isUp(), isFalse);
    });

    test('generateAppIcon submits app_icon job with prompt/style profile '
        'and returns first result bytes', () async {
      final stub = _StubAdlab();
      final url = await stub.start();
      final client = AdlabClient(
          baseUrl: url, pollInterval: const Duration(milliseconds: 5));
      final bytes = await client.generateAppIcon(
          app: 'myapp', prompt: 'a dice tower', style: 'playful');
      expect(utf8.decode(bytes), 'ENHANCED');
      expect(stub.lastJobRequest!['asset_type'], 'app_icon');
      final payload = stub.lastJobRequest!['payload'] as Map<String, dynamic>;
      expect(payload['profile']['scene'], 'a dice tower');
      expect(payload['profile']['tone'], 'playful');
      await stub.stop();
    });

    test('waitForJob fails fast on non-200 (server restarted, job gone)',
        () async {
      final stub = _StubAdlab();
      final url = await stub.start();
      final client = AdlabClient(
          baseUrl: url,
          pollInterval: const Duration(milliseconds: 5),
          timeout: const Duration(minutes: 30));
      final sw = Stopwatch()..start();
      // 스텁은 /jobs/unknown 에 404를 반환 — 30분 폴링이 아니라 즉시 예외.
      await expectLater(
          client.waitForJob('unknown'), throwsA(isA<CliException>()));
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      await stub.stop();
    });

    test('submitJob non-202 throws CliException without start-server hint',
        () async {
      final stub = _StubAdlab(submitStatus: 400);
      final url = await stub.start();
      final client = AdlabClient(baseUrl: url);
      await expectLater(
        client.submitJob(app: 'a', assetType: 'app_icon', payload: {}),
        throwsA(isA<CliException>().having(
            (e) => e.solution, 'solution', isNot(contains('uvicorn')))),
      );
      await stub.stop();
    });

    test('downloadResult non-200 throws CliException', () async {
      final stub = _StubAdlab();
      final url = await stub.start();
      final client = AdlabClient(baseUrl: url);
      await expectLater(client.downloadResult('nope', 0),
          throwsA(isA<CliException>()));
      await stub.stop();
    });

    test('generateAppIcon with zero results throws CliException', () async {
      final stub = _StubAdlab(emptyResults: true);
      final url = await stub.start();
      final client = AdlabClient(
          baseUrl: url, pollInterval: const Duration(milliseconds: 5));
      await expectLater(
          client.generateAppIcon(app: 'a', prompt: 'x', style: 'y'),
          throwsA(isA<CliException>()));
      await stub.stop();
    });
  });
}
