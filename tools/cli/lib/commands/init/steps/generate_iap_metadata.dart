import 'dart:io';

import 'package:boilerplate_cli/commands/iap/iap_contract_writer.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// project.yaml의 IAP SSOT(iap.subscriptions + iap.products)에서
/// `metadata/in_app_purchases/{ios,android}/<id>.<packageName>.json`을
/// 재생성한다.
///
/// 직렬화는 iap_contract_writer.dart가 SSOT다 (P1-17a) — 이 스텝은
/// SSOT 입력을 [IapContractEntry]로 변환해 writeIosIapContract /
/// writeAndroidIapContract에 넘기기만 한다.
///
/// 재생성 전에 두 디렉토리의 기존 `*.json`을 **모두** 지운다. 그래서
/// 포커가 package_name을 바꿔도 이전 패키지명으로 된 작성자 산출물
/// (예: `*.com.raynear.myapp.json`)이 잔존하지 않는다.
/// IO 실패는 init을 막지 않고 경고만 남긴다.
Future<void> generateIapMetadataStep({
  required String projectRoot,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final packageName = config.packageName;
  final baseDir = '$projectRoot/metadata/in_app_purchases';
  final iosDir = '$baseDir/ios';
  final androidDir = '$baseDir/android';

  try {
    // 1. 기존 JSON 산출물 전부 제거 (이전 패키지명 잔재 포함).
    await _purgeExistingContracts(iosDir);
    await _purgeExistingContracts(androidDir);

    // 2. SSOT → 계약 엔트리.
    final entries = _buildEntries(config: config, packageName: packageName);

    // 3. SSOT 직렬화로 새 계약 파일 작성.
    for (final entry in entries) {
      final iosFile = await writeIosIapContract(iosDir: iosDir, entry: entry);
      final androidFile = await writeAndroidIapContract(
        androidDir: androidDir,
        entry: entry,
      );
      if (verbose) {
        CliLogger.debug(
          'IAP 계약 생성: ${iosFile.path}, ${androidFile.path}',
        );
      }
    }

    if (entries.isEmpty) {
      print('    IAP 메타데이터: 정의 없음 (건너뛰기)');
    } else {
      print('    IAP 메타데이터 ${entries.length}개 생성 완료');
    }
  } catch (e) {
    CliLogger.warning('IAP 메타데이터 생성 경고: $e');
    print('    IAP 메타데이터 생성 건너뛰기');
  }
}

/// 디렉토리의 기존 `*.json` 계약 파일을 모두 삭제한다.
/// 디렉토리가 없으면 no-op.
Future<void> _purgeExistingContracts(String dirPath) async {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync()) {
    if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
      entity.deleteSync();
    }
  }
}

/// SSOT(iap.subscriptions + iap.products)를 계약 엔트리 목록으로 변환한다.
/// productId는 `<id>.<packageName>` 최종형으로 만든다.
List<IapContractEntry> _buildEntries({
  required ConfigLoader config,
  required String packageName,
}) {
  final entries = <IapContractEntry>[];

  // 구독 상품 (auto_renewable_subscription).
  for (final sub in config.iapSubscriptions) {
    if (sub is! Map) continue;
    for (final product in _extractList(sub, 'products')) {
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

  // 일반 상품 (non_consumable / consumable).
  for (final product in config.iapProducts) {
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

  return entries;
}

/// YAML Map에서 중첩된 _value 값을 추출.
String? _extractValue(Map map, String key) {
  final value = map[key];
  if (value is Map && value.containsKey('_value')) {
    return value['_value']?.toString();
  }
  if (value is String) return value;
  if (value != null) return value.toString();
  return null;
}

/// YAML Map에서 리스트 추출.
List<dynamic> _extractList(Map map, String key) {
  final value = map[key];
  if (value is List) return value;
  if (value is Map && value.containsKey('_list')) {
    return value['_list'] as List;
  }
  return [];
}

/// YAML Map에서 다국어 Map 추출 (name, description 등).
Map<String, String> _extractMap(Map map, String key) {
  final value = map[key];
  if (value is! Map) return {};
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
