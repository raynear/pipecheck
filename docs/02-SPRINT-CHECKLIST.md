# 🚀 4-Week Sprint Checklist - 아이디어에서 출시까지

> **이 하나의 체크리스트로 모든 것을 실행** - 기획, 개발, 마케팅, 출시 완전 통합
>
> ⚡ 20일 근무일 | 🎯 MVP First | 🤖 AI + Fastlane 자동화

---

## 🎯 시작 전 체크

### 필수 준비물
- [ ] Mac (iOS 개발시) 또는 Windows/Linux (Android만)
- [ ] Flutter stable 최신 설치 (`flutter doctor`)
- [ ] VS Code 또는 Android Studio
- [ ] Git 설치
- [ ] AI 도구 계정 (Claude/ChatGPT)

### 프로젝트 정보
- **프로젝트명**: _________________
- **Bundle ID**: com._________________
- **시작일**: _________________
- **목표 출시일**: _________________ (4주 후)
- **플랫폼**: [ ] iOS [ ] Android [ ] Both
- **팀 규모**: [ ] Solo [ ] 2-3명 [ ] 4-5명

---

# 📅 WEEK 1: 검증과 설계 (Day 1-5)

## Day 1: 아이디어 검증 🔍

### ✅ Morning (4시간)

#### 시장 조사 - AI 프롬프트
```
다음 앱 아이디어를 분석해줘: [아이디어 설명]

1. 시장 규모와 성장률
2. 경쟁 앱 5개와 특징
3. 타겟 사용자 정의
4. 수익 모델 옵션 3개
5. 주요 리스크와 기회

표 형태로 정리해줘.
```
- [ ] 시장 조사 완료
- [ ] 경쟁사 분석 (최소 3개)
- [ ] 타겟 시장 정의

#### 가치 제안 정의
- [ ] 핵심 문제 1문장: _________________
- [ ] 해결책 1문장: _________________
- [ ] 차별점 3개: 
  1. _________________
  2. _________________
  3. _________________

### ⚠️ Go/No-Go 결정점
- [ ] 시장 있음 (최소 10만명)
- [ ] 명확한 문제-해결 fit
- [ ] 기술적 실현 가능
- [ ] **결정**: [ ] GO! [ ] STOP

### ✅ Afternoon (4시간)

#### 사용자 페르소나 - AI 프롬프트
```
[앱 이름]의 사용자 페르소나 3개를 만들어줘:

각 페르소나별로:
- 이름과 나이
- 직업과 라이프스타일
- 현재 겪는 문제점
- 앱을 사용하는 시나리오
- 기대하는 핵심 기능 3개
```
- [ ] 페르소나 3개 생성
- [ ] 사용자 시나리오 작성

#### MVP 기능 정의
- [ ] 필수 기능 (최대 5개):
  1. [ ] _________________
  2. [ ] _________________
  3. [ ] _________________
  4. [ ] _________________
  5. [ ] _________________
- [ ] 수익 모델 선택:
  - [ ] 무료 + 광고
  - [ ] 구독
  - [ ] 일회성 구매

---

## Day 2: PRD 작성 📝

### ✅ PRD 생성 - AI 프롬프트
```
다음 정보로 Product Requirements Document를 작성해줘:

앱 이름: [이름]
핵심 문제: [문제]
타겟 사용자: [페르소나]
MVP 기능: [기능 리스트]

포함 내용:
1. Executive Summary
2. 기능별 User Story
3. 기술 요구사항
4. 성공 지표 (KPIs)
5. 타임라인

각 기능별로 acceptance criteria 3개씩 포함해줘.
```

### ✅ 기술 스택 결정
- [ ] Frontend: Flutter ✓
- [ ] Backend:
  - [ ] 없음 — local-only Drift (공식 기본)
  - [ ] Firebase (추천 - 빠른 개발)
  - [ ] Custom API
- [ ] Database:
  - [ ] Firestore
  - [ ] SQLite (로컬)
- [ ] 인증:
  - [ ] Firebase Auth
  - [ ] 소셜 로그인 (Google/Apple)

### ✅ 성공 지표 정의
- [ ] 기술 지표:
  - 로드 시간 < 3초
  - 크래시율 < 1%
  - 일일 활성 사용자 > 100명
- [ ] 비즈니스 지표:
  - 다운로드 > 1,000 (첫달)
  - 리텐션 > 20% (7일)
  - 평점 > 4.0

---

## Day 3: 디자인 🎨

### ✅ 와이어프레임 (2시간)
- [ ] 핵심 화면 5개 스케치:
  1. [ ] 스플래시/온보딩
  2. [ ] 로그인/회원가입
  3. [ ] 메인 화면
  4. [ ] 핵심 기능 화면
  5. [ ] 설정/프로필

### ✅ 디자인 시스템 (2시간)
- [ ] 색상 팔레트 (Primary, Secondary, Background)
- [ ] 폰트 선택 (제목, 본문)
- [ ] 아이콘 스타일 결정

### ✅ 로고 생성 - AI 프롬프트
```
앱 로고 디자인 설명:
- 앱 이름: [이름]
- 스타일: [미니멀/모던/플레이풀]
- 색상: [컬러 팔레트]
- 포함 요소: [아이콘/텍스트]

SVG 형식으로 만들 수 있는 간단한 도형 조합으로 설명해줘.
```
- [ ] 로고 생성 (`./run generate-icon` — adlab)
- [ ] 앱 아이콘 변환 (1024x1024)

### ✅ UI 라이브러리 선택 (2시간)
- [ ] Flutter 기본 Material Design
- [ ] 커스텀 디자인 시스템
- [ ] UI 템플릿 구매 검토 ($50-100)

---

## Day 4: 기술 환경 설정 ⚙️

### ✅ 프로젝트 초기화 (4시간)

#### 1. Repository 생성 (BoilerPlate Fork)
```bash
# GitHub에서 boilerplate fork
# 1. https://github.com/[username]/boiler_plate 에서 "Fork" 클릭
# 2. 새 저장소 이름 입력 (예: my_app)
# 3. "Create fork" 클릭

# Fork한 저장소 클론
git clone https://github.com/[your-username]/my_app.git
cd my_app

# (선택) Upstream 연결 - 원본 boilerplate 업데이트 받기 위함
git remote add upstream https://github.com/[original-username]/boiler_plate.git
```
- [ ] GitHub에서 boilerplate Fork
- [ ] Fork한 저장소 클론

#### 2. Flutter 프로젝트 설정
```bash
# ⚠️ 프로젝트 초기 설정 (필수! 가장 먼저 실행)
./init
# → project.yaml + app_config.yaml 기반으로 패키지명, 번들 ID 등 자동 변경

# 변경사항 커밋
git add .
git commit -m "Rename project to MyApp"
git push origin main

# Fastlane 추가 설정 (선택)
fastlane setup

# 설정 검증
fastlane validate
fastlane info
```
- [ ] **프로젝트 초기화 완료** (`./init` 실행)
- [ ] Bundle ID 설정 완료

#### 3. 환경 설정 (루트 3파일 편집)
```yaml
# project.yaml — 광고 사용 시 release용 실제 단위 ID 입력
admob:
  ios_app_id: "ca-app-pub-xxx~yyy"
  android_app_id: "ca-app-pub-xxx~yyy"
  units:
    ios:     { banner: "ca-app-pub-xxx/...", interstitial: "...", ... }
    android: { banner: "ca-app-pub-xxx/...", interstitial: "...", ... }
```
```yaml
# app_config.yaml — 공통 인프라 (서비스 토글 등)
services:
  firebase:
    enabled: true
```
```bash
# 진짜 시크릿만 루트 .env에 (앱 번들에 절대 포함되지 않음)
# 이후 ./build 실행 → app/config/env/.env.{debug,profile,release} 자동 생성
# (debug/profile = Google 테스트 광고 ID 자동, release = admob.units 실값)
```
- [ ] `project.yaml` admob.units 입력 (광고 사용 시)
- [ ] `./build` 실행으로 env 산출물 생성 확인 (수동 생성 금지)

### ✅ 백엔드 설정 (선택적, 필요시)

> ⚠️ **Feature CLI로 필요한 기능만 활성화**
> ```bash
> ./feature status           # 현재 상태 확인
> ./feature enable firebase  # Firebase 활성화
> ```

#### 🔥 Firebase 설정 (`isFirebaseEnabled = true` 인 경우)
```bash
# Firebase 프로젝트 생성
fastlane firebase_config

# 또는 수동
firebase login
flutterfire configure
```
- [ ] Firebase 프로젝트 생성
- [ ] Authentication 활성화 (필요시)
- [ ] Firestore 데이터베이스 생성 (필요시)
- [ ] Analytics 설정 (필요시)

> 💡 Supabase는 P1-16.5a에서 철거됨 — 백엔드는 local-only Drift 기본 + Firebase Auth(email, 16.5b 전환 완료). docs/MODULES.md §5 참조.

#### 📵 백엔드 없이 시작하는 경우
- 로컬 DB(Drift)만 사용 가능
- 나중에 필요시 `./feature enable` 으로 활성화

### ✅ Firebase App Distribution 설정 (테스트 배포)
> 스토어를 거치지 않는 테스트 배포. 로컬에서 distribute 레인을 실행해 테스터에게 배포한다 (CI 자동 배포 없음 — Actions 영구 미사용).

```bash
cd fastlane

# 1. 플러그인 설치 (최초 1회)
bundle install

# 2. iOS Ad Hoc 프로비저닝 생성 (최초 1회)
bundle exec fastlane match adhoc

# 3. 테스트 배포 실행
bundle exec fastlane distribute_android   # Android만
bundle exec fastlane distribute           # iOS + Android
```

**Firebase Console에서:**
1. App Distribution → Get Started
2. Testers & Groups → `qa-testers` 그룹 생성
3. 테스터 이메일 추가

**설정 위치:** `app_config.yaml services.firebase`(service_account_file, tester_groups, testers)

> 자세한 가이드: [EXTERNAL_SETUP.md](guides/EXTERNAL_SETUP.md#firebase-app-distribution-설정)

- [ ] Firebase App Distribution 활성화
- [ ] 테스터 그룹 생성 및 테스터 추가
- [ ] Service Account JSON 경로를 app_config.yaml에 설정
- [ ] Match Ad Hoc 프로파일 생성
- [ ] distribute 레인 실행해 배포 확인

### ✅ 개발자 계정 (출시 계획에 따라 선택)
- [ ] Apple Developer ($99/year) - iOS 출시 시 필수
- [ ] Google Play Console ($25 일회) - Android 출시 시 필수
- [ ] 계정 정보 저장

---

## Day 5: 마케팅 기초 & 계획 📱

### ✅ 도메인 & 브랜딩 (2시간)
- [ ] 도메인 구매 (Namecheap, GoDaddy)
- [ ] 이메일 설정 (hello@domain.com)
- [ ] 브랜드 가이드라인 문서

### ✅ 소셜 미디어 계정 (2시간)
- [ ] Twitter/X (@appname)
- [ ] Instagram (@appname)
- [ ] LinkedIn 회사 페이지
- [ ] TikTok (선택)

### ✅ 랜딩 페이지 (2시간)
- [ ] 템플릿 선택 (Carrd, Webflow)
- [ ] 대기자 명단 폼 추가
- [ ] 기본 정보 작성

### ✅ 앱 스토어 최적화 (ASO) - AI 프롬프트
```
[앱 이름]의 앱 스토어 최적화:

1. 짧은 설명 (80자)
2. 긴 설명 (4000자)
3. 키워드 100개 (관련성 순)
4. 카테고리 추천
5. 경쟁 앱과 차별화 포인트

각 스토어(iOS/Android)별로 작성해줘.
```
- [ ] 앱 설명 초안 작성
- [ ] 키워드 리스트 생성

### ✅ 스프린트 계획 (2시간)
- [ ] Week 2 일일 목표 설정
- [ ] 기능 우선순위 확정
- [ ] 리스크 식별 및 대응 계획

**🎉 Week 1 완료: 검증됨, 설계됨, 준비됨!**

---

# 📅 WEEK 2: 핵심 개발 (Day 6-10)

## Day 6: BoilerPlate 커스터마이징 🏗

### ✅ 기존 구조 확인 (1시간)
```bash
# boilerplate 구조 (이미 설정됨!)
lib/
├── config/           # 앱 설정, 기능 플래그
├── core/             # 서비스, 위젯, 라우터, 테마
├── data/             # DB, Repository
└── features/         # 기능별 모듈 (auth, home, settings 등)
```
- [ ] 기존 폴더 구조 확인
- [ ] CLAUDE.md 읽고 코드 패턴 이해

### ✅ 필요한 기능 활성화/비활성화 (1시간)
```bash
# 현재 상태 확인
./feature status

# 수익화 기능
./feature enable ads           # 광고 (AdMob)
./feature enable splashAd      # 스플래시 전면 광고
./feature enable subscription  # 구독/인앱 결제

# 알림 기능
./feature enable notification  # 기본 알림
./feature enable reminder      # 리마인더 알림
./feature enable reEngagement  # 재참여 알림

# 백엔드
./feature enable firebase      # Firebase 활성화

# 기타
./feature enable darkMode      # 다크 모드
./feature disable location     # 불필요하면 비활성화

# 사용 가능한 기능 목록
./feature list
```
- [ ] 수익화 기능 결정 (ads, subscription)
- [ ] 백엔드 선택 (firebase — local-only 기본이면 생략)
- [ ] 알림 기능 결정
- [ ] `app_feature_config.dart` 확인

### ✅ 테마 커스터마이징 (2시간)
```bash
# 디자인 시스템 파일 위치
lib/core/design/
├── design_system.dart       # 디자인 시스템 정의 (색상/타이포/테마)
├── design_context.dart      # 컨텍스트 확장
├── material3/               # Material 3 프리셋
└── bold_minimalism/         # 대체 프리셋
```
- [ ] Primary/Secondary 색상 변경
- [ ] 폰트 변경 (필요시)
- [ ] 다크모드 설정

### ✅ 기본 화면 수정 (2시간)
- [ ] `home_view.dart` 메인 화면 수정
- [ ] `splash_view.dart` 스플래시 수정
- [ ] 온보딩 화면 수정 (필요시)

### ✅ 라우팅 확인 (1시간)
```dart
// lib/core/router.dart
// 이미 설정된 라우트 확인 및 수정
GoRoute(
  path: Routes.home,
  builder: (context, state) => const HomeView(),
),
```
- [ ] 기존 라우트 확인
- [ ] 필요한 라우트 추가 계획

### 📝 코드 생성 (첫 빌드)
```bash
./build   # Freezed, Drift, Riverpod 코드 생성 (프로젝트 루트에서)
```
- [ ] 첫 빌드 성공 확인

---

## Day 7: 인증 시스템 설정 🔐

> ⚠️ **BoilerPlate에 인증 시스템이 이미 구현되어 있습니다!**

### ✅ 인증 방식 결정 (30분)
```bash
# 현재 인증 설정 확인
./feature status | grep -E "(biometric|firebase)"
```

| 인증 방식 | 플래그 | 용도 |
|----------|--------|------|
| 생체인증 | `isBiometricAuthEnabled` | PIN/Face ID |
| 이메일 | `isEmailAuthEnabled` | Firebase Auth 이메일 로그인/가입 (16.5b 전환 완료 — Firebase 콘솔에서 Email/Password 활성화 필요) |
| Firebase | `isFirebaseEnabled` | Firebase 서비스 전반 (이메일 인증의 전제 조건) |

- [ ] 인증 방식 결정
- [ ] 해당 기능 활성화 (`./feature enable ...`)

### ✅ 인증 UI 커스터마이징 (2시간)
```bash
# 기존 인증 화면 위치
lib/features/auth/
├── views/auth_view.dart       # 인증 메인 화면
└── view_models/auth_view_model.dart
```
- [ ] 로고/브랜딩 변경
- [ ] 색상/스타일 커스터마이징
- [ ] 문구 수정

> 💡 Supabase 인증은 P1-16.5a에서 철거됨 — 서버 인증은 Firebase Auth(email, P1-16.5b 전환 완료), docs/MODULES.md §5 참조.

### ✅ 인증 로직 설정 (Firebase 사용시, 2시간)
```bash
# Firebase 활성화
./feature enable firebase
flutterfire configure
```
- [ ] `firebase_options.dart` 생성
- [ ] Firebase Console에서 Auth 설정

### ✅ 생체인증만 사용하는 경우 (1시간)
```bash
# 기본값: 생체인증 활성화됨
./feature status | grep biometric
```
- [ ] 백엔드 연동 없이 로컬 인증만 사용
- [ ] PIN/Face ID 테스트

### 📝 코드 생성 및 테스트
```bash
./build
flutter run
# → 인증 화면 테스트
```
- [ ] 인증 플로우 테스트 완료

---

## Day 8: 핵심 기능 1-2 💡

> ⚠️ **Feature CLI로 스캐폴딩 생성 후 커스터마이징**

### ✅ 기능 1: [기능명] (4시간)

#### Feature 스캐폴딩 생성
```bash
# 전체 구조 생성 (model, viewmodel, view, widgets)
./feature generate -n [feature_name] --full

# 또는 필요한 것만 선택
./feature generate -n [feature_name] --with-model --with-viewmodel
```

생성되는 구조:
```
lib/features/[feature_name]/
├── models/[feature_name]_model.dart      # Freezed 모델
├── view_models/[feature_name]_view_model.dart  # Riverpod
├── views/[feature_name]_view.dart        # UI
└── widgets/                              # 전용 위젯
```

- [ ] Feature 스캐폴딩 생성
- [ ] Model 정의 (Freezed)
- [ ] ViewModel 로직 구현
- [ ] View UI 구현
- [ ] 라우트 등록 (`router.dart`)

#### 코드 생성
```bash
./build   # 필수! Model, ViewModel 변경 후 항상 실행
```

### ✅ 기능 2: [기능명] (4시간)
```bash
./feature generate -n [feature_name_2] --full
```
- [ ] Feature 스캐폴딩 생성
- [ ] Model/ViewModel/View 구현
- [ ] `./build` 실행
- [ ] 라우트 등록

### ✅ 데이터 모델 (Freezed 패턴)
```dart
// lib/features/[name]/models/[name]_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '[name]_model.freezed.dart';
part '[name]_model.g.dart';

@freezed
class [Name]Model with _$[Name]Model {
  const factory [Name]Model({
    required String id,
    required String title,
    @Default(false) bool isActive,
  }) = _[Name]Model;

  factory [Name]Model.fromJson(Map<String, dynamic> json) =>
      _$[Name]ModelFromJson(json);
}
```
- [ ] Freezed 모델 정의
- [ ] `./build`로 코드 생성
- [ ] copyWith 사용 (immutable)

### ✅ DB 테이블 추가 (로컬 저장 필요시)
```bash
# 1. 테이블 정의 파일 생성
lib/data/definitions/[name].dart

# 2. 코드 생성 (자동으로 database.dart에 등록됨)
./build
```
- [ ] 테이블 정의 (`lib/data/definitions/`)
- [ ] `./build` 실행
- [ ] 자동 생성된 Repository 사용

---

## Day 9: 핵심 기능 3-4 🚀

### ✅ 기능 3: [기능명] (4시간)
```bash
./feature generate -n [feature_name_3] --full
```
- [ ] Feature 스캐폴딩 생성
- [ ] ViewModel 상태 관리 구현
- [ ] View UI 구현
- [ ] 기존 서비스 활용 (아래 참조)
- [ ] `./build` 실행

### ✅ 기능 4: [기능명] (선택, 4시간)
```bash
./feature generate -n [feature_name_4] --full
```
- [ ] Feature 스캐폴딩 생성
- [ ] 구현 및 코드 생성

### ✅ 기존 서비스 활용
> BoilerPlate에 이미 구현된 서비스들:

| 서비스 | 위치 | 용도 |
|--------|------|------|
| SnackbarService | `core/services/snackbar_service.dart` | 피드백 메시지 |
| AdService | `core/services/ad/ad_service.dart` | 광고 표시 (Banner, Interstitial) |
| NotificationService | `core/services/notification/notification_service.dart` | 로컬/푸시 알림 |
| FirebaseService | `core/services/firebase_service.dart` | Analytics, Crashlytics |
| AuthenticationService | `core/services/authentication_service.dart` | 생체인증 (PIN/Face ID) |
| InAppPurchaseService | `core/services/in_app_purchase_service.dart` | 구독, IAP |
| RemoteConfigService | `core/services/remote_config_service.dart` | Firebase Remote Config |
| ABTestService | `core/services/ab_test_service.dart` | A/B 할당 + RC 킬스위치 |
| BadgeService | `core/services/badge_service.dart` | 배지 시스템 |
| ForceUpdateService | `core/services/force_update_service.dart` | 강제 업데이트 |
| AppReviewService | `core/services/app_review_service.dart` | 앱 리뷰 요청 |
| NetworkStatusService | `core/services/network_status_service.dart` | 네트워크 상태 |
| PrivacyConsentService | `core/services/privacy_consent_service.dart` | ATT/개인정보 동의 |
| ShareService | `core/services/share_service.dart` | 공유 |

```dart
// ViewModel에서 서비스 사용 예시 (수동 Notifier — @riverpod 코드 생성 미사용)
final myViewModelProvider =
    NotifierProvider<MyViewModel, MyState>(MyViewModel.new);

class MyViewModel extends Notifier<MyState> {
  @override
  MyState build() => const MyState();

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      // Repository(Drift) 사용 예시
      final data = await ref.read(myRepositoryProvider).getAll();
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      // 스낵바로 에러 표시
      ref.read(snackbarServiceProvider).showError(e.toString());
      state = state.copyWith(isLoading: false);
    }
  }
}
```

### ✅ 공통 위젯 활용
> `lib/core/widgets/`에 이미 있는 위젯들:

- [ ] `LoadingIndicator` (`core/widgets/loading/`) - 로딩 인디케이터
- [ ] `AppErrorWidget` (`core/widgets/error/`) - 에러 상태
- [ ] `EmptyState` (`core/widgets/feedback/`) - 빈 상태
- [ ] `AdContainer` (`core/widgets/ads/`) - 광고 배너

```dart
// View에서 상태별 처리 예시
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(myViewModelProvider);

  if (state.isLoading) return const LoadingIndicator();
  if (state.error != null) return AppErrorWidget(message: state.error!);
  if (state.items.isEmpty) return const EmptyState();

  return ListView.builder(...);
}
```

---

## Day 10: 통합 & 안정화 🔧

### ✅ 코드 정리 및 빌드 확인 (2시간)
```bash
# 코드 생성 최종 실행
./build

# 린트 검사
cd app
flutter analyze

# 전체 빌드 확인
flutter build apk --debug
flutter build ios --debug --no-codesign
```
- [ ] `./build` 성공
- [ ] `flutter analyze` 경고 해결
- [ ] 빌드 성공 확인

### ✅ 라우트 & 네비게이션 점검 (1시간)
```dart
// lib/core/router.dart 확인
// 모든 Feature의 라우트가 등록되었는지 점검
```
- [ ] 모든 화면 라우트 등록
- [ ] 딥링크 설정 (필요시)
- [ ] 네비게이션 플로우 테스트

### ✅ 기능 플래그 최종 확인 (1시간)
```bash
./feature status
```
- [ ] 활성화된 기능만 포함
- [ ] 불필요한 기능 비활성화
- [ ] `app_feature_config.dart` 정리

### ✅ 통합 테스트 (2시간)
```bash
# 전체 기능 테스트
cd app
flutter test

# 또는 Fastlane 사용
fastlane test type:integration
```
- [ ] 사용자 시나리오 테스트
- [ ] 인증 → 메인 → 기능 플로우
- [ ] 오프라인 모드 테스트 (Drift)

### ✅ 버그 수정 (1시간)
- [ ] 크리티컬 버그 수정
- [ ] UI 이슈 수정
- [ ] 상태 관리 이슈 수정

### ✅ 성능 최적화 (1시간)
```dart
// 이미 BoilerPlate에 구현된 최적화 확인
// - 이미지 캐싱 (cached_network_image)
// - Riverpod의 상태 캐싱
// - Drift의 로컬 캐싱
```
- [ ] 불필요한 리빌드 제거
- [ ] const 위젯 사용
- [ ] 이미지 최적화

### 🧹 프로젝트 정리
```bash
# Flutter 캐시 정리
flutter clean
flutter pub get
./build

# 또는 Fastlane 사용
fastlane clean
```

**🎉 Week 2 완료: MVP 기능 완성!**

---

# 📅 WEEK 3: 완성과 준비 (Day 11-15)

## Day 11: UI/UX 개선 ✨

### ✅ UI 폴리싱 (4시간)
- [ ] 색상 일관성
- [ ] 폰트 일관성
- [ ] 여백 조정
- [ ] 아이콘 정리

### ✅ 애니메이션 (2시간)
```dart
// 간단한 애니메이션
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  // ...
)
```
- [ ] 화면 전환 애니메이션
- [ ] 로딩 애니메이션
- [ ] 마이크로 인터랙션

### ✅ 반응형 레이아웃 (2시간)
- [ ] 태블릿 대응
- [ ] 가로 모드 대응
- [ ] 다크 모드 (선택)

---

## Day 12: 테스트 🧪

### ✅ 디바이스 테스트 (4시간)
```bash
# 여러 디바이스 동시 실행
flutter run -d all
```
- [ ] iPhone (최신, 구형)
- [ ] Android (최신, 구형)  
- [ ] 태블릿 (선택)

### ✅ 시나리오 테스트 (2시간)
- [ ] 신규 사용자 플로우
- [ ] 기존 사용자 플로우
- [ ] 오프라인 모드
- [ ] 에러 상황

### ✅ 버그 수정 (2시간)
- [ ] 크래시 수정
- [ ] UI 버그 수정
- [ ] 로직 오류 수정

---

## Day 13: 스토어 자산 준비 📸

### ✅ 스크린샷 (4시간)
```bash
# 스크린샷 자동 생성 (tools/cli 하니스 — iOS/Android 통합 표준)
./run screenshot
# 산출물: <root>/screenshots/{platform}/{language}/
```
- [ ] iPhone 스크린샷 (5-10장)
- [ ] Android 스크린샷 (4-8장)
- [ ] 태블릿 스크린샷 (선택)

### ✅ 앱 아이콘 (2시간)
- [ ] iOS 아이콘 (모든 사이즈)
- [ ] Android 아이콘 (적응형)
- [ ] 스토어 아이콘

### ✅ 프로모션 자산 (2시간)
- [ ] Feature Graphic (Android)
- [ ] 프로모션 이미지
- [ ] 30초 데모 비디오 (선택)

---

## Day 14: 메타데이터 준비 📝

### ✅ 앱 설명 최종 - AI 프롬프트
```
다음 앱의 스토어 설명을 작성해줘:

앱: [이름]
기능: [MVP 기능 리스트]
타겟: [사용자]

포함 내용:
1. 후킹 첫 문장
2. 주요 기능 3개 (이모지 포함)
3. 사용자 이점
4. 콜 투 액션

iOS와 Android 버전 각각 작성.
```

### ✅ 버전 설정
```bash
# 첫 출시 버전은 project.yaml의 project.version에 직접 설정 (예: "1.0.0")
# 이후 증분은 ./deploy --bump patch|minor|major 또는:
cd fastlane && bundle exec fastlane bump_version type:patch  # type만 지원 (patch/minor/major/build)
```
- [ ] 버전 번호 설정 (project.yaml)
- [ ] 빌드 번호 설정

### ✅ 법적 문서
- [ ] 개인정보 처리방침
- [ ] 이용약관
- [ ] 연령 등급 설정

### ✅ 릴리즈 노트
```
버전 1.0.0 - 첫 출시! 🎉

새로운 기능:
• 기능 1
• 기능 2
• 기능 3

여러분의 피드백을 기다립니다!
```

### 🔄 환경 파일 (자동 생성)
```bash
# 환경 파일은 ./build이 자동 생성 — 수동 전환 명령 없음
./build   # app/config/env/.env.{debug,profile,release} 생성
# release 빌드는 project.yaml admob.units의 실값을 주입 (비면 preflight가 차단)
```

---

## Day 15: 마케팅 콘텐츠 생산 📱

### ✅ 소셜 미디어 콘텐츠 - AI 프롬프트
```
[앱 이름] 출시를 위한 소셜 미디어 포스트 30개 생성:

플랫폼별:
- Twitter: 10개 (280자)
- Instagram: 10개 (캡션)
- LinkedIn: 5개 (전문적)
- TikTok: 5개 (스크립트)

톤: [캐주얼/전문적/재미있는]
해시태그 포함
```
- [ ] 30개 포스트 생성
- [ ] 이미지/그래픽 준비
- [ ] 포스팅 일정 계획

### ✅ 블로그 포스트 - AI 프롬프트
```
[앱 이름] 소개 블로그 포스트 작성:

1. 개발 스토리 (500단어)
2. 주요 기능 소개 (700단어)
3. 사용 가이드 (500단어)

SEO 최적화, 이미지 위치 표시
```
- [ ] 블로그 포스트 3개
- [ ] Medium/Dev.to 발행 준비

### ✅ 이메일 템플릿
- [ ] 웰컴 이메일
- [ ] 출시 공지 이메일
- [ ] 기능 소개 이메일

### ✅ 프레스 릴리즈
- [ ] 제목과 부제
- [ ] 본문 (300-500 단어)
- [ ] 연락처 정보

### ✅ 랜딩 페이지 완성
- [ ] 히어로 섹션
- [ ] 기능 소개
- [ ] 다운로드 버튼
- [ ] 연락처/소셜 링크

**🎉 Week 3 완료: 출시 준비 완료!**

---

# 📅 WEEK 4: 출시와 성장 (Day 16-20)

## Day 16: 스토어 제출 📦

### ✅ 베타 제출 (4시간)

#### 인증서 설정 (최초 1회)
```bash
cd fastlane && bundle exec fastlane setup_certs   # iOS Match + Android Keystore
```

#### 베타 배포 (통합 오케스트레이터)
```bash
# 프로젝트 루트에서 — preflight → build → upload (TestFlight + Play 내부 트랙)
./deploy --target beta
```

- [ ] 인증서 설정
- [ ] `./deploy --target beta` 실행
- [ ] TestFlight / Play 내부 트랙 업로드 확인
- [ ] 내부 테스터 초대

> 개별 레인이 필요하면 `cd fastlane && bundle exec fastlane build_and_upload_ios`(또는 `_android`)를 직접 실행할 수 있다. 통합 경로는 `./deploy`가 표준.

### ✅ 심사 준비
- [ ] 심사 노트 작성
- [ ] 테스트 계정 제공
- [ ] 연락처 정보 확인

---

## Day 17: 출시 준비 🎯

### ✅ 소셜 미디어 예약 (2시간)
- [ ] 출시일 공지 포스트
- [ ] 카운트다운 포스트
- [ ] 기능 소개 포스트
- [ ] Buffer/Hootsuite 예약

### ✅ 이메일 캠페인 (2시간)
- [ ] 대기자 명단 이메일
- [ ] 출시 공지 이메일 작성
- [ ] 발송 예약

### ✅ 커뮤니티 준비 (2시간)
- [ ] Product Hunt 준비
- [ ] Reddit 서브레딧 리스트
- [ ] Facebook 그룹 리스트
- [ ] Discord/Slack 커뮤니티

### ✅ 모니터링 설정 (2시간)
- [ ] Google Analytics
- [ ] Firebase Crashlytics
- [ ] App Store Connect Analytics
- [ ] Play Console Statistics

---

## Day 18: Launch Day! 🚀

### ✅ 스토어 출시 (2시간)

```bash
# 프로덕션 배포 (App Store + Google Play) — 프로젝트 루트에서
./deploy --target production

# iOS 심사 자동 제출까지 (opt-in — 첫 제출은 ASC 항목 미비로 실패 가능)
./deploy --target production --submit-review
```

- [ ] `./deploy --target production` 실행
- [ ] 심사 승인 확인
- [ ] 출시 버튼 클릭 (또는 IOS_AUTOMATIC_RELEASE)
- [ ] 스토어 링크 확인

### ✅ 마케팅 실행 (6시간)

#### 소셜 미디어
- [ ] 출시 공지 포스트 (모든 채널)
- [ ] 스토어 링크 공유
- [ ] 스토리/릴스 업로드
- [ ] 해시태그 캠페인

#### 이메일
- [ ] 출시 이메일 발송
- [ ] 프레스 릴리즈 배포

#### 커뮤니티
- [ ] Product Hunt 등록
- [ ] Reddit 포스팅
- [ ] 관련 커뮤니티 공유

### ✅ 실시간 모니터링
- [ ] 다운로드 추적
- [ ] 크래시 리포트
- [ ] 사용자 피드백
- [ ] 서버 상태

---

## Day 19: 출시 증폭 📈

### ✅ 피드백 대응 (4시간)
- [ ] 앱 스토어 리뷰 응답
- [ ] 소셜 미디어 댓글 응답
- [ ] 이메일 문의 응답
- [ ] 버그 리포트 정리

### ✅ 인플루언서 연락 (2시간)
- [ ] 마이크로 인플루언서 DM
- [ ] 리뷰 요청
- [ ] 프로모 코드 제공

### ✅ 긴급 대응 (2시간)

#### 핫픽스 필요시
```bash
# 패치 버전 증분 + 긴급 배포 (한 번에 — 루트에서)
./deploy --target production --bump patch
```
- [ ] 크리티컬 버그 수정
- [ ] 긴급 업데이트 배포

### ✅ 메트릭 분석
- [ ] Day 1 다운로드
- [ ] 활성 사용자
- [ ] 리텐션
- [ ] 크래시율

---

## Day 20: 분석 & 다음 계획 📊

### ✅ 출시 성과 분석 (4시간)

#### 주요 메트릭
- [ ] 총 다운로드: _______
- [ ] DAU: _______
- [ ] 평점: _______
- [ ] 리뷰 수: _______
- [ ] 크래시율: _______%
- [ ] 리텐션 (Day 1): _______%

#### 마케팅 성과
- [ ] 최고 성과 채널: _______
- [ ] CPI (설치당 비용): _______
- [ ] 전환율: _______%

### ✅ 사용자 피드백 정리 (2시간)
- [ ] 긍정적 피드백 TOP 5
- [ ] 개선 요청 TOP 5
- [ ] 버그 리포트 정리
- [ ] 기능 요청 정리

### ✅ 다음 스프린트 계획 (2시간)

#### 버전 1.1 계획
```bash
# 다음 버전은 배포 시 증분 (./deploy --bump minor) — 별도 환경 전환 명령 없음
# 개발 빌드 환경 파일은 ./build이 자동 생성
./build
```

- [ ] 우선순위 기능 3개
- [ ] 버그 수정 목록
- [ ] 개선사항 목록
- [ ] 타임라인 설정

### 🎉 팀 회고 & 축하
- [ ] 잘한 점 3가지
- [ ] 개선할 점 3가지
- [ ] 배운 점 3가지
- [ ] **축하 파티!** 🍾

---

# 🚀 빠른 참조

## Feature CLI 명령어 모음

### 기능 관리
```bash
./feature status              # 현재 기능 상태 확인
./feature list                # 사용 가능한 기능 목록
./feature enable [기능명]      # 기능 활성화
./feature disable [기능명]     # 기능 비활성화
```

### 사용 가능한 기능 목록 (15개 — `./feature list`가 SSOT)
| 기능명 | 설명 |
|--------|------|
| `ads` | 광고 (Google AdMob) |
| `splashAd` | 스플래시 전면 광고 |
| `subscription` | 구독/인앱 결제 |
| `firebase` | Firebase (Analytics, Crashlytics) |
| `crashReporting` | 크래시 리포팅 |
| `notification` | 알림 (로컬/푸시) |
| `reminder` | 리마인더 알림 |
| `reEngagement` | 재참여 알림 |
| `backgroundNotification` | 백그라운드 알림 |
| `biometric` | 생체 인증 (Face ID/지문) |
| `location` | 위치 서비스 |
| `onboarding` | 온보딩 화면 |
| `darkMode` | 다크 모드 |
| `multiLanguage` | 다국어 지원 |
| `abTesting` | A/B 테스팅 |

### Feature 스캐폴딩 생성
```bash
./feature generate -n [이름]           # 기본 (view만)
./feature generate -n [이름] --full    # 전체 구조
./feature generate -n [이름] --with-model --with-viewmodel  # 선택적
```

### 코드 생성
```bash
./build    # Freezed, Drift, Riverpod 코드 생성 (필수! 프로젝트 루트에서)
```

## Fastlane 명령어 모음

> `cd fastlane && bundle exec fastlane <레인>`으로 실행. 통합 배포는 fastlane이 아니라 루트 `./deploy`.

### 매일 사용
```bash
fastlane run_app        # 앱 실행
fastlane codegen        # 코드 생성 (./build과 동일)
fastlane test           # 테스트
fastlane clean          # 정리
fastlane info           # 프로젝트 정보 확인
```

### 버전 관리
```bash
fastlane bump_version type:patch  # 1.0.0 → 1.0.1 (type: patch/minor/major/build)
fastlane validate                 # 프로젝트 설정 검증
# 환경 파일(.env.*)은 ./build이 자동 생성 — 전환 명령 없음
```

### 인증서 관리
```bash
fastlane setup_certs              # 인증서 설정 (iOS Match + Android Keystore)
fastlane check_certificates       # 인증서 유효성 검증
fastlane show_certificate_info    # 인증서 정보 확인
```

### Firebase/외부 서비스
```bash
fastlane firebase_config  # Firebase 설정 업데이트
fastlane sha1            # SHA1 키 생성 (Google 로그인용)
```

### 테스트 배포 (Firebase App Distribution)
```bash
fastlane distribute           # iOS + Android → Firebase 배포
fastlane distribute_android   # Android만 배포
fastlane distribute_ios       # iOS만 배포
```

### 스토어 빌드/배포
```bash
fastlane build_and_upload target:beta platform:all  # 빌드 및 업로드
# 통합 배포는 프로젝트 루트에서 ./deploy (fastlane deploy 레인은 제거됨)
```

### 스크린샷/메타데이터
```bash
./run screenshot                     # 스크린샷 생성 (tools/cli 하니스 — 통합 표준)
fastlane generate_release_notes      # 릴리스 노트 생성
fastlane upload_localized_metadata   # 다국어 메타데이터 업로드
```

## AI 프롬프트 템플릿

### 시장 조사
```
[앱 아이디어]의 시장 분석:
- 시장 규모와 성장률
- 경쟁사 5개 분석
- 차별화 포인트
- 수익 모델 제안
```

### 콘텐츠 생성
```
[앱 이름] 소셜 미디어 포스트:
- 플랫폼: [Twitter/Instagram/LinkedIn]
- 톤: [캐주얼/전문적]
- 개수: [X개]
- 해시태그 포함
```

### 스토어 최적화
```
[앱 이름] ASO:
- 짧은 설명 (80자)
- 긴 설명 (4000자)  
- 키워드 100개
- 카테고리 추천
```

## 위기 대응

### 빌드 실패
```bash
fastlane clean
flutter pub get
cd ios && pod install
```

### 심사 거절
1. 거절 사유 확인
2. 수정 사항 적용
3. 심사 노트 상세 작성
4. 재제출

### 서버 다운
1. 상태 페이지 업데이트
2. 소셜 미디어 공지
3. 긴급 수정
4. 사후 리포트

---

# 📊 성공 지표

## 최소 성공 (Minimum)
- [ ] 100+ 다운로드
- [ ] 3.5+ 평점
- [ ] 5+ 리뷰
- [ ] 크래시율 <2%

## 목표 성공 (Target)
- [ ] 1,000+ 다운로드
- [ ] 4.0+ 평점
- [ ] 20+ 리뷰
- [ ] Day 7 리텐션 20%

## 대성공 (Stretch)
- [ ] 5,000+ 다운로드
- [ ] 4.5+ 평점
- [ ] 50+ 리뷰
- [ ] 언론 보도
- [ ] Day 7 리텐션 30%

---

# 💡 성공 팁

## Do's ✅
- MVP에 집중 (기능 5개 이하)
- **`./build` 자주 실행** (모델 변경 후 필수!)
- **`./feature` CLI 활용** (기능 관리, 스캐폴딩)
- 기존 서비스/위젯 재사용
- AI 활용 극대화
- 빠른 피드백 반영

## Don'ts ❌
- 완벽주의 추구
- 기능 추가 유혹
- **BoilerPlate 구조 무시** (기존 패턴 따르기)
- **코드 생성 누락** (`./build` 잊지 말기)
- 마케팅 미루기
- 테스트 건너뛰기

## BoilerPlate 핵심 규칙 📋
1. **Model 변경 → `./build`** (Freezed 코드 생성)
2. **ViewModel 변경 → `./build`** (Riverpod 코드 생성)
3. **테이블 추가 → `./build`** (Drift 코드 생성 + 자동 등록)
4. **기능 ON/OFF → `./feature enable/disable`** (15개 기능 지원)
5. **새 Feature → `./feature generate -n [이름] --full`**
6. **환경 설정 → 루트 3파일 (`project.yaml`/`app_config.yaml`/`.env`) 편집 후 `./build`** (env 산출물은 자동 생성, 손 편집 금지)
7. **프로젝트 검증 → `fastlane validate`**

---

# 🎯 체크리스트 완료!

**축하합니다! 4주 만에 앱을 출시했습니다! 🎉**

이제 할 일:
1. 사용자 피드백 수집
2. 데이터 분석
3. 다음 버전 계획
4. 지속적 개선

### 다음 버전 개발 시
```bash
# 새 기능 추가
./feature generate -n [새기능] --full
./build

# 필요한 서비스 활성화 (15개 기능 지원)
./feature enable [기능명]    # ads, subscription, abTesting 등
./feature status            # 현재 상태 확인

# 버전 업데이트
fastlane bump_version type:minor

# 프로젝트 검증
fastlane validate
fastlane info
```

**Remember:**
> "Launch fast, iterate faster"
> "Users will tell you what to build next"
> "Every app starts with version 1.0"
> **"BoilerPlate는 시작점, 커스터마이징은 필수"**

---

**프로젝트 정보 기록**

- 시작일: _______________
- 출시일: _______________
- 첫 다운로드: _______________
- 첫 리뷰: _______________
- 첫 수익: _______________

**팀 서명:** _______________________

---

*이 체크리스트는 지속적으로 업데이트됩니다. 피드백을 환영합니다!*