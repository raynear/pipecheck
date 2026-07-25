import 'dart:convert';
import 'dart:io';

import 'package:boilerplate_cli/commands/iap/iap_contract_writer.dart';
import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';
import 'package:boilerplate_cli/core/progress/progress_indicator.dart';

/// Apple 카테고리 매핑 (project.yaml 값 → deliver primary_category)
const _appleCategoryMap = <String, String>{
  'productivity': 'MZGenre.Productivity',
  'utility': 'MZGenre.Utilities',
  'business': 'MZGenre.Business',
  'developer_tools': 'MZGenre.DeveloperTools',
  'education': 'MZGenre.Education',
  'reference': 'MZGenre.Reference',
  'books': 'MZGenre.Books',
  'entertainment': 'MZGenre.Entertainment',
  'games': 'MZGenre.Games',
  'music': 'MZGenre.Music',
  'photo_video': 'MZGenre.PhotoAndVideo',
  'graphics_design': 'MZGenre.GraphicsAndDesign',
  'social': 'MZGenre.SocialNetworking',
  'lifestyle': 'MZGenre.Lifestyle',
  'news': 'MZGenre.News',
  'food_drink': 'MZGenre.FoodAndDrink',
  'health_fitness': 'MZGenre.HealthAndFitness',
  'medical': 'MZGenre.Medical',
  'sports': 'MZGenre.Sports',
  'finance': 'MZGenre.Finance',
  'shopping': 'MZGenre.Shopping',
  'travel': 'MZGenre.Travel',
  'navigation': 'MZGenre.Navigation',
  'weather': 'MZGenre.Weather',
  'kids': 'MZGenre.Kids',
};

/// Apple 연령등급 키 매핑 (project.yaml 키 → deliver `app_rating_config_path` 키).
///
/// 값(value)은 fastlane deliver가 `AgeRatingDeclaration.map_key_from_itc`로
/// 인식하는 **legacy ITC 키**여야 한다 (deliver/lib/deliver/upload_metadata.rb).
/// 미인식 키는 deliver가 그대로 통과시켜 spaceship 단계에서 깨지므로
/// 철자가 정확해야 한다 — fastlane 2.233.0 스키마 기준 검증됨.
const _ageRatingKeyMap = <String, String>{
  'cartoon_fantasy_violence': 'CARTOON_FANTASY_VIOLENCE',
  'realistic_violence': 'REALISTIC_VIOLENCE',
  'prolonged_graphic_sadistic_violence':
      'PROLONGED_GRAPHIC_SADISTIC_REALISTIC_VIOLENCE',
  'profanity_crude_humor': 'PROFANITY_CRUDE_HUMOR',
  'mature_suggestive_themes': 'MATURE_SUGGESTIVE',
  'horror_fear_themes': 'HORROR',
  'medical_treatment_info': 'MEDICAL_TREATMENT_INFO',
  'alcohol_tobacco_drugs': 'ALCOHOL_TOBACCO_DRUGS',
  'gambling': 'GAMBLING',
  'sexual_content_nudity': 'SEXUAL_CONTENT_NUDITY',
  'unrestricted_web_access': 'UNRESTRICTED_WEB_ACCESS',
  'gambling_contests': 'GAMBLING_CONTESTS',
};

/// project.yaml의 카테고리/연령등급/IAP 정의를 기반으로
/// `<root>/metadata/` 파일을 자동 생성합니다 (P0-8 경로 SSOT).
Future<StepResult> setupStoreInfoStep({
  required String projectRoot,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final progress = ProgressIndicator(message: '스토어 정보 설정');
  progress.start();

  final results = <String>[];

  try {
    // 1. 카테고리/연령등급 설정 파일 생성
    final storeInfoResult = await _generateStoreInfoFiles(
      projectRoot: projectRoot,
      config: config,
      verbose: verbose,
    );
    results.add(storeInfoResult);

    // 2. IAP 정의 파일 생성
    final iapResult = await _generateIapFiles(
      projectRoot: projectRoot,
      config: config,
      verbose: verbose,
    );
    results.add(iapResult);

    progress.complete('스토어 정보: ${results.join(', ')}');
    return const StepResult.done();
  } catch (e) {
    CliLogger.error('스토어 정보 설정 오류: $e');
    progress.complete('스토어 정보 설정 실패 (건너뜀)');
    return StepResult.failed('스토어 정보 설정 오류: $e');
  }
}

/// 카테고리/연령등급 JSON 파일 생성
Future<String> _generateStoreInfoFiles({
  required String projectRoot,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final storeDataDir = '$projectRoot/metadata';
  await Directory(storeDataDir).create(recursive: true);

  // 카테고리 매핑
  final category = config.category;
  final appleCategory = _appleCategoryMap[category] ?? '';
  if (appleCategory.isEmpty) {
    CliLogger.info('카테고리 "$category"에 대한 Apple 매핑 없음');
  } else {
    CliLogger.info('카테고리: $category → $appleCategory');
  }

  // 연령등급 JSON 생성
  final ageRating = config.ageRating;
  final ageRatingConfig = <String, int>{};
  for (final entry in ageRating.entries) {
    final appleKey = _ageRatingKeyMap[entry.key];
    if (appleKey != null) {
      ageRatingConfig[appleKey] = entry.value;
    }
  }

  // 빈 연령등급이면 기본값 (전부 0)으로 채움
  if (ageRatingConfig.isEmpty) {
    for (final appleKey in _ageRatingKeyMap.values) {
      ageRatingConfig[appleKey] = 0;
    }
  }

  final storeInfoFile = File('$storeDataDir/store_info.json');
  final storeInfo = {
    'primary_category': appleCategory,
    'age_rating_config': ageRatingConfig,
  };

  await storeInfoFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(storeInfo),
  );

  // deliver `app_rating_config_path`가 읽는 평면(flat) JSON 산출물.
  // store_info.json은 사람이 보는 SSOT, rating_config.json은 deliver 소비용
  // (ios.rb upload_metadata_ios가 파일 존재 시 deliver_options에 연결).
  final ratingConfigFile = File('$storeDataDir/rating_config.json');
  await ratingConfigFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(ageRatingConfig),
  );

  if (verbose) {
    CliLogger.debug('store_info.json 생성됨: ${storeInfoFile.path}');
    CliLogger.debug('rating_config.json 생성됨: ${ratingConfigFile.path}');
  }

  return '카테고리/연령등급';
}

/// IAP 정의 파일 생성 (iOS + Android) — 계약 직렬화는
/// iap_contract_writer.dart가 SSOT (P1-17a, 소비자 포맷 기준).
Future<String> _generateIapFiles({
  required String projectRoot,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final packageName = config.packageName;
  final storeDataDir = '$projectRoot/metadata/in_app_purchases';
  final iosDir = '$storeDataDir/ios';
  final androidDir = '$storeDataDir/android';

  await cleanLegacyIapArtifacts(iosDir: iosDir, androidDir: androidDir);

  final entries = <IapContractEntry>[];

  // 구독 상품 처리
  final subscriptions = config.iapSubscriptions;
  for (final sub in subscriptions) {
    if (sub is! Map) continue;
    final subProducts = _extractList(sub, 'products');

    for (final product in subProducts) {
      if (product is! Map) continue;
      final id = _extractValue(product, 'id') ?? '';
      if (id.isEmpty) continue;

      entries.add(IapContractEntry(
        productId: '$id.$packageName',
        type: 'auto_renewable_subscription',
        priceTier:
            int.tryParse(_extractValue(product, 'price_tier') ?? '5') ?? 5,
        names: _extractMap(product, 'name'),
        descriptions: _extractMap(product, 'description'),
        subscriptionDuration: _extractValue(product, 'duration') ?? 'P1M',
      ));
    }
  }

  // 일반 상품 처리 (non-consumable, consumable)
  final products = config.iapProducts;
  for (final product in products) {
    if (product is! Map) continue;
    final id = _extractValue(product, 'id') ?? '';
    if (id.isEmpty) continue;

    entries.add(IapContractEntry(
      productId: '$id.$packageName',
      type: _extractValue(product, 'type') ?? 'non_consumable',
      priceTier:
          int.tryParse(_extractValue(product, 'price_tier') ?? '10') ?? 10,
      names: _extractMap(product, 'name'),
      descriptions: _extractMap(product, 'description'),
    ));
  }

  for (final entry in entries) {
    final iosFile = await writeIosIapContract(iosDir: iosDir, entry: entry);
    final androidFile =
        await writeAndroidIapContract(androidDir: androidDir, entry: entry);
    if (verbose) {
      CliLogger.debug('IAP 계약 파일 생성: ${iosFile.path}, '
          '${androidFile.path}');
    }
  }

  if (entries.isEmpty) {
    return 'IAP 없음';
  }
  return 'IAP ${entries.length}개';
}

/// YAML Map에서 중첩된 _value 값을 추출
String? _extractValue(Map map, String key) {
  final value = map[key];
  if (value is Map && value.containsKey('_value')) {
    return value['_value']?.toString();
  }
  if (value is String) return value;
  if (value != null) return value.toString();
  return null;
}

/// YAML Map에서 리스트 추출
List<dynamic> _extractList(Map map, String key) {
  final value = map[key];
  if (value is List) return value;
  if (value is Map && value.containsKey('_list')) {
    return value['_list'] as List;
  }
  return [];
}

/// YAML Map에서 다국어 Map 추출 (name, description 등)
Map<String, String> _extractMap(Map map, String key) {
  final value = map[key];
  if (value is Map) {
    final result = <String, String>{};
    for (final entry in value.entries) {
      final k = entry.key.toString();
      if (k == '_value') continue;
      final v = entry.value;
      if (v is Map && v.containsKey('_value')) {
        result[k] = v['_value'].toString();
      } else if (v is String) {
        result[k] = v;
      } else if (v != null) {
        result[k] = v.toString();
      }
    }
    return result;
  }
  return {};
}
