// 스토어 권리 → 프리미엄 상태 파생(순수 함수). 서비스 배선은 iap_store_test.dart.

import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart' show SK2Transaction;

const _ids = {'monthly': 'm', 'yearly': 'y', 'lifetime': 'l'};
final _now = DateTime(2026, 10, 8, 12);

StoreEntitlement _e(String id, {DateTime? exp, bool revoked = false, bool openEnded = false}) =>
    StoreEntitlement(productId: id, expiresAt: exp, revoked: revoked, openEnded: openEnded);

PremiumEntitlement _derive(List<StoreEntitlement> items) =>
    derivePremiumEntitlement(items, productIds: _ids, now: _now);

void main() {
  group('derivePremiumEntitlement', () {
    test('구매·체험·해지 후 만료 전은 스토어 만료일까지 활성', () {
      final exp = _now.add(const Duration(days: 3));
      final r = _derive([_e('m', exp: exp)]);
      expect(r.subscriptionExpiry, exp);
      expect(r.hasLifetime, isFalse);
    });

    test('만료된 구독은 권리가 아니다', () {
      expect(_derive([_e('m', exp: _now.subtract(const Duration(seconds: 1)))]).isActiveAt(_now), isFalse);
    });

    test('환불(revoked)은 만료일이 남아 있어도 무시한다', () {
      final r = _derive([_e('y', exp: _now.add(const Duration(days: 300)), revoked: true)]);
      expect(r.isActiveAt(_now), isFalse);
    });

    test('평생+월간은 어떤 순서든 평생을 유지하고 만료일은 최댓값', () {
      final late = _now.add(const Duration(days: 20));
      final soon = _now.add(const Duration(days: 2));
      for (final list in [
        [_e('l'), _e('m', exp: soon), _e('m', exp: late)],
        [_e('m', exp: late), _e('m', exp: soon), _e('l')],
        [_e('m', exp: soon), _e('l'), _e('m', exp: late)],
      ]) {
        final r = _derive(list);
        expect(r.hasLifetime, isTrue);
        expect(r.subscriptionExpiry, late);
      }
    });

    test('옛 월간이 만료됐어도 평생은 남는다', () {
      final r = _derive([_e('m', exp: _now.subtract(const Duration(days: 40))), _e('l')]);
      expect(r.hasLifetime, isTrue);
      expect(r.subscriptionExpiry, isNull);
    });

    test('만료일을 안 주는 구독(Google Play)은 시간 창 없이 활성이고 날짜를 지어내지 않는다', () {
      final r = _derive([_e('y', openEnded: true)]);
      expect(r.subscriptionExpiry, isNull);
      expect(r.subscriptionOpenEnded, isTrue);
      expect(r.isActiveAt(_now), isTrue);
    });

    test('열린 구독과 날짜 있는 구독이 섞이면 둘 다 반영한다', () {
      final exp = _now.add(const Duration(days: 30));
      final r = _derive([_e('y', openEnded: true), _e('m', exp: exp)]);
      expect(r.subscriptionOpenEnded, isTrue);
      expect(r.subscriptionExpiry, exp);
    });

    test('환불된 열린 구독은 권리가 아니다', () {
      expect(_derive([_e('y', openEnded: true, revoked: true)]).isActiveAt(_now), isFalse);
    });

    test('만료일을 모르는 iOS 구독은 권리가 아니다(fail-closed) — 재조회마다 연장되지 않는다', () {
      final r = _derive([_e('m'), _e('y')]);
      expect(r.isActiveAt(_now), isFalse);
      expect(r.subscriptionOpenEnded, isFalse);
    });

    test('모르는 상품과 빈 목록은 권리 없음', () {
      expect(_derive([_e('zzz', exp: _now.add(const Duration(days: 9)))]).isActiveAt(_now), isFalse);
      expect(_derive(const []).isActiveAt(_now), isFalse);
    });
  });

  group('iOS 오프라인 캐시·회수 증거·유예', () {
    Duration d(int n) => Duration(days: n);
    const day = Duration(days: 1);
    // 저장된 만료일 [stored]를 안고, 이번 조회가 [items]만 돌려준 상황.
    PremiumEntitlement again(List<StoreEntitlement> items, DateTime? stored) =>
        derivePremiumEntitlement(items, productIds: _ids, now: _now, storedExpiry: stored);

    test('회귀: 1년 전 환불된 월간 1건 + 살아 있는 월간 1건 — 다음 조회가 만료된 옛 거래만 줘도 활성 유지', () {
      final live = _now.add(d(10));
      final first = _derive([
        _e('m', exp: _now.subtract(d(335)), revoked: true),
        _e('m', exp: live),
      ]);
      expect(first.subscriptionExpiry, live);

      final next = again([
        _e('m', exp: _now.subtract(d(335)), revoked: true),
        _e('m', exp: _now.subtract(d(300))),
      ], first.subscriptionExpiry);
      expect(next.subscriptionExpiry, live);
      expect(next.isActiveAt(_now), isTrue);
    });

    test('저장 만료일이 미래이고 증거가 없으면 빈 캐시·더 짧은 만료일로 덮지 않는다', () {
      final stored = _now.add(d(5));
      expect(again(const [], stored).subscriptionExpiry, stored);
      expect(again([_e('m', exp: _now.add(d(2)))], stored).subscriptionExpiry, stored);
    });

    test('더 긴 새 만료일(갱신)은 저장값을 이긴다', () {
      final renewed = _now.add(d(35));
      expect(again([_e('m', exp: renewed)], _now.add(d(5))).subscriptionExpiry, renewed);
    });

    test('회수된 거래의 만료일이 저장 만료일보다 이르지 않으면(경계 포함) 증거다', () {
      final stored = _now.add(d(5));
      for (final exp in [stored, stored.add(day)]) {
        final r = again([_e('m', exp: exp, revoked: true)], stored);
        expect(r.isActiveAt(_now), isFalse, reason: '$exp');
        expect(r.subscriptionGrace, isFalse);
      }
      // 저장 만료일보다 1초 이른 회수는 증거가 아니다
      expect(again([_e('m', exp: stored.subtract(const Duration(seconds: 1)), revoked: true)], stored).isActiveAt(_now), isTrue);
    });

    test('회수된 평생권은 증거다', () {
      expect(again([_e('l', revoked: true)], _now.add(d(5))).isActiveAt(_now), isFalse);
    });

    test('증거가 있어도 살아 있는 다른 거래의 만료일은 유지되지만 유예는 없다', () {
      final live = _now.add(d(2));
      final r = again([_e('m', exp: _now.add(d(9)), revoked: true), _e('m', exp: live)], _now.add(d(5)));
      expect(r.subscriptionExpiry, live);
      expect(r.subscriptionGrace, isFalse);
      expect(r.isActiveAt(live.add(day)), isFalse);
    });

    test('유예 경계: 저장 만료 2일 뒤는 활성, 4일 뒤는 비활성(저장값은 늘지 않는다)', () {
      final stored = _now.subtract(d(2));
      final day2 = again(const [], stored);
      expect(day2.subscriptionExpiry, stored);
      expect(day2.isActiveAt(_now), isTrue);

      final day4 = again(const [], _now.subtract(d(4)));
      expect(day4.isActiveAt(_now), isFalse);
      expect(day4.subscriptionExpiry, isNull);

      // 정확히 3일째 경계는 활성이 아니다(isAfter)
      expect(again(const [], _now.subtract(subscriptionGracePeriod)).isActiveAt(_now), isFalse);
    });

    test('만료 2일 뒤라도 그 기간을 덮는 회수가 있으면 유예 없음', () {
      final stored = _now.subtract(d(2));
      expect(again([_e('m', exp: stored, revoked: true)], stored).isActiveAt(_now), isFalse);
    });

    test('유예는 평생권·열린 구독(Android)에 영향을 주지 않는다', () {
      expect(again([_e('l')], null).subscriptionGrace, isFalse);
      final open = again([_e('y', openEnded: true)], null);
      expect(open.subscriptionExpiry, isNull);
      expect(open.subscriptionGrace, isFalse);
    });

    test('저장 만료일이 없으면 만료된 구독은 그대로 비활성(유예를 지어내지 않는다)', () {
      expect(again([_e('m', exp: _now.subtract(day))], null).isActiveAt(_now), isFalse);
    });
  });

  group('entitlementFromSk2', () {
    SK2Transaction tx({String? json, String? expiration}) => SK2Transaction(
          id: '1',
          originalId: '1',
          productId: 'm',
          purchaseDate: '2026-10-08 12:00:00',
          expirationDate: expiration,
          appAccountToken: null,
          jsonRepresentation: json,
        );

    test('JSON의 expiresDate(밀리초)를 쓰고 날짜 문자열 파싱에 기대지 않는다', () {
      final exp = DateTime.utc(2026, 11, 8).millisecondsSinceEpoch;
      final e = entitlementFromSk2(tx(json: '{"expiresDate":$exp}', expiration: '이상한 문자열'));
      expect(e.expiresAt, DateTime.fromMillisecondsSinceEpoch(exp));
      expect(e.revoked, isFalse);
    });

    test('revocationDate가 있으면 회수된 거래', () {
      final e = entitlementFromSk2(tx(json: '{"expiresDate":1,"revocationDate":2}'));
      expect(e.revoked, isTrue);
    });

    test('업그레이드로 대체된 옛 거래(isUpgraded)는 만료일이 남아 있어도 권리가 아니다', () {
      final exp = _now.add(const Duration(days: 20)).millisecondsSinceEpoch;
      final e = entitlementFromSk2(tx(json: '{"expiresDate":$exp,"isUpgraded":true}'));
      expect(e.revoked, isTrue);
      expect(_derive([e]).isActiveAt(_now), isFalse);
    });

    test('JSON을 못 읽으면 만료일 모름 → 활성이 아니다', () {
      final e = entitlementFromSk2(tx(json: 'not json', expiration: '2026-11-08 09:30:00'));
      expect(e.expiresAt, isNull);
      expect(_derive([e]).isActiveAt(_now), isFalse);
    });
  });

  group('calculateDiscount', () {
    test('rawPrice로 계산한다 — 100만 단위 통화도 예외 없다', () {
      expect(calculateDiscount(129000, 1290000, 12), '0.17');
      expect(calculateDiscount(9.99, 79.99, 12), '0.33');
    });

    test('0 가격·연간이 더 비싼 경우는 0%', () {
      expect(calculateDiscount(0, 10, 12), '0.00');
      expect(calculateDiscount(1, 99, 12), '0.00');
    });
  });
}
