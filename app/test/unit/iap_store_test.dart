// 가짜 스토어 플랫폼으로 스토어 조회·구매 시작·프로바이더 배선을 잰다.

import 'dart:async';

import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../support/fake_snackbar.dart';
import '../support/orange_harness.dart';


PurchaseWrapper _wrapper(String product, PurchaseStateWrapper state, {bool acknowledged = true}) =>
    PurchaseWrapper(
      orderId: 'o-$product',
      packageName: 'pkg',
      purchaseTime: 1,
      purchaseToken: 't-$product',
      signature: 's',
      products: [product],
      isAutoRenewing: true,
      originalJson: '{}',
      isAcknowledged: acknowledged,
      purchaseState: state,
    );

class _FakePlatform extends InAppPurchasePlatform {
  bool available = true;
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  PurchaseParam? bought;
  Set<String> queried = {};

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    queried = identifiers;
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
            id: 'm', title: 'm', description: '', price: '1', rawPrice: 1, currencyCode: 'USD'),
      ],
      notFoundIDs: ['y'],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought = purchaseParam;
    return true;
  }

  final completed = <PurchaseDetails>[];
  int restoreCalls = 0;

  bool completeThrows = false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completeThrows) throw StateError('ack failed');
    completed.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async => restoreCalls++;
}

class _FakeAndroidAddition extends Fake implements InAppPurchaseAndroidPlatformAddition {
  List<PurchaseWrapper> purchases = [];
  bool error = false;

  /// 처음 n번의 조회만 실패시킨다(일시적 오프라인).
  int failFirst = 0;
  int calls = 0;

  /// 있으면 n번째 조회가 gates[n]이 열릴 때까지 기다렸다가 그 목록을 돌려준다
  /// (느린 옛 조회와 빠른 새 조회의 순서를 테스트가 쥔다).
  List<Completer<List<PurchaseWrapper>>>? gates;
  int inflight = 0;
  int maxInflight = 0;

  @override
  Future<QueryPurchaseDetailsResponse> queryPastPurchases({String? applicationUserName}) async {
    final call = calls++;
    final failing = error || call < failFirst;
    var result = purchases;
    if (gates != null) {
      inflight++;
      if (inflight > maxInflight) maxInflight = inflight;
      result = await gates![call].future;
      inflight--;
    }
    return QueryPurchaseDetailsResponse(
      pastPurchases: result.expand(GooglePlayPurchaseDetails.fromPurchase).toList(),
      error: failing ? IAPError(source: 'test', code: 'x', message: 'boom') : null,
    );
  }
}

PurchaseDetails _purchase(String id, PurchaseStatus status) => PurchaseDetails(
      productID: id,
      verificationData: PurchaseVerificationData(
          localVerificationData: '', serverVerificationData: '', source: 'test'),
      transactionDate: null,
      status: status,
    )..pendingCompletePurchase = true;

final _now = DateTime(2026, 10, 8, 12);

ProductDetails _product(String id) => ProductDetails(
    id: id, title: id, description: '', price: '1', rawPrice: 1, currencyCode: 'USD');

void main() {
  late _FakePlatform platform;
  late _FakeAndroidAddition addition;
  late bool originalIap;

  setUpOrange('iap_store_test');

  setUpAll(() async {
    // InAppPurchase.instance는 첫 접근 때 실제 플랫폼을 등록하며 연결을 시도한다 —
    // 채널이 없는 테스트에선 그 비동기 오류를 여기서 삼키고, 각 테스트가 가짜로 덮는다.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await runZonedGuarded(() async {
      InAppPurchase.instance;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, (_, _) {});
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() async {
    AppConfig.debugSetConfig({'MONTHLY': 'm', 'YEARLY': 'y', 'LIFETIME': 'l'});
    await Settings.initial().saveToOrange();
    platform = _FakePlatform();
    addition = _FakeAndroidAddition();
    InAppPurchasePlatform.instance = platform;
    InAppPurchasePlatformAddition.instance = addition;
    originalIap = AppFeatureConfig.isInAppPurchaseEnabled;
    AppFeatureConfig.isInAppPurchaseEnabled = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppFeatureConfig.isInAppPurchaseEnabled = originalIap;
  });

  test('loadProducts: 꺼져 있으면 빈 맵, 스토어가 막히면 빈 맵, 아니면 로드된 상품', () async {
    AppFeatureConfig.isInAppPurchaseEnabled = false;
    expect(await loadProducts(), isEmpty);

    AppFeatureConfig.isInAppPurchaseEnabled = true;
    platform.available = false;
    expect(await loadProducts(), isEmpty);

    platform.available = true;
    final products = await loadProducts();
    expect(products.keys, ['m']);
    expect(platform.queried, {'m', 'y', 'l'});
  });

  group('fetchStoreEntitlements(Android)', () {
    test('구매 완료 상태만 권리로 넘기고 대기는 뺀다', () async {
      addition.purchases = [
        _wrapper('m', PurchaseStateWrapper.purchased),
        _wrapper('y', PurchaseStateWrapper.pending),
      ];
      final items = await fetchStoreEntitlements();
      expect(items.map((e) => e.productId), ['m']);
      expect(items.single.openEnded, isTrue);
    });

    test('조회 오류와 스토어 불가는 예외로 알린다(빈 목록과 구분)', () async {
      addition.error = true;
      await expectLater(fetchStoreEntitlements(), throwsStateError);
      addition.error = false;
      platform.available = false;
      await expectLater(fetchStoreEntitlements(), throwsStateError);
    });

    test('스토어가 없는 플랫폼은 빈 목록', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(await fetchStoreEntitlements(), isEmpty);
    });
  });

  group('buyProduct', () {
    late ProviderContainer c;
    late InAppPurchaseService service;

    setUp(() {
      c = ProviderContainer();
      addTearDown(c.dispose);
      service = InAppPurchaseService(c.read(settingsProvider.notifier));
      addTearDown(service.dispose);
    });

    test('Android에서 다른 구독이 활성이면 변경(업그레이드)으로 산다', () async {
      addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased)];
      expect(await service.buyProduct(_product('y')), isTrue);
      final param = platform.bought as GooglePlayPurchaseParam;
      expect(param.changeSubscriptionParam?.oldPurchaseDetails.productID, 'm');
    });

    test('기존 구독이 없거나 평생 상품이면 일반 구매', () async {
      expect(await service.buyProduct(_product('y')), isTrue);
      expect(platform.bought, isNot(isA<GooglePlayPurchaseParam>()));

      addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased)];
      expect(await service.buyProduct(_product('l')), isTrue);
      expect(platform.bought, isNot(isA<GooglePlayPurchaseParam>()));
    });

    test('기존 구독 조회가 실패해도 구매는 시작한다', () async {
      addition.error = true;
      expect(await service.buyProduct(_product('y')), isTrue);
      expect(platform.bought, isNot(isA<GooglePlayPurchaseParam>()));
    });

    test('같은 상품의 대기 거래가 있으면 새로 시작하지 않는다', () async {
      Timer(const Duration(milliseconds: 100), () {
        platform.controller.add([
          PurchaseDetails(
            productID: 'y',
            verificationData: PurchaseVerificationData(
                localVerificationData: '', serverVerificationData: '', source: 'test'),
            transactionDate: null,
            status: PurchaseStatus.pending,
          ),
        ]);
      });
      expect(await service.buyProduct(_product('y')), isTrue);
      expect(platform.bought, isNull);
    });
  });

  test('프로바이더: 꺼져 있으면 null, 켜져 있으면 서비스를 만들고 부팅 조회를 건다', () async {
    AppFeatureConfig.isInAppPurchaseEnabled = false;
    final off = ProviderContainer();
    addTearDown(off.dispose);
    expect(off.read(inAppPurchaseServiceProvider), isNull);

    AppFeatureConfig.isInAppPurchaseEnabled = true;
    addition.purchases = [_wrapper('l', PurchaseStateWrapper.purchased)];
    final on = ProviderContainer();
    addTearDown(on.dispose);
    expect(on.read(inAppPurchaseServiceProvider), isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(on.read(settingsProvider).hasLifetime, isTrue);
  });

  group('InAppPurchaseService 권리 동기화', () {
    late ProviderContainer c;
    late SettingsNotifier n;
    late FakeSnack snack;
    late InAppPurchaseService service;

    setUp(() {
      c = ProviderContainer();
      addTearDown(c.dispose);
      n = c.read(settingsProvider.notifier);
      snack = FakeSnack();
      service = InAppPurchaseService(n, snackBarService: snack, clock: () => _now, retryDelay: Duration.zero);
      addTearDown(service.dispose);
    });

    Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

    test('구매 이벤트는 마무리(completePurchase)하고 열린 구독으로 반영한다', () async {
      addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased)];
      platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
      await pump();
      expect(platform.completed, hasLength(1));
      final s = c.read(settingsProvider);
      expect(s.subscriptionExpiryDate, isNull);
      expect(s.subscriptionOpenEnded, isTrue);
    });

    test('조회가 실패해도 거래는 마무리하고 마지막 상태를 유지한다', () async {
      await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: null));
      addition.error = true;
      platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
      await pump();
      expect(platform.completed, hasLength(1));
      expect(c.read(settingsProvider).hasLifetime, isTrue);
    });

    test('구매 직후 조회가 일시적으로 실패하면 다시 시도해서 반영하고 실패 문구는 띄우지 않는다', () async {
      addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased)];
      addition.failFirst = 1;
      platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
      await pump();
      expect(addition.calls, 2);
      expect(c.read(settingsProvider).subscriptionOpenEnded, isTrue);
      expect(snack.log.where((l) => l.startsWith('error:')), isEmpty);
    });

    test('재시도까지 모두 실패하면 "확인 중" 안내만 띄우고 마지막 상태를 유지한다', () async {
      await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: null));
      addition.error = true;
      platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
      await pump();
      expect(addition.calls, 3, reason: '첫 조회 + 재시도 2회');
      expect(snack.log, ['info:Confirming your purchase. It will be applied shortly.']);
      expect(c.read(settingsProvider).hasLifetime, isTrue);
    });

    test('사용자가 취소·실패한 구매 뒤 같은 상품의 자동 갱신은 성공 알림을 띄우지 않는다', () async {
      for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
        snack.log.clear();
        addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased)];
        await service.buyProduct(_product('m'));
        platform.controller.add([_purchase('m', status)..pendingCompletePurchase = false]);
        await pump();
        platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
        await pump();
        expect(snack.log.where((l) => l.startsWith('success:')), isEmpty, reason: '$status');
      }
    });

    test('오프라인 재조회는 프리미엄을 지우지 않고, 환불 뒤 재조회는 지운다', () async {
      addition.purchases = [_wrapper('y', PurchaseStateWrapper.purchased)];
      await service.refreshEntitlement();
      expect(c.read(settingsProvider).isSubscriptionActive, isTrue);

      addition.error = true;
      expect(await service.refreshEntitlement(), isNull);
      expect(c.read(settingsProvider).isSubscriptionActive, isTrue);

      addition.error = false;
      addition.purchases = [];
      await service.refreshEntitlement();
      final s = c.read(settingsProvider);
      expect(s.isSubscriptionActive, isFalse);
      expect(s.subscriptionOpenEnded, isFalse);
    });

    test('평생+월간이 한 번에 복원돼도 평생이 남는다', () async {
      addition.purchases = [
        _wrapper('l', PurchaseStateWrapper.purchased),
        _wrapper('m', PurchaseStateWrapper.purchased),
      ];
      platform.controller.add([
        _purchase('l', PurchaseStatus.restored),
        _purchase('m', PurchaseStatus.restored),
      ]);
      await service.restorePurchase();
      expect(c.read(settingsProvider).hasLifetime, isTrue);
    });

    test('복원 이벤트는 마무리만 하고 조회는 restorePurchase 한 번뿐이다', () async {
      platform.controller.add([_purchase('m', PurchaseStatus.restored)]);
      await pump();
      expect(platform.completed, hasLength(1));
      expect(addition.calls, 0);
    });

    for (final status in [PurchaseStatus.error, PurchaseStatus.canceled, PurchaseStatus.restored]) {
      test('$status 이벤트도 pendingCompletePurchase면 정확히 한 번 마무리한다', () async {
        platform.controller.add([_purchase('m', status)]);
        await pump();
        expect(platform.completed, hasLength(1));
        expect(platform.completed.single.status, status);
        expect(addition.calls, 0, reason: '구매 완료만 조회를 건다');
        if (status == PurchaseStatus.error) expect(snack.log, ['error:Purchase failed']);
      });
    }

    test('이미 마무리된(pendingCompletePurchase=false) 거래는 다시 마무리하지 않는다', () async {
      platform.controller.add([_purchase('m', PurchaseStatus.canceled)..pendingCompletePurchase = false]);
      await pump();
      expect(platform.completed, isEmpty);
    });

    group('Android 미확인 구매 (프로세스 종료·대기 결제 승인 뒤)', () {
      test('조회 때 확인 안 된 purchased 구매를 마무리하고 권리는 그대로 반영한다', () async {
        addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased, acknowledged: false)];
        await service.refreshEntitlement();
        expect(platform.completed.map((p) => p.productID), ['m']);
        expect(c.read(settingsProvider).subscriptionOpenEnded, isTrue);
      });

      test('소모성 등 월간·연간·평생이 아닌 상품은 확인 안 돼도 마무리하지 않는다', () async {
        addition.purchases = [
          _wrapper('coins', PurchaseStateWrapper.purchased, acknowledged: false),
          _wrapper('y', PurchaseStateWrapper.purchased, acknowledged: false),
        ];
        await service.refreshEntitlement();
        expect(platform.completed.map((p) => p.productID), ['y']);
      });

      test('이미 확인된 구매와 대기(pending) 구매는 마무리하지 않는다', () async {
        addition.purchases = [
          _wrapper('m', PurchaseStateWrapper.purchased),
          _wrapper('y', PurchaseStateWrapper.pending, acknowledged: false),
        ];
        await service.refreshEntitlement();
        expect(platform.completed, isEmpty);
      });

      test('마무리가 실패해도 조회는 권리를 반영하고 다음 조회에서 다시 시도한다', () async {
        platform.completeThrows = true;
        addition.purchases = [_wrapper('l', PurchaseStateWrapper.purchased, acknowledged: false)];
        expect(await service.refreshEntitlement(), isNotNull);
        expect(c.read(settingsProvider).hasLifetime, isTrue);
        platform.completeThrows = false;
        await service.refreshEntitlement();
        expect(platform.completed.map((p) => p.productID), ['l']);
      });
    });

    test('사용자가 시작하지 않은 구매(자동 갱신)는 성공 알림을 띄우지 않는다', () async {
      addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased)];
      platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
      await pump();
      expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
      expect(snack.log.where((l) => l.startsWith('success:')), isEmpty);
    });

    test('buyProduct로 시작한 상품이 반영되면 성공 알림, 다른 상품 권리만 있으면 알림 없음', () async {
      addition.purchases = [_wrapper('l', PurchaseStateWrapper.purchased)];
      await service.buyProduct(_product('m'));
      platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
      await pump();
      expect(snack.log.where((l) => l.startsWith('success:')), isEmpty,
          reason: '월간은 반영되지 않았고 평생 권리만 있다');

      addition.purchases = [_wrapper('m', PurchaseStateWrapper.purchased)];
      await service.buyProduct(_product('m'));
      platform.controller.add([_purchase('m', PurchaseStatus.purchased)]);
      await pump();
      expect(snack.log.where((l) => l.startsWith('success:')), hasLength(1));
    });

    test('대기(pending) 거래는 건드리지도 조회하지도 않는다', () async {
      platform.controller.add([_purchase('m', PurchaseStatus.pending)]);
      await pump();
      expect(platform.completed, isEmpty);
      expect(addition.calls, 0);
    });

    test('복원: 권리가 있어야 성공, 없으면 "없음", 조회 실패면 실패', () async {
      await service.restorePurchase();
      expect(platform.restoreCalls, 1);
      expect(snack.log.last, startsWith('info:'));

      addition.purchases = [_wrapper('l', PurchaseStateWrapper.purchased)];
      await service.restorePurchase();
      expect(snack.log.last, startsWith('success:'));

      addition.error = true;
      await service.restorePurchase();
      expect(snack.log.last, startsWith('error:'));
    });

    test('겹친 조회는 순서대로 돌아서, 늦게 끝난 옛 조회가 새 권리를 지우지 못한다', () async {
      final gates = [Completer<List<PurchaseWrapper>>(), Completer<List<PurchaseWrapper>>()];
      addition.gates = gates;
      final first = service.refreshEntitlement(); // 앱 복귀 — 구매 기록 전 목록
      final second = service.refreshEntitlement(); // purchased 이벤트 — 구매 기록 후 목록
      await pump();
      expect(addition.calls, 1, reason: '두 번째 조회는 첫 조회가 끝나야 시작한다');

      gates[0].complete([]);
      await pump();
      expect(addition.calls, 2);
      gates[1].complete([_wrapper('l', PurchaseStateWrapper.purchased)]);
      await Future.wait([first, second]);

      expect(addition.maxInflight, 1);
      expect(c.read(settingsProvider).hasLifetime, isTrue);
    });
  });
}
