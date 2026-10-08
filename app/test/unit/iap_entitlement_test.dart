// 스토어 권리 → 프리미엄 상태 파생(순수 함수). 서비스 배선은 iap_store_test.dart.

import 'package:pipecheck/core/services/in_app_purchase_service.dart';
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
      expect(_derive([_e('m', exp: _now.subtract(const Duration(seconds: 1)))]).isActive, isFalse);
    });

    test('환불(revoked)은 만료일이 남아 있어도 무시한다', () {
      final r = _derive([_e('y', exp: _now.add(const Duration(days: 300)), revoked: true)]);
      expect(r.isActive, isFalse);
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

    test('만료일을 안 주는 구독(Google Play)은 재조회 창만큼만 활성이고 임시 창으로 표시된다', () {
      final r = _derive([_e('y', openEnded: true)]);
      expect(r.subscriptionExpiry, _now.add(const Duration(days: 7)));
      expect(r.subscriptionOpenEnded, isTrue);
    });

    test('스토어가 준 실제 만료일이 임시 창보다 길면 임시 창이 아니다', () {
      final r = _derive([_e('y', openEnded: true), _e('m', exp: _now.add(const Duration(days: 30)))]);
      expect(r.subscriptionOpenEnded, isFalse);
    });

    test('만료일을 모르는 iOS 구독은 권리가 아니다(fail-closed) — 재조회마다 연장되지 않는다', () {
      final r = _derive([_e('m'), _e('y')]);
      expect(r.isActive, isFalse);
      expect(r.subscriptionOpenEnded, isFalse);
    });

    test('모르는 상품과 빈 목록은 권리 없음', () {
      expect(_derive([_e('zzz', exp: _now.add(const Duration(days: 9)))]).isActive, isFalse);
      expect(_derive(const []).isActive, isFalse);
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
      expect(_derive([e]).isActive, isFalse);
    });

    test('JSON을 못 읽으면 만료일 모름 → 활성이 아니다', () {
      final e = entitlementFromSk2(tx(json: 'not json', expiration: '2026-11-08 09:30:00'));
      expect(e.expiresAt, isNull);
      expect(_derive([e]).isActive, isFalse);
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
