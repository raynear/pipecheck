import 'dart:async';

import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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

class InAppPurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final SettingsNotifier settingsNotifier;
  final SnackBarService? snackBarService;

  InAppPurchaseService(this.settingsNotifier, [this.snackBarService]) {
    _subscription = _inAppPurchase.purchaseStream.listen(_listenToPurchaseUpdated);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    logger.d('Purchase stream received');
    for (final purchaseDetails in purchaseDetailsList) {
      // logger.i('Purchase product details:\n'
      //     '- productID: ${purchaseDetails.productID}\n'
      //     '- status: ${purchaseDetails.status}\n'
      //     '- purchaseID: ${purchaseDetails.purchaseID}\n'
      //     '- transactionDate: ${purchaseDetails.transactionDate}\n'
      //     '- pendingCompletePurchase: ${purchaseDetails.pendingCompletePurchase}\n'
      //     '- error: ${purchaseDetails.error?.message}, ${purchaseDetails.error?.code}, ${purchaseDetails.error?.details}');
      logger.d('Purchase status: ${purchaseDetails.status}');

      if (purchaseDetails.status != PurchaseStatus.pending) {
        logger.d('Purchase status: ${purchaseDetails.status}');
        if (purchaseDetails.status == PurchaseStatus.error) {
          logger.e('Purchase error: ${purchaseDetails.error}');
          snackBarService?.showError('in_app_purchase.purchaseFailed'.tr());
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // logger.i('Purchase completed or restored: ${purchaseDetails.productID}');
          // logger.i('Purchase product details:\n'
          //     '- productID: ${purchaseDetails.productID}\n'
          //     '- status: ${purchaseDetails.status}\n'
          //     '- purchaseID: ${purchaseDetails.purchaseID}\n'
          //     '- transactionDate: ${purchaseDetails.transactionDate}\n'
          //     '- pendingCompletePurchase: ${purchaseDetails.pendingCompletePurchase}\n'
          //     '- error: ${purchaseDetails.error?.message}, ${purchaseDetails.error?.code}, ${purchaseDetails.error?.details}');
          logger.d('Purchase completed or restored: ${purchaseDetails.productID}');

          // 구매 시간 안전하게 파싱
          final transactionDate = purchaseDetails.transactionDate;

          if (transactionDate == null) {
            logger.e('Transaction date is null for purchase: ${purchaseDetails.productID}');
            logger.e('Cannot determine accurate subscription period without transaction date');
            snackBarService?.showError('Purchase verification failed - invalid transaction date');
            continue; // 이 구매는 건너뛰고 다음으로
          }

          DateTime purchaseTime;
          try {
            purchaseTime = _parseTransactionDate(transactionDate);
            logger.d('Purchase time parsed: $purchaseTime');
          } catch (e) {
            logger.e('Failed to parse transaction date: $transactionDate, error: $e');
            logger.e('Cannot process purchase without valid transaction date');
            snackBarService?.showError('Purchase verification failed - invalid date format');
            continue; // 이 구매는 건너뛰고 다음으로
          }

          logger.d('Final purchase time: $purchaseTime');

          // 구독 만료일 설정 및 알림
          await _handleSubscriptionActivation(purchaseDetails.productID, purchaseTime);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> buyProduct(ProductDetails prod) async {
    try {
      // 진행 중인 거래 확인 및 처리
      final purchaseDetails = await _checkPendingPurchase(prod.id);
      if (purchaseDetails != null) {
        logger.d('Ongoing transaction found: ${purchaseDetails.status}');
        // await _handlePurchase(purchaseDetails, ref);
        return true;
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: prod);
      final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      // 이 success가 구매완료하고 성공했을때 반환하는 것이 아님
      if (success) {
        logger.d('Purchase process started successfully: ${prod.title}');
      } else {
        logger.e('Purchase process failed to start: ${prod.title}');
      }

      return success;
    } catch (e) {
      logger.e('Error occurred while starting purchase: $e');
      return false;
    }
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

  Future<void> restorePurchase() async {
    try {
      logger.d('Restore purchase started');

      // 복원된 구매를 감지하기 위한 Completer
      final Completer<bool> restoreCompleter = Completer<bool>();
      bool hasRestoredPurchases = false;

      // 타임아웃을 위한 타이머
      Timer? timeoutTimer;

      // 구매 스트림 구독 (일시적)
      StreamSubscription<List<PurchaseDetails>>? tempSubscription;

      void cleanup() {
        timeoutTimer?.cancel();
        tempSubscription?.cancel();
      }

      // 타임아웃 설정 (10초)
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!restoreCompleter.isCompleted) {
          logger.d('Restore purchase timeout - no purchases found');
          restoreCompleter.complete(false);
          cleanup();
        }
      });

      // 임시 구독으로 복원된 구매 감지
      tempSubscription = _inAppPurchase.purchaseStream.listen((purchases) {
        logger.d('Purchase stream received during restore: ${purchases.length} purchases');

        bool foundRestored = false;
        for (final purchase in purchases) {
          if (purchase.status == PurchaseStatus.restored) {
            foundRestored = true;
            hasRestoredPurchases = true;
            logger.d('Purchase restored: ${purchase.productID}');
          }
        }

        // 복원된 구매를 찾았거나 처리할 구매가 있으면 완료
        if (foundRestored && !restoreCompleter.isCompleted) {
          restoreCompleter.complete(true);
          cleanup();
        }
      });

      // 복원 시작
      await _inAppPurchase.restorePurchases();
      logger.d('RestorePurchases() call completed');

      // 결과 대기
      final bool success = await restoreCompleter.future;

      if (success && hasRestoredPurchases) {
        logger.d('Purchase restoration completed successfully');
        snackBarService?.showSuccess('Purchase restored successfully');
      } else {
        logger.d('No purchases found to restore');
        snackBarService?.showInfo('No previous purchases found');
      }
    } catch (e) {
      logger.e('Failed to restore purchase: $e');
      snackBarService?.showError('Failed to restore purchase');
    }
  }

  /// iOS transactionDate 파싱: 소수점 처리 + 초/밀리초 자동 판별
  /// - iOS SKPaymentTransaction.transactionDate는 TimeInterval(Double)이라 소수점 포함 가능
  /// - StoreKit 2 전환 시 초 단위로 올 수 있음 (Android는 항상 밀리초)
  DateTime _parseTransactionDate(String transactionDate) {
    final double timestamp = double.parse(transactionDate);
    // 10자리 이하(~2286년까지)면 초 단위, 13자리면 밀리초 단위
    // 구분 기준: 10,000,000,000 (2286-11-20 in seconds, 1970-04-26 in ms)
    final int millis;
    if (timestamp < 10000000000) {
      millis = (timestamp * 1000).round();
    } else {
      millis = timestamp.round();
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  String calculateDiscount(String basePrice, String discountedPrice, int months) {
    final baseValue = double.parse(basePrice.replaceAll(RegExp(r'[^\d.]'), ''));
    final discountedValue = double.parse(discountedPrice.replaceAll(RegExp(r'[^\d.]'), ''));
    return (1 - (discountedValue / (baseValue * months))).toStringAsFixed(2);
  }

  // 구독 활성화 처리 헬퍼 메서드
  Future<void> _handleSubscriptionActivation(String productID, DateTime purchaseTime) async {
    final appConfig = AppConfig();

    try {
      if (productID == appConfig.productIds['monthly']) {
        final expiryDate = DateTime(purchaseTime.year, purchaseTime.month + 1, purchaseTime.day);
        await settingsNotifier.updateSingleSetting(subscriptionExpiryDate: expiryDate);
        snackBarService?.showSuccess('Monthly subscription activated');
        logger.d('Monthly subscription activated until: $expiryDate');
      } else if (productID == appConfig.productIds['yearly']) {
        final expiryDate = DateTime(purchaseTime.year + 1, purchaseTime.month, purchaseTime.day);
        await settingsNotifier.updateSingleSetting(subscriptionExpiryDate: expiryDate);
        snackBarService?.showSuccess('Yearly subscription activated');
        logger.d('Yearly subscription activated until: $expiryDate');
      } else if (productID == appConfig.productIds['lifetime']) {
        final expiryDate = DateTime(purchaseTime.year + 100, purchaseTime.month, purchaseTime.day);
        await settingsNotifier.updateSingleSetting(subscriptionExpiryDate: expiryDate);
        snackBarService?.showSuccess('Lifetime subscription activated');
        logger.d('Lifetime subscription activated until: $expiryDate');
      } else {
        logger.w('Unknown product ID: $productID');
        snackBarService?.showError('Unknown subscription type');
      }
    } catch (e) {
      logger.e('Failed to activate subscription for $productID: $e');
      snackBarService?.showError('Failed to activate subscription');
    }
  }

  // 클래스 내부에 새로운 메서드 추가
  Future<void> updateSubscription(DateTime expiryDate, {WidgetRef? ref}) async {
    // 여기서 구독 정보를 업데이트하는 로직 구현
    // SettingsNotifier를 통해 구독 정보 업데이트
    final settingsNotifier = ref?.read(settingsProvider.notifier);
    await settingsNotifier?.updateSingleSetting(subscriptionExpiryDate: expiryDate);
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
  final service = InAppPurchaseService(settingsNotifier, snackBarService);
  ref.onDispose(() => service.dispose());
  return service;
});
