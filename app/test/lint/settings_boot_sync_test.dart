import 'dart:io';

import 'package:test/test.dart';

/// 보안 가드 (PR #100 리뷰 Critical-1 회귀 방지).
///
/// SettingsNotifier.build()가 Orange 로드를 microtask 뒤로 미루면,
/// 부팅 첫 read(라우터 redirect는 동기 실행)가 Settings.initial()
/// (userAuthOption=none)을 보게 되어 **PIN/생체 잠금이 우회**된다
/// (authState가 "잠금 없음"으로 판정해 자동 인증 → 잠금 화면 미표시).
/// Orange.init()은 runApp 전에 await되므로 build()는 동기 로드여야 한다.
///
/// unit 테스트에서 Orange를 seed할 수 없어(_map private + path_provider)
/// 소스 구조로 고정한다 — hardcoded_string_test.dart와 같은 방식.
void main() {
  test('SettingsNotifier.build는 Orange 로드를 미루지 않는다 (동기 fromOrange)', () {
    final source =
        File('lib/core/state/settings.dart').readAsStringSync();

    // build() 본문 추출 (SettingsNotifier 클래스 내 첫 build)
    final rawBody = RegExp(
      r'class SettingsNotifier[\s\S]*?Settings build\(\)\s*\{([\s\S]*?)\n  \}',
    ).firstMatch(source)?.group(1);

    expect(rawBody, isNotNull,
        reason: 'SettingsNotifier.build()를 찾지 못함 — 리팩토링 시 이 가드를 갱신하세요');

    // 주석은 위험을 설명하느라 금지 단어를 언급할 수 있다 — 코드 줄만 검사.
    final buildBody = rawBody!
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(buildBody, contains('Settings.fromOrange()'),
        reason: 'build()는 fromOrange()를 동기 반환해야 한다');
    expect(buildBody, isNot(contains('microtask')),
        reason: '로드를 microtask로 미루면 부팅 첫 read가 initial(none)을 보아 잠금이 우회된다');
    expect(buildBody, isNot(contains('Settings.initial()')),
        reason: 'build()가 initial()을 반환하면 잠금 사용자도 none으로 판정된다');
  });
}
