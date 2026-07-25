import 'package:boilerplate/core/services/pin_service.dart';
import 'package:boilerplate/core/services/snackbar_service.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:boilerplate/core/widgets/inputs/pin_entry.dart';
import 'package:boilerplate/core/widgets/navigation/adaptive_app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// PIN 설정/변경 단계.
enum _PinStep { verifyCurrent, enterNew, confirmNew }

/// PIN 설정/변경 플로우 (P2-23h ②).
///
/// 진입 시 [PinService.hasPin]으로 모드를 판별한다:
/// - PIN 없음(설정): 새 PIN 입력 → 확인 입력 → 저장.
/// - PIN 있음(변경): 현재 PIN 확인(잠금 정책 적용) → 새 PIN → 확인 → 저장.
///
/// 성공 시 `Navigator.pop(true)`로 결과를 돌려준다(설정 화면이 잠금 방식을
/// pin으로 전환할지 판단).
class PinSetupView extends ConsumerStatefulWidget {
  const PinSetupView({super.key});

  @override
  ConsumerState<PinSetupView> createState() => _PinSetupViewState();
}

class _PinSetupViewState extends ConsumerState<PinSetupView> {
  final _entryController = PinEntryController();

  _PinStep? _step; // null = hasPin 조회 중
  bool _isChange = false;
  bool _busy = false;
  String? _newPin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final hasPin = await ref.read(pinServiceProvider).hasPin();
    if (!mounted) return;
    setState(() {
      _isChange = hasPin;
      _step = hasPin ? _PinStep.verifyCurrent : _PinStep.enterNew;
    });
  }

  Future<void> _onCompleted(String pin) async {
    if (_busy) return;
    switch (_step!) {
      case _PinStep.verifyCurrent:
        _busy = true;
        final result = await ref.read(pinServiceProvider).verifyPin(pin);
        if (!mounted) return;
        _busy = false;
        switch (result.outcome) {
          case PinVerifyOutcome.success:
            _goTo(_PinStep.enterNew);
          case PinVerifyOutcome.wrong:
            _fail(result.attemptsRemaining <= 2
                ? 'auth.pin.attemptsLeft'.tr(args: ['${result.attemptsRemaining}'])
                : 'auth.pin.incorrect'.tr());
          case PinVerifyOutcome.lockedOut:
            _fail('auth.pin.lockedFor'
                .tr(args: [_formatRemaining(result.lockRemaining ?? Duration.zero)]));
          case PinVerifyOutcome.noPin:
            _goTo(_PinStep.enterNew); // 경합으로 PIN이 사라진 경우 설정으로 폴백
        }

      case _PinStep.enterNew:
        _newPin = pin;
        _goTo(_PinStep.confirmNew);

      case _PinStep.confirmNew:
        if (pin == _newPin) {
          _busy = true;
          await ref.read(pinServiceProvider).setPin(pin);
          if (!mounted) return;
          _busy = false;
          ref.read(snackBarServiceProvider).showSuccess(
                _isChange ? 'auth.pin.changeSuccess' : 'auth.pin.setSuccess',
              );
          if (context.canPop()) context.pop(true);
        } else {
          _newPin = null;
          _goTo(_PinStep.enterNew);
          _fail('auth.pin.mismatch'.tr());
        }
    }
  }

  void _goTo(_PinStep step) {
    setState(() {
      _step = step;
      _error = null;
    });
    _entryController.clear();
  }

  void _fail(String message) {
    setState(() => _error = message);
    _entryController.shake();
  }

  String _formatRemaining(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get _instructionKey {
    switch (_step!) {
      case _PinStep.verifyCurrent:
        return 'auth.pin.enterCurrent';
      case _PinStep.enterNew:
        return 'auth.pin.enterNew';
      case _PinStep.confirmNew:
        return 'auth.pin.confirmNew';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: SText(_isChange ? 'auth.pin.changeTitle' : 'auth.pin.setupTitle'),
      ),
      body: SafeArea(
        child: Center(
          child: _step == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Text(
                        _instructionKey.tr(),
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    PinEntry(
                      controller: _entryController,
                      onCompleted: _onCompleted,
                      errorText: _error,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
