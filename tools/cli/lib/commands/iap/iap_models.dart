/// IAP 상품 데이터 모델.
library;

/// 일반 인앱 구매 상품.
class IapProduct {
  const IapProduct({
    required this.id,
    required this.type,
    required this.names,
    required this.descriptions,
    required this.priceTier,
  });

  final String id;
  final String type;
  final Map<String, String> names;
  final Map<String, String> descriptions;
  final int priceTier;
}

/// 구독 그룹.
class SubscriptionGroup {
  const SubscriptionGroup({
    required this.groupId,
    required this.groupNames,
    required this.products,
  });

  final String groupId;
  final Map<String, String> groupNames;
  final List<SubscriptionProduct> products;
}

/// 구독 상품.
class SubscriptionProduct {
  const SubscriptionProduct({
    required this.id,
    required this.duration,
    required this.names,
    required this.descriptions,
    required this.priceTier,
  });

  final String id;
  final String duration;
  final Map<String, String> names;
  final Map<String, String> descriptions;
  final int priceTier;
}
