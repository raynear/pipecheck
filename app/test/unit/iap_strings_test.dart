// 구매·복원 알림과 구독 상태 행이 쓰는 번역 키가 모든 로케일 파일에 있는지.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Iterable<String> trKeys(String path) =>
      RegExp(r"'([^'\n]+)'\.tr\(").allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!);
  // 설정 화면의 구독 상태 행은 SText('...') 리터럴로 쓴다.
  final statusRow = RegExp(r"SText\('(Lifetime|Active)'\)").allMatches(File('lib/features/settings/views/settings_view.dart').readAsStringSync()).map((m) => m.group(1)!);

  final keys = {
    ...trKeys('lib/core/services/in_app_purchase_service.dart'),
    // 구매 화면(온보딩 페이월·구독 시트)이 가격 줄에 쓰는 키.
    ...trKeys('lib/features/onboarding/views/onboarding_view.dart'),
    ...trKeys('lib/features/subscription/views/subscription_view.dart'),
    ...statusRow,
    // 서비스가 이름을 조립하는 구독 이름.
    'Monthly Subscription', 'Yearly Subscription', 'Lifetime Subscription',
  };

  test('서비스 소스에서 번역 키를 실제로 뽑아냈다', () {
    expect(keys, containsAll(['Purchase failed', '{} activated', 'Failed to restore purchase', 'Loading...', '{}/year ({}% discount)', 'Lifetime', 'Active']));
  });

  for (final file in Directory('assets/languages').listSync().whereType<File>().where((f) => RegExp(r'-[A-Z]{2}\.json$').hasMatch(f.path))) {
    test('${file.uri.pathSegments.last}에 모든 키가 번역돼 있다', () {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final k in keys) {
        expect(data[k], isA<String>().having((v) => v.trim(), 'trimmed', isNotEmpty), reason: k);
      }
      expect(data['{} activated'], contains('{}'));
    });
  }
}
