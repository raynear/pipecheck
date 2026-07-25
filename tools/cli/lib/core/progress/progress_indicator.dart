import 'dart:async';
import 'dart:io';

/// CLI 진행률 표시기.
///
/// 장시간 실행되는 작업의 진행 상황을 실시간으로 표시합니다.
/// 스피너, 진행률 바, 단계별 상태 표시를 지원합니다.
class ProgressIndicator {
  /// 생성자.
  ProgressIndicator({
    required this.message,
    this.total = 0,
    this.output,
  });

  /// 진행 중 표시할 메시지.
  final String message;

  /// 전체 작업 수 (0이면 스피너만 표시).
  final int total;

  /// 출력 대상 (테스트용 의존성 주입).
  final StringSink? output;

  /// 현재 진행 상태.
  int _current = 0;

  /// 스피너 타이머.
  Timer? _spinnerTimer;

  /// 스피너 프레임 인덱스.
  int _spinnerFrame = 0;

  /// 스피너 애니메이션 프레임.
  static const List<String> _spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  /// 실행 중 여부.
  bool _isRunning = false;

  /// 진행 표시기 시작.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _current = 0;

    _printStatus('$message...');

    if (total == 0) {
      _startSpinner();
    }
  }

  /// 진행 상황 업데이트 (총량 지정 시).
  void update(int current) {
    if (!_isRunning) return;
    _current = current;
    _printProgress();
  }

  /// 진행 상황 틱 (메시지 변경 가능).
  void tick([String? newMessage]) {
    if (!_isRunning) return;
    _current++;

    if (total > 0) {
      _printProgress(newMessage);
    } else {
      _printStatus('${newMessage ?? message}...');
    }
  }

  /// 작업 성공 완료.
  void complete([String? completionMessage]) {
    _stop();
    final msg = completionMessage ?? message;
    _writeLine('\r\x1B[K✅ $msg 완료');
  }

  /// 작업 실패.
  void fail(String error) {
    _stop();
    _writeLine('\r\x1B[K❌ $message 실패: $error');
  }

  /// 스피너 시작.
  void _startSpinner() {
    _spinnerTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _spinnerFrame = (_spinnerFrame + 1) % _spinnerFrames.length;
      _write('\r${_spinnerFrames[_spinnerFrame]} $message...');
    });
  }

  /// 진행 중지.
  void _stop() {
    _isRunning = false;
    _spinnerTimer?.cancel();
    _spinnerTimer = null;
  }

  /// 진행률 바 출력.
  void _printProgress([String? newMessage]) {
    final percentage = ((_current / total) * 100).toInt();
    final barWidth = 20;
    final filled = ((_current / total) * barWidth).toInt();
    final empty = barWidth - filled;
    final bar = '[${'█' * filled}${'░' * empty}]';

    final msg = newMessage ?? message;
    _write('\r\x1B[K$bar $percentage% $_current/$total $msg');
  }

  /// 상태 메시지 출력.
  void _printStatus(String status) {
    _write('\r\x1B[K$status');
  }

  /// 출력 (줄바꿈 없음).
  void _write(String text) {
    if (output != null) {
      output!.write(text);
    } else {
      stdout.write(text);
    }
  }

  /// 출력 (줄바꿈 포함).
  void _writeLine(String text) {
    if (output != null) {
      output!.writeln(text);
    } else {
      stdout.writeln(text);
    }
  }
}

/// 단계별 진행 상태 표시기.
///
/// 여러 단계로 구성된 작업의 진행 상황을 표시합니다.
class StepProgress {
  /// 생성자.
  StepProgress({
    required this.steps,
    this.output,
  });

  /// 단계 목록.
  final List<String> steps;

  /// 출력 대상.
  final StringSink? output;

  /// 현재 단계 인덱스.
  int _currentStep = -1;

  /// 현재 단계 이름 (범위 밖이면 빈 문자열).
  String get currentStepName =>
      (_currentStep >= 0 && _currentStep < steps.length)
          ? steps[_currentStep]
          : '';

  /// 다음 단계 시작.
  void nextStep([String? customMessage]) {
    _currentStep++;
    if (_currentStep >= steps.length) return;

    final stepNum = _currentStep + 1;
    final totalSteps = steps.length;
    final msg = customMessage ?? steps[_currentStep];

    _writeLine('[$stepNum/$totalSteps] $msg...');
  }

  /// 현재 단계 완료.
  void completeStep() {
    if (_currentStep < 0 || _currentStep >= steps.length) return;

    final stepNum = _currentStep + 1;
    final totalSteps = steps.length;
    _writeLine('  ✅ [$stepNum/$totalSteps] ${steps[_currentStep]} 완료');
  }

  /// 현재 단계 실패.
  void failStep(String error) {
    if (_currentStep < 0 || _currentStep >= steps.length) return;

    final stepNum = _currentStep + 1;
    final totalSteps = steps.length;
    _writeLine('  ❌ [$stepNum/$totalSteps] ${steps[_currentStep]} 실패: $error');
  }

  /// 현재 단계 건너뜀 (크리덴셜/전제조건 미비 — hard-fail 아님).
  void skipStep(String reason) {
    if (_currentStep < 0 || _currentStep >= steps.length) return;

    final stepNum = _currentStep + 1;
    final totalSteps = steps.length;
    _writeLine('  ⊘ [$stepNum/$totalSteps] ${steps[_currentStep]} 건너뜀: $reason');
  }

  /// 모든 단계 완료.
  void complete() {
    _writeLine('\n✅ 모든 단계가 완료되었습니다!');
  }

  /// 출력.
  void _writeLine(String text) {
    if (output != null) {
      output!.writeln(text);
    } else {
      stdout.writeln(text);
    }
  }
}
