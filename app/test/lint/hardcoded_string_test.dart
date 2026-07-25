import 'dart:io';

import 'package:test/test.dart';

/// 하드코딩 한국어 문자열 가드 (P2-23d).
///
/// `lib/` 아래 Dart 소스의 **문자열 리터럴**에 한글이 들어 있으면 실패한다.
/// i18n는 easy_localization `'key'.tr()` 패턴으로 해야 한다(키는 영문).
///
/// CI는 영구 off이므로 이 테스트가 로컬 가드다. 점진 마이그레이션을 위해
/// 아직 전환 안 된 파일은 [_allowlist]에 둔다(P2-23d 스윕이 진행되며 비워짐).
/// 의도적 예외(번역 불필요한 한글 리터럴)는 해당 줄에 `// i18n-ignore` 주석.
void main() {
  // lib/ 기준 상대 경로(파일) 또는 디렉토리 접두(끝에 '/'). P2-23d 스윕이
  // 진행되며 비워진다(features/domain/services 사용자 메시지 = PR2/PR3).
  // 비-UI(개발 도구/디자인 메타데이터)는 영구 예외로 남을 수 있다.
  const allowlist = <String>{
    // 코드 생성 dev 도구 (앱 런타임 UI 아님) — 영구 예외
    'data/table_generator/',
    // 디자인 시스템 메타데이터 (테마 표시명/설명) — 별도 결정 시 전환
    'core/design/',
    // 설정/프로파일 메타데이터·디버그 (개발자 콘솔, 앱 UI 아님)
    'config/',
    // ── P2-23d i18n 스윕 완료(2026-06-15): 코어 위젯/다이얼로그(PR1) ·
    // domain/service(PR2) · features permission/auth/settings/home(PR3) ·
    // 입력 위젯(PR4) 전환 완료. 위 3개는 영구 예외(앱 UI 아님). ──
  };

  bool isAllowed(String rel) => allowlist.any(
      (e) => e.endsWith('/') ? rel.startsWith(e) : rel == e);

  // 로깅 호출(logger.x / debugPrint / print)의 한글은 UI가 아니므로 제외.
  final loggingCall = RegExp(r'(logger\.[a-z]+\(|debugPrint\(|[^A-Za-z0-9_]print\()');

  // 문자열 리터럴 안의 한글: 따옴표로 둘러싸인 토큰에 한글이 있으면 매치.
  // (주석 안 한글은 줄 단위로 제외하므로 매치되지 않는다.)
  final stringWithHangul = RegExp(r'''(['"])[^'"\n]*[가-힣ㄱ-ㅎㅏ-ㅣ][^'"\n]*\1''');

  test('lib/ 소스 문자열 리터럴에 하드코딩 한국어가 없다', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'flutter test는 app/ 에서 실행되어야 한다');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue; // 생성 코드 제외
      }
      final rel = entity.path.replaceFirst(RegExp(r'^lib[/\\]'), '');
      if (isAllowed(rel)) continue;

      final lines = entity.readAsLinesSync();
      var inBlockComment = false;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();

        // 블록 주석 /* ... */ 추적(단순 — 한 줄 내 열고닫기는 무시 가능)
        if (inBlockComment) {
          if (trimmed.contains('*/')) inBlockComment = false;
          continue;
        }
        if (trimmed.startsWith('/*')) {
          if (!trimmed.contains('*/')) inBlockComment = true;
          continue;
        }
        // 줄 주석 / 문서 주석 / 블록 주석 본문(*)
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        // 의도적 예외
        if (line.contains('// i18n-ignore')) continue;
        // 로깅(UI 아님)
        if (loggingCall.hasMatch(line)) continue;

        if (stringWithHangul.hasMatch(line)) {
          violations.add('$rel:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '하드코딩 한국어 문자열 발견 (.tr() 전환 또는 allowlist 필요):\n'
          '${violations.join('\n')}',
    );
  });
}
