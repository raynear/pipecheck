// 공용 Android keystore 검증 로직 테스트 (파일 존재 + .env 비밀번호).

import 'package:boilerplate_cli/commands/init/steps/setup_signing_step.dart';
import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:test/test.dart';

void main() {
  group('classifyKeystore', () {
    test('경로 미설정이면 skipped', () {
      final r = classifyKeystore(
        keystorePath: '',
        exists: false,
        hasStorePassword: false,
        hasKeyPassword: false,
      );
      expect(r.status, StepStatus.skipped);
    });

    test('파일 없으면 skipped + keytool 가이드', () {
      final r = classifyKeystore(
        keystorePath: '~/key.jks',
        exists: false,
        hasStorePassword: true,
        hasKeyPassword: true,
      );
      expect(r.status, StepStatus.skipped);
      expect(r.reason, contains('keytool'));
    });

    test('파일 있으나 비밀번호 미설정이면 skipped', () {
      final r = classifyKeystore(
        keystorePath: '~/key.jks',
        exists: true,
        hasStorePassword: false,
        hasKeyPassword: true,
      );
      expect(r.status, StepStatus.skipped);
      expect(r.reason, contains('.env'));
    });

    test('파일 있으나 KEY_PASSWORD만 없어도 skipped', () {
      final r = classifyKeystore(
        keystorePath: '~/key.jks',
        exists: true,
        hasStorePassword: true,
        hasKeyPassword: false,
      );
      expect(r.status, StepStatus.skipped);
      expect(r.reason, contains('.env'));
    });

    test('파일 존재 + 비밀번호 설정이면 done + 경로 표기', () {
      final r = classifyKeystore(
        keystorePath: '~/key.jks',
        exists: true,
        hasStorePassword: true,
        hasKeyPassword: true,
      );
      expect(r.status, StepStatus.done);
      expect(r.reason, contains('~/key.jks'));
    });
  });
}
