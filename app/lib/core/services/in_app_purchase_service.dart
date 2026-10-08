import 'dart:async';
import 'dart:convert';

import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// 스토어 권리를 직접 조회하려면 플랫폼 구현 패키지의 API가 필요하다.
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart' show SK2Transaction;
import 'package:utils/utils.dart';

final InAppPurchase _inAppPurchase = InAppPurchase.instance;

Future<Map<String, ProductDetails>> loadProducts() async {
  // 인앱 구매가 비활성화된 경우 빈 맵 반환
  if (!AppFeatureConfig.isInAppPurchaseEnabled) {
    logger.d('In-App Purchases are disabled by feature flag');
    return {};
  }

  final bool available = await _inAppPurchase.isAvailable();
  if (!available) {
    logger.w('Unable to connect to the app store');
    return {};
  }

  final appConfig = AppConfig();
  final Set<String> kIds = appConfig.productIds.values.toSet();
  final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);

  if (response.notFoundIDs.isNotEmpty) {
    logger.w('Some product IDs could not be found: ${response.notFoundIDs}');
  }

  return Map.fromEntries(response.productDetails.map((prod) => MapEntry(prod.id, prod)));
}

/// 스토어가 알려 준 권리 한 건. [expiresAt]이 null이면 만료일을 모르는 것이다.
/// [openEnded]는 "만료일을 안 주는 스토어"(Google Play 구독)라서 null이 정상이라는 표시 —
/// iOS처럼 만료일을 줘야 하는 스토어에서 null이면 권리로 치지 않는다(fail-closed).
class StoreEntitlement {
  const StoreEntitlement({
    required this.productId,
    this.expiresAt,
    this.revoked = false,
    this.openEnded = false,
  });

  final String productId;
  final DateTime? expiresAt;

  /// 환불·취소로 회수된 거래.
  final bool revoked;

  final bool openEnded;
}

/// 모든 권리를 합친 최종 프리미엄 상태. [subscriptionExpiry]가 null이면 활성 구독이 없다.
/// [subscriptionOpenEnded]면 그 값은 실제 만료일이 아니라 다음 재조회까지의 임시 창이다.
class PremiumEntitlement {
  const PremiumEntitlement({
    required this.hasLifetime,
    required this.subscriptionExpiry,
    this.subscriptionOpenEnded = false,
  });

  final bool hasLifetime;
  final DateTime? subscriptionExpiry;
  final bool subscriptionOpenEnded;

  bool get isActive => hasLifetime || subscriptionExpiry != null;
}

/// 만료일을 안 주는 구독의 임시 창. 활성 여부는 openEnded 플래그가 정하고, 이 값은 만료일을 null이 아니게 하는 용도다.
const _openEndedWindow = Duration(days: 7);

/// 스토어 권리 목록 → 프리미엄 상태. 순서와 무관하다(평생·월간이 섞여도, 옛 갱신이
/// 뒤에 와도 결과가 같다). 만료일을 로컬에서 더해 만들지 않는다 — 스토어가 준 값만 쓰고,
/// 만료일을 주지 않는 구독([StoreEntitlement.openEnded], Google Play)만 다음 재조회까지
/// 성공한 조회가 소유하지 않는다고 말할 때까지 활성으로 본다. 만료일을 모르는 그 밖의 구독은 권리가 아니다.
PremiumEntitlement derivePremiumEntitlement(
  Iterable<StoreEntitlement> items, {
  required Map<String, String> productIds,
  required DateTime now,
}) {
  var lifetime = false;
  DateTime? expiry;
  var openEnded = false;
  for (final e in items) {
    if (e.revoked) continue;
    if (e.productId == productIds['lifetime']) {
      lifetime = true;
    } else if (e.productId == productIds['monthly'] || e.productId == productIds['yearly']) {
      final until = e.expiresAt ?? (e.openEnded ? now.add(_openEndedWindow) : null);
      if (until != null && until.isAfter(now) && (expiry == null || until.isAfter(expiry))) {
        expiry = until;
        openEnded = e.expiresAt == null;
      }
    }
  }
  return PremiumEntitlement(
    hasLifetime: lifetime,
    subscriptionExpiry: expiry,
    subscriptionOpenEnded: openEnded,
  );
}

/// StoreKit 2 거래 → [StoreEntitlement]. 날짜 문자열은 기기 로케일에 따라 달라져 믿을 수
/// 없으므로, 스토어가 준 JSON(밀리초 epoch)만 읽는다. 만료일을 모르면 iOS에서는 권리 없음이다.
/// 업그레이드로 대체된 옛 거래(isUpgraded)는 회수된 것과 같이 권리에서 뺀다.
StoreEntitlement entitlementFromSk2(SK2Transaction t) {
  DateTime? expiresAt;
  var revoked = false;
  try {
    final json = jsonDecode(t.jsonRepresentation ?? '');
    if (json is Map) {
      final exp = json['expiresDate'];
      if (exp is num) expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.round());
      revoked = json['revocationDate'] != null || json['isUpgraded'] == true;
    }
  } catch (_) {}
  return StoreEntitlement(productId: t.productId, expiresAt: expiresAt, revoked: revoked);
}

/// 스토어에서 지금 유효한 권리를 읽어 온다. 실패는 예외로 알린다(빈 목록과 구분).
Future<List<StoreEntitlement>> fetchStoreEntitlements() async {
  final iap = _inAppPurchase;
  if (!await iap.isAvailable()) throw StateError('store unavailable');
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      // Transaction.all — 만료·환불 거래도 오므로 파생 단계에서 걸러낸다.
      return (await SK2Transaction.transactions()).map(entitlementFromSk2).toList();
    case TargetPlatform.android:
      final past = await _androidPast(iap);
      return past
          .where((p) => p.status == PurchaseStatus.purchased)
          .map((p) => StoreEntitlement(productId: p.productID, openEnded: true))
          .toList();
    default:
      return const [];
  }
}

Future<List<GooglePlayPurchaseDetails>> _androidPast(InAppPurchase iap) async {
  final resp = await iap
      .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
      .queryPastPurchases();
  if (resp.error != null) throw StateError('queryPastPurchases: ${resp.error!.message}');
  return resp.pastPurchases;
}

/// 연간 할인율('0.29'). 로케일 가격 문자열이 아니라 스토어의 [ProductDetails.rawPrice]로 계산한다.
String calculateDiscount(double monthlyRaw, double yearlyRaw, int months) {
  if (monthlyRaw <= 0 || yearlyRaw <= 0) return '0.00';
  return (1 - yearlyRaw / (monthlyRaw * months)).clamp(0.0, 1.0).toStringAsFixed(2);
}

class InAppPurchaseService {
  InAppPurchaseService(
    this.settingsNotifier, {
    this.snackBarService,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    // 부팅 때부터 붙어 있어야 앱이 꺼진 사이 도착한 거래(갱신·대기 승인)를 받는다.
    _subscription = _inAppPurchase.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onError: (Object e) => logger.e('Purchase stream error: $e'),
    );
  }

  final SettingsNotifier settingsNotifier;
  final SnackBarService? snackBarService;
  final DateTime Function() _clock;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _refreshQueue = Future.value();
  String? _buying; // 사용자가 buyProduct로 시작한 상품

  /// 스토어를 다시 읽어 프리미엄 상태를 맞춘다. 조회가 실패하면(오프라인 등) 마지막
  /// 상태를 그대로 두고 null을 돌려준다 — 결제한 사용자를 오프라인에서 잠그지 않는다.
  /// 부팅·앱 복귀·구매·복원이 겹쳐도 한 번에 하나씩만 돈다 — 늦게 끝난 옛 조회가
  /// 방금 산 권리를 덮어쓰지 못하게 한다.
  Future<PremiumEntitlement?> refreshEntitlement() {
    final run = _refreshQueue.then((_) => _refreshNow());
    _refreshQueue = run;
    return run;
  }

  Future<PremiumEntitlement?> _refreshNow() async {
    try {
      final items = await fetchStoreEntitlements();
      final entitlement = derivePremiumEntitlement(items, productIds: AppConfig().productIds, now: _clock());
      await settingsNotifier.applyStoreEntitlement(
        hasLifetime: entitlement.hasLifetime,
        subscriptionExpiry: entitlement.subscriptionExpiry,
        subscriptionOpenEnded: entitlement.subscriptionOpenEnded,
      );
      return entitlement;
    } catch (e) {
      logger.w('Entitlement refresh failed, keeping last known state: $e');
      return null;
    }
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    var needsRefresh = false;
    final newlyPurchased = <String>[];
    for (final purchaseDetails in purchaseDetailsList) {
      logger.d('Purchase status: ${purchaseDetails.status} ${purchaseDetails.productID}');
      if (purchaseDetails.status == PurchaseStatus.pending) continue;
      if (purchaseDetails.status == PurchaseStatus.error) {
        logger.e('Purchase error: ${purchaseDetails.error}');
        snackBarService?.showError('in_app_purchase.purchaseFailed'.tr());
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 복원은 restorePurchase가 직접 한 번 조회하므로 구매만 여기서 조회한다.
        if (purchaseDetails.status == PurchaseStatus.purchased) {
          needsRefresh = true;
          newlyPurchased.add(purchaseDetails.productID);
        }
      }
      // 처리 성공 여부와 무관하게 마무리한다 — 안 하면 iOS는 거래가 계속 재전송되고
      // Google Play는 3일 뒤 자동 환불한다.
      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchaseDetails);
        } catch (e) {
          logger.e('completePurchase failed: $e');
        }
      }
    }
    if (!needsRefresh) return;
    final entitlement = await refreshEntitlement();
    if (entitlement == null) {
      snackBarService?.showError('Failed to activate subscription');
      return;
    }
    for (final productId in newlyPurchased) {
      // 자동 갱신 등 사용자가 지금 시작하지 않은 거래는 알리지 않는다.
      if (productId != _buying) continue;
      _buying = null;
      final role = AppConfig().productIds.entries.firstWhereOrNull((e) => e.value == productId)?.key;
      if (role == null) {
        snackBarService?.showError('Unknown subscription type');
      } else if (role == 'lifetime' ? entitlement.hasLifetime : entitlement.subscriptionExpiry != null) {
        snackBarService?.showSuccess('${role[0].toUpperCase()}${role.substring(1)} subscription activated');
      }
    }
  }

  Future<bool> buyProduct(ProductDetails prod) async {
    try {
      // 진행 중인 거래 확인 및 처리
      final purchaseDetails = await _checkPendingPurchase(prod.id);
      if (purchaseDetails != null) {
        logger.d('Ongoing transaction found: ${purchaseDetails.status}');
        return true;
      }

      final PurchaseParam purchaseParam = await _purchaseParam(prod);
      _buying = prod.id;
      final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      // 이 success가 구매완료하고 성공했을때 반환하는 것이 아님
      if (success) {
        logger.d('Purchase process started successfully: ${prod.title}');
      } else {
        logger.e('Purchase process failed to start: ${prod.title}');
        _buying = null;
      }

      return success;
    } catch (e) {
      logger.e('Error occurred while starting purchase: $e');
      _buying = null;
      return false;
    }
  }

  /// Android에서 이미 다른 구독이 활성이면 새 구독을 "변경"으로 산다 — 아니면 구독이 둘 겹친다.
  Future<PurchaseParam> _purchaseParam(ProductDetails prod) async {
    final ids = AppConfig().productIds;
    final isSub = prod.id == ids['monthly'] || prod.id == ids['yearly'];
    if (defaultTargetPlatform == TargetPlatform.android && isSub) {
      try {
        final past = await _androidPast(_inAppPurchase);
        final old = past.firstWhereOrNull((p) =>
            p.status == PurchaseStatus.purchased &&
            p.productID != prod.id &&
            (p.productID == ids['monthly'] || p.productID == ids['yearly']));
        if (old != null) {
          return GooglePlayPurchaseParam(
            productDetails: prod,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: old,
              replacementMode: ReplacementMode.withTimeProration,
            ),
          );
        }
      } catch (e) {
        logger.w('Could not look up existing subscription: $e');
      }
    }
    return PurchaseParam(productDetails: prod);
  }

  Future<PurchaseDetails?> _checkPendingPurchase(String productId) async {
    try {
      final purchases = await _inAppPurchase.purchaseStream
          .firstWhere(
            (purchases) => purchases.any((purchase) => purchase.productID == productId),
            orElse: () => <PurchaseDetails>[],
          )
          .timeout(const Duration(seconds: 1));

      final pendingPurchase = purchases
          .firstWhereOrNull((purchase) => purchase.productID == productId && purchase.status == PurchaseStatus.pending);
      return pendingPurchase;
    } on TimeoutException {
      logger.e('Ongoing transaction check timeout');
      return null;
    }
  }

  /// 구매 복원. 스토어에 복원을 요청한 뒤 **실제로 권리가 생겼는지**로 성공을 판정한다.
  Future<void> restorePurchase() async {
    try {
      await _inAppPurchase.restorePurchases();
      final entitlement = await refreshEntitlement();
      if (entitlement == null) {
        snackBarService?.showError('Failed to restore purchase');
      } else if (entitlement.isActive) {
        snackBarService?.showSuccess('Purchase restored successfully');
      } else {
        snackBarService?.showInfo('No previous purchases found');
      }
    } catch (e) {
      logger.e('Failed to restore purchase: $e');
      snackBarService?.showError('Failed to restore purchase');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

// 프로바이더 설정
final inAppPurchaseServiceProvider = Provider<InAppPurchaseService?>((ref) {
  // 인앱 구매가 비활성화된 경우 null 반환
  if (!AppFeatureConfig.isInAppPurchaseEnabled) {
    return null;
  }

  final settingsNotifier = ref.read(settingsProvider.notifier);
  final snackBarService = ref.read(snackBarServiceProvider);
  final service = InAppPurchaseService(settingsNotifier, snackBarService: snackBarService);
  // 부팅 때 한 번, 그리고 앱으로 돌아올 때마다 스토어 기준으로 다시 맞춘다
  // (갱신·해지·환불은 앱이 꺼진 사이에 일어난다).
  // 앱으로 돌아올 때의 재조회는 main.dart의 resumed 분기가 건다.
  unawaited(service.refreshEntitlement());
  ref.onDispose(service.dispose);
  return service;
});
