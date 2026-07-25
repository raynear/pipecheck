import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/authentication_service.dart';
import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:pipecheck/core/widgets/navigation/adaptive_app_bar.dart';
import 'package:pipecheck/data/core/repositories/repository_providers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// PIN 분실 복구 (P2-23h ③: 계층 폴백).
///
/// 서버 0줄 제약(backend-direction)에서 PIN은 로컬 앱 접근만 보호한다.
/// 가용한 대체 인증 수단을 적응형으로 제시한다:
/// 1. 생체 인증(기기에 등록돼 있으면) → 본인 확인 후 잠금 해제 + PIN 제거.
/// 2. 이메일 재인증(이메일 인증이 켜진 포크) → Firebase 로그인으로 본인 확인.
/// 3. 앱 데이터 초기화(항상) → 보호 데이터를 폐기하고 잠금 제거. PIN을 모르는
///    사람이 잠금을 우회해 데이터를 보는 것을 막기 위해 데이터를 함께 지운다.
///
/// 복구가 끝나면 잠금 방식을 none으로 돌려 사용자가 진입할 수 있게 하고,
/// 새 PIN은 설정 화면에서 다시 만들 수 있다.
class PinRecoveryView extends ConsumerStatefulWidget {
  const PinRecoveryView({super.key});

  @override
  ConsumerState<PinRecoveryView> createState() => _PinRecoveryViewState();
}

class _PinRecoveryViewState extends ConsumerState<PinRecoveryView> {
  bool? _biometricAvailable; // null = 조회 중
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _resolveBiometric();
  }

  Future<void> _resolveBiometric() async {
    final ok = await AuthenticationService().canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = ok);
  }

  bool get _emailReady =>
      AppFeatureConfig.isEmailAuthEnabled &&
      AppFeatureConfig.isFirebaseEnabled &&
      const FirebaseEmailAuthService().isFirebaseReady;

  /// 복구 완료 — 잠금을 제거하고 홈으로 이동한다.
  ///
  /// 데이터 wipe → PIN 제거 → 잠금 해제 순서. 어느 단계든 실패하면 잠금을
  /// 풀지 않고(fail-closed) 에러를 알린다(데이터 wipe는 트랜잭션이라 원자적 —
  /// 부분 삭제로 일관성이 깨지지 않는다).
  Future<void> _finishRecovery({required AuthMethod method, bool wipeData = false}) async {
    try {
      if (wipeData) {
        await ref.read(databaseProvider).clearAll();
      }
      await ref.read(pinServiceProvider).clearPin();
      await ref.read(settingsProvider.notifier).updateSingleSetting(userAuthOption: UserAuthOption.none);
    } catch (e) {
      if (!mounted) return;
      ref.read(snackBarServiceProvider).showError('auth.pin.recoveryFailed');
      return;
    }
    ref.read(authStateProvider.notifier).setAuthState(AuthState.authenticated(method: method));
    if (!mounted) return;
    ref.read(snackBarServiceProvider).showSuccess('auth.pin.recoverySuccess');
    context.go('/home');
  }

  Future<void> _recoverWithBiometric() async {
    if (_busy) return;
    _busy = true;
    final ok = await AuthenticationService().authenticateWithBiometrics();
    _busy = false;
    if (!mounted) return;
    if (ok) {
      await _finishRecovery(method: AuthMethod.biometric);
    } else {
      ref.read(snackBarServiceProvider).showError('auth.biometricFailed');
    }
  }

  Future<void> _recoverWithEmail() async {
    if (_busy) return;
    final creds = await showDialog<({String email, String password})>(
      context: context,
      builder: (_) => const _EmailReauthDialog(),
    );
    if (creds == null || !mounted) return;
    _busy = true;
    try {
      await const FirebaseEmailAuthService().signIn(email: creds.email, password: creds.password);
      if (!mounted) return;
      await _finishRecovery(method: AuthMethod.email);
    } on AuthException {
      if (!mounted) return;
      ref.read(snackBarServiceProvider).showError('auth.errorInvalidCredentials');
    } finally {
      _busy = false;
    }
  }

  Future<void> _recoverWithReset() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: SText('auth.pin.recoverReset'),
        content: SText('auth.pin.resetWarning'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: SText('common.cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: SText('common.confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _busy = true;
    await _finishRecovery(method: AuthMethod.none, wipeData: true);
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AdaptiveAppBar(title: SText('auth.pin.recoveryTitle')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SText('auth.pin.recoveryIntro', style: textTheme.bodyLarge),
            const SizedBox(height: 24),
            if (_biometricAvailable == true)
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: SText('auth.pin.recoverBiometric'),
                onTap: _recoverWithBiometric,
              ),
            if (_emailReady)
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: SText('auth.pin.recoverEmail'),
                onTap: _recoverWithEmail,
              ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
              title: SText('auth.pin.recoverReset', style: TextStyle(color: colorScheme.error)),
              onTap: _recoverWithReset,
            ),
          ],
        ),
      ),
    );
  }
}

/// 이메일 재인증 다이얼로그 — 이메일/비밀번호를 받아 records로 돌려준다.
class _EmailReauthDialog extends StatefulWidget {
  const _EmailReauthDialog();

  @override
  State<_EmailReauthDialog> createState() => _EmailReauthDialogState();
}

class _EmailReauthDialogState extends State<_EmailReauthDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: SText('auth.pin.recoverEmail'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: 'login.emailLabel'.tr()),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: 'login.passwordLabel'.tr()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: SText('common.cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            (email: _email.text.trim(), password: _password.text),
          ),
          child: SText('common.confirm'),
        ),
      ],
    );
  }
}
