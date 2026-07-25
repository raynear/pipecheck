/// Android용 IAP 계약 JSON 생성 — 직렬화는 iap_contract_writer.dart가 SSOT.
///
/// 소비자는 fastlane upload_iap_android (flat `android/<productId>.json`
/// glob, 파일당 객체 1개). 구 포맷(배열형 inappproducts.json/
/// subscriptions.json)은 소비자에서 TypeError 크래시를 냈다
/// (P1-17a에서 계약 통일).
library;

import 'package:boilerplate_cli/commands/iap/iap_contract_writer.dart';
import 'package:boilerplate_cli/commands/iap/iap_models.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Android용 IAP 계약 파일을 생성합니다.
///
/// 상품 ID는 호출자가 이미 `<id>.<packageName>` 최종형으로 변환해서
/// 넘겨야 한다.
Future<void> generateAndroidMetadata({
  required String projectRoot,
  required List<IapProduct> products,
  required List<SubscriptionGroup> subscriptionGroups,
  required bool isVerbose,
}) async {
  final baseDir = '$projectRoot/metadata/in_app_purchases/android';

  for (final product in products) {
    final file = await writeAndroidIapContract(
      androidDir: baseDir,
      entry: IapContractEntry(
        productId: product.id,
        type: product.type,
        priceTier: product.priceTier,
        names: product.names,
        descriptions: product.descriptions,
      ),
    );
    if (isVerbose) {
      CliLogger.debug('  Android IAP 계약 생성: ${file.path}');
    }
  }

  for (final group in subscriptionGroups) {
    for (final product in group.products) {
      final file = await writeAndroidIapContract(
        androidDir: baseDir,
        entry: IapContractEntry(
          productId: product.id,
          type: 'auto_renewable_subscription',
          priceTier: product.priceTier,
          names: product.names,
          descriptions: product.descriptions,
          subscriptionDuration: product.duration,
        ),
      );
      if (isVerbose) {
        CliLogger.debug('  Android 구독 계약 생성: ${file.path}');
      }
    }
  }

  print('');
  print('  📋 Android 상품 등록 안내:');
  print('     인앱 상품은 fastlane upload_iap_android로 자동 등록,');
  print('     구독은 Google Play Console에서 수동 등록이 필요합니다.');
  print('     생성된 파일: metadata/in_app_purchases/android/');
}
