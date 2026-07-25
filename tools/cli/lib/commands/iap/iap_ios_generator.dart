/// iOS용 IAP 계약 JSON 생성 — 직렬화는 iap_contract_writer.dart가 SSOT.
///
/// 소비자는 fastlane upload_iap_ios / upload_subscription_ios
/// (flat `ios/<productId>.json` glob). 구 포맷(서브디렉토리 + metadata.json)
/// 은 소비자가 읽지 못해 무음 no-op였다 (P1-17a에서 계약 통일).
library;

import 'dart:io';

import 'package:boilerplate_cli/commands/iap/iap_contract_writer.dart';
import 'package:boilerplate_cli/commands/iap/iap_models.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// iOS용 IAP 계약 파일을 생성합니다.
///
/// [products]/[subscriptionGroups]의 상품 ID는 호출자가 이미
/// `<id>.<packageName>` 최종형으로 변환해서 넘겨야 한다.
Future<void> generateIosMetadata({
  required String projectRoot,
  required List<IapProduct> products,
  required List<SubscriptionGroup> subscriptionGroups,
  required bool isVerbose,
}) async {
  final baseDir = '$projectRoot/metadata/in_app_purchases/ios';

  // 일반 상품
  for (final product in products) {
    final file = await writeIosIapContract(
      iosDir: baseDir,
      entry: IapContractEntry(
        productId: product.id,
        type: product.type,
        priceTier: product.priceTier,
        names: product.names,
        descriptions: product.descriptions,
      ),
    );
    if (isVerbose) {
      CliLogger.debug('  iOS IAP 계약 생성: ${file.path}');
    }
  }

  // 구독 상품 (구독 그룹은 fastlane이 ENV SUBSCRIPTION_GROUP_NAME으로
  // 관리 — 파일 계약에 포함하지 않는다)
  for (final group in subscriptionGroups) {
    for (final product in group.products) {
      final file = await writeIosIapContract(
        iosDir: baseDir,
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
        CliLogger.debug('  iOS 구독 계약 생성: ${file.path}');
      }
    }
  }

  // App Store Connect API 안내 메시지
  final hasApiKey =
      Platform.environment.containsKey('APPSTORE_CONNECT_API_KEY');
  if (hasApiKey) {
    print('');
    print('  💡 APPSTORE_CONNECT_API_KEY가 설정되어 있습니다.');
    print('     fastlane upload_iap (./deploy 경유)로 자동 등록이 가능합니다.');
  } else {
    print('');
    print('  📋 iOS 상품 등록 안내:');
    print('     1. App Store Connect에서 수동으로 상품을 등록하세요.');
    print('     2. 또는 APPSTORE_CONNECT_API_KEY 환경 변수를 설정하여');
    print('        fastlane upload_iap로 자동 등록할 수 있습니다.');
  }
}
