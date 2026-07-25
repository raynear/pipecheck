/// IAP 상품 정의 검증.
library;

import 'package:boilerplate_cli/commands/iap/iap_models.dart';
import 'package:boilerplate_cli/core/error_handler.dart';

/// 일반 상품 정의를 검증합니다.
void validateProducts(List<IapProduct> products) {
  for (final product in products) {
    if (product.id.isEmpty) {
      throw CliException(
        '상품 ID가 비어 있습니다',
        solution: '모든 상품에 고유한 ID를 지정하세요.\n'
            '형식: com.company.app.product_name',
      );
    }

    if (!RegExp(r'^[a-z][a-z0-9_.]+$').hasMatch(product.id)) {
      throw CliException(
        '잘못된 상품 ID 형식: ${product.id}',
        solution: '상품 ID는 소문자, 숫자, 점, 밑줄만 사용할 수 있습니다.\n'
            '형식: com.company.app.product_name',
      );
    }

    if (product.type != 'consumable' && product.type != 'non_consumable') {
      throw CliException(
        '잘못된 상품 유형: ${product.type} (상품: ${product.id})',
        solution: '상품 유형은 consumable 또는 non_consumable이어야 합니다.',
      );
    }

    if (product.names.isEmpty) {
      throw CliException(
        '상품 이름이 정의되지 않았습니다: ${product.id}',
        solution: '최소 하나의 언어로 상품 이름을 정의하세요.',
      );
    }

    if (product.priceTier <= 0) {
      throw CliException(
        '잘못된 가격 티어: ${product.priceTier} (상품: ${product.id})',
        solution: '가격 티어는 1 이상의 정수여야 합니다.',
      );
    }
  }
}

/// 구독 그룹 정의를 검증합니다.
void validateSubscriptionGroups(List<SubscriptionGroup> groups) {
  for (final group in groups) {
    if (group.groupId.isEmpty) {
      throw CliException(
        '구독 그룹 ID가 비어 있습니다',
        solution: '모든 구독 그룹에 고유한 group_id를 지정하세요.',
      );
    }

    if (group.products.isEmpty) {
      throw CliException(
        '구독 그룹에 상품이 없습니다: ${group.groupId}',
        solution: '각 구독 그룹에 최소 하나의 상품을 추가하세요.',
      );
    }

    for (final product in group.products) {
      if (product.id.isEmpty) {
        throw CliException(
          '구독 상품 ID가 비어 있습니다 (그룹: ${group.groupId})',
          solution: '모든 구독 상품에 고유한 ID를 지정하세요.',
        );
      }

      if (!RegExp(r'^[a-z][a-z0-9_.]+$').hasMatch(product.id)) {
        throw CliException(
          '잘못된 구독 상품 ID 형식: ${product.id}',
          solution: '상품 ID는 소문자, 숫자, 점, 밑줄만 사용할 수 있습니다.',
        );
      }

      if (product.duration.isEmpty) {
        throw CliException(
          '구독 기간이 정의되지 않았습니다: ${product.id}',
          solution: 'duration 필드를 추가하세요. (예: P1M, P1Y)',
        );
      }

      if (product.names.isEmpty) {
        throw CliException(
          '구독 상품 이름이 정의되지 않았습니다: ${product.id}',
          solution: '최소 하나의 언어로 상품 이름을 정의하세요.',
        );
      }

      if (product.priceTier <= 0) {
        throw CliException(
          '잘못된 가격 티어: ${product.priceTier} (상품: ${product.id})',
          solution: '가격 티어는 1 이상의 정수여야 합니다.',
        );
      }
    }
  }
}
