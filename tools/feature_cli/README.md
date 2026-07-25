# Feature CLI

Flutter BoilerPlate 통합 기능 관리 도구

## 설치

의존성 설치:
```bash
cd tools/feature_cli
dart pub get
```

## 사용법

프로젝트 루트에서 `./feature` 명령어로 실행:

```bash
# 도움말
./feature --help

# 기능 상태 확인
./feature status

# 기능 목록
./feature list              # 토글 가능한 기능 목록
./feature list --features   # 생성된 feature 모듈 목록

# 기능 활성화/비활성화
./feature enable ads        # 광고 기능 활성화
./feature disable ads       # 광고 기능 비활성화
./feature enable ads --dry-run  # 변경 없이 미리보기

# Feature 스캐폴딩 생성
./feature generate -n profile           # 기본 구조 (view만)
./feature generate -n profile --full    # 전체 구조 (model, viewmodel, widgets)
./feature generate -n profile --with-model --with-viewmodel  # 선택적 생성
```

## 명령어

### `status` (st)
현재 기능 플래그 상태를 표시합니다.

### `list` (ls)
- 기본: 토글 가능한 기능 목록
- `--features`: 생성된 feature 모듈 목록

### `enable` (add, on)
기능을 활성화합니다. `AppFeatureConfig`의 플래그를 `true`로 설정합니다.

### `disable` (remove, off)
기능을 비활성화합니다. `AppFeatureConfig`의 플래그를 `false`로 설정합니다.

### `generate` (gen, g)
새 feature 모듈 스캐폴딩을 생성합니다.

옵션:
- `-n, --name`: Feature 이름 (필수)
- `-f, --full`: 전체 구조 생성
- `--with-model`: Model 파일 생성
- `--with-viewmodel`: ViewModel 파일 생성
- `--with-widgets`: Widgets 폴더 생성

## 지원 기능 목록 (15개)

| 기능 | 설명 | 패키지 | 의존성 |
|------|------|--------|--------|
| ads | 광고 | google_mobile_ads | - |
| subscription | 구독/인앱 결제 | in_app_purchase | - |
| firebase | 분석/크래시 | firebase_* | - |
| notification | 알림 | awesome_notifications | - |
| biometric | 생체 인증 | local_auth | - |
| location | 위치 | geolocator, geocoding | - |
| onboarding | 온보딩 | - | - |
| reEngagement | 재참여 알림 | - | notification |
| reminder | 리마인더 알림 | - | notification |
| backgroundNotification | 백그라운드 알림 | - | notification |
| darkMode | 다크 모드 | flex_color_scheme | - |
| multiLanguage | 다국어 지원 | easy_localization | - |
| abTesting | A/B 테스팅 | - | - |
| crashReporting | 크래시 리포팅 | firebase_crashlytics | firebase |
| splashAd | 스플래시 전면 광고 | - | ads |

## 마이그레이션 노트

이 CLI는 기존 두 도구를 대체합니다:
- `tools/feature_generator/` → `./feature generate`
- `tools/feature_manager/` → `./feature enable/disable/status`

기존 도구들은 삭제되었습니다. 모든 기능 관리는 이 CLI를 사용하세요.
