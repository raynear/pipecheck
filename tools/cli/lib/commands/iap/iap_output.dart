/// IAP 등록 결과 출력.
library;

import 'package:boilerplate_cli/commands/iap/iap_models.dart';
import 'package:boilerplate_cli/commands/iap/iap_utils.dart';

/// Dry-run 모드에서 요약 정보를 출력합니다.
void printDryRunSummary({
  required List<IapProduct> products,
  required List<SubscriptionGroup> subscriptionGroups,
  required String platform,
}) {
  final consumables =
      products.where((p) => p.type == 'consumable').toList();
  final nonConsumables =
      products.where((p) => p.type == 'non_consumable').toList();

  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
  print('  🔍 Dry Run 모드 - 파일이 생성되지 않습니다');
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');

  // 소모성 상품
  if (consumables.isNotEmpty) {
    print('  📦 소모성 상품 (Consumable): ${consumables.length}개');
    for (final product in consumables) {
      final name = product.names['en'] ?? product.names.values.first;
      print('    • ${product.id}');
      print('      이름: $name | 가격 티어: ${product.priceTier}');
    }
    print('');
  }

  // 비소모성 상품
  if (nonConsumables.isNotEmpty) {
    print('  🔓 비소모성 상품 (Non-consumable): ${nonConsumables.length}개');
    for (final product in nonConsumables) {
      final name = product.names['en'] ?? product.names.values.first;
      print('    • ${product.id}');
      print('      이름: $name | 가격 티어: ${product.priceTier}');
    }
    print('');
  }

  // 구독 상품
  if (subscriptionGroups.isNotEmpty) {
    print('  🔄 구독 그룹: ${subscriptionGroups.length}개');
    for (final group in subscriptionGroups) {
      final groupName =
          group.groupNames['en'] ?? group.groupNames.values.first;
      print('    📂 ${group.groupId} ($groupName)');
      for (final product in group.products) {
        final name = product.names['en'] ?? product.names.values.first;
        print('      • ${product.id}');
        print('        이름: $name | 기간: ${product.duration} '
            '| 가격 티어: ${product.priceTier}');
      }
    }
    print('');
  }

  // 생성될 파일 목록
  print('  📁 생성될 파일:');
  print('');

  if (platform == 'all' || platform == 'ios') {
    print('    iOS (fastlane upload_iap_* 계약 형식):');
    for (final product in products) {
      print('      • metadata/in_app_purchases/ios/${product.id}.json');
    }
    for (final group in subscriptionGroups) {
      for (final product in group.products) {
        print('      • metadata/in_app_purchases/ios/${product.id}.json');
      }
    }
    print('');
  }

  if (platform == 'all' || platform == 'android') {
    print('    Android (fastlane upload_iap_android 계약 형식):');
    for (final product in products) {
      print('      • metadata/in_app_purchases/android/${product.id}.json');
    }
    for (final group in subscriptionGroups) {
      for (final product in group.products) {
        print('      • metadata/in_app_purchases/android/${product.id}.json');
      }
    }
    print('');
  }

  print('    Dart 상수:');
  print('      • app/lib/config/iap_product_ids.dart');
  print('');

  // Dart 상수 미리보기
  print('  📝 Dart 상수 미리보기:');
  print('');
  print('    class IapProductIds {');
  for (final product in consumables) {
    print('      static const String ${toConstantName(product.id)} = '
        '\'${product.id}\';');
  }
  for (final product in nonConsumables) {
    print('      static const String ${toConstantName(product.id)} = '
        '\'${product.id}\';');
  }
  for (final group in subscriptionGroups) {
    for (final product in group.products) {
      print('      static const String ${toConstantName(product.id)} = '
          '\'${product.id}\';');
    }
  }
  print('    }');
  print('');
}

/// 성공 메시지를 출력합니다.
void printSuccessMessage({
  required double elapsed,
  required List<IapProduct> products,
  required List<SubscriptionGroup> subscriptionGroups,
  required String platform,
}) {
  final allSubProducts =
      subscriptionGroups.expand((g) => g.products).toList();
  final totalProducts = products.length + allSubProducts.length;

  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
  print('  ✅ IAP 상품 등록 파일 생성이 완료되었습니다!');
  print('');
  print('     총 상품 수: $totalProducts개');
  print('     소요 시간: ${elapsed.toStringAsFixed(1)}초');
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
  print('  📌 생성된 파일:');
  print('');

  if (platform == 'all' || platform == 'ios') {
    print('  • metadata/in_app_purchases/ios/ (iOS 메타데이터)');
  }
  if (platform == 'all' || platform == 'android') {
    print('  • metadata/in_app_purchases/android/ (Android 상품 JSON)');
  }
  print('  • app/lib/config/iap_product_ids.dart (Dart 상수)');
  print('');
  print('  💡 다음 단계:');
  print('     1. 생성된 파일을 검토하세요.');
  print('     2. App Store Connect / Google Play Console에서 상품을 등록하세요.');
  print('     3. IapProductIds 클래스를 사용하여 앱에서 상품을 참조하세요.');
  print('');
}
