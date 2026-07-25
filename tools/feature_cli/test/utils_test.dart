import 'dart:io';

import 'package:feature_cli/utils.dart';
import 'package:test/test.dart';

void main() {
  group('applyAppConfigFeature', () {
    const baseConfig = '''
profile: "standard"

features:
  # ads: false
  # subscription: true

services:
  firebase:
    enabled: true
''';

    test('enabling a commented key uncomments and sets it to true', () {
      final result = applyAppConfigFeature(baseConfig, 'ads', true);

      expect(result, contains('  ads: true'));
      expect(result, isNot(contains('# ads')));
      // 다른 키와 비기능 섹션은 보존된다.
      expect(result, contains('# subscription: true'));
      expect(result, contains('services:'));
    });

    test('disabling a commented key uncomments and sets it to false', () {
      final result = applyAppConfigFeature(baseConfig, 'ads', false);

      expect(result, contains('  ads: false'));
      expect(result, isNot(contains('# ads')));
    });

    test('a key absent from the block is inserted after the header', () {
      final result = applyAppConfigFeature(baseConfig, 'darkMode', true);
      final lines = result.split('\n');
      final headerIndex = lines.indexWhere((l) => l == 'features:');

      expect(headerIndex, greaterThanOrEqualTo(0));
      // 헤더 바로 다음 줄에 삽입된다.
      expect(lines[headerIndex + 1], '  darkMode: true');
    });

    test('an already-uncommented key is overwritten in place', () {
      const config = '''
features:
  ads: false

services:
  x: 1
''';
      final result = applyAppConfigFeature(config, 'ads', true);

      expect(result, contains('  ads: true'));
      expect('  ads: false'.allMatches(result).length, 0);
      // 블록 밖 키는 건드리지 않는다.
      expect(result, contains('  x: 1'));
    });

    test('throws when the features block header is missing', () {
      const noBlock = 'profile: "standard"\n';
      expect(
        () => applyAppConfigFeature(noBlock, 'ads', true),
        throwsA(isA<Exception>()),
      );
    });

    test('input string is not mutated (immutable)', () {
      const config = 'features:\n  # ads: false\n';
      applyAppConfigFeature(config, 'ads', true);
      expect(config, 'features:\n  # ads: false\n');
    });
  });

  group('applyAppConfigFeature via temp file round-trip', () {
    late Directory tempDir;
    late File configFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('feature_cli_test_');
      configFile = File('${tempDir.path}/app_config.yaml');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('enabling ads on a temp config yields uncommented ads: true',
        () async {
      await configFile.writeAsString('''
profile: "standard"

features:
  # ads: false

services:
  firebase:
    enabled: true
''');

      final content = await configFile.readAsString();
      final updated = applyAppConfigFeature(content, 'ads', true);
      await configFile.writeAsString(updated);

      final result = await configFile.readAsString();
      expect(result, contains('  ads: true'));
      expect(result, isNot(contains('# ads')));
    });

    test('disabling ads yields ads: false', () async {
      await configFile.writeAsString('features:\n  # ads: false\n');

      final content = await configFile.readAsString();
      await configFile.writeAsString(
        applyAppConfigFeature(content, 'ads', false),
      );

      expect(await configFile.readAsString(), contains('  ads: false'));
    });

    test('a key absent from the block gets inserted', () async {
      await configFile.writeAsString('features:\n  # ads: false\n');

      final content = await configFile.readAsString();
      await configFile.writeAsString(
        applyAppConfigFeature(content, 'location', true),
      );

      expect(await configFile.readAsString(), contains('  location: true'));
    });
  });
}
