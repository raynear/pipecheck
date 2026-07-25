import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'error_handler.dart';

/// adlab(로컬 AI 마케팅 에셋 서비스, ~/Project/adlab) HTTP 클라이언트.
///
/// 계약: `POST /jobs` → 202 `{job_id}` · `GET /jobs/{id}` →
/// `{status: pending|running|done|failed|cancelled, results: [...]}` ·
/// `GET /jobs/{id}/result/{i}` → 이미지 바이트 · `GET /health`.
/// 서버 주소는 `ADLAB_URL` 환경변수(기본 `http://127.0.0.1:8791`).
class AdlabClient {
  AdlabClient({
    String? baseUrl,
    this.pollInterval = const Duration(seconds: 2),
    // 이미지 1장당 최대 4회 생성+비전 저지 재시도라 배치가 길어질 수 있다.
    this.timeout = const Duration(minutes: 30),
  }) : base = Uri.parse(baseUrl ??
            Platform.environment['ADLAB_URL'] ??
            'http://127.0.0.1:8791');

  final Uri base;
  final Duration pollInterval;
  final Duration timeout;

  static const startHint = 'adlab 서버를 실행하세요:\n'
      '  cd ~/Project/adlab && ADLAB_STORAGE=./out '
      'uvicorn adlab.server:app --host 127.0.0.1 --port 8791\n'
      '다른 주소면 ADLAB_URL 환경변수로 지정하세요.';

  /// 서버 헬스체크. 연결 실패는 false (예외 없음).
  Future<bool> isUp() async {
    try {
      final (status, _) = await _request('GET', '/health');
      return status == 200;
    } on IOException {
      return false;
    }
  }

  /// 잡 제출 → job_id 반환.
  Future<String> submitJob({
    required String app,
    required String assetType,
    required Map<String, dynamic> payload,
  }) async {
    final (status, body) = await _request('POST', '/jobs', body: {
      'app': app,
      'asset_type': assetType,
      'count': 1,
      'payload': payload,
    });
    if (status != 202) {
      throw CliException(
        'adlab 잡 제출 실패 ($status): $body',
        // 4xx는 서버가 살아서 요청을 거부한 것 — 서버 기동 안내는 오답.
        solution: status >= 500
            ? startHint
            : '요청 내용을 확인하세요 (adlab 서버 응답 본문 참조).',
      );
    }
    return (jsonDecode(body) as Map<String, dynamic>)['job_id'] as String;
  }

  /// done까지 폴링. failed/cancelled/timeout/HTTP 오류면 CliException.
  Future<Map<String, dynamic>> waitForJob(String jobId) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final (statusCode, body) = await _request('GET', '/jobs/$jobId');
      if (statusCode != 200) {
        // adlab JobStore는 인메모리 — 서버 재시작 시 404. 30분 폴링 대신 즉시 실패.
        throw CliException(
          'adlab 잡 조회 실패 ($statusCode): $body',
          solution: 'adlab 서버가 재시작되어 잡이 사라졌을 수 있습니다 — 재실행하세요.',
        );
      }
      final job = jsonDecode(body) as Map<String, dynamic>;
      final status = job['status'] as String?;
      if (status == 'done') return job;
      if (status == 'failed' || status == 'cancelled') {
        throw CliException(
          'adlab 잡 $status: ${job['error'] ?? '원인 미상'}',
          solution: 'adlab 서버 로그를 확인하세요 '
              '(provider 키 GEMINI_API_KEY/OPENAI_API_KEY 설정 여부 포함).',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw CliException(
          'adlab 잡 타임아웃 (${timeout.inMinutes}분): $jobId',
          solution: 'adlab 서버 로그를 확인하거나 이미지 수를 줄여 재시도하세요.',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  /// results[index] 이미지 바이트 다운로드.
  Future<List<int>> downloadResult(String jobId, int index) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(base.resolve('/jobs/$jobId/result/$index'));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw CliException('adlab 결과 다운로드 실패 '
            '($jobId/$index, HTTP ${res.statusCode})');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
      }
      return builder.toBytes();
    } finally {
      client.close();
    }
  }

  /// app_icon 잡 원샷: 프롬프트/스타일 → 1024×1024 아이콘 PNG 바이트.
  Future<List<int>> generateAppIcon({
    required String app,
    required String prompt,
    required String style,
    String seed = 'v1',
  }) async {
    final jobId = await submitJob(app: app, assetType: 'app_icon', payload: {
      'profile': {'scene': prompt, 'tone': style},
      'seeds': [seed],
    });
    final job = await waitForJob(jobId);
    final results = job['results'] as List<dynamic>;
    if (results.isEmpty) {
      throw CliException(
        'adlab이 아이콘을 생성하지 못했습니다 (결과 0개)',
        solution: 'adlab 서버에 provider API 키(GEMINI_API_KEY 또는 '
            'OPENAI_API_KEY)가 설정돼 있는지 확인하세요.',
      );
    }
    return downloadResult(jobId, 0);
  }

  Future<(int, String)> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.openUrl(method, base.resolve(path));
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close();
      final text = await utf8.decoder.bind(res).join();
      return (res.statusCode, text);
    } finally {
      client.close();
    }
  }
}
