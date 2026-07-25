import 'dart:async';

import 'package:boilerplate/core/services/authentication_service.dart';
import 'package:boilerplate/core/services/pin_service.dart';
import 'package:boilerplate/core/services/snackbar_service.dart';
import 'package:boilerplate/core/state/auth_state.dart';
import 'package:boilerplate/core/state/settings.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:boilerplate/core/widgets/inputs/pin_entry.dart';
import 'package:boilerplate/core/widgets/navigation/adaptive_app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 잠금 해제 화면 (P2-23h ④: PIN 기반 + 생체 가속).
///
/// 잠금 방식([UserAuthOption])에 따라:
/// - `pin`: PIN 입력만.
/// - `biometric`: PIN + 생체(가속). 진입 시 생체를 자동 프롬프트하고, PIN을
///   항상 폴백으로 보여준다(생체 실패/취소 시 PIN으로 해제). 생체는 PIN
///   시도 제한과 무관하므로 잠금 중에도 시도할 수 있다.
///   (PIN이 아직 설정되지 않은 레거시 생체 설정은 생체 전용으로 폴백한다.)
/// - `none`: 자동 통과.
class AuthenticationView extends ConsumerStatefulWidget {
  const AuthenticationView({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AuthenticationViewState();
}

class _AuthenticationViewState extends ConsumerState<AuthenticationView> {
  final _pinEntryController = PinEntryController();

  bool _bioAttempted = false;
  bool _pinAvailable = false;

  // ① 오입력 피드백 / 시도 제한 상태
  String? _pinError;
  bool _pinLocked = false;
  bool _isVerifying = false;
  Duration _lockRemaining = Duration.zero;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  /// PIN 설정 여부 + 잔여 잠금을 진입 시 1회 해소한다.
  Future<void> _init() async {
    final svc = ref.read(pinServiceProvider);
    final hasPin = await svc.hasPin();
    final lock = await svc.lockRemaining();
    if (!mounted) return;
    setState(() => _pinAvailable = hasPin);
    if (lock != null) _startLockCountdown(lock);
  }

  void _navigateHome() {
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// 진입 시 생체를 1회 자동 프롬프트한다.
  void _autoPromptBiometric() {
    if (_bioAttempted) return;
    _bioAttempted = true;
    _triggerBiometric();
  }

  Future<void> _triggerBiometric() async {
    try {
      final ok = await AuthenticationService().authenticateWithBiometrics();
      if (!mounted) return;
      if (ok) {
        ref.read(authStateProvider.notifier).setAuthState(AuthState.authenticated(method: AuthMethod.biometric));
        _navigateHome();
      } else {
        ref.read(snackBarServiceProvider).showError('auth.biometricFailed');
      }
    } catch (e) {
      if (!mounted) return;
      ref.read(snackBarServiceProvider).showError('auth.biometricFailed');
    }
  }

  /// PIN 입력 완료 시 검증 → 결과별 피드백.
  Future<void> _onPinCompleted(String pin) async {
    if (_pinLocked || _isVerifying) return;
    _isVerifying = true;
    final result = await ref.read(pinServiceProvider).verifyPin(pin);
    if (!mounted) return;
    _isVerifying = false;
    switch (result.outcome) {
      case PinVerifyOutcome.success:
        ref.read(authStateProvider.notifier).setAuthState(AuthState.authenticated(method: AuthMethod.pin));
        _navigateHome();
      case PinVerifyOutcome.wrong:
        setState(() {
          _pinError = result.attemptsRemaining <= 2
              ? 'auth.pin.attemptsLeft'.tr(args: ['${result.attemptsRemaining}'])
              : 'auth.pin.incorrect'.tr();
        });
        _pinEntryController.shake();
      case PinVerifyOutcome.lockedOut:
        _pinEntryController.clear();
        _startLockCountdown(result.lockRemaining ?? Duration.zero);
      case PinVerifyOutcome.noPin:
        // PIN 미설정 — 설정 플로우는 settings에서. 잠금화면에선 무동작.
        break;
    }
  }

  /// 잠금 카운트다운 — 1초마다 갱신, 만료 시 해제.
  void _startLockCountdown(Duration initial) {
    _lockTimer?.cancel();
    setState(() {
      _pinLocked = true;
      _lockRemaining = initial;
      _pinError = 'auth.pin.lockedFor'.tr(args: [_formatRemaining(initial)]);
    });
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _lockRemaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() {
          _pinLocked = false;
          _lockRemaining = Duration.zero;
          _pinError = null;
        });
      } else {
        setState(() {
          _lockRemaining = next;
          _pinError = 'auth.pin.lockedFor'.tr(args: [_formatRemaining(next)]);
        });
      }
    });
  }

  String _formatRemaining(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final option = ref.watch(settingsProvider).userAuthOption;

    // 진입 시 자동 동작: 생체 프롬프트(biometric) 또는 자동 통과(none).
    if (option == UserAuthOption.biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPromptBiometric());
    } else if (option == UserAuthOption.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateHome());
    }

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: SText('authentication'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Center(child: _buildAuthBody(option)),
      ),
    );
  }

  Widget _buildAuthBody(UserAuthOption option) {
    final showBiometric = option == UserAuthOption.biometric;
    // PIN 폴백: pin 모드이거나, 생체 모드인데 PIN이 설정돼 있으면.
    final showPin = option == UserAuthOption.pin || (showBiometric && _pinAvailable);

    // 레거시: PIN 없는 생체 설정 → 생체 전용 화면.
    if (showBiometric && !showPin) {
      return IconButton(
        icon: const Icon(Icons.face_unlock_outlined),
        onPressed: _triggerBiometric,
        iconSize: 96,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPin)
          PinEntry(
            controller: _pinEntryController,
            enabled: !_pinLocked,
            errorText: _pinError,
            onCompleted: _onPinCompleted,
          ),
        if (showBiometric) ...[
          const SizedBox(height: 16),
          // 생체는 PIN 시도 제한과 무관 — 잠금 중에도 시도 가능.
          TextButton.icon(
            onPressed: _triggerBiometric,
            icon: const Icon(Icons.fingerprint),
            label: SText('auth.pin.useBiometric'),
          ),
        ],
        if (showPin) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/pin-recovery'),
            child: SText('auth.pin.forgotPin'),
          ),
        ],
      ],
    );
  }
}
