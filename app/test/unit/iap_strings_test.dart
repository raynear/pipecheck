// 구매·복원 알림과 구독 상태 행이 쓰는 번역 키가 모든 로케일 파일에 있는지.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final keys = {
    ...RegExp(r"'([^'\n]+)'\.tr\(").allMatches(File('lib/core/services/in_app_purchase_service.dart').readAsStringSync()).map((m) => m.group(1)!),
    // 서비스가 이름을 조립하는 구독 이름과 설정 화면의 구독 상태 행.
    'Monthly Subscription', 'Yearly Subscription', 'Lifetime Subscription', 'Lifetime', 'Active',
  };

  test('서비스 소스에서 번역 키를 실제로 뽑아냈다', () {
    expect(keys, containsAll(['Purchase failed', '{} activated', 'Failed to restore purchase']));
  });

  for (final file in Directory('assets/languages').listSync().whereType<File>().where((f) => f.path.endsWith('-US.json') || RegExp(r'-[A-Z]{2}\.json$').hasMatch(f.path))) {
    test('${file.uri.pathSegments.last}에 모든 키가 번역돼 있다', () {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final k in keys) {
        expect(data[k], isA<String>().having((v) => v.trim(), 'trimmed', isNotEmpty), reason: k);
      }
      expect(data['{} activated'], contains('{}'));
    });
  }
}
