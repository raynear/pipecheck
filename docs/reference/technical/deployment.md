# 🚀 배포 가이드

iOS App Store와 Google Play Store 배포를 위한 완전한 가이드입니다. Fastlane 자동화로 배포 시간을 92% 단축했습니다.

## 📱 iOS 배포

### 1. Apple Developer 계정 설정

```bash
# Fastlane 인증서 자동 설정 (Phase 1-2 완료)
fastlane setup_certs  # 모든 인증서 자동 설정

# iOS 서명 설정 (필요시)
fastlane setup_ios_signing

# 인증서 검증
fastlane check_certificates
```

### 2. App Store Connect 앱 생성

```bash
# ./init의 "스토어 앱 등록" 스텝이 produce로 자동 생성한다
# (tools/cli register_store_apps_step — ASC API 키/Apple ID 필요)
./init

# 또는 수동으로 App Store Connect에서 생성
# 1. https://appstoreconnect.apple.com 접속
# 2. My Apps → + → New App
# 3. 필요 정보 입력
```

### 3. iOS 빌드 및 업로드

```bash
# 통합 배포 프로세스 (자동화 완료) — 프로젝트 루트에서 실행
./deploy  # 테스트 + 빌드 + 업로드

# 개별 명령어
fastlane bump_version type:patch  # 버전 증가
fastlane test  # 테스트 실행
fastlane generate_release_notes  # 릴리스 노트 생성
fastlane build_and_upload_ios  # iOS 업로드
```

### 4. 메타데이터 업로드

```bash
# 다국어 메타데이터 자동 관리 (Phase 2 완료)
fastlane upload_localized_metadata  # 4개 언어 지원

# 릴리스 메타데이터 준비 (스켈레톤 생성)
fastlane initialize_metadata_ios

# 메타데이터 업로드
fastlane upload_metadata_ios
```

## 🤖 Android 배포

### 1. Google Play Console 설정

```bash
# 서비스 계정 키 생성
# 1. Google Cloud Console 접속
# 2. IAM & Admin → Service Accounts
# 3. Create Service Account
# 4. JSON 키 다운로드 → ~/serviceAccount.json (app_config.yaml google.json_key_file 경로)

# Play Console에서 서비스 계정 권한 부여
# 1. Settings → API access
# 2. Grant access to service account
```

### 2. 앱 서명 설정

```bash
# Keystore 생성
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# key.properties는 ./init이 자동 생성 (app/android/key.properties)
# 비밀번호는 루트 .env의 KEYSTORE_PASSWORD/KEY_PASSWORD에서 읽음
```

### 3. Android 빌드 및 업로드

```bash
# 내부 테스트 트랙 업로드
fastlane build_and_upload_android

# 프로덕션 배포
fastlane build_and_upload_android_production

# 단계별 승격
fastlane promote_to_beta
fastlane promote_to_production
```

### 4. 메타데이터 관리

```bash
# 메타데이터 업로드
fastlane upload_metadata_android

# 인앱 구매 설정
fastlane upload_iap_android
```

## 🔄 배포 자동화 (로컬 전용)

GitHub Actions 기반 배포는 사용하지 않습니다 (Actions 영구 미사용 정책). 통합 배포와 배포 전 검증은 전부 로컬에서 실행합니다.

```bash
# 프로젝트 루트에서 원버튼 배포 (preflight → build → upload)
./deploy

# 배포 전 검증만 따로 실행
./run preflight
```

## 📊 버전 관리 (Fastlane 자동화)

### 1. 버전 번호 체계

```yaml
# pubspec.yaml
version: 1.2.3+45
# 1.2.3 = 사용자에게 보이는 버전
# 45 = 빌드 번호 (자동 증가)
```

### 2. 🚀 Fastlane 자동 버전 관리

```bash
# Semantic Versioning 자동화
fastlane bump_version type:patch    # 1.2.3 → 1.2.4 (버그 수정)
fastlane bump_version type:minor    # 1.2.3 → 1.3.0 (새 기능)
fastlane bump_version type:major    # 1.2.3 → 2.0.0 (주요 변경)

# iOS 프로젝트 버전 동기화 (pubspec.yaml 기준)
fastlane sync_version_ios

# 릴리스 노트 자동 생성 (Git 커밋 기반)
fastlane generate_release_notes lang:ko  # 한국어
fastlane generate_release_notes lang:en  # 영어
fastlane generate_release_notes lang:ja  # 일본어
fastlane generate_release_notes lang:zh  # 중국어
```

### 3. Git 태그 관리

```bash
# 자동 태그 및 배포 (프로젝트 루트)
./deploy  # 버전 증가 + 태그 + 배포 한번에

# 수동 태그 생성 (필요시)
git tag -a v1.2.3 -m "Release version 1.2.3"
git push origin v1.2.3
```

## 🎯 배포 전 체크리스트

### 자동 검증
```bash
# 배포 전 모든 항목 자동 검증 (./deploy가 자동 수행)
./run preflight
```

### iOS 체크리스트 (자동 검증됨)
- [ ] Bundle ID 확인 ✅ `fastlane validate`
- [ ] 인증서 및 프로비저닝 프로파일 유효성 ✅ `fastlane check_certificates`
- [ ] 앱 아이콘 (1024x1024 포함) ✅ 자동 검증
- [ ] 스플래시 스크린 ✅ 자동 검증
- [ ] 권한 설명 문구 (Info.plist) ✅ 자동 검증
- [ ] 최소 iOS 버전 확인 ✅ 자동 검증
- [ ] 스크린샷 (6.5", 5.5" 필수) ✅ `fastlane generate_screenshots`

### Android 체크리스트 (자동 검증됨)
- [ ] Package Name 확인 ✅ `fastlane validate`
- [ ] 서명 키 백업 ⚠️ 수동 백업 필요
- [ ] 앱 아이콘 (512x512 포함) ✅ 자동 검증
- [ ] 권한 설정 (AndroidManifest.xml) ✅ 자동 검증
- [ ] 최소 SDK 버전 확인 ✅ 자동 검증
- [ ] ProGuard 규칙 ✅ 자동 검증
- [ ] 스크린샷 (폰, 태블릿) ✅ `fastlane generate_screenshots`

### 공통 체크리스트
- [ ] 환경 변수 프로덕션 설정 ✅ `./build`가 자동 생성 (app/config/env/.env.release)
- [ ] API 엔드포인트 확인 ✅ 자동 검증
- [ ] 분석 도구 설정 ✅ 자동 검증
- [ ] 크래시 리포팅 설정 ✅ 자동 검증
- [ ] 개인정보 처리방침 URL ⚠️ 수동 입력 필요
- [ ] 서비스 약관 URL ⚠️ 수동 입력 필요

## 📈 배포 후 모니터링

### 1. Crashlytics 설정

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase Crashlytics
  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  runApp(MyApp());
}
```

### 2. 성능 모니터링

```dart
// Firebase Performance
final trace = FirebasePerformance.instance.newTrace('api_call');
await trace.start();

// API 호출
final response = await http.get(url);

await trace.stop();
```

### 3. 사용자 피드백 수집

```dart
// In-app review
final InAppReview inAppReview = InAppReview.instance;

if (await inAppReview.isAvailable()) {
  inAppReview.requestReview();
}
```

## 🔄 업데이트 관리

### 1. 강제 업데이트

```dart
// 최소 버전 체크
Future<bool> checkMinimumVersion() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.fetchAndActivate();
  
  final minVersion = remoteConfig.getString('minimum_version');
  final currentVersion = packageInfo.version;
  
  return Version.parse(currentVersion) >= Version.parse(minVersion);
}
```

### 2. 점진적 롤아웃

```bash
# Android - Play Console에서 설정
fastlane staged_rollout rollout:0.1  # 10% 롤아웃

# iOS - TestFlight 업로드 (그룹 배정은 App Store Connect에서)
fastlane upload_ios target:beta
```

## 🛡️ 보안 체크리스트

- [ ] API 키 하드코딩 제거
- [ ] 디버그 로그 제거
- [ ] ProGuard/R8 난독화 활성화
- [ ] 인증서 pinning (선택사항)
- [ ] 루팅/탈옥 감지 (선택사항)
- [ ] 안전한 저장소 사용 (flutter_secure_storage)

## 📱 스토어 최적화 (ASO)

### 키워드 최적화
- 제목에 주요 키워드 포함
- 부제목/짧은 설명 활용
- 키워드 필드 최적화 (iOS)

### 시각적 자산
- 고품질 스크린샷
- 앱 미리보기 비디오
- 매력적인 앱 아이콘

### 지역화
```bash
# 다국어 메타데이터 (P0-8 SSOT: <root>/metadata/{ios,android})
metadata/ios/
├── en-US/
├── ko/
└── ja/
metadata/android/
├── en-US/
├── ko-KR/
└── ja-JP/
```

## 🚀 Fastlane 배포 명령어 총정리

### 일반 배포 프로세스
```bash
# 📦 완전 자동 배포 (테스트 + 빌드 + 업로드) — 프로젝트 루트에서
./deploy --bump patch  # 패치 버전으로 배포
./deploy --bump minor  # 마이너 버전으로 배포
./deploy --bump major  # 메이저 버전으로 배포 (스크린샷은 ./run screenshot)

# 🎯 단계별 배포
fastlane test                      # 1. 테스트 실행
fastlane bump_version type:patch   # 2. 버전 증가
fastlane generate_release_notes    # 3. 릴리스 노트 생성
fastlane build_and_upload          # 4. 빌드 및 업로드
```

### iOS 전용 명령어
```bash
# 🍎 iOS 배포
fastlane setup_certs               # 인증서 설정
fastlane build_and_upload_ios      # TestFlight 업로드
fastlane upload_metadata_ios       # 메타데이터 업로드
fastlane generate_screenshots      # 스크린샷 생성

# 📱 iOS 인증서 관리
fastlane match development         # 개발 인증서
fastlane match appstore           # 배포 인증서
fastlane check_certificates        # 인증서 검증
```

### Android 전용 명령어
```bash
# 🤖 Android 배포
fastlane build_and_upload_android  # 내부 테스트 업로드
fastlane promote_to_beta          # 베타로 승격
fastlane promote_to_production    # 프로덕션 배포
fastlane upload_metadata_android  # 메타데이터 업로드

# 🔑 Android 서명
fastlane sha1                     # SHA-1 fingerprint 확인
```

### 다국어 지원 (Phase 2 완료)
```bash
# 🌍 다국어 메타데이터 관리
fastlane upload_localized_metadata  # 4개 언어 자동 업로드
fastlane generate_release_notes lang:ko  # 한국어 릴리스 노트
fastlane generate_release_notes lang:en  # 영어 릴리스 노트
fastlane generate_release_notes lang:ja  # 일본어 릴리스 노트
fastlane generate_release_notes lang:zh  # 중국어 릴리스 노트
```

### 검증 및 모니터링
```bash
# ✅ 배포 전 검증
fastlane validate                 # 프로젝트 설정 검증
./run preflight                  # 릴리스 준비 검증 (로컬)
fastlane test coverage:true      # 테스트 커버리지 확인

# 📊 배포 후 모니터링
fastlane check_release_status    # 릴리스 상태 확인
fastlane download_dsyms          # iOS 디버그 심볼 다운로드
```

## IAP JSON 계약 (P1-17a)

계약 소유자는 **소비자**(fastlane `upload_iap_ios`/`upload_subscription_ios`/
`upload_iap_android`)이고, 생산자 2곳(`./init`의 setupStoreInfoStep,
`./run iap-register`)은 `tools/cli/lib/commands/iap/iap_contract_writer.dart`
를 통해서만 직렬화한다. 상품 ID는 `<id>.<package_name>` 최종형.

- iOS: `metadata/in_app_purchases/ios/<productId>.json` (flat, 파일당 객체 1개)

```json
{
  "product_id": "premium_monthly.com.example.app",
  "type": "auto_renewable_subscription",
  "reference_name": "premium_monthly.com.example.app",
  "pricing": { "tier": 5 },
  "localizations": [
    { "locale": "en-US", "name": "Monthly Premium", "description": "..." }
  ],
  "subscription_duration": "P1M",
  "subscription_family_sharable": false
}
```

- Android: `metadata/in_app_purchases/android/<productId>.json`
  (flat, 파일당 객체 1개 — **배열 금지**)

```json
{
  "productId": "premium_monthly.com.example.app",
  "purchaseType": "subscription",
  "defaultLanguage": "en-US",
  "defaultPrice": { "priceMicros": "4990000", "currency": "USD" },
  "listings": { "en-US": { "title": "Monthly Premium", "description": "..." } },
  "subscriptionPeriod": "P1M"
}
```

`type`은 `non_consumable`/`consumable`/`auto_renewable_subscription`,
`priceMicros`는 tier→USD 매핑의 `round(usd × 1e6)` (미정의 tier는 생성기가
명시 에러). Android **구독**은 업로드 레인이 수동 등록 안내만 출력한다
(Play 구독 API는 별도 — 자동 등록 아님).

## 🔗 다음 단계

- [Fastlane 상세 설정](../../guides/FASTLANE_SETUP.md)
- [문제 해결](../../guides/TROUBLESHOOTING.md)