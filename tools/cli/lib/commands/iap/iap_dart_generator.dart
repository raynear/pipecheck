/// Dart IAP 상수 파일 생성.
library;

import 'dart:io';

import 'package:boilerplate_cli/commands/iap/iap_models.dart';
import 'package:boilerplate_cli/commands/iap/iap_utils.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Dart 상수 파일을 생성합니다.
Future<void> generateDartConstants({
  required String projectRoot,
  required List<IapProduct> products,
  required List<SubscriptionProduct> subscriptionProducts,
  required bool isVerbose,
}) async {
  final consumables =
      products.where((p) => p.type == 'consumable').toList();
  final nonConsumables =
      products.where((p) => p.type == 'non_consumable').toList();

  final buffer = StringBuffer();

  buffer.writeln(
      '/// Auto-generated IAP product IDs from project.yaml');
  buffer.writeln('/// DO NOT EDIT MANUALLY');
  buffer.writeln('class IapProductIds {');
  buffer.writeln('  IapProductIds._();');

  // Consumable 상품
  if (consumables.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('  // Consumable');
    for (final product in consumables) {
      final constName = toConstantName(product.id);
      buffer.writeln(
          "  static const String $constName = '${product.id}';");
    }
  }

  // Non-consumable 상품
  if (nonConsumables.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('  // Non-consumable');
    for (final product in nonConsumables) {
      final constName = toConstantName(product.id);
      buffer.writeln(
          "  static const String $constName = '${product.id}';");
    }
  }

  // 구독 상품
  if (subscriptionProducts.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('  // Subscriptions');
    for (final product in subscriptionProducts) {
      final constName = toConstantName(product.id);
      buffer.writeln(
          "  static const String $constName = '${product.id}';");
    }
  }

  // 상품 리스트
  buffer.writeln('');

  if (consumables.isNotEmpty) {
    final consumableNames =
        consumables.map((p) => toConstantName(p.id)).join(', ');
    buffer.writeln(
        '  static const List<String> consumables = [$consumableNames];');
  } else {
    buffer.writeln(
        '  static const List<String> consumables = [];');
  }

  if (nonConsumables.isNotEmpty) {
    final nonConsumableNames =
        nonConsumables.map((p) => toConstantName(p.id)).join(', ');
    buffer.writeln(
        '  static const List<String> nonConsumables = [$nonConsumableNames];');
  } else {
    buffer.writeln(
        '  static const List<String> nonConsumables = [];');
  }

  if (subscriptionProducts.isNotEmpty) {
    final subNames =
        subscriptionProducts.map((p) => toConstantName(p.id)).join(', ');
    buffer.writeln(
        '  static const List<String> subscriptions = [$subNames];');
  } else {
    buffer.writeln(
        '  static const List<String> subscriptions = [];');
  }

  buffer.writeln(
      '  static const List<String> allProducts = '
      '[...consumables, ...nonConsumables, ...subscriptions];');
  buffer.writeln('}');

  // 파일 저장
  final outputPath = '$projectRoot/app/lib/config/iap_product_ids.dart';
  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(buffer.toString());

  if (isVerbose) {
    CliLogger.debug('  Dart 상수 파일 생성: $outputPath');
  }
}
