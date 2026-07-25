import 'dart:async';

import 'package:boilerplate/core/services/pin_service.dart' show kPinLength;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// [PinEntry]를 부모가 제어하는 컨트롤러 (shake/clear).
///
/// 부모는 검증 결과에 따라 [shake](오입력 흔들림 + 햅틱 + 필드 비움)나
/// [clear](필드만 비움)를 호출한다. TextEditingController와 같은 수명 패턴 —
/// 부모가 생성/보관하고 위젯에 주입한다.
class PinEntryController {
  VoidCallback? _shake;
  VoidCallback? _clear;

  void shake() => _shake?.call();
  void clear() => _clear?.call();

  void _bind({required VoidCallback shake, required VoidCallback clear}) {
    _shake = shake;
    _clear = clear;
  }

  void _unbind() {
    _shake = null;
    _clear = null;
  }
}

/// 재사용 PIN 입력 위젯 (P2-23h).
///
/// 표시 전용 — 검증/잠금/확인 로직은 부모가 소유한다. [length]자리 입력이
/// 완료되면 [onCompleted]를 호출하고, 부모는 [PinEntryController.shake]로
/// 오입력 피드백을, [errorText]로 메시지를, [enabled]로 잠금 중 비활성화를
/// 제어한다. 잠금 해제 화면(verify)과 설정/변경 플로우에서 함께 쓴다.
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.autoFocus = true,
    this.length = kPinLength,
  });

  final PinEntryController controller;
  final void Function(String pin) onCompleted;
  final void Function(String pin)? onChanged;
  final String? errorText;
  final bool enabled;
  final bool autoFocus;
  final int length;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> {
  final _textController = TextEditingController();
  final _errorController = StreamController<ErrorAnimationType>.broadcast();

  @override
  void initState() {
    super.initState();
    widget.controller._bind(shake: _shake, clear: _clear);
  }

  @override
  void didUpdateWidget(PinEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._unbind();
      widget.controller._bind(shake: _shake, clear: _clear);
    }
  }

  @override
  void dispose() {
    widget.controller._unbind();
    // _textController는 PinCodeTextField가 소유권을 가져가 자체 dispose하므로
    // 여기서 dispose하지 않는다(이중 dispose 방지).
    _errorController.close();
    super.dispose();
  }

  void _shake() {
    if (!mounted) return;
    _errorController.add(ErrorAnimationType.shake);
    HapticFeedback.heavyImpact();
    _clear();
  }

  void _clear() => _textController.clear();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: PinCodeTextField(
            autoFocus: widget.autoFocus,
            appContext: context,
            enabled: widget.enabled,
            length: widget.length,
            obscureText: true,
            obscuringCharacter: '*',
            blinkWhenObscuring: true,
            animationType: AnimationType.fade,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(5),
              fieldHeight: 50,
              fieldWidth: 40,
              activeColor: scheme.primary,
              selectedColor: scheme.primary,
              selectedFillColor: scheme.surface,
              inactiveColor: scheme.outline,
              inactiveFillColor: scheme.surface,
              activeFillColor: scheme.surface,
              errorBorderColor: scheme.error,
            ),
            cursorColor: scheme.onSurface,
            animationDuration: const Duration(milliseconds: 300),
            enableActiveFill: true,
            errorAnimationController: _errorController,
            controller: _textController,
            keyboardType: TextInputType.number,
            boxShadows: const [
              BoxShadow(offset: Offset(0, 1), color: Colors.black12, blurRadius: 10),
            ],
            onCompleted: widget.onCompleted,
            onChanged: (value) => widget.onChanged?.call(value),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.errorText!,
              style: TextStyle(color: scheme.error),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
