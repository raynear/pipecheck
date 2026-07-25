import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart' as flutter_sound;
import 'package:logger/logger.dart' show Level;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_audio_trimmer/simple_audio_trimmer.dart';
import 'package:utils/utils.dart';

class AudioRecorderController extends ChangeNotifier {
  RecorderController recorderController = RecorderController();
  PlayerController playerController = PlayerController();
  flutter_sound.FlutterSoundRecorder? _flutterSoundRecorder;
  bool _isRecording = false;
  bool isPlaying = false;
  String? _recordingPath;
  RangeValues _currentRangeValues = const RangeValues(0, 1);
  int _audioDuration = 0;
  bool _showTrimControls = false;
  bool _disposed = false;
  Timer? _waveformUpdateTimer;

  // 에러 메시지를 표시하기 위한 콜백 함수 추가
  void Function(String)? onError;

  void Function(String?)? onRecordingPathChanged;

  bool get isRecording => _isRecording;

  AudioRecorderController() {
    if (Platform.isIOS) {
      _initFlutterSound();
    }
    _setupPlayerController();
    _loadAudioDuration();
    _initializeRecorderController();
  }

  // RecorderSettings for audio recording configuration (audio_waveforms 2.0.x)
  RecorderSettings get _recorderSettings => const RecorderSettings(
        androidEncoderSettings: AndroidEncoderSettings(
          androidEncoder: AndroidEncoder.aacLc,
        ),
        iosEncoderSettings: IosEncoderSetting(
          iosEncoder: IosEncoder.kAudioFormatMPEG4AAC,
        ),
        sampleRate: 44100,
        bitRate: 128000,
      );

  void _initializeRecorderController() {
    // RecorderController 초기화 - 2.0.x에서는 record() 호출 시 RecorderSettings 전달
  }

  Future<void> _initFlutterSound() async {
    // iOS에서만 FlutterSound 초기화
    if (Platform.isIOS) {
      _flutterSoundRecorder = flutter_sound.FlutterSoundRecorder(logLevel: Level.error);
      await _flutterSoundRecorder?.openRecorder();
    }
  }

  void _setupPlayerController() {
    // PlayerController 설정
    playerController.onPlayerStateChanged.listen((state) {
      if (!_disposed) {
        logger.d('플레이어 상태 변경: $state');
        isPlaying = state == PlayerState.playing;
        notifyListeners();
      }
    });

    playerController.onCompletion.listen((_) async {
      if (!_disposed) {
        logger.d('플레이어 완료 이벤트');
        isPlaying = false;
        notifyListeners();

        // Android에서는 플레이어를 완전히 정지하고 재준비
        if (Platform.isAndroid) {
          try {
            await playerController.stopPlayer();
            await Future.delayed(const Duration(milliseconds: 100));

            if (recordingPath != null && !_disposed) {
              await playerController.preparePlayer(path: recordingPath!);
              await playerController.seekTo(_currentRangeValues.start.toInt());
            }
          } catch (e) {
            logger.e('플레이어 재준비 오류: $e');
          }
        } else {
          // iOS에서는 기존 로직 유지
          await playerController.seekTo(_currentRangeValues.start.toInt());
        }
      }
    });

    // 이벤트 중복 처리 방지를 위한 변수 추가
    bool isHandlingEndEvent = false;

    playerController.onCurrentDurationChanged.listen((duration) async {
      if (!_disposed && duration >= _currentRangeValues.end.toInt() && isPlaying && !isHandlingEndEvent) {
        isHandlingEndEvent = true; // 이벤트 처리 중 플래그 설정

        logger.d('범위 끝 도달, 플레이어 중지');

        // 플레이어 상태 변경
        isPlaying = false;
        notifyListeners();

        // Android에서는 더 안전한 정지 및 리셋
        if (Platform.isAndroid) {
          try {
            await playerController.stopPlayer();
            await Future.delayed(const Duration(milliseconds: 100));

            if (recordingPath != null && !_disposed) {
              await playerController.preparePlayer(path: recordingPath!);
              await playerController.seekTo(_currentRangeValues.start.toInt());
            }
          } catch (e) {
            logger.e('범위 끝 처리 오류: $e');
          }
        } else {
          // iOS에서는 기존 로직 유지
          await playerController.stopPlayer();
          await playerController.seekTo(_currentRangeValues.start.toInt());
        }

        // 플래그 해제
        isHandlingEndEvent = false;
      }
    });

    // 초기 볼륨 설정
    playerController.setVolume(1.0);
  }

  void _loadAudioDuration() async {
    if (recordingPath != null) {
      try {
        final duration = await playerController.getDuration();
        _audioDuration = duration;
        _currentRangeValues = RangeValues(0, _audioDuration.toDouble());
        if (!_disposed) {
          notifyListeners();
        }
      } catch (e) {
        logger.e('오디오 지속 시간 로드 중 오류: $e');
        _audioDuration = 0;
        _currentRangeValues = const RangeValues(0, 1);
        if (!_disposed) {
          notifyListeners();
        }
      }
    }
  }

  void toggleRecording() async {
    if (_isRecording) {
      // 녹음 중지 - 즉시 UI 업데이트
      _isRecording = false;
      _stopWaveformTimer();
      notifyListeners(); // UI 즉시 업데이트

      String? path;
      try {
        if (Platform.isAndroid) {
          // Android: RecorderController만 사용
          path = await recorderController.stop();
          logger.d('Android 녹음 중지 완료: $path');
        } else {
          // iOS: FlutterSound 사용
          // 안전하게 녹음 중지
          if (_flutterSoundRecorder != null) {
            // 상태 확인 후 중지
            if (_flutterSoundRecorder!.isRecording) {
              await _flutterSoundRecorder?.stopRecorder();
            }
            path = _recordingPath;
          }

          // RecorderController도 중지 (iOS에서는 백업용)
          try {
            await recorderController.stop();
          } catch (controllerError) {
            logger.e('RecorderController 중지 오류 무시: $controllerError');
          }
        }
      } catch (e) {
        logger.e('녹음 중지 중 오류: $e');
        onError?.call('녹음을 중지하는 동안 오류가 발생했습니다: $e');

        // 오류 발생해도 나머지 과정은 계속 진행
        path = _recordingPath;
      }

      // 파일 처리는 백그라운드에서 진행
      if (path != null) {
        await _processRecordedFile(path);
      } else {
        logger.e('녹음 파일 경로가 없음');
      }
    } else {
      // 녹음 시작
      try {
        _isRecording = true;
        notifyListeners();

        if (Platform.isAndroid) {
          // Android: RecorderController만 사용
          logger.d('Android 녹음 시작');
          await recorderController.record(recorderSettings: _recorderSettings);

          // RecorderController가 생성할 파일 경로 추적
          _recordingPath = null; // RecorderController가 자동으로 경로 생성
        } else {
          // iOS: FlutterSound 사용
          // 임시 파일 경로 생성
          final tempDir = await getTemporaryDirectory();
          _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

          // RecorderController 시작
          try {
            await recorderController.record(recorderSettings: _recorderSettings);
          } catch (e) {
            _isRecording = false;
            logger.e('RecorderController 시작 오류: $e');
            notifyListeners();
            return;
          }

          // 호환성을 위해 WAV 형식으로 녹음 시작
          await _startRecordingWithFallback();
        }

        // 타이머 시작하여 waveform 업데이트
        _startWaveformTimer();
      } catch (e) {
        logger.e('녹음 시작 중 오류: $e');
        onError?.call('녹음을 시작하는 동안 오류가 발생했습니다: $e');
        _isRecording = false;
        notifyListeners();
      }
    }
  }

  Future<void> _startRecordingWithFallback() async {
    // iOS에서만 사용
    if (Platform.isAndroid) {
      return;
    }

    // 코덱 우선순위: WAV > AAC > MP3
    final codecs = [
      flutter_sound.Codec.pcm16WAV,
      flutter_sound.Codec.aacADTS,
      flutter_sound.Codec.mp3,
    ];

    final fileExtensions = ['.wav', '.m4a', '.mp3'];

    for (int i = 0; i < codecs.length; i++) {
      try {
        // 파일 확장자에 맞게 경로 업데이트
        final tempDir = await getTemporaryDirectory();
        final baseFileName = 'audio_${DateTime.now().millisecondsSinceEpoch}';
        _recordingPath = '${tempDir.path}/$baseFileName${fileExtensions[i]}';

        await _flutterSoundRecorder?.startRecorder(
          toFile: _recordingPath,
          codec: codecs[i],
        );

        logger.d('녹음 시작 성공: ${codecs[i]} 형식');
        return; // 성공하면 반복 중단
      } catch (e) {
        logger.e('${codecs[i]} 코덱 실패: $e');

        // 마지막 코덱까지 실패하면 에러 발생
        if (i == codecs.length - 1) {
          throw Exception('모든 오디오 코덱이 지원되지 않습니다: $e');
        }
      }
    }
  }

  Future<void> _processRecordedFile(String path) async {
    try {
      // 파일 존재 확인
      final file = File(path);
      if (await file.exists() && await file.length() > 0) {
        logger.d('녹음 파일 생성 확인: $path, 크기: ${await file.length()} bytes');

        // Android에서는 RecorderController가 생성한 파일을 바로 사용
        if (Platform.isAndroid) {
          // RecorderController의 경우 바로 PlayerController에 연결
          recordingPath = path;
          await _initializePlayerController(path);
        } else {
          // iOS에서는 기존 로직 유지
          await _initializePlayerController(path);
          recordingPath = path;
        }

        onRecordingPathChanged?.call(path);

        // UI 업데이트는 메인 쓰레드에서
        if (!_disposed) {
          notifyListeners();
        }
      } else {
        logger.e('녹음 파일이 없거나 비어 있음: $path');
        // 이미 _isRecording은 false로 설정됨
        if (!_disposed) {
          notifyListeners();
        }
      }
    } catch (e) {
      logger.e('녹음 파일 처리 중 오류: $e');
      // 이미 _isRecording은 false로 설정됨
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> _initializePlayerController(String path) async {
    try {
      // PlayerController 재설정
      await playerController.stopPlayer();

      // 잠시 대기하여 리소스 해제 보장
      await Future.delayed(const Duration(milliseconds: 200));

      // 파일 형식 확인 및 플레이어 초기화
      logger.d('플레이어 초기화 시작: $path');
      await playerController.preparePlayer(path: path);
      await playerController.setVolume(1.0);

      logger.d('플레이어 초기화 완료');

      // 오디오 지속 시간 로드
      _loadAudioDuration();
    } catch (e) {
      logger.e('PlayerController 초기화 중 오류: $e');

      // 초기화 실패 시 재시도
      try {
        logger.d('플레이어 초기화 재시도...');
        await Future.delayed(const Duration(milliseconds: 500));
        await playerController.preparePlayer(path: path);
        await playerController.setVolume(1.0);
        _loadAudioDuration();
        logger.d('플레이어 초기화 재시도 성공');
      } catch (retryError) {
        logger.e('플레이어 초기화 재시도 실패: $retryError');
        rethrow;
      }
    }
  }

  void _startWaveformTimer() {
    // 100ms마다 waveform 업데이트
    _waveformUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording) {
        // audio_waveforms는 자동으로 waveform을 업데이트하므로 별도 명령이 필요 없음
        // 필요한 경우 여기에 추가 로직을 넣을 수 있음
        notifyListeners();
      } else {
        _stopWaveformTimer();
      }
    });
  }

  void _stopWaveformTimer() {
    _waveformUpdateTimer?.cancel();
    _waveformUpdateTimer = null;
  }

  void _togglePlaying() async {
    logger.d('_togglePlaying 호출 - 현재 isPlaying: $isPlaying');

    if (isPlaying) {
      try {
        await playerController.pausePlayer();
        isPlaying = false;
        logger.d('플레이어 일시정지');
        notifyListeners();
      } catch (e) {
        logger.e('플레이어 일시정지 오류: $e');
      }
    } else {
      if (recordingPath != null) {
        try {
          // 파일 존재 여부 확인
          final file = File(recordingPath!);
          if (!await file.exists()) {
            logger.e('오디오 파일을 찾을 수 없음: $recordingPath');
            onError?.call('오디오 파일을 찾을 수 없습니다');
            return;
          }

          // 파일 크기 체크
          final fileSize = await file.length();
          if (fileSize <= 0) {
            logger.e('오디오 파일이 비어 있음: $recordingPath');
            onError?.call('오디오 파일이 비어 있습니다');
            return;
          }

          // Android에서는 매번 플레이어를 재준비
          if (Platform.isAndroid) {
            logger.d('Android: 플레이어 재준비 시작');
            try {
              await playerController.stopPlayer();
              await Future.delayed(const Duration(milliseconds: 100));

              await playerController.preparePlayer(path: recordingPath!);
              await playerController.setVolume(1.0);

              logger.d('Android: 플레이어 재준비 완료');

              // seekTo는 플레이어 시작 후에 호출
              await playerController.startPlayer();
              await Future.delayed(const Duration(milliseconds: 50));
              await playerController.seekTo(_currentRangeValues.start.toInt());
            } catch (e) {
              logger.e('Android 플레이어 재준비 오류: $e');

              // 재준비 실패 시 전체 재초기화 시도
              try {
                await _initializePlayerController(recordingPath!);
                await playerController.startPlayer();
                await Future.delayed(const Duration(milliseconds: 50));
                await playerController.seekTo(_currentRangeValues.start.toInt());
              } catch (retryError) {
                logger.e('Android 플레이어 전체 재초기화 실패: $retryError');
                onError?.call('오디오 재생 중 오류가 발생했습니다: $retryError');
                return;
              }
            }
          } else {
            // iOS에서는 기존 로직 유지
            // 플레이어가 준비되지 않은 경우 재초기화
            try {
              await playerController.getDuration();
            } catch (e) {
              logger.d('플레이어 재초기화 필요: $e');
              await _initializePlayerController(recordingPath!);
            }

            // 플레이어 시작
            await playerController.startPlayer();
            await playerController.seekTo(_currentRangeValues.start.toInt());
          }

          isPlaying = true;
          logger.d('플레이어 시작 완료');
          notifyListeners();
        } catch (e) {
          logger.e('오디오 재생 중 오류: $e');
          onError?.call('오디오 재생 중 오류가 발생했습니다: $e');
        }
      } else {
        logger.e('재생할 오디오 파일 경로가 없음');
        onError?.call('재생할 오디오 파일이 없습니다');
      }
    }
  }

  Future<void> _trimAndSaveAudio() async {
    // iOS에서만 trimming 기능 사용
    if (!Platform.isIOS) {
      return;
    }

    final startTime = _currentRangeValues.start.toInt();
    final endTime = _currentRangeValues.end.toInt();

    // simple_audio_trimmer를 사용하여 오디오 트림
    final trimmedPath = await _trimAudio(recordingPath!, startTime, endTime);
    if (trimmedPath != null) {
      try {
        // 파일이 존재하는지 확인
        final file = File(trimmedPath);
        if (await file.exists()) {
          recordingPath = trimmedPath;

          // 플레이어 컨트롤러 재설정
          await playerController.stopPlayer();
          await playerController.preparePlayer(path: trimmedPath);

          // 웨이브폼 데이터 강제 업데이트
          await Future.delayed(const Duration(milliseconds: 300));

          _loadAudioDuration();
          _showTrimControls = !_showTrimControls;
          notifyListeners();
        } else {
          logger.e('trimmed file not found: $trimmedPath');
        }
      } catch (e) {
        logger.e('error during trimmed audio processing: $e');
        // ScaffoldMessenger 대신 콜백 함수 사용
        onError?.call('error during audio processing: $e');
      }
    } else {
      logger.e('failed to trim audio');
      // ScaffoldMessenger 대신 콜백 함수 사용
      onError?.call('failed to trim audio');
    }
  }

  Future<String?> _trimAudio(String inputPath, int startMs, int endMs) async {
    // iOS에서만 trimming 기능 사용
    if (!Platform.isIOS) {
      return null;
    }

    final directory = path.dirname(inputPath);
    final fileName = path.basenameWithoutExtension(inputPath);
    final outputPath = path.join(directory, '${fileName}_trimmed_${DateTime.now().millisecondsSinceEpoch}.m4a');

    try {
      // 출력 디렉토리가 존재하는지 확인하고 없으면 생성
      final outputDir = Directory(path.dirname(outputPath));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // SimpleAudioTrimmer를 사용하여 트리밍 수행
      final trimmedPath = await SimpleAudioTrimmer.trim(
        inputPath: inputPath,
        outputPath: outputPath,
        start: startMs / 1000.0, // 초 단위로 변환
        end: endMs / 1000.0, // 초 단위로 변환
      );

      return trimmedPath;
    } catch (e) {
      logger.e('Audio trimming error: $e');
      return null;
    }
  }

  static Future<bool> requestPermission() async {
    if (await Permission.microphone.isGranted) {
      return true;
    }

    // 권한 요청 with timeout
    bool hasResponse = false;
    Permission.microphone.request().then((status) {
      hasResponse = true;
    });

    // 5초 동안 응답 대기
    final startTime = DateTime.now();
    while (!hasResponse && DateTime.now().difference(startTime).inSeconds < 5) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 현재 상태 확인 및 모니터링
    final currentStatus = await Permission.microphone.status;
    if (currentStatus.isGranted) {
      return true;
    }
    if (currentStatus.isDenied || currentStatus.isPermanentlyDenied) {
      return false;
    }

    // 상태가 불확실한 경우 15초 동안 추가 모니터링
    while (DateTime.now().difference(startTime).inSeconds < 10) {
      final status = await Permission.microphone.status;
      if (status.isGranted) {
        return true;
      }
      if (status.isDenied || status.isPermanentlyDenied) {
        return false;
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    // 최종 상태 반환
    final finalStatus = await Permission.microphone.status;
    return finalStatus.isGranted;
  }

  /// FlutterSoundRecorder 등 비동기 정리를 위한 메서드
  Future<void> disposeRecorder() async {
    // iOS에서만 FlutterSound 정리
    if (!Platform.isIOS) {
      return;
    }

    try {
      if (_flutterSoundRecorder != null) {
        if (_flutterSoundRecorder!.isRecording) {
          try {
            await _flutterSoundRecorder?.stopRecorder();
          } catch (e) {
            logger.e('stopRecorder 오류 무시: $e');
          }
        }
        try {
          await _flutterSoundRecorder?.closeRecorder();
        } catch (e) {
          logger.e('closeRecorder 오류 무시: $e');
        }
      }
    } catch (e) {
      logger.e('FlutterSound 정리 오류: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopWaveformTimer();

    try {
      recorderController.dispose();
    } catch (e) {
      logger.e('recorderController 정리 오류: $e');
    }

    try {
      playerController.dispose();
    } catch (e) {
      logger.e('playerController 정리 오류: $e');
    }

    // 비동기 정리는 disposeRecorder에서 처리
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  set recordingPath(String? path) {
    _recordingPath = path;
    if (path != null) {
      _initializeWithPath(path);
    }
    notifyListeners();
  }

  String? get recordingPath => _recordingPath;

  Future<void> _initializeWithPath(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        // 파일 크기 체크
        final fileSize = await file.length();

        if (fileSize <= 0) {
          logger.e('오디오 파일이 비어 있음: $path');
          onError?.call('오디오 파일이 비어 있습니다');
          return;
        }

        // 백그라운드에서 플레이어 초기화
        await _initializePlayerController(path);
      } else {
        logger.e('오디오 파일을 찾을 수 없음: $path');
        onError?.call('오디오 파일을 찾을 수 없습니다');
        return;
      }
    } catch (e) {
      logger.e('오디오 파일 초기화 중 오류: $e');
      onError?.call('오디오 파일 초기화 중 오류가 발생했습니다');
      return;
    }
  }
}

class AudioRecorder extends StatelessWidget {
  final AudioRecorderController controller;
  final Function(String?) onRecordingPathChanged;

  const AudioRecorder({
    super.key,
    required this.controller,
    required this.onRecordingPathChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 컨트롤러에 에러 콜백 설정
    controller.onError = (message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    };

    // 녹음 경로가 변경될 때 호출될 콜백 추가
    controller.onRecordingPathChanged = (path) {
      onRecordingPathChanged(path);
    };

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        final waveformWidth = MediaQuery.of(context).size.width - 100;
        final waveformHeight = 50.0;

        final waveformData = controller.playerController.waveformExtraction.waveformData;
        final playerWaveStyle = PlayerWaveStyle(
          spacing: waveformWidth /
              (waveformData.isNotEmpty ? waveformData.length : 100),
          waveThickness: 2,
          fixedWaveColor: Colors.black,
          liveWaveColor: Colors.blue,
          seekLineColor: Colors.red,
        );

        return Column(
          children: [
            // 녹음 중일 때 waveform 표시
            if (controller.isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    SText(
                      'audio_recorder.recording',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AudioWaveforms(
                      size: Size(waveformWidth, waveformHeight),
                      recorderController: controller.recorderController,
                      waveStyle: WaveStyle(
                        waveColor: colorScheme.primary,
                        extendWaveform: true,
                        showMiddleLine: false,
                        scaleFactor: 100,
                      ),
                      enableGesture: true,
                    ),
                  ],
                ),
              ),

            // 녹음된 파일이 있을 때 waveform 표시
            if (controller.recordingPath != null)
              Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: IconButton(
                          onPressed: controller._togglePlaying,
                          icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            AudioFileWaveforms(
                              key: ValueKey(controller.recordingPath), // 경로가 변경될 때 위젯 재생성
                              enableSeekGesture: true,
                              padding: EdgeInsets.zero,
                              margin: EdgeInsets.zero,
                              waveformType: WaveformType.fitWidth,
                              size: Size(waveformWidth, waveformHeight),
                              playerController: controller.playerController,
                              playerWaveStyle: playerWaveStyle,
                            ),
                            SizedBox(
                              width: waveformWidth,
                              child: CustomPaint(
                                painter: DimmingPainter(
                                  start: controller._currentRangeValues.start / controller._audioDuration.toDouble(),
                                  end: controller._currentRangeValues.end / controller._audioDuration.toDouble(),
                                  size: Size(waveformWidth, waveformHeight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Android에서는 단순 delete 버튼, iOS에서는 PopupMenuButton
                      if (Platform.isAndroid)
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              controller.recordingPath = null;
                              controller._isRecording = false;
                              controller.notifyListeners();
                            },
                          ),
                        )
                      else
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (String result) {
                              if (result == 'delete') {
                                controller.recordingPath = null;
                                controller._isRecording = false;
                                controller.notifyListeners();
                              } else if (result == 'trim') {
                                controller._showTrimControls = !controller._showTrimControls;
                                controller.notifyListeners();
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete),
                                  title: SText('utils.delete'),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'trim',
                                child: ListTile(
                                  leading: Icon(Icons.cut),
                                  title: SText('audio_recorder.trim'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // iOS에서만 trim 컨트롤 표시
                  if (Platform.isIOS && !controller.isRecording && controller._showTrimControls) ...[
                    Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 50,
                        child: RangeSlider(
                          values: controller._currentRangeValues,
                          min: 0,
                          max: controller._audioDuration.toDouble(),
                          onChanged: (values) {
                            controller._currentRangeValues = values;
                            controller.notifyListeners();
                          },
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: controller._trimAndSaveAudio,
                          child: SText('audio_recorder.trimAndSave'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            controller._showTrimControls = false;
                            controller.notifyListeners();
                          },
                          child: SText('utils.cancel'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class DimmingPainter extends CustomPainter {
  final double start;
  final double end;
  final Size size;

  DimmingPainter({required this.start, required this.end, required this.size});

  @override
  // ignore: avoid_renaming_method_parameters
  void paint(Canvas canvas, Size _) {
    if (size.width.isNaN || size.height.isNaN || start.isNaN || end.isNaN) {
      return;
    }

    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // 왼쪽 dimming 영역
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width * start.clamp(0.0, 1.0), size.height), paint);

    // 오른쪽 dimming 영역
    canvas.drawRect(Rect.fromLTRB(size.width * end.clamp(0.0, 1.0), 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
