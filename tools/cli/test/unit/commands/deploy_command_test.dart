import 'package:args/args.dart';
import 'package:boilerplate_cli/commands/deploy_command.dart';
import 'package:test/test.dart';

/// P0-7 deploy 계약: CLI가 fastlane으로 직렬화하는 인자의 허용값/기본값을
/// 고정한다. fastlane 쪽(push/build_and_upload_* 레인)의 검증과 거울상 —
/// 한쪽이 바뀌면 이 테스트가 깨져 계약 발산을 막는다.
void main() {
  group('DeployCommand 인자 계약 (P0-7)', () {
    late ArgParser parser;

    setUp(() {
      parser = DeployCommand(projectRoot: '/tmp/unused').buildArgParser();
    });

    test('target: beta|production만 허용, 기본 beta', () {
      expect(parser.parse([])['target'], 'beta');
      expect(parser.parse(['--target', 'production'])['target'], 'production');
      expect(parser.parse(['--target', 'beta'])['target'], 'beta');
      // fastlane push 레인의 %w[beta production] 검증과 동일 집합
      expect(
        () => parser.parse(['--target', 'internal']),
        throwsA(isA<FormatException>()),
      );
    });

    test('platform: ios|android|all만 허용, 기본 all', () {
      expect(parser.parse([])['platform'], 'all');
      expect(parser.parse(['--platform', 'ios'])['platform'], 'ios');
      expect(parser.parse(['--platform', 'android'])['platform'], 'android');
      // fastlane push 레인의 %w[ios android all] 검증과 동일 집합
      expect(
        () => parser.parse(['--platform', 'web']),
        throwsA(isA<FormatException>()),
      );
    });

    test('bump: patch|minor|major|build만 허용, 기본 patch', () {
      expect(parser.parse([])['bump'], 'patch');
      expect(parser.parse(['--bump', 'major'])['bump'], 'major');
      expect(
        () => parser.parse(['--bump', 'rc']),
        throwsA(isA<FormatException>()),
      );
    });

    test('스크린샷은 기본 skip (production 체크리스트에서 명시적으로 켬)', () {
      expect(parser.parse([])['skip-screenshots'], isTrue);
      expect(
        parser.parse(['--no-skip-screenshots'])['skip-screenshots'],
        isFalse,
      );
    });

    test('iOS 심사 제출은 opt-in 기본 false (P1-17c)', () {
      // 첫 제출은 ASC 필수 항목(스크린샷/연령등급 등) 미비로 실패할 수
      // 있어 opt-in. fastlane submit_ios_review 레인과 짝.
      expect(parser.parse([])['submit-review'], isFalse);
      expect(parser.parse(['--submit-review'])['submit-review'], isTrue);
    });
  });
}
