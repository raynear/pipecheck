import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:utils/utils.dart';
import 'package:uuid/uuid.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  static CameraService get instance => _instance;

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  FlashMode _currentFlashMode = FlashMode.off;
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  // Getters
  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;
  List<CameraDescription> get cameras => _cameras;
  int get currentCameraIndex => _currentCameraIndex;
  CameraDescription? get currentCamera => _cameras.isNotEmpty ? _cameras[_currentCameraIndex] : null;
  FlashMode get currentFlashMode => _currentFlashMode;
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;
  bool get hasMultipleCameras => _cameras.length > 1;
  bool get isBackCamera => currentCamera?.lensDirection == CameraLensDirection.back;
  bool get isFrontCamera => currentCamera?.lensDirection == CameraLensDirection.front;

  // 같은 방향의 카메라들 관련 getter들
  List<CameraDescription> get sameLensDirectionCameras {
    if (currentCamera == null) return [];
    return _cameras.where((camera) => camera.lensDirection == currentCamera!.lensDirection).toList();
  }

  bool get hasMultipleSameLensDirectionCameras => sameLensDirectionCameras.length > 1;

  // 헬퍼 메서드들
  bool _ensureControllerReady() {
    if (!_isInitialized || _controller == null) {
      logger.w('카메라가 준비되지 않았습니다');
      return false;
    }
    return true;
  }

  CameraController? _getReadyController() {
    final controller = _controller;
    if (!_isInitialized || controller == null) {
      logger.w('카메라가 준비되지 않았습니다');
      return null;
    }
    return controller;
  }

  CameraController? _getInitializedController() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return controller;
    }
    return null;
  }

  Future<bool> initialize({
    ResolutionPreset resolutionPreset = ResolutionPreset.high,
    bool enableAudio = false,
    CameraLensDirection preferredLensDirection = CameraLensDirection.back,
  }) async {
    // 카메라가 비활성화된 경우 조기 종료
    if (!AppFeatureConfig.isCameraEnabled) {
      logger.w('Camera feature is disabled by feature flag');
      return false;
    }

    try {
      logger.d('카메라 서비스 초기화 시작');

      // 사용 가능한 카메라 목록 가져오기
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        logger.w('사용 가능한 카메라가 없습니다');
        return false;
      }

      logger.d('발견된 카메라 개수: ${_cameras.length}');

      // 선호하는 카메라 방향으로 초기 카메라 설정
      _currentCameraIndex = _findCameraIndex(preferredLensDirection);

      // 카메라 컨트롤러 초기화
      await _initializeController(resolutionPreset, enableAudio);

      _isInitialized = true;
      logger.d('카메라 서비스 초기화 완료');
      return true;
    } catch (e) {
      logger.e('카메라 초기화 실패: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> _initializeController(
    ResolutionPreset resolutionPreset,
    bool enableAudio,
  ) async {
    await _controller?.dispose();

    _controller = CameraController(
      _cameras[_currentCameraIndex],
      resolutionPreset,
      enableAudio: enableAudio,
    );

    final controller = _controller;
    if (controller == null) {
      throw Exception('카메라 컨트롤러 생성 실패');
    }

    await controller.initialize();

    // 줌 레벨 설정
    _minZoomLevel = await controller.getMinZoomLevel();
    _maxZoomLevel = await controller.getMaxZoomLevel();
    _currentZoomLevel = _minZoomLevel;

    logger.d('카메라 컨트롤러 초기화 완료 - 줌 범위: $_minZoomLevel ~ $_maxZoomLevel');
  }

  int _findCameraIndex(CameraLensDirection direction) {
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == direction) {
        return i;
      }
    }
    return 0; // 찾지 못하면 첫 번째 카메라 사용
  }

  Future<bool> switchCamera() async {
    if (!_ensureControllerReady() || _cameras.length <= 1) {
      logger.w('카메라 전환 불가: 초기화되지 않았거나 카메라가 하나뿐입니다');
      return false;
    }

    try {
      logger.d('카메라 전환 시작');

      // 다음 카메라 인덱스 계산
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;

      // 현재 설정 저장
      final controller = _getReadyController();
      if (controller == null) {
        return false;
      }

      final currentResolution = controller.resolutionPreset;
      final enableAudio = controller.enableAudio;

      // 새 카메라로 컨트롤러 재초기화
      await _initializeController(currentResolution, enableAudio);

      logger.d('카메라 전환 완료: ${currentCamera?.lensDirection}');
      return true;
    } catch (e) {
      logger.e('카메라 전환 실패: $e');
      return false;
    }
  }

  Future<bool> switchToSameLensDirectionCamera() async {
    if (!_ensureControllerReady()) {
      return false;
    }

    final sameLensCameras = sameLensDirectionCameras;
    if (sameLensCameras.length <= 1) {
      logger.w('같은 방향의 카메라가 하나뿐입니다');
      return false;
    }

    try {
      logger.d('같은 방향의 다음 카메라로 전환 시작');

      // 현재 카메라의 같은 방향 카메라들 중에서 현재 카메라의 인덱스 찾기
      final currentCameraDesc = currentCamera;
      if (currentCameraDesc == null) return false;

      int currentIndexInSameLens = -1;
      for (int i = 0; i < sameLensCameras.length; i++) {
        if (sameLensCameras[i] == currentCameraDesc) {
          currentIndexInSameLens = i;
          break;
        }
      }

      if (currentIndexInSameLens == -1) return false;

      // 다음 같은 방향 카메라 선택 (순환)
      final nextIndexInSameLens = (currentIndexInSameLens + 1) % sameLensCameras.length;
      final nextCamera = sameLensCameras[nextIndexInSameLens];

      // 전체 카메라 목록에서 다음 카메라의 인덱스 찾기
      int nextCameraIndex = -1;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i] == nextCamera) {
          nextCameraIndex = i;
          break;
        }
      }

      if (nextCameraIndex == -1) return false;

      _currentCameraIndex = nextCameraIndex;

      // 현재 설정 저장
      final controller = _getReadyController();
      if (controller == null) {
        return false;
      }

      final currentResolution = controller.resolutionPreset;
      final enableAudio = controller.enableAudio;

      // 새 카메라로 컨트롤러 재초기화
      await _initializeController(currentResolution, enableAudio);

      logger.d('같은 방향의 카메라 전환 완료: ${currentCamera?.lensDirection}');
      return true;
    } catch (e) {
      logger.e('같은 방향 카메라 전환 실패: $e');
      return false;
    }
  }

  Future<bool> switchToCamera(CameraLensDirection direction) async {
    if (!_ensureControllerReady()) {
      return false;
    }

    final targetIndex = _findCameraIndex(direction);
    if (targetIndex == _currentCameraIndex) {
      logger.d('이미 요청된 카메라를 사용중입니다');
      return true;
    }

    try {
      logger.d('$direction 카메라로 전환 시작');

      _currentCameraIndex = targetIndex;

      // 현재 설정 저장
      final controller = _getReadyController();
      if (controller == null) {
        return false;
      }

      final currentResolution = controller.resolutionPreset;
      final enableAudio = controller.enableAudio;

      // 새 카메라로 컨트롤러 재초기화
      await _initializeController(currentResolution, enableAudio);

      logger.d('$direction 카메라로 전환 완료');
      return true;
    } catch (e) {
      logger.e('카메라 전환 실패: $e');
      return false;
    }
  }

  Future<File?> takePicture() async {
    // 카메라가 비활성화된 경우 조기 종료
    if (!AppFeatureConfig.isCameraEnabled) {
      logger.w('Camera feature is disabled by feature flag');
      return null;
    }

    final controller = _getInitializedController();
    if (controller == null) {
      logger.w('카메라가 준비되지 않았습니다');
      return null;
    }

    try {
      logger.d('사진 촬영 시작');
      final image = await controller.takePicture();
      logger.d('사진 촬영 완료: ${image.path}');
      return File(image.path);
    } catch (e) {
      logger.e('사진 촬영 실패: $e');
      return null;
    }
  }

  Future<bool> setFlashMode(FlashMode flashMode) async {
    final controller = _getReadyController();
    if (controller == null) {
      return false;
    }

    try {
      await controller.setFlashMode(flashMode);
      _currentFlashMode = flashMode;
      logger.d('플래시 모드 변경: $flashMode');
      return true;
    } catch (e) {
      logger.e('플래시 모드 변경 실패: $e');
      return false;
    }
  }

  Future<bool> toggleFlash() async {
    FlashMode newMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        newMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newMode = FlashMode.always;
        break;
      case FlashMode.always:
        newMode = FlashMode.off;
        break;
      case FlashMode.torch:
        newMode = FlashMode.off;
        break;
    }
    return await setFlashMode(newMode);
  }

  Future<bool> setZoomLevel(double zoomLevel) async {
    final controller = _getReadyController();
    if (controller == null) {
      return false;
    }

    try {
      final clampedZoom = zoomLevel.clamp(_minZoomLevel, _maxZoomLevel);
      await controller.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;
      logger.d('줌 레벨 변경: $clampedZoom');
      return true;
    } catch (e) {
      logger.e('줌 레벨 변경 실패: $e');
      return false;
    }
  }

  Future<bool> zoomIn([double increment = 0.1]) async {
    final newZoom = (_currentZoomLevel + increment).clamp(_minZoomLevel, _maxZoomLevel);
    return await setZoomLevel(newZoom);
  }

  Future<bool> zoomOut([double decrement = 0.1]) async {
    final newZoom = (_currentZoomLevel - decrement).clamp(_minZoomLevel, _maxZoomLevel);
    return await setZoomLevel(newZoom);
  }

  Future<bool> resetZoom() async {
    return await setZoomLevel(_minZoomLevel);
  }

  Future<File?> cropImage(File imageFile) async {
    try {
      logger.d('이미지 크롭 시작: ${imageFile.path}');

      final capturedImage = img.decodeImage(await imageFile.readAsBytes());
      if (capturedImage != null) {
        final height = capturedImage.height;
        final width = capturedImage.width;
        final cropHeight = width ~/ 8;
        final cropTop = (height - cropHeight) ~/ 2;

        final croppedImage = img.copyCrop(
          capturedImage,
          x: 0,
          y: cropTop,
          width: width,
          height: cropHeight,
        );

        final encodedImage = img.encodePng(croppedImage);

        await imageFile.delete();
        await File(imageFile.path).writeAsBytes(encodedImage);

        logger.d('이미지 크롭 완료');
        return File(imageFile.path);
      }
    } catch (e) {
      logger.e('이미지 크롭 실패: $e');
    }
    return null;
  }

  Future<File?> cropImageSquare(File imageFile) async {
    try {
      logger.d('정사각형 이미지 크롭 시작: ${imageFile.path}');

      final capturedImage = img.decodeImage(await imageFile.readAsBytes());
      if (capturedImage != null) {
        // 1:1 비율로 크롭 (정사각형)
        final size = capturedImage.width < capturedImage.height ? capturedImage.width : capturedImage.height;

        final offsetX = (capturedImage.width - size) ~/ 2;
        final offsetY = (capturedImage.height - size) ~/ 2;

        final croppedImage = img.copyCrop(
          capturedImage,
          x: offsetX,
          y: offsetY,
          width: size,
          height: size,
        );

        final tempFile = File('${imageFile.path}_cropped.jpg');
        await tempFile.writeAsBytes(img.encodeJpg(croppedImage));

        logger.d('정사각형 이미지 크롭 완료');
        return tempFile;
      }
    } catch (e) {
      logger.e('정사각형 이미지 크롭 실패: $e');
    }
    return null;
  }

  Future<String?> saveToGallery(File file, {String? fileName}) async {
    try {
      logger.d('갤러리에 이미지 저장 시작: ${file.path}');

      // 파일을 바이트로 읽기
      final Uint8List bytes = await file.readAsBytes();

      final fixedFileName = fileName ?? 'habit_review_${DateTime.now().millisecondsSinceEpoch}';

      // bytes to XFile
      final xFile = XFile.fromData(bytes, name: fixedFileName);

      // 갤러리에 저장
      final result = await GallerySaver.saveImage(xFile.path);

      if (result != null) {
        logger.d('갤러리에 이미지 저장 완료: ${xFile.path}');
        return xFile.path;
      } else {
        logger.w('갤러리 저장 실패: ${xFile.path}');
        return null;
      }
    } catch (e) {
      logger.e('갤러리 저장 실패: $e');
      return null;
    }
  }

  Future<String?> saveToAppStorage(File file, String prefix) async {
    try {
      logger.d('앱 저장소에 이미지 저장 시작: ${file.path}');

      final uuid = const Uuid().v4();
      final docPath = await getApplicationDocumentsDirectory();
      final extension = file.path.split('.').last;
      final fileName = '$prefix-$uuid.$extension';
      final newPath = '${docPath.path}/$fileName';

      await file.copy(newPath);

      logger.d('앱 저장소에 이미지 저장 완료: $newPath');
      return newPath;
    } catch (e) {
      logger.e('앱 저장소 저장 실패: $e');
      return null;
    }
  }

  Future<Map<String, String?>> saveImageBoth(
    File file, {
    String prefix = 'image',
    String? galleryFileName,
  }) async {
    try {
      logger.d('이미지를 갤러리와 앱 저장소에 모두 저장 시작');

      final galleryPath = await saveToGallery(file, fileName: galleryFileName);
      final appStoragePath = await saveToAppStorage(file, prefix);

      logger.d('이미지 저장 완료 - 갤러리: $galleryPath, 앱저장소: $appStoragePath');

      return {
        'galleryPath': galleryPath,
        'appStoragePath': appStoragePath,
      };
    } catch (e) {
      logger.e('이미지 저장 실패: $e');
      return {
        'galleryPath': null,
        'appStoragePath': null,
      };
    }
  }

  Future<File?> takePictureAndCrop({
    bool cropSquare = false,
    bool saveToGalleryFlag = false,
    bool saveToAppStorageFlag = false,
    String appStoragePrefix = 'captured',
    String? galleryFileName,
  }) async {
    try {
      logger.d('사진 촬영 및 처리 시작');

      // 사진 촬영
      final capturedFile = await takePicture();
      if (capturedFile == null) {
        logger.w('사진 촬영 실패');
        return null;
      }

      // 크롭 처리
      File? processedFile = capturedFile;
      if (cropSquare) {
        processedFile = await cropImageSquare(capturedFile);
        if (processedFile == null) {
          logger.w('이미지 크롭 실패');
          return capturedFile;
        }
      }

      // 저장 처리
      if (saveToGalleryFlag || saveToAppStorageFlag) {
        if (saveToGalleryFlag && saveToAppStorageFlag) {
          await saveImageBoth(
            processedFile,
            prefix: appStoragePrefix,
            galleryFileName: galleryFileName,
          );
        } else if (saveToGalleryFlag) {
          await saveToGallery(processedFile, fileName: galleryFileName);
        } else if (saveToAppStorageFlag) {
          await saveToAppStorage(processedFile, appStoragePrefix);
        }
      }

      logger.d('사진 촬영 및 처리 완료');
      return processedFile;
    } catch (e) {
      logger.e('사진 촬영 및 처리 실패: $e');
      return null;
    }
  }

  Future<void> pausePreview() async {
    final controller = _getInitializedController();
    if (controller != null) {
      try {
        await controller.pausePreview();
        logger.d('카메라 프리뷰 일시정지');
      } catch (e) {
        logger.e('카메라 프리뷰 일시정지 실패: $e');
      }
    }
  }

  Future<void> resumePreview() async {
    final controller = _getInitializedController();
    if (controller != null) {
      try {
        await controller.resumePreview();
        logger.d('카메라 프리뷰 재개');
      } catch (e) {
        logger.e('카메라 프리뷰 재개 실패: $e');
      }
    }
  }

  void dispose() {
    logger.d('카메라 서비스 정리 시작');
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    logger.d('카메라 서비스 정리 완료');
  }
}
