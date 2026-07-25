// What's-new 표시 판단 테스트 (P2-24).
//
// WhatsNewService는 package_info/SharedPreferences에 결합하지 않고
// readVersion/readLastSeen/writeLastSeen 람다만 받으므로 플러그인 없이 검증한다.
// 트리거 = semver 마이너 이상(패치는 스킵, 사용자 결정).

import 'package:pipecheck/core/services/whats_new_service.dart';
import 'package:flutter_test/flutter_test.dart';

WhatsNewService _svc(
  String current,
  String? lastSeen, {
  void Function(String)? onWrite,
}) =>
    WhatsNewService(
      readVersion: () async => current,
      readLastSeen: () async => lastSeen,
      writeLastSeen: (v) async => onWrite?.call(v),
    );

void main() {
  group('WhatsNewService.shouldShow — semver 마이너 이상', () {
    test('마이너 증가 → 표시', () async {
      expect(await _svc('1.2.0', '1.1.5').shouldShow(), true);
    });

    test('메이저 증가 → 표시', () async {
      expect(await _svc('2.0.0', '1.9.9').shouldShow(), true);
    });

    test('패치만 증가 → 표시 안 함', () async {
      expect(await _svc('1.2.1', '1.2.0').shouldShow(), false);
    });

    test('동일 버전 → 표시 안 함', () async {
      expect(await _svc('1.2.0', '1.2.0').shouldShow(), false);
    });

    test('다운그레이드 → 표시 안 함', () async {
      expect(await _svc('1.1.0', '1.2.0').shouldShow(), false);
    });

    test('첫 실행(lastSeen null) → 표시 안 함', () async {
      expect(await _svc('1.0.0', null).shouldShow(), false);
    });

    test('lastSeen 미파싱 → 표시 안 함', () async {
      expect(await _svc('1.2.0', 'garbage').shouldShow(), false);
    });

    test('현재 버전 미파싱 → 표시 안 함', () async {
      expect(await _svc('not-a-version', '1.0.0').shouldShow(), false);
    });

    test('빌드 메타(+N)/프리릴리스(-x)는 무시하고 비교', () async {
      expect(await _svc('1.2.0+13', '1.1.0+9').shouldShow(), true);
      expect(await _svc('1.2.1+14', '1.2.0+13').shouldShow(), false);
      expect(await _svc('1.2.0-beta', '1.1.0').shouldShow(), true);
    });
  });

  group('WhatsNewService.markSeen', () {
    test('현재 버전을 기록', () async {
      String? written;
      await _svc('1.2.0', '1.0.0', onWrite: (v) => written = v).markSeen();
      expect(written, '1.2.0');
    });

    test('현재 버전이 파싱 불가면 기록 안 함(쓰레기 기준선 방지)', () async {
      String? written;
      await _svc('garbage', '1.0.0', onWrite: (v) => written = v).markSeen();
      expect(written, isNull);
    });
  });
}
