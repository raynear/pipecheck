# ⚙️ 프로젝트 설정 가이드

프로덕션 준비를 위한 필수 설정들을 안내합니다.

## 🔥 Firebase 설정

### 1. Firebase 프로젝트 생성

```bash
# Firebase CLI 설치
npm install -g firebase-tools

# 로그인
firebase login

# 프로젝트 생성
firebase projects:create my-app-id --display-name "My App"
```

### 2. iOS 설정

1. [Firebase Console](https://console.firebase.google.com)에서 iOS 앱 추가
2. Bundle ID 입력: `com.mycompany.myapp`
3. `GoogleService-Info.plist` 다운로드
4. `app/ios/Runner/` 폴더에 파일 추가
5. Xcode에서 파일을 프로젝트에 추가 (Add Files to "Runner")

### 3. Android 설정

1. Firebase Console에서 Android 앱 추가
2. Package name 입력: `com.mycompany.myapp`
3. SHA-1 fingerprint 추가 (선택사항, Google Sign-In 필요시 필수)
4. `google-services.json` 다운로드
5. `app/android/app/` 폴더에 파일 추가

### 4. FlutterFire 설정

```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# 설정 실행
flutterfire configure

# 플랫폼 선택 및 설정 자동화
```

## 🌊 Supabase 설정 (철거됨)

> Supabase는 P1-16.5a에서 전면 철거되었습니다 — 백엔드는 local-only Drift가 공식 기본, 서버 인증은 Firebase Auth(email) 전환 예정(P1-16.5b)입니다. 운영 기준: docs/MODULES.md §5.

## 📱 푸시 알림 설정 (FCM)

### 1. iOS APNs 설정

#### Apple Developer Console
1. [Apple Developer](https://developer.apple.com) 접속
2. Keys 메뉴에서 새 Key 생성
3. Apple Push Notifications service (APNs) 활성화
4. `.p8` 파일 다운로드 및 Key ID 저장

#### Firebase Console
1. 프로젝트 설정 → 클라우드 메시징
2. iOS 앱 구성에서 APNs 인증 키 업로드
3. Key ID와 Team ID 입력

### 2. iOS 프로젝트 설정

```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter
import Firebase
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ application: UIApplication, 
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
```

### 3. Android 설정

```xml
<!-- app/android/app/src/main/AndroidManifest.xml -->
<manifest>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    
    <application>
        <!-- FCM 기본 채널 -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />
            
        <!-- FCM 아이콘 -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
    </application>
</manifest>
```

### 4. Flutter 코드 설정

```dart
// app/lib/core/services/notification/notification_service.dart
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  static Future<void> initialize() async {
    // 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // FCM 토큰 획득
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      
      // 토큰을 서버에 저장
      await _saveTokenToServer(token);
      
      // 토큰 갱신 리스너
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToServer);
      
      // 메시지 수신 리스너
      FirebaseMessaging.onMessage.listen(_handleMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);
    }
  }
  
  static Future<void> _saveTokenToServer(String? token) async {
    if (token != null) {
      // TODO: 서버 백엔드 도입 시 토큰 저장 구현
      // (Supabase는 P1-16.5a에서 철거 — 현재 local-only, docs/MODULES.md §5)
    }
  }
}
```

## 🔐 환경 변수 관리

### 현행: 루트 3파일 + 생성 산출물

사용자가 손으로 편집하는 설정 파일은 루트 **3개뿐**입니다:

| 파일 | 역할 | git |
|------|------|-----|
| `project.yaml` | 앱 정체성 (이름, package, 스토어, AdMob 앱 ID + `admob.units`, IAP) | 추적 |
| `app_config.yaml` | 인프라 (`services.firebase` 등 서비스/플랫폼/서명) | 추적 |
| `.env` | 진짜 시크릿 전용 (fastlane/CLI만 소비, 앱 번들 포함 금지) | 무시 |

`app/config/env/.env.{debug,profile,release}`는 `./build` · `./run gen-env` · `./init`이 생성하는 **산출물**입니다 (손 편집 금지, gitignore). debug/profile에는 Google 테스트 광고 ID가 자동 주입되고, release에는 `admob.units` 실값이 들어가며, 비어 있으면 preflight가 release를 차단합니다. 자세한 보안 원칙은 [EXTERNAL_SETUP.md의 '환경 변수 보안'](../../guides/EXTERNAL_SETUP.md) 참고.

### Phase 2 계획 (dart-define 전환) — 미구현

> ⚠️ 아래 구조(`.env.development`/`.env.production`, `env_config.dart`, `--dart-define` 주입)는 **현재 코드베이스에 존재하지 않습니다.** dotenv 산출물 파이프라인이 릴리즈에서 검증된 후 도입을 검토하는 Phase 2 계획안입니다 (docs/CONFIG_CONSOLIDATION_PLAN.md §4 참고).

```dart
// (Phase 2 계획) lib/core/config/env_config.dart
class EnvConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get isDevelopment => const bool.fromEnvironment('DEV', defaultValue: false);
  static bool get isProduction => const bool.fromEnvironment('PROD', defaultValue: false);
}

// 빌드 시 환경 변수 주입
// flutter run --dart-define=API_BASE_URL=https://api.myapp.com
```

## 🔑 인증 설정

### 1. Google Sign-In

```yaml
# pubspec.yaml
dependencies:
  google_sign_in: ^6.1.5
```

```dart
// iOS: Info.plist에 URL Scheme 추가
// Android: SHA-1 fingerprint Firebase Console에 추가

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);

Future<User?> signInWithGoogle() async {
  final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
  if (googleUser == null) return null;
  
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  
  // 서버 인증 연동: Supabase는 P1-16.5a에서 철거됨 — Firebase Auth(email) 전환 예정(P1-16.5b)
  // googleAuth.idToken을 전환 후 서버 인증에 사용 (docs/MODULES.md §5)
  return null; // TODO(P1-16.5b)
}
```

### 2. Apple Sign-In

```yaml
# pubspec.yaml
dependencies:
  sign_in_with_apple: ^5.0.0
```

```dart
// iOS: Xcode에서 Sign in with Apple capability 추가
// Android: 별도 설정 필요

Future<User?> signInWithApple() async {
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
  );
  
  // 서버 인증 연동: Supabase는 P1-16.5a에서 철거됨 — Firebase Auth(email) 전환 예정(P1-16.5b)
  // credential.identityToken을 전환 후 서버 인증에 사용 (docs/MODULES.md §5)
  return null; // TODO(P1-16.5b)
}
```

## 📊 Analytics 설정

### Firebase Analytics

```dart
// 현행 구현: app/lib/core/services/firebase_service.dart (FirebaseService)
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  static Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
  
  static Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }
  
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
}
```

## 🗄️ 로컬 데이터베이스 설정

### Drift 설정

```dart
// app/lib/data/datasources/local/database/database.dart
@DriftDatabase(tables: [Users, Products])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
  
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(path.join(dbFolder.path, 'app.db'));
      return NativeDatabase(file);
    });
  }
}
```

## 🔗 다음 단계

- [배포 가이드](./deployment.md)
- [외부 서비스 설정 가이드](../../guides/EXTERNAL_SETUP.md)
- [Fastlane 자동화](../../guides/FASTLANE_SETUP.md)