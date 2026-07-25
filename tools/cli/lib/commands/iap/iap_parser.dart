/// IAP YAML 설정 파일 파싱.
library;

import 'package:yaml/yaml.dart';

import 'package:boilerplate_cli/commands/iap/iap_models.dart';

/// YAML에서 일반 상품 목록을 파싱합니다.
List<IapProduct> parseProducts(YamlMap config) {
  final productsYaml = config['products'] as YamlList?;
  if (productsYaml == null) return [];

  return productsYaml.map((item) {
    final map = item as YamlMap;
    return IapProduct(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      names: _parseLocalizedMap(map['name']),
      descriptions: _parseLocalizedMap(map['description']),
      priceTier: map['price_tier'] as int? ?? 0,
    );
  }).toList();
}

/// YAML에서 구독 그룹 목록을 파싱합니다.
List<SubscriptionGroup> parseSubscriptions(YamlMap config) {
  final subsYaml = config['subscriptions'] as YamlList?;
  if (subsYaml == null) return [];

  return subsYaml.map((item) {
    final map = item as YamlMap;
    final productsYaml = map['products'] as YamlList? ?? YamlList();

    final products = productsYaml.map((p) {
      final pMap = p as YamlMap;
      return SubscriptionProduct(
        id: pMap['id'] as String? ?? '',
        duration: pMap['duration'] as String? ?? '',
        names: _parseLocalizedMap(pMap['name']),
        descriptions: _parseLocalizedMap(pMap['description']),
        priceTier: pMap['price_tier'] as int? ?? 0,
      );
    }).toList();

    return SubscriptionGroup(
      groupId: map['group_id'] as String? ?? '',
      groupNames: _parseLocalizedMap(map['group_name']),
      products: products,
    );
  }).toList();
}

/// 다국어 맵을 파싱합니다.
Map<String, String> _parseLocalizedMap(dynamic value) {
  if (value == null) return {};
  if (value is YamlMap) {
    return Map.fromEntries(
      value.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
    );
  }
  return {};
}
