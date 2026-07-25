// legal 생성기 테스트 (P1-15.5) — index.html 포함 3파일 저장 + 템플릿 내용

import 'dart:io';

import 'package:boilerplate_cli/commands/legal/legal_generator.dart'
    as generator;
import 'package:boilerplate_cli/commands/legal/legal_templates.dart'
    as templates;
import 'package:test/test.dart';

void main() {
  group('generateLegalIndex', () {
    test('앱 이름과 문서 링크 2개를 포함한다', () {
      final html = templates.generateLegalIndex(appName: 'Smoke App');
      expect(html, contains('Smoke App — Legal'));
      expect(html, contains('href="privacy_policy.html"'));
      expect(html, contains('href="terms_of_service.html"'));
    });
  });

  group('saveFiles', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('legal_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('privacy/terms/index 3파일을 출력 디렉토리에 저장한다', () async {
      final saved = await generator.saveFiles(
        projectRoot: tempDir.path,
        outputDir: 'docs/legal',
        privacyPolicyHtml: '<html>privacy</html>',
        termsOfServiceHtml: '<html>terms</html>',
        legalIndexHtml: '<html>index</html>',
        isVerbose: false,
      );

      expect(saved, hasLength(3));
      expect(
        File('${tempDir.path}/docs/legal/privacy_policy.html')
            .readAsStringSync(),
        '<html>privacy</html>',
      );
      expect(
        File('${tempDir.path}/docs/legal/terms_of_service.html')
            .readAsStringSync(),
        '<html>terms</html>',
      );
      expect(
        File('${tempDir.path}/docs/legal/index.html').readAsStringSync(),
        '<html>index</html>',
      );
    });
  });
}
