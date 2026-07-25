// PIN 인증 엔진 테스트 (P2-23h PR1).
//
// PinService는 SecureStore 인터페이스에 결합하므로 flutter_secure_storage
// 플러그인 없이 인메모리 가짜 저장소로 검증한다. 잠금 시각 계산은 주입한
// clock으로 결정적으로 검증한다(시계 조작 시나리오 포함).

import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStore implements SecureStore {
  final Map<String, String> map = {};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  late _FakeSecureStore store;
  late DateTime now;
  late PinService service;

  setUp(() {
    store = _FakeSecureStore();
    now = DateTime.utc(2026, 1, 1, 12);
    service = PinService(store, clock: () => now);
  });

  group('형식 검증', () {
    test('6자리 숫자만 유효', () {
      expect(service.isValidFormat('123456'), true);
      expect(service.isValidFormat('12345'), false);
      expect(service.isValidFormat('1234567'), false);
      expect(service.isValidFormat('12345a'), false);
      expect(service.isValidFormat(''), false);
    });
  });

  group('설정/검증', () {
    test('설정 전에는 PIN 없음', () async {
      expect(await service.hasPin(), false);
      final r = await service.verifyPin('123456');
      expect(r.outcome, PinVerifyOutcome.noPin);
    });

    test('설정 후 정확한 PIN은 성공', () async {
      await service.setPin('123456');
      expect(await service.hasPin(), true);
      final r = await service.verifyPin('123456');
      expect(r.isSuccess, true);
    });

    test('잘못된 형식 설정은 ArgumentError', () async {
      expect(() => service.setPin('12ab'), throwsArgumentError);
    });

    test('평문이 아니라 해시로 저장(salt 동반)', () async {
      await service.setPin('123456');
      // 어떤 키에도 평문 PIN이 그대로 들어가면 안 된다.
      expect(store.map.values.any((v) => v == '123456'), false);
      expect(store.map['pin_hash'], isNotNull);
      expect(store.map['pin_salt'], isNotNull);
      expect(store.map['pin_hash'], isNot('123456'));
    });

    test('salt가 달라 같은 PIN도 해시가 매번 다름', () async {
      await service.setPin('123456');
      final h1 = store.map['pin_hash'];
      await service.setPin('123456');
      final h2 = store.map['pin_hash'];
      expect(h1, isNot(h2));
    });
  });

  group('오입력 카운트', () {
    test('틀리면 남은 시도 횟수가 줄어든다', () async {
      await service.setPin('123456');
      for (var i = 1; i <= 4; i++) {
        final r = await service.verifyPin('000000');
        expect(r.outcome, PinVerifyOutcome.wrong);
        expect(r.attemptsRemaining, 5 - i);
      }
    });

    test('5회 틀리면 잠금(약 30초)', () async {
      await service.setPin('123456');
      for (var i = 1; i <= 4; i++) {
        await service.verifyPin('000000');
      }
      final r = await service.verifyPin('000000');
      expect(r.outcome, PinVerifyOutcome.lockedOut);
      expect(r.lockRemaining!.inSeconds, inInclusiveRange(29, 30));
    });

    test('잠금 중에는 정확한 PIN도 거부', () async {
      await service.setPin('123456');
      for (var i = 1; i <= 5; i++) {
        await service.verifyPin('000000');
      }
      final r = await service.verifyPin('123456');
      expect(r.outcome, PinVerifyOutcome.lockedOut);
    });
  });

  group('잠금 에스컬레이션', () {
    test('배치마다 잠금이 길어진다: 30s → 1m → 5m', () async {
      await service.setPin('123456');

      Future<Duration> lockOnce() async {
        Duration last = Duration.zero;
        for (var i = 1; i <= 5; i++) {
          final r = await service.verifyPin('000000');
          if (r.outcome == PinVerifyOutcome.lockedOut) last = r.lockRemaining!;
        }
        return last;
      }

      final d1 = await lockOnce();
      expect(d1.inSeconds, 30);

      now = now.add(const Duration(seconds: 31)); // 1차 잠금 해제
      final d2 = await lockOnce();
      expect(d2.inMinutes, 1);

      now = now.add(const Duration(minutes: 2)); // 2차 잠금 해제
      final d3 = await lockOnce();
      expect(d3.inMinutes, 5);
    });

    test('잠금 해제 후 5회 새 시도가 허용된다', () async {
      await service.setPin('123456');
      for (var i = 1; i <= 5; i++) {
        await service.verifyPin('000000');
      }
      now = now.add(const Duration(seconds: 31));
      final r = await service.verifyPin('000000');
      expect(r.outcome, PinVerifyOutcome.wrong);
      expect(r.attemptsRemaining, 4);
    });
  });

  group('성공 리셋', () {
    test('성공하면 실패 카운트와 에스컬레이션이 초기화', () async {
      await service.setPin('123456');
      // 1차 잠금까지 간 뒤 해제하고 성공
      for (var i = 1; i <= 5; i++) {
        await service.verifyPin('000000');
      }
      now = now.add(const Duration(seconds: 31));
      expect((await service.verifyPin('123456')).isSuccess, true);

      // 리셋되었으면 다음 잠금은 다시 30초(레벨 0)부터
      Duration last = Duration.zero;
      for (var i = 1; i <= 5; i++) {
        final r = await service.verifyPin('000000');
        if (r.outcome == PinVerifyOutcome.lockedOut) last = r.lockRemaining!;
      }
      expect(last.inSeconds, 30);
    });
  });

  group('시계 조작 방어', () {
    test('잠금 중 시계를 되돌려도 잠금이 풀리지 않는다', () async {
      await service.setPin('123456');
      for (var i = 1; i <= 5; i++) {
        await service.verifyPin('000000');
      }
      now = now.subtract(const Duration(hours: 1)); // 시계 되돌림
      final r = await service.verifyPin('123456');
      expect(r.outcome, PinVerifyOutcome.lockedOut);
    });
  });

  group('변경/삭제', () {
    test('changePin: 정확한 기존 PIN이면 변경 성공', () async {
      await service.setPin('123456');
      final ok = await service.changePin('123456', '654321');
      expect(ok, true);
      expect((await service.verifyPin('654321')).isSuccess, true);
      expect((await service.verifyPin('123456')).outcome,
          PinVerifyOutcome.wrong);
    });

    test('changePin: 틀린 기존 PIN이면 실패하고 기존 유지', () async {
      await service.setPin('123456');
      final ok = await service.changePin('999999', '654321');
      expect(ok, false);
      expect((await service.verifyPin('123456')).isSuccess, true);
    });

    test('clearPin: PIN과 모든 상태 제거', () async {
      await service.setPin('123456');
      await service.verifyPin('000000');
      await service.clearPin();
      expect(await service.hasPin(), false);
      expect((await service.verifyPin('123456')).outcome,
          PinVerifyOutcome.noPin);
      expect(store.map.isEmpty, true);
    });

    test('setPin은 구버전 평문 pin_code를 제거', () async {
      store.map['pin_code'] = '111111'; // 23h 이전 잔재
      await service.setPin('123456');
      expect(store.map.containsKey('pin_code'), false);
    });
  });

  group('잠금 잔여 조회', () {
    test('lockRemaining는 시도 소모 없이 잔여를 반환', () async {
      await service.setPin('123456');
      for (var i = 1; i <= 5; i++) {
        await service.verifyPin('000000');
      }
      final d = await service.lockRemaining();
      expect(d, isNotNull);
      expect(d!.inSeconds, inInclusiveRange(29, 30));
      // 조회만으로 잠금이 바뀌지 않음
      expect((await service.lockRemaining())!.inSeconds, inInclusiveRange(29, 30));
    });

    test('잠금이 없으면 null', () async {
      await service.setPin('123456');
      expect(await service.lockRemaining(), isNull);
    });
  });
}
