import 'dart:io';

import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigLoader 문자열 리스트 언래핑 (P2-23a 회귀)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('config_loader_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<ConfigLoader> load({
      String projectYaml = '',
      String appConfigYaml = 'project:\n  name: Test\n',
    }) async {
      File('${tempDir.path}/project.yaml').writeAsStringSync(projectYaml);
      File('${tempDir.path}/app_config.yaml').writeAsStringSync(appConfigYaml);
      final config = ConfigLoader('${tempDir.path}/app_config.yaml');
      await config.load();
      return config;
    }

    test('universal_links 원소가 _value 래퍼 없이 풀린다', () async {
      final config = await load(projectYaml: '''
deep_link:
  scheme: "myapp"
  universal_links: ["a.web.app", "b.example.com"]
''');
      expect(config.deepLinkUniversalLinks, ['a.web.app', 'b.example.com']);
      expect(
        config.deepLinkUniversalLinks.any((e) => e.contains('_value')),
        isFalse,
      );
      // 스칼라 경로는 원래 정상이었음 — 함께 가드
      expect(config.deepLinkScheme, 'myapp');
    });

    test('tracking_domains도 동일하게 언래핑된다', () async {
      final config = await load(projectYaml: '''
privacy:
  tracking_domains: ["track.example.com", "a.b.c"]
''');
      expect(config.trackingDomains, ['track.example.com', 'a.b.c']);
    });

    test('빈 리스트 / 미설정 키는 기본값', () async {
      final empty = await load(projectYaml: 'deep_link:\n  universal_links: []\n');
      expect(empty.deepLinkUniversalLinks, isEmpty);

      final missing = await load();
      expect(missing.deepLinkUniversalLinks, isEmpty);
      expect(missing.trackingDomains, isEmpty);
    });
  });
}
