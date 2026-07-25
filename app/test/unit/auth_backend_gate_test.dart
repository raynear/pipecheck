// 서버 인증 백엔드 게이트 테스트 (P1-16.5b)
//
// 13b deno 핸들러 테스트의 동등 대체 — 백엔드가 Firebase Auth(클라이언트
// 직접)로 전환되면서 서버 핸들러가 사라졌으므로, 클라이언트 게이트가
// Firebase 호출 전에 안전하게 실패를 반환하는지 고정한다.
//
// 테스트 환경에는 Firebase.initializeApp이 없으므로 _firebaseAuthReady가
// false — 게이트가 뚫리면 FirebaseAuth.instance 접근에서 예외가 나며
// 테스트가 실패한다 (게이트 검증과 누출 검증을 겸함).

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/state/auth_state.dart';
import 'package:boilerplate/features/auth/view_models/auth_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthViewModel — Firebase 미초기화/플래그 OFF 시 실패 반환 (크래시 금지)', () {
    test('signInWithEmail은 게이트에서 실패를 반환한다', () async {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      final vm = container.read(authViewModelProvider.notifier);

      final result = await vm.signInWithEmail(
        email: 'a@b.com',
        password: 'password',
      );

      expect(result.isSuccess, false);
      expect(result.message, isNotNull);
    });

    test('signUpWithEmail은 게이트에서 실패를 반환한다', () async {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      final vm = container.read(authViewModelProvider.notifier);

      final result = await vm.signUpWithEmail(
        email: 'a@b.com',
        password: 'password',
      );

      expect(result.isSuccess, false);
    });

    test('sendPasswordResetEmail도 같은 게이트를 쓴다 (게이트 비대칭 풋건 방지)',
        () async {
      // 과거 supabase 구현은 password reset만 다른 플래그를 보는 비대칭이
      // 있었다 — 세 경로 모두 단일 게이트(_emailAuthReady)를 공유해야 한다.
      AppFeatureConfig.applyBootConfig(
        profileName: 'standard',
        overrides: {'isEmailAuthEnabled': true},
      );
      final vm = container.read(authViewModelProvider.notifier);

      // 플래그가 켜져 있어도 Firebase 미초기화면 실패 (예외 없이)
      final result = await vm.sendPasswordResetEmail(email: 'a@b.com');
      expect(result.isSuccess, false);
    });
  });

  group('AuthStateNotifier.deleteAccount — 클라이언트 직접 삭제 게이트', () {
    test('플래그 OFF면 false', () async {
      AppFeatureConfig.applyBootConfig(
        profileName: 'standard',
        overrides: {'isAccountDeletionEnabled': false},
      );
      final notifier = container.read(authStateProvider.notifier);

      expect(await notifier.deleteAccount(), false);
    });

    test('플래그 ON이어도 Firebase 미초기화면 false (예외 없이)', () async {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      expect(AppFeatureConfig.isAccountDeletionEnabled, true);
      final notifier = container.read(authStateProvider.notifier);

      expect(await notifier.deleteAccount(), false);
    });
  });
}
