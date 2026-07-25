// 법적 문서 호스팅 URL 도출 테스트.
//
// 호스팅 방식(listing.legal_hosting): firebase(<projectId>.web.app) | github
// (<owner>.github.io/<repo>, A1). project_id SSOT는 google-services.json.

import 'dart:io';

import 'package:boilerplate_cli/core/env_artifacts.dart';
import 'package:test/test.dart';

void main() {
  test('projectId → Firebase Hosting URL', () {
    expect(
      deriveLegalHostingUrl('myapp-2024', 'privacy_policy.html'),
      'https://myapp-2024.web.app/privacy_policy.html',
    );
    expect(
      deriveLegalHostingUrl('myapp-2024', 'terms_of_service.html'),
      'https://myapp-2024.web.app/terms_of_service.html',
    );
  });

  test('projectId 비면 빈 문자열 (앱이 버튼 숨김)', () {
    expect(deriveLegalHostingUrl('', 'privacy_policy.html'), '');
  });

  group('deriveGithubPagesUrl (A1)', () {
    test('owner/repo → github.io 프로젝트 사이트 URL', () {
      expect(
        deriveGithubPagesUrl('acme/myapp', 'privacy_policy.html'),
        'https://acme.github.io/myapp/privacy_policy.html',
      );
    });

    test('미편집 placeholder/형식오류는 빈 문자열', () {
      expect(deriveGithubPagesUrl('', 'privacy_policy.html'), '');
      expect(deriveGithubPagesUrl('your-org/myapp', 'privacy_policy.html'), '');
      expect(deriveGithubPagesUrl('owner/repo', 'privacy_policy.html'), '');
      expect(deriveGithubPagesUrl('noSlash', 'privacy_policy.html'), '');
    });
  });

  group('readFirebaseProjectId — google-services.json SSOT', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('firebase_id_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('project_info.project_id를 읽는다', () {
      final file = File(
          '${tempDir.path}/app/android/app/google-services.json')
        ..createSync(recursive: true);
      file.writeAsStringSync(
          '{"project_info": {"project_id": "smoke-2024"}}');

      expect(readFirebaseProjectId(tempDir.path), 'smoke-2024');
    });

    test('파일 부재/파싱 실패는 빈 문자열 (도출 URL도 빈 값 → 버튼 숨김)', () {
      expect(readFirebaseProjectId(tempDir.path), '');

      final file = File(
          '${tempDir.path}/app/android/app/google-services.json')
        ..createSync(recursive: true);
      file.writeAsStringSync('not json');
      expect(readFirebaseProjectId(tempDir.path), '');
    });
  });
}
