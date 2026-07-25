// IAP JSON 계약 테스트 (P1-17a) — 생산자/소비자 포맷 단일화 회귀 가드.
//
// 계약 소유자는 소비자(fastlane upload_iap_ios/upload_subscription_ios/
// upload_iap_android)다. 이 테스트는 생산자 출력이 소비자가 읽는 형태
// (flat <productId>.json, 객체, 필수 키)에서 발산하지 않게 고정한다.

import 'dart:convert';
import 'dart:io';

import 'package:boilerplate_cli/commands/iap/iap_contract_writer.dart';
import 'package:boilerplate_cli/commands/iap/iap_models.dart';
import 'package:boilerplate_cli/commands/iap/iap_android_generator.dart';
import 'package:boilerplate_cli/commands/iap/iap_ios_generator.dart';
import 'package:test/test.dart';

const _entry = IapContractEntry(
  productId: 'premium_monthly.com.example.app',
  type: 'auto_renewable_subscription',
  priceTier: 5,
  names: {'en': 'Monthly Premium', 'ko': '월간 프리미엄'},
  descriptions: {'en': 'Monthly sub', 'ko': '월간 구독'},
  subscriptionDuration: 'P1M',
);

const _oneTime = IapContractEntry(
  productId: 'lifetime.com.example.app',
  type: 'non_consumable',
  priceTier: 30,
  names: {'en': 'Lifetime'},
  descriptions: {'en': 'One-time purchase'},
);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('iap_contract_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('가격 변환', () {
    test('priceMicros = round(usd * 1e6) — tier*990000 근사 아님', () {
      expect(priceMicrosForTier(5), '4990000'); // $4.99
      expect(priceMicrosForTier(30), '29990000'); // $29.99
      expect(priceMicrosForTier(1), '990000'); // $0.99
    });

    test('미정의 tier는 폴백 없이 명시적으로 던진다 (가격 오등록 방지)', () {
      expect(() => priceMicrosForTier(11), throwsArgumentError);
      expect(() => usdForTier(999), throwsArgumentError);
    });
  });

  group('iOS 계약 (upload_iap_ios/upload_subscription_ios가 읽는 형태)', () {
    test('flat <productId>.json, 필수 키 전부 존재', () async {
      final file = await writeIosIapContract(
        iosDir: '${tempDir.path}/ios',
        entry: _entry,
      );

      expect(file.path, endsWith('/ios/premium_monthly.com.example.app.json'),
          reason: '서브디렉토리 금지 — 소비자는 flat glob');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['product_id'], 'premium_monthly.com.example.app');
      expect(json['type'], 'auto_renewable_subscription');
      expect(json['reference_name'], isNotEmpty);
      expect(json['pricing'], {'tier': 5});
      expect(json['subscription_duration'], 'P1M');
      final locs = json['localizations'] as List;
      expect(locs, hasLength(iapContractLocales.length));
      for (final loc in locs.cast<Map<String, dynamic>>()) {
        expect(loc.keys, containsAll(['locale', 'name', 'description']));
      }
      // ko locale에 ko 카피가 들어간다
      final ko = locs.cast<Map<String, dynamic>>()
          .firstWhere((l) => l['locale'] == 'ko-KR');
      expect(ko['name'], '월간 프리미엄');
    });

    test('non_consumable은 구독 필드를 갖지 않는다', () async {
      final file = await writeIosIapContract(
        iosDir: '${tempDir.path}/ios',
        entry: _oneTime,
      );
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['type'], 'non_consumable');
      expect(json.containsKey('subscription_duration'), false);
    });
  });

  group('Android 계약 (upload_iap_android가 읽는 형태)', () {
    test('flat <productId>.json, 객체(배열 금지), 필수 키 전부 존재', () async {
      final file = await writeAndroidIapContract(
        androidDir: '${tempDir.path}/android',
        entry: _entry,
      );

      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>(),
          reason: '배열이면 소비자 레인이 TypeError 크래시');
      final json = decoded as Map<String, dynamic>;
      expect(json['productId'], 'premium_monthly.com.example.app');
      expect(json['purchaseType'], 'subscription');
      expect(json['subscriptionPeriod'], 'P1M');
      expect(json['defaultLanguage'], 'en-US');
      expect(json['defaultPrice'],
          {'priceMicros': '4990000', 'currency': 'USD'});
      final listings = json['listings'] as Map<String, dynamic>;
      expect(listings['ko-KR'],
          {'title': '월간 프리미엄', 'description': '월간 구독'});
    });

    test('일반 상품은 managedUser, 구독 필드 없음', () async {
      final file = await writeAndroidIapContract(
        androidDir: '${tempDir.path}/android',
        entry: _oneTime,
      );
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['purchaseType'], 'managedUser');
      expect(json.containsKey('subscriptionPeriod'), false);
    });
  });

  group('생산자 2곳 반발산 (setupStoreInfoStep ↔ iap-register)', () {
    test('iap-register 생성기가 공유 라이터와 동일 출력을 낸다', () async {
      // 생성기 경유
      await generateIosMetadata(
        projectRoot: tempDir.path,
        products: const [
          IapProduct(
            id: 'lifetime.com.example.app',
            type: 'non_consumable',
            names: {'en': 'Lifetime'},
            descriptions: {'en': 'One-time purchase'},
            priceTier: 30,
          ),
        ],
        subscriptionGroups: const [],
        isVerbose: false,
      );
      await generateAndroidMetadata(
        projectRoot: tempDir.path,
        products: const [
          IapProduct(
            id: 'lifetime.com.example.app',
            type: 'non_consumable',
            names: {'en': 'Lifetime'},
            descriptions: {'en': 'One-time purchase'},
            priceTier: 30,
          ),
        ],
        subscriptionGroups: const [],
        isVerbose: false,
      );

      // 공유 라이터 직접 호출 (setupStoreInfoStep 경로와 동일 직렬화)
      final refDir = Directory.systemTemp.createTempSync('iap_ref_');
      addTearDown(() => refDir.deleteSync(recursive: true));
      final iosRef = await writeIosIapContract(
        iosDir: '${refDir.path}/ios',
        entry: _oneTime,
      );
      final androidRef = await writeAndroidIapContract(
        androidDir: '${refDir.path}/android',
        entry: _oneTime,
      );

      expect(
        File('${tempDir.path}/metadata/in_app_purchases/ios/'
                'lifetime.com.example.app.json')
            .readAsStringSync(),
        iosRef.readAsStringSync(),
        reason: '생산자 출력이 라이터와 바이트 동일해야 발산이 없다',
      );
      expect(
        File('${tempDir.path}/metadata/in_app_purchases/android/'
                'lifetime.com.example.app.json')
            .readAsStringSync(),
        androidRef.readAsStringSync(),
      );
    });
  });

  group('구포맷 잔재 정리', () {
    test('서브디렉토리와 배열형 JSON 3종을 지운다', () async {
      final iosDir = '${tempDir.path}/ios';
      final androidDir = '${tempDir.path}/android';
      Directory('$iosDir/old.product.dir/locales')
          .createSync(recursive: true);
      Directory(androidDir).createSync(recursive: true);
      File('$androidDir/in_app_products.json').writeAsStringSync('[]');
      File('$androidDir/inappproducts.json').writeAsStringSync('[]');
      File('$androidDir/subscriptions.json').writeAsStringSync('[]');

      await cleanLegacyIapArtifacts(iosDir: iosDir, androidDir: androidDir);

      expect(Directory('$iosDir/old.product.dir').existsSync(), false);
      expect(File('$androidDir/in_app_products.json').existsSync(), false);
      expect(File('$androidDir/inappproducts.json').existsSync(), false);
      expect(File('$androidDir/subscriptions.json').existsSync(), false);
    });
  });
}
