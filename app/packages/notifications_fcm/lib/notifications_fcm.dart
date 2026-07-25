/// Firebase Cloud Messaging 알림 엔진 (앱-무관, opt-in).
///
/// 앱은 부팅 시점에 [FcmConfig]를 `FcmNotificationService.configure`로 주입한 뒤
/// `FcmNotificationService().initialize()`를 호출한다 (Firebase.initializeApp 이후).
/// 이 패키지는 Firebase를 초기화하지 않고 firebase_messaging을 사용만 한다.
///
/// [AuthorizationStatus](firebase_messaging의 권한 상태 열거형)를 재노출해
/// 앱이 firebase_messaging을 직접 import하지 않고 권한 상태를 다룰 수 있게 한다.
library;

export 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus;

export 'src/fcm_config.dart';
export 'src/fcm_notification_service.dart';
