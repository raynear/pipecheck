// parameter로 어떤 permission이 필요한지와 왜 필요한지를 넣어주면 그에 대한 설명을 보여주고 그 아래에 권한 요청 버튼을 보여준다.
// consumerStatefulWidget으로 만들거야.
// 앱에서 사용하는 권한은 위치, 카메라, 음성, 알림이야.
// 어떤 권한을 요구할지 리스트를 받아올꺼야.
// 그 리스트와 설명을 아이콘과 텍스트로 예쁘게 보여주고 버튼을 누르면 권한 요청이 되도록 할꺼야. 거부할 수도 있어야 해.
// 거부하는 경우에는 context.pop(false)로 거부하고 페이지를 빠져나올꺼야.
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/notification/notification.dart';
import 'package:pipecheck/core/widgets/buttons/adaptive_button.dart';
import 'package:pipecheck/core/widgets/loading/loading_indicator.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:positioning/positioning.dart';
import 'package:utils/utils.dart';

enum PermissionType {
  location,
  camera,
  microphone,
  notification,
}

class PermissionInfo {
  final PermissionType type;
  final String title;
  final String description;
  final IconData icon;
  final Permission permission;
  final String lottieAsset;
  final PermissionStatus status;

  PermissionInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.permission,
    required this.lottieAsset,
    required this.status,
  });

  // 복사본 생성 메서드 (상태 변경을 위해)
  PermissionInfo copyWith({
    PermissionType? type,
    String? title,
    String? description,
    IconData? icon,
    Permission? permission,
    String? lottieAsset,
    PermissionStatus? status,
  }) {
    return PermissionInfo(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      permission: permission ?? this.permission,
      lottieAsset: lottieAsset ?? this.lottieAsset,
      status: status ?? this.status,
    );
  }
}

class PermissionRequestView extends ConsumerStatefulWidget {
  final Map<PermissionType, String> permissionMap;
  // i18n: 기본값은 build()에서 permission.* 키로 해석한다. const 생성자라 기본값에
  // .tr()를 직삽할 수 없어 nullable로 두고 null이면 로컬라이즈된 기본값을 쓴다.
  final String? mainTitle;
  final String? description;
  final String? approveButtonText;
  final String? rejectButtonText;
  final String? settingsButtonText;
  final String? permanentlyDeniedMessage;

  const PermissionRequestView({
    super.key,
    required this.permissionMap,
    this.mainTitle,
    this.description,
    this.approveButtonText,
    this.rejectButtonText,
    this.settingsButtonText,
    this.permanentlyDeniedMessage,
  });

  @override
  ConsumerState<PermissionRequestView> createState() => _PermissionRequestViewState();
}

class _PermissionRequestViewState extends ConsumerState<PermissionRequestView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final Map<PermissionType, PermissionInfo> _defaultPermissionInfoMap = {};
  List<PermissionInfo> _regularPermissions = []; // 일반 권한 요청
  final List<PermissionInfo> _permanentlyDeniedPermissions = []; // 영구 거부된 권한
  bool _isRequesting = false;
  bool _initialized = false;
  // 각 권한별 결과를 추적하는 맵 변경: PermissionStatus 사용
  final Map<PermissionType, PermissionStatus> _permissionResults = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 비동기 초기화 시작
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    // 기본 권한 정보 초기화
    await _initDefaultPermissionInfo();

    // 요청된 권한 상태 확인 및 분류
    await _checkPermissionStatuses();

    // 초기 권한 결과 맵 설정 (기본값은 false)
    _permissionResults.clear();
    for (var type in widget.permissionMap.keys) {
      if (_defaultPermissionInfoMap.containsKey(type)) {
        // 이미 승인된 권한은 true로 설정
        _permissionResults[type] = _defaultPermissionInfoMap[type]!.status;
      }
    }

    // 모든 권한이 이미 허용되었는지 확인
    if (_regularPermissions.isEmpty && _permanentlyDeniedPermissions.isEmpty) {
      if (mounted) {
        // 모든 권한이 이미 허용된 경우 결과 맵 반환
        context.pop(_permissionResults);
      }
      return;
    }

    setState(() {
      _initialized = true;
    });

    _animationController.forward();
  }

  Future<void> _initDefaultPermissionInfo() async {
    // 각 권한에 대한 초기 상태 확인
    Map<PermissionType, PermissionStatus> statuses = {};

    for (var type in PermissionType.values) {
      Permission permission;
      PermissionStatus status;

      switch (type) {
        case PermissionType.location:
          permission = Permission.location;
          
          // AppFeatureConfig에서 위치 기능이 비활성화되어 있으면 권한 확인 생략
          if (!AppFeatureConfig.isLocationEnabled) {
            logger.d('위치 기능이 AppFeatureConfig에서 비활성화되어 있음 - 권한 확인 생략');
            status = PermissionStatus.denied; // 기본값으로 denied 설정
            break;
          }
          
          // iOS에서 위치 권한은 Geolocator로 더 정확하게 확인
          status = await permission.status;
          logger.d('위치 권한 초기 상태: $status');

          if (AppFeatureConfig.isLocationEnabled) {
            try {
              // Geolocator로 위치 권한 상태 직접 확인
              LocationPermission geoStatus = await LocationService().checkPermission();
              logger.d('Geolocator 위치 권한 상태: $geoStatus');

              // Geolocator 상태를 Permission 상태로 변환
              if (geoStatus == LocationPermission.always || geoStatus == LocationPermission.whileInUse) {
                status = PermissionStatus.granted;
                logger.d('Geolocator에서 위치 권한 확인됨: 허용됨');
              } else if (geoStatus == LocationPermission.deniedForever) {
                status = PermissionStatus.permanentlyDenied;
                logger.d('Geolocator에서 위치 권한 확인됨: 영구 거부');
              } else {
                status = PermissionStatus.denied;
                logger.d('Geolocator에서 위치 권한 확인됨: 거부됨');
              }
            } catch (e) {
              logger.e('Geolocator 위치 권한 확인 중 오류: $e');
            }
          }
          break;

        case PermissionType.notification:
          permission = Permission.notification;
          
          // AppFeatureConfig에서 알림이 비활성화되어 있으면 권한 확인 생략
          if (!AppFeatureConfig.isNotificationEnabled) {
            logger.d('알림이 AppFeatureConfig에서 비활성화되어 있음 - 권한 확인 생략');
            status = PermissionStatus.denied; // 기본값으로 denied 설정
            break;
          }
          
          status = await permission.status;
          logger.d('알림 권한 초기 상태(permission_handler): $status');

          // AppFeatureConfig에서 알림이 활성화되어 있을 때만 AwesomeNotifications 확인
          if (AppFeatureConfig.isNotificationEnabled) {
            try {
              // iOS에서는 별도 확인이 필요
              bool isAllowed = await RaynearNotification().isNotificationAllowedRaw();
              logger.d('AwesomeNotifications 알림 권한 상태: $isAllowed');

              // iOS에서 더 깊은 알림 상태 확인 시도
              if (isAllowed) {
                status = PermissionStatus.granted;
                logger.d('알림 권한 상태 업데이트: 허용됨');
              }
            } catch (e) {
              logger.e('알림 권한 확인 중 오류: $e');
            }
          }
          break;

        case PermissionType.camera:
          permission = Permission.camera;
          status = await permission.status;
          break;

        case PermissionType.microphone:
          permission = Permission.microphone;
          status = await permission.status;
          break;
      }

      // 권한 상태 로깅 추가
      logger.d('최종 권한 상태: $type - status: $status, isGranted: ${status.isGranted}, '
          'isDenied: ${status.isDenied}, isPermanentlyDenied: ${status.isPermanentlyDenied}');

      statuses[type] = status;
    }

    // 기본 권한 정보 맵 초기화
    _defaultPermissionInfoMap.clear();
    _defaultPermissionInfoMap.addAll({
      PermissionType.location: PermissionInfo(
        type: PermissionType.location,
        title: 'permission.location.title'.tr(),
        description: 'permission.location.description'.tr(),
        icon: Icons.location_on_rounded,
        permission: Permission.location,
        lottieAsset: 'assets/lottie/location.lottie',
        status: statuses[PermissionType.location] ?? PermissionStatus.denied,
      ),
      PermissionType.camera: PermissionInfo(
        type: PermissionType.camera,
        title: 'permission.camera.title'.tr(),
        description: 'permission.camera.description'.tr(),
        icon: Icons.camera_alt_rounded,
        permission: Permission.camera,
        lottieAsset: 'assets/lottie/camera.lottie',
        status: statuses[PermissionType.camera] ?? PermissionStatus.denied,
      ),
      PermissionType.microphone: PermissionInfo(
        type: PermissionType.microphone,
        title: 'permission.microphone.title'.tr(),
        description: 'permission.microphone.description'.tr(),
        icon: Icons.mic_rounded,
        permission: Permission.microphone,
        lottieAsset: 'assets/lottie/mic.lottie',
        status: statuses[PermissionType.microphone] ?? PermissionStatus.denied,
      ),
      PermissionType.notification: PermissionInfo(
        type: PermissionType.notification,
        title: 'permission.notification.title'.tr(),
        description: 'permission.notification.description'.tr(),
        icon: Icons.notifications_rounded,
        permission: Permission.notification,
        lottieAsset: 'assets/lottie/notification.lottie',
        status: statuses[PermissionType.notification] ?? PermissionStatus.denied,
      ),
    });
  }

  Future<void> _checkPermissionStatuses() async {
    _regularPermissions.clear();
    _permanentlyDeniedPermissions.clear();

    // 요청된 권한만 처리
    for (var entry in widget.permissionMap.entries) {
      // 알림 권한이 비활성화되어 있으면 알림 권한은 건너뛰기
      if (entry.key == PermissionType.notification && !AppFeatureConfig.isNotificationEnabled) {
        logger.d('알림이 AppFeatureConfig에서 비활성화되어 있음 - 알림 권한 요청 건너뛰기');
        continue;
      }
      
      // 위치 권한이 비활성화되어 있으면 위치 권한은 건너뛰기
      if (entry.key == PermissionType.location && !AppFeatureConfig.isLocationEnabled) {
        logger.d('위치 기능이 AppFeatureConfig에서 비활성화되어 있음 - 위치 권한 요청 건너뛰기');
        continue;
      }
      
      if (_defaultPermissionInfoMap.containsKey(entry.key)) {
        final permissionInfo = _defaultPermissionInfoMap[entry.key]!;

        // 상태 로깅
        logger.d('권한 분류: ${entry.key} - status: ${permissionInfo.status}, '
            'isGranted: ${permissionInfo.status.isGranted}');

        // ⭐️ 핵심 수정: 권한 체크 강화
        bool isActuallyGranted = permissionInfo.status.isGranted;

        // 실제 권한 상태 재확인 (알림 권한)
        if (entry.key == PermissionType.notification && isActuallyGranted && AppFeatureConfig.isNotificationEnabled) {
          // 알림이 활성화되어 있을 때만 AwesomeNotifications API로 실제 허용 여부 한번 더 확인
          bool isAllowed = await RaynearNotification().isNotificationAllowedRaw();
          logger.d('알림 권한 실제 상태 재확인: $isAllowed');
          isActuallyGranted = isAllowed;
        } else if (entry.key == PermissionType.notification && !AppFeatureConfig.isNotificationEnabled) {
          // 알림이 비활성화되어 있으면 권한이 허용되지 않은 것으로 처리
          logger.d('알림이 AppFeatureConfig에서 비활성화되어 있음 - 권한 요청하지 않음');
          isActuallyGranted = false;
        }

        // 실제 권한 상태 재확인 (위치 권한)
        if (entry.key == PermissionType.location && isActuallyGranted && AppFeatureConfig.isLocationEnabled) {
          // 위치 기능이 활성화되어 있을 때만 실제 허용 여부 재확인
          logger.d('위치 권한 실제 상태 유지: $isActuallyGranted');
        } else if (entry.key == PermissionType.location && !AppFeatureConfig.isLocationEnabled) {
          // 위치 기능이 비활성화되어 있으면 권한이 허용되지 않은 것으로 처리
          logger.d('위치 기능이 AppFeatureConfig에서 비활성화되어 있음 - 권한 요청하지 않음');
          isActuallyGranted = false;
        }

        // 이미 승인된 권한은 건너뛰기
        if (isActuallyGranted) {
          logger.d('${entry.key} 권한이 이미 승인되어 있어 목록에서 제외');
          continue;
        }

        // 설명만 커스텀 설명으로 업데이트한 권한 정보 생성
        final updatedInfo = PermissionInfo(
          type: permissionInfo.type,
          title: permissionInfo.title,
          description: entry.value, // 커스텀 설명 사용
          icon: permissionInfo.icon,
          permission: permissionInfo.permission,
          lottieAsset: permissionInfo.lottieAsset,
          status: permissionInfo.status,
        );

        // 영구 거부된 권한과 일반 권한 분류
        if (updatedInfo.status.isPermanentlyDenied) {
          logger.d('${entry.key} 권한이 영구 거부됨');
          _permanentlyDeniedPermissions.add(updatedInfo);
        } else {
          logger.d('${entry.key} 권한이 일반 권한으로 분류됨');
          _regularPermissions.add(updatedInfo);
        }
      }
    }

    // 최종 분류 결과 로깅
    logger.d('권한 분류 완료: 일반 권한 ${_regularPermissions.length}개, 영구 거부 권한 ${_permanentlyDeniedPermissions.length}개');
    for (var p in _regularPermissions) {
      logger.d('일반 권한: ${p.type}');
    }
    for (var p in _permanentlyDeniedPermissions) {
      logger.d('영구 거부 권한: ${p.type}');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (_regularPermissions.isEmpty) return;

    setState(() {
      _isRequesting = true;
    });

    // 권한별 개별 처리
    List<PermissionInfo> updatedRegular = List.from(_regularPermissions);
    List<PermissionInfo> updatedPermanentlyDenied = [];

    for (int i = 0; i < _regularPermissions.length; i++) {
      final info = _regularPermissions[i];
      PermissionStatus status;

      // 알림 권한은 AwesomeNotifications로 처리
      if (info.type == PermissionType.notification) {
        // AppFeatureConfig 확인
        if (!AppFeatureConfig.isNotificationEnabled) {
          logger.d('알림이 AppFeatureConfig에서 비활성화되어 있음 - 권한 요청 생략');
          status = PermissionStatus.denied;
        } else {
          logger.d('알림 권한 요청 시작 (AwesomeNotifications 사용)');
          bool isAllowed = await RaynearNotification().requestPermissionRaw();
          logger.d('알림 권한 요청 결과: $isAllowed');

          status = isAllowed ? PermissionStatus.granted : PermissionStatus.denied;
        }
      } else if (info.type == PermissionType.location) {
        // 위치 권한 처리
        if (!AppFeatureConfig.isLocationEnabled) {
          logger.d('위치 기능이 AppFeatureConfig에서 비활성화되어 있음 - 권한 요청 생략');
          status = PermissionStatus.denied;
        } else {
          // permission_handler로 위치 권한 요청
          status = await info.permission.request();
          logger.d('위치 권한 요청 결과: $status');
          
          // iOS에서 더 정확한 권한 확인
          if (AppFeatureConfig.isLocationEnabled && status == PermissionStatus.granted) {
            try {
              final geoStatus = await LocationService().checkPermission();
              if (geoStatus == LocationPermission.denied || geoStatus == LocationPermission.deniedForever) {
                // Geolocator로 다시 권한 요청
                final requestedStatus = await LocationService().requestPermission();
                if (requestedStatus == LocationPermission.whileInUse || requestedStatus == LocationPermission.always) {
                  status = PermissionStatus.granted;
                } else if (requestedStatus == LocationPermission.deniedForever) {
                  status = PermissionStatus.permanentlyDenied;
                } else {
                  status = PermissionStatus.denied;
                }
              }
            } catch (e) {
              logger.e('위치 권한 재요청 중 오류: $e');
            }
          }
        }
      } else {
        // 다른 권한은 permission_handler로 처리
        status = await info.permission.request();
        logger.d('${info.type} 권한 요청 결과: $status');
      }

      // 권한 상태 업데이트된 정보 생성
      final updatedInfo = info.copyWith(status: status);

      // 결과 맵 업데이트
      _permissionResults[info.type] = status;

      // 승인된 권한은 목록에서 제거
      if (status.isGranted) {
        updatedRegular.remove(info);
      } else if (status.isPermanentlyDenied) {
        // 영구 거부된 권한으로 이동
        updatedRegular.remove(info);
        updatedPermanentlyDenied.add(updatedInfo);
      } else {
        // 여전히 일반 권한 (상태만 업데이트)
        int index = updatedRegular.indexOf(info);
        if (index >= 0) {
          updatedRegular[index] = updatedInfo;
        }
      }
    }

    // 모든 퍼미션 목록 갱신
    _permanentlyDeniedPermissions.addAll(updatedPermanentlyDenied);

    setState(() {
      _regularPermissions = updatedRegular;
      _isRequesting = false;
    });

    // 모든 권한이 처리되었으면 결과 반환
    if (_regularPermissions.isEmpty && _permanentlyDeniedPermissions.isEmpty) {
      if (mounted) {
        context.pop(_permissionResults);
      }
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();

    // 설정에서 돌아왔을 때 권한 상태 다시 확인
    await _initDefaultPermissionInfo();
    await _checkPermissionStatuses();

    // 결과 맵 업데이트
    for (var type in widget.permissionMap.keys) {
      if (_defaultPermissionInfoMap.containsKey(type)) {
        _permissionResults[type] = _defaultPermissionInfoMap[type]!.status;
      }
    }

    // 모든 요청된 권한이 granted 되었는지 명시적으로 확인
    bool allRequestedPermissionsGranted = true;
    for (var type in widget.permissionMap.keys) {
      if (_permissionResults[type] != PermissionStatus.granted) {
        allRequestedPermissionsGranted = false;
        break;
      }
    }

    logger.d('설정에서 돌아온 후 권한 상태 확인:');
    for (var entry in _permissionResults.entries) {
      logger.d('${entry.key}: ${entry.value}');
    }
    logger.d('모든 요청된 권한이 granted됨: $allRequestedPermissionsGranted');

    // 모든 권한이 granted되었으면 즉시 화면 닫기
    if (allRequestedPermissionsGranted) {
      logger.d('모든 권한이 허용되어 권한 요청 화면을 자동으로 닫습니다.');
      if (mounted) {
        context.pop(_permissionResults);
      }
      return;
    }

    setState(() {
      // UI 업데이트
    });

    // 기존 로직: 처리해야 할 권한이 없으면 결과 반환
    if (_regularPermissions.isEmpty && _permanentlyDeniedPermissions.isEmpty) {
      if (mounted) {
        context.pop(_permissionResults);
      }
    }
  }

  void _rejectPermissions() {
    // 요청된 권한에 대해 현재 상태 기반으로 설정
    for (var type in widget.permissionMap.keys) {
      if (_defaultPermissionInfoMap.containsKey(type)) {
        // 이미 승인된 권한은 true로 유지, 그렇지 않으면 false
        _permissionResults[type] = _defaultPermissionInfoMap[type]!.status;
      } else {
        // 권한 정보가 없으면 false
        _permissionResults[type] = PermissionStatus.denied;
      }
    }
    context.pop(_permissionResults);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // 초기화 중 로딩 화면
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOut,
                )),
                child: FadeTransition(
                  opacity: _animationController,
                  child: Text(
                    widget.mainTitle ?? 'permission.requestTitle'.tr(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOut,
                )),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.1, 1.0),
                  ),
                  child: Text(
                    widget.description ?? 'permission.requestDescription'.tr(),
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 일반 권한 섹션
              if (_regularPermissions.isNotEmpty) ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: _regularPermissions.length,
                    itemBuilder: (context, index) {
                      final info = _regularPermissions[index];
                      final delay = 200 + (index * 100);

                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeOut,
                        )),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(delay / 1000, 1.0),
                          ),
                          child: _buildPermissionCard(info),
                        ),
                      );
                    },
                  ),
                ),
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  )),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.4, 1.0),
                    ),
                    child: Column(
                      children: [
                        AdaptiveButton(
                          label: '',
                          onPressed: _isRequesting ? null : _requestPermissions,
                          variant: ButtonVariant.primary,
                          isLoading: _isRequesting,
                          child: Text(widget.approveButtonText ?? 'permission.approveButton'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 영구 거부된 권한 섹션
              if (_permanentlyDeniedPermissions.isNotEmpty) ...[
                if (_regularPermissions.isNotEmpty) const SizedBox(height: 32),

                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  )),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.2, 1.0),
                    ),
                    child: Text(
                      widget.permanentlyDeniedMessage ?? 'permission.permanentlyDeniedMessage'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 영구 거부된 권한 리스트가 있으면 별도 섹션으로 표시
                Expanded(
                  flex: _regularPermissions.isEmpty ? 1 : 1,
                  child: ListView.builder(
                    itemCount: _permanentlyDeniedPermissions.length,
                    itemBuilder: (context, index) {
                      final info = _permanentlyDeniedPermissions[index];
                      final delay = 300 + (index * 100);

                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeOut,
                        )),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(delay / 1000, 1.0),
                          ),
                          child: _buildPermissionCard(
                            info,
                            true, // 영구 거부된 권한임을 표시
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  )),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.4, 1.0),
                    ),
                    child: Column(
                      children: [
                        AdaptiveButton(
                          label: '',
                          onPressed: _openSettings,
                          variant: ButtonVariant.secondary,
                          child: Text(widget.settingsButtonText ?? 'permission.settingsButton'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 거부 버튼은 항상 표시
              AdaptiveButton(
                label: '',
                onPressed: _rejectPermissions,
                variant: ButtonVariant.text,
                child: Text(
                  widget.rejectButtonText ?? 'permission.rejectButton'.tr(),
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<LottieComposition?> customDecoder(List<int> bytes) {
    return LottieComposition.decodeZip(
      bytes,
      filePicker: (files) =>
          files.firstWhereOrNull((file) => file.name.startsWith('animations/') && file.name.endsWith('.json')),
    );
  }

  Widget _buildLottie(String assetName, [double width = 48]) {
    return Lottie.asset(
      assetName,
      width: width,
      height: width,
      fit: BoxFit.contain,
      decoder: customDecoder,
      animate: !const bool.fromEnvironment('INTEGRATION_TEST', defaultValue: false),
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        logger.d('Lottie 로딩 에러: $error');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPermissionCard(PermissionInfo info, [bool isPermanentlyDenied = false]) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            isPermanentlyDenied ? Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isPermanentlyDenied
                    ? theme.colorScheme.error.withValues(alpha: 0.1)
                    : theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: info.lottieAsset.isNotEmpty
                    ? _buildLottie(info.lottieAsset)
                    : Icon(
                        info.icon,
                        color: isPermanentlyDenied ? theme.colorScheme.error : theme.primaryColor,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPermanentlyDenied ? theme.colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPermanentlyDenied
                        ? '${info.description}\n${'permission.openSettingsHint'.tr()}'
                        : info.description,
                    style: TextStyle(
                      color: isPermanentlyDenied
                          ? theme.colorScheme.error.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 필요한 권한들의 상태를 확인하고, 필요한 경우 권한 요청 화면을 표시합니다.
///
/// [permissionMap]에 포함된 모든 권한이 이미 허용되었다면 권한 요청 화면을 표시하지 않고
/// 결과만 반환합니다.
///
/// 권한이 필요한 경우 [PermissionRequestView]를 표시하고 결과를 반환합니다.
Future<Map<PermissionType, PermissionStatus>> requestPermissions({
  required BuildContext context,
  required Map<PermissionType, String> permissionMap,
  // i18n: null이면 PermissionRequestView가 permission.* 기본값을 해석한다.
  String? mainTitle,
  String? description,
  String? approveButtonText,
  String? rejectButtonText,
  String? settingsButtonText,
  String? permanentlyDeniedMessage,
}) async {
  // 결과 맵 초기화
  Map<PermissionType, PermissionStatus> results = {};

  // 모든 권한이 이미 허용되었는지 확인
  bool allGranted = true;
  bool hasRequestablePermissions = false; // 요청 가능한 권한이 있는지 확인

  // 각 권한의 현재 상태 확인
  for (var type in permissionMap.keys) {
    bool isGranted = false;
    bool isPermanentlyDenied = false;

    switch (type) {
      case PermissionType.location:
        try {
          // 위치 권한은 Geolocator로 확인
          LocationPermission geoStatus = await LocationService().checkPermission();
          isGranted = geoStatus == LocationPermission.always || geoStatus == LocationPermission.whileInUse;
          isPermanentlyDenied = geoStatus == LocationPermission.deniedForever;
        } catch (e) {
          logger.e('위치 권한 확인 중 오류: $e');
          PermissionStatus status = await Permission.location.status;
          isGranted = status.isGranted;
          isPermanentlyDenied = status.isPermanentlyDenied;
        }
        break;

      case PermissionType.notification:
        try {
          // 알림 권한은 AwesomeNotifications로 확인
          isGranted = await RaynearNotification().isNotificationAllowedRaw();
          if (!isGranted) {
            PermissionStatus status = await Permission.notification.status;
            isPermanentlyDenied = status.isPermanentlyDenied;
          }
        } catch (e) {
          logger.e('알림 권한 확인 중 오류: $e');
          PermissionStatus status = await Permission.notification.status;
          isGranted = status.isGranted;
          isPermanentlyDenied = status.isPermanentlyDenied;
        }
        break;

      case PermissionType.camera:
        PermissionStatus status = await Permission.camera.status;
        isGranted = status.isGranted;
        isPermanentlyDenied = status.isPermanentlyDenied;
        break;

      case PermissionType.microphone:
        PermissionStatus status = await Permission.microphone.status;
        isGranted = status.isGranted;
        isPermanentlyDenied = status.isPermanentlyDenied;
        break;
    }

    results[type] = isGranted
        ? PermissionStatus.granted
        : isPermanentlyDenied
            ? PermissionStatus.permanentlyDenied
            : PermissionStatus.denied;

    // 허용되지 않은 권한이 있으면 플래그 변경
    if (!isGranted) {
      allGranted = false;

      // 영구 거부되지 않은 권한이 있으면 요청 가능
      if (!isPermanentlyDenied) {
        hasRequestablePermissions = true;
      }
    }

    logger.d('권한 상태 확인: $type - granted: $isGranted, permanentlyDenied: $isPermanentlyDenied');
  }

  // 모든 권한이 이미 허용되었으면 결과 바로 반환
  if (allGranted) {
    logger.d('모든 필요 권한이 이미 허용됨: $results');
    return results;
  }

  // 요청 가능한 권한이 없으면 (모든 거부된 권한이 영구 거부) 바로 결과 반환
  if (!hasRequestablePermissions) {
    // 단, permanentlyDeniedMessage가 커스터마이징(caller가 non-null로 전달)되었다면
    // 설정 유도 화면 표시. (i18n 전: 기본 한글 문자열과 == 비교 → null 비교로 전환)
    bool hasCustomMessage = permanentlyDeniedMessage != null;

    if (!hasCustomMessage) {
      logger.d('모든 거부된 권한이 영구 거부 상태이고 기본 메시지 사용. 권한 요청 화면을 표시하지 않고 현재 상태 반환: $results');
      return results;
    } else {
      logger.d('영구 거부된 권한이 있지만 커스텀 메시지가 제공되어 설정 유도 화면 표시');
      // 아래 권한 요청 화면 표시 로직으로 계속 진행
    }
  }

  // 권한 요청 화면 표시
  logger.d('권한 요청 화면 표시. 필요 권한: ${permissionMap.keys.toList()}');
  if (!context.mounted) return results;
  final requestResult = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PermissionRequestView(
        permissionMap: permissionMap,
        mainTitle: mainTitle,
        description: description,
        approveButtonText: approveButtonText,
        rejectButtonText: rejectButtonText,
        settingsButtonText: settingsButtonText,
        permanentlyDeniedMessage: permanentlyDeniedMessage,
      ),
    ),
  );

  // 권한 요청 결과 처리
  if (requestResult is Map<PermissionType, PermissionStatus>) {
    logger.d('권한 요청 결과: $requestResult');
    return requestResult;
  } else {
    // 만약 예상치 못한 결과 타입이 반환되면 기존 결과 사용
    logger.e('권한 요청 결과가 예상된 형식이 아님: $requestResult');
    return results;
  }
}
