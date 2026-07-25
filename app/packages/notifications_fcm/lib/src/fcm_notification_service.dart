import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:utils/utils.dart';

import 'fcm_config.dart';

/// Firebase 백그라운드 메시지 핸들러
///
/// 앱이 백그라운드 또는 종료 상태일 때 Firebase Cloud Messaging 메시지를 처리합니다.
/// 이 함수는 반드시 최상위 레벨 함수여야 하며, 익명 함수가 아니어야 합니다.
///
/// @param message 수신된 Firebase 원격 메시지
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.d('Handling a background message: ${message.messageId}');
  // 백그라운드에서 메시지 처리
  // 필요한 경우 로컬 알림 표시
}

/// Firebase Cloud Messaging 알림을 관리하는 서비스
///
/// FCM 푸시 알림의 수신, 토큰 관리, 토픽 구독 등을 처리합니다.
///
/// 주요 기능:
/// - FCM 토큰 획득 및 저장
/// - FCM 메시지 리스너 설정 (포그라운드/백그라운드)
/// - 로컬 알림 표시 (FCM 메시지용)
/// - FCM 권한 관리
/// - 토픽 구독/해제
///
/// 싱글톤 패턴을 사용하여 앱 전체에서 하나의 인스턴스만 사용됩니다.
class FcmNotificationService {
  static final FcmNotificationService _instance = FcmNotificationService._internal();
  factory FcmNotificationService() => _instance;
  FcmNotificationService._internal();

  static FcmConfig _config = const FcmConfig.disabled();

  /// 앱이 부팅 시점에 기능 플래그를 주입한다. 호출 전에는 initialize가 no-op.
  static void configure(FcmConfig config) {
    _config = config;
  }

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  String? _fcmToken;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// 현재 FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;

  /// FCM 서비스를 초기화합니다.
  ///
  /// Firebase Messaging이 활성화되어 있을 때만 초기화를 수행합니다.
  /// 1. FirebaseMessaging 인스턴스 초기화
  /// 2. 백그라운드 메시지 핸들러 설정
  /// 3. 로컬 알림 플러그인 초기화
  /// 4. FCM 토큰 획득 및 저장
  /// 5. FCM 메시지 리스너 설정
  /// 6. 종료 상태에서 알림 클릭으로 앱이 열렸는지 확인
  Future<void> initialize() async {
    if (!_config.firebaseEnabled || !_config.messagingEnabled) {
      return;
    }

    try {
      // FirebaseMessaging 인스턴스 초기화
      _messaging = FirebaseMessaging.instance;
      // 백그라운드 메시지 핸들러 설정
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 로컬 알림 초기화 (FCM용)
      await _initializeLocalNotifications();

      // FCM 토큰 가져오기
      await _getAndSaveFCMToken();

      // 토큰 리프레시 리스너
      _messaging?.onTokenRefresh.listen(_onTokenRefresh);

      // FCM 메시지 리스너 설정
      _setupFCMMessageListeners();

      // 종료된 상태에서 알림 클릭으로 앱이 열렸는지 확인
      final initialMessage = await _messaging?.getInitialMessage();
      if (initialMessage != null) {
        _handleFCMMessageClick(initialMessage);
      }

      _isInitialized = true;
      logger.d('FCM notification service initialized');
    } catch (e) {
      logger.e('Failed to initialize FCM notifications: $e');
    }
  }

  // FCM 토큰 가져오기 및 저장
  Future<void> _getAndSaveFCMToken() async {
    try {
      // iOS에서는 APNs 토큰이 있어야 FCM 토큰을 받을 수 있음
      if (Platform.isIOS) {
        final apnsToken = await _messaging?.getAPNSToken();
        if (apnsToken == null) {
          logger.w('APNs token not available yet');
          // 나중에 다시 시도
          Future.delayed(const Duration(seconds: 5), _getAndSaveFCMToken);
          return;
        }
      }

      _fcmToken = await _messaging?.getToken();
      if (_fcmToken != null) {
        logger.d('FCM Token: $_fcmToken');
        // [P1-16.5b 확정] 서버측 토큰 저장 없음 — local-only/서버 0줄
        // 원칙(docs/MODULES.md §1). 개별 타깃 푸시는 비지원, 푸시는
        // 토픽 구독 브로드캐스트 + FCM 콘솔 캠페인으로 운영한다.
        // 개별 타깃이 필요해지는 포크는 Firestore Spark 한도 내 저장을
        // 직접 배선할 것 (이 지점 + _onTokenRefresh + requestFCMPermission).
      }
    } catch (e) {
      logger.e('Failed to get FCM token: $e');
    }
  }

  // 토큰 리프레시 처리 (서버측 저장 없음 — 위 [P1-16.5b 확정] 참조)
  void _onTokenRefresh(String token) async {
    logger.d('FCM Token refreshed: $token');
    _fcmToken = token;
  }

  // 로컬 알림 초기화 (FCM용)
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationClick,
    );

    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      await _createAndroidNotificationChannel();
    }
  }

  // Android 알림 채널 생성
  Future<void> _createAndroidNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // FCM 메시지 리스너 설정
  void _setupFCMMessageListeners() {
    // 포그라운드 메시지
    _onMessageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드에서 알림 클릭
    _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleFCMMessageClick);
  }

  // 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) async {
    logger.d('Foreground message received: ${message.messageId}');

    // 로컬 알림으로 표시
    await _showLocalNotification(message);
  }

  // FCM 메시지 클릭 처리
  void _handleFCMMessageClick(RemoteMessage message) {
    logger.d('FCM Message clicked: ${message.messageId}');

    // 메시지 데이터에 따라 적절한 화면으로 네비게이션
    final data = message.data;
    if (data['type'] == 'subscription') {
      // 구독 화면으로 이동
      // rootNavigatorKey.currentContext?.go('/subscription');
    } else if (data['type'] == 'habit') {
      // 특정 습관 화면으로 이동
      // final habitId = data['habitId'];
      // rootNavigatorKey.currentContext?.go('/habit/$habitId');
    }
  }

  // 로컬 알림 표시 (FCM용)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      Random().nextInt(100000), // 랜덤 ID
      notification.title ?? 'New Notification',
      notification.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  // 로컬 알림 클릭 (FCM용)
  void _onLocalNotificationClick(NotificationResponse response) {
    logger.d('Local FCM notification clicked: ${response.payload}');
    // 페이로드 파싱하여 적절한 처리
  }

  // FCM 권한 요청
  Future<bool> requestFCMPermission() async {
    try {
      final settings = await _messaging?.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings == null) {
        logger.w('FCM Permission request returned null');
        return false;
      }

      logger.d('FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 권한이 허용되면 FCM 토큰 업데이트
        await _getAndSaveFCMToken();
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        // iOS에서 임시 권한
        return true;
      }

      return false;
    } catch (e) {
      logger.e('Failed to request FCM permission: $e');
      return false;
    }
  }

  // 현재 FCM 권한 상태 확인
  Future<AuthorizationStatus> getFCMPermissionStatus() async {
    final settings = await _messaging?.getNotificationSettings();
    if (settings == null) {
      return AuthorizationStatus.denied;
    }
    return settings.authorizationStatus;
  }

  // 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging?.subscribeToTopic(topic);
      logger.d('Subscribed to topic: $topic');
    } catch (e) {
      logger.e('Failed to subscribe to topic: $e');
    }
  }

  // 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging?.unsubscribeFromTopic(topic);
      logger.d('Unsubscribed from topic: $topic');
    } catch (e) {
      logger.e('Failed to unsubscribe from topic: $e');
    }
  }

  // 배지 업데이트 (iOS)
  Future<void> updateBadgeCount(int count) async {
    if (Platform.isIOS) {
      // iOS에서는 직접 배지 업데이트 가능
      // Android에서는 알림과 함께만 가능
    }
  }

  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
  }
}
