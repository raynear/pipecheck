import 'dart:io';

import 'package:path/path.dart' as p;

/// 사용자 설정 경로(keystore, service-account JSON 등)를 실제 파일 경로로 확장한다.
///
/// 규칙 (첫 매칭에서 멈춤):
/// - `~` / `~/…`  → `HOME` 기준으로 확장. `HOME`이 없으면 **원본을 그대로 반환**해
///   `/x`로 잘못 해석되지 않고 에러가 진단 가능하게 남는다 (fail-safe).
/// - 절대 경로     → 그대로 (projectRoot 무시).
/// - 상대 경로     → `projectRoot`가 주어지면 그 아래로 join, 없으면 그대로.
///
/// [home]은 테스트 주입용. 기본값은 `Platform.environment['HOME']`.
///
/// 도입 배경: project.yaml의 `keystore_path`/`google_json_key`에 `~/key.jks`
/// 같은 값을 쓰면 preflight/서명 게이트가 raw `File()`로 검사해 오탐(false-fail)했다.
/// deploy 레인에만 있던 `~` 확장을 공용화해 게이트 전반에서 일관되게 쓴다.
String expandUserPath(String path, {String? projectRoot, String? home}) {
  if (path.isEmpty) return path;

  if (path == '~' || path.startsWith('~/')) {
    final h = home ?? Platform.environment['HOME'];
    if (h == null || h.isEmpty) return path; // fail-safe: 원본 유지
    if (path == '~') return h;
    return p.join(h, path.substring(2));
  }

  if (p.isAbsolute(path)) return path;

  if (projectRoot != null && projectRoot.isNotEmpty) {
    return p.join(projectRoot, path);
  }
  return path;
}
