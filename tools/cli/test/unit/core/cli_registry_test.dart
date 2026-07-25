import 'package:boilerplate_cli/core/cli_registry.dart';
import 'package:test/test.dart';

/// P1-10 디스패치 계약: ./run(bp.dart)이 노출하는 커맨드 집합을 고정한다.
/// 구 셸 ./run의 case 분기와 동일해야 하며, 커맨드 추가/삭제 시
/// usage 문서와 레지스트리가 함께 움직이는지 잡아낸다.
void main() {
  group('cli_registry (P1-10)', () {
    test('레지스트리 커맨드 집합 = 구 ./run case 분기 (feature 제외)', () {
      expect(
        commandRunners.keys.toSet(),
        {
          'init',
          'build',
          'gen-env',
          'deploy',
          'deploy-legal', // P1-15.5b: 법적 문서 Firebase Hosting 배포
          'test',
          'preflight',
          'rename',
          'setup',
          'screenshot',
          'generate-icon',
          'generate-legal',
          'generate-privacy', // P1-13d: Apple Privacy Manifest 생성
          'generate-deeplink', // P2-23a: 딥링크 네이티브 선언 생성
          'generate-data-safety', // P1-13f: Data Safety 답안지 생성
          'generate-desc',
          'iap-register',
        },
      );
    });

    test('fastlane 필요 커맨드는 전부 레지스트리에 존재', () {
      expect(
        fastlaneRequiringCommands.difference(commandRunners.keys.toSet()),
        isEmpty,
      );
    });

    test('usage 문서가 모든 레지스트리 커맨드 + feature를 언급', () {
      for (final name in commandRunners.keys) {
        expect(cliUsage, contains(name), reason: 'usage에 $name 누락');
      }
      expect(cliUsage, contains('feature'));
    });
  });
}
