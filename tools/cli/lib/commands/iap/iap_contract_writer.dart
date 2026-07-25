/// IAP JSON 계약 직렬화 SSOT (P1-17a).
///
/// 계약 소유자는 **소비자**(fastlane upload_iap_ios /
/// upload_subscription_ios / upload_iap_android — flutter-fastlane repo)다.
/// 생산자 2곳(./init setupStoreInfoStep, ./run iap-register)은 반드시
/// 이 모듈을 통해서만 파일을 만든다 — 직렬화 로직을 다른 곳에 두지 말 것.
///
/// ## 계약 (소비자가 읽는 포맷)
/// - iOS: `metadata/in_app_purchases/ios/<productId>.json` — flat, 객체 1개
///   `{product_id, type('non_consumable'|'consumable'|
///    'auto_renewable_subscription'), reference_name, pricing:{tier:int},
///    localizations:[{locale,name,description}],
///    (구독) subscription_duration('P1M'|'P1Y'),
///    subscription_family_sharable:bool}`
/// - Android: `metadata/in_app_purchases/android/<productId>.json` — flat,
///   객체 1개 (배열 금지 — 배열이면 업로드 레인이 크래시했다)
///   `{productId, purchaseType('subscription'|'managedUser'),
///    defaultLanguage, defaultPrice:{priceMicros:string, currency},
///    listings:{locale:{title,description}},
///    (구독) subscriptionPeriod('P1M'|'P1Y')}`
library;

import 'dart:convert';
import 'dart:io';

/// iOS price tier → USD 가격 매핑 (대표적인 티어만).
///
/// 여기 없는 tier는 [usdForTier]가 명시적으로 던진다 — 폴백 가격이
/// 스토어에 잘못 등록되는 사고 방지.
const priceTierToUsd = <int, String>{
  1: '0.99',
  2: '1.99',
  3: '2.99',
  4: '3.99',
  5: '4.99',
  6: '5.99',
  7: '6.99',
  8: '7.99',
  9: '8.99',
  10: '9.99',
  15: '14.99',
  20: '19.99',
  25: '24.99',
  30: '29.99',
  40: '39.99',
  50: '49.99',
  60: '59.99',
  70: '69.99',
  80: '79.99',
  90: '89.99',
  100: '99.99',
};

/// 계약이 커버하는 locale 8종 (deliver metadata/ios 디렉토리와 동일 셋).
const iapContractLocales = [
  'en-US',
  'ko-KR',
  'ja-JP',
  'zh-CN',
  'de-DE',
  'fr-FR',
  'ru-RU',
  'pt-BR',
];

/// locale → 다국어 입력 키 (project.yaml name/description의 언어 키)
const iapLocaleToLangKey = <String, String>{
  'en-US': 'en',
  'ko-KR': 'ko',
  'ja-JP': 'ja',
  'zh-CN': 'zh',
  'de-DE': 'de',
  'fr-FR': 'fr',
  'ru-RU': 'ru',
  'pt-BR': 'pt',
};

/// tier의 USD 가격 문자열. 매핑에 없는 tier는 [ArgumentError].
String usdForTier(int tier) {
  final usd = priceTierToUsd[tier];
  if (usd == null) {
    throw ArgumentError.value(
      tier,
      'tier',
      '정의되지 않은 price tier — priceTierToUsd 맵에 추가하거나 '
          '지원 tier(${priceTierToUsd.keys.join(', ')}) 중 하나를 쓰세요',
    );
  }
  return usd;
}

/// tier의 Google Play priceMicros 문자열 (USD 기준 1e6 스케일).
String priceMicrosForTier(int tier) {
  final usd = double.parse(usdForTier(tier));
  return (usd * 1000000).round().toString();
}

/// 계약 직렬화 입력 — 생산자 공통 모델.
class IapContractEntry {
  const IapContractEntry({
    required this.productId,
    required this.type,
    required this.priceTier,
    required this.names,
    required this.descriptions,
    this.subscriptionDuration,
  });

  /// 최종 상품 ID — `<id>.<packageName>` 규칙으로 생산자가 만들어 넘긴다.
  final String productId;

  /// 'non_consumable' | 'consumable' | 'auto_renewable_subscription'
  final String type;

  final int priceTier;

  /// 언어 키('en','ko',…) → 표시명
  final Map<String, String> names;

  /// 언어 키 → 설명
  final Map<String, String> descriptions;

  /// 구독만: 'P1M' | 'P1Y'
  final String? subscriptionDuration;

  bool get isSubscription => type == 'auto_renewable_subscription';
}

/// iOS 계약 파일 1개를 쓴다 → `<iosDir>/<productId>.json`
Future<File> writeIosIapContract({
  required String iosDir,
  required IapContractEntry entry,
}) async {
  await Directory(iosDir).create(recursive: true);

  final json = <String, dynamic>{
    'product_id': entry.productId,
    'type': entry.type,
    'reference_name': entry.productId,
    'pricing': {'tier': entry.priceTier},
    'localizations': _localizations(entry),
    if (entry.isSubscription) ...{
      'subscription_duration': entry.subscriptionDuration ?? 'P1M',
      'subscription_family_sharable': false,
    },
  };

  final file = File('$iosDir/${entry.productId}.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(json),
  );
  return file;
}

/// Android 계약 파일 1개를 쓴다 → `<androidDir>/<productId>.json`
Future<File> writeAndroidIapContract({
  required String androidDir,
  required IapContractEntry entry,
}) async {
  await Directory(androidDir).create(recursive: true);

  final json = <String, dynamic>{
    'productId': entry.productId,
    'purchaseType': entry.isSubscription ? 'subscription' : 'managedUser',
    'defaultLanguage': 'en-US',
    'defaultPrice': {
      'priceMicros': priceMicrosForTier(entry.priceTier),
      'currency': 'USD',
    },
    'listings': _listings(entry),
    if (entry.isSubscription)
      'subscriptionPeriod': entry.subscriptionDuration ?? 'P1M',
  };

  final file = File('$androidDir/${entry.productId}.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(json),
  );
  return file;
}

/// 구포맷 잔재 정리 — 서브디렉토리(구 setup_store_info/iap-register
/// 산출물)와 배열형 JSON 3종. 새 계약 파일 생성 전에 호출.
Future<void> cleanLegacyIapArtifacts({
  required String iosDir,
  required String androidDir,
}) async {
  final ios = Directory(iosDir);
  if (ios.existsSync()) {
    for (final entity in ios.listSync()) {
      if (entity is Directory) {
        entity.deleteSync(recursive: true);
      }
    }
  }

  for (final legacy in [
    '$androidDir/in_app_products.json',
    '$androidDir/inappproducts.json',
    '$androidDir/subscriptions.json',
  ]) {
    final file = File(legacy);
    if (file.existsSync()) file.deleteSync();
  }
}

List<Map<String, String>> _localizations(IapContractEntry entry) {
  final result = <Map<String, String>>[];
  for (final locale in iapContractLocales) {
    final langKey = iapLocaleToLangKey[locale] ?? 'en';
    final name = entry.names[langKey] ?? entry.names['en'] ?? entry.productId;
    final description =
        entry.descriptions[langKey] ?? entry.descriptions['en'] ?? '';
    result.add({
      'locale': locale,
      'name': name,
      'description': description,
    });
  }
  return result;
}

Map<String, Map<String, String>> _listings(IapContractEntry entry) {
  final listings = <String, Map<String, String>>{};
  for (final locale in iapContractLocales) {
    final langKey = iapLocaleToLangKey[locale] ?? 'en';
    final title = entry.names[langKey] ?? entry.names['en'] ?? '';
    final description =
        entry.descriptions[langKey] ?? entry.descriptions['en'] ?? '';
    if (title.isNotEmpty) {
      listings[locale] = {'title': title, 'description': description};
    }
  }
  return listings;
}
