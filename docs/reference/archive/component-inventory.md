# 컴포넌트 인벤토리 (Component Inventory)

> Flutter BoilerPlate의 UI 컴포넌트 및 서비스 목록

---

## UI 컴포넌트 (core/widgets/)

### 네비게이션 (navigation/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `AdaptiveAppBar` | adaptive_app_bar.dart | 반응형 앱바 |
| `BottomNavBar` | bottom_nav_bar.dart | 하단 네비게이션 바 |
| `DateNavigation` | date_navigation.dart | 날짜 네비게이션 |

### 버튼 (buttons/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `ActionButton` | action_button.dart | 액션 버튼 |
| `AdaptiveButton` | adaptive_button.dart | 반응형 버튼 |
| `AnalyticsButtons` | analytics_buttons.dart | 분석 추적 버튼 |
| `CustomButtons` | custom_buttons.dart | 커스텀 버튼 |
| `FloatingActionButtons` | floating_action_buttons.dart | FAB |
| `IconButtons` | icon_buttons.dart | 아이콘 버튼 |

### 입력 (inputs/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `AdaptiveTextField` | adaptive_text_field.dart | 반응형 텍스트 필드 |
| `FormFields` | form_fields.dart | 폼 필드 컬렉션 |
| `SelectionControls` | selection_controls.dart | 선택 컨트롤 |

### 카드 & 리스트 (cards/, lists/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `CustomCards` | custom_cards.dart | 커스텀 카드 |
| `AdaptiveListTile` | adaptive_list_tile.dart | 반응형 리스트 타일 |
| `InteractiveLists` | interactive_lists.dart | 인터랙티브 리스트 |

### 다이얼로그 & 시트 (dialogs/, sheets/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `AdaptiveDialogs` | adaptive_dialogs.dart | 반응형 다이얼로그 |
| `BadgeDialog` | badge_dialog.dart | 배지 다이얼로그 |
| `IconPickerDialog` | icon_picker_dialog.dart | 아이콘 선택기 |
| `AdaptiveSheets` | adaptive_sheets.dart | 반응형 바텀 시트 |

### 프로그레스 & 로딩 (progress/, loading/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `AdaptiveProgress` | adaptive_progress.dart | 반응형 프로그레스 |
| `LoadingIndicator` | loading_indicator.dart | 로딩 인디케이터 |

### 피드백 & 에러 (feedback/, error/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `EmptyState` | empty_state.dart | 빈 상태 표시 |
| `ErrorWidget` | error_widget.dart | 에러 표시 위젯 |

### 미디어 (media/)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `AudioRecorder` | audio_recorder.dart | 오디오 녹음 위젯 |

### 기타 컴포넌트

| 카테고리 | 컴포넌트 |
|----------|----------|
| **ads/** | `AdContainer` - 광고 컨테이너 |
| **avatars/** | `AdaptiveAvatar` - 반응형 아바타 |
| **badges/** | `AdaptiveBadge` - 반응형 배지 |
| **bars/** | `AdaptiveRatingBar`, `AdaptiveSliders` |
| **chips/** | `AdaptiveChip`, `AdaptiveTag` |
| **tabs/** | `AdaptiveTabs` - 반응형 탭 |
| **toggles/** | `AdaptiveToggle` - 반응형 토글 |
| **common/** | `Accordion`, `Blur`, `ClickableTooltip`, `ScrollingWidget`, `Semantics` |

---

## 서비스 (core/services/)

### 인증 & 보안

| 서비스 | 파일 | 설명 |
|--------|------|------|
| `AuthenticationService` | authentication_service.dart | 인증 로직 |

### 백엔드 연동

| 서비스 | 파일 | 설명 |
|--------|------|------|
| `FirebaseService` | firebase_service.dart | Firebase 초기화 및 서비스 |
| `SupabaseService` | supabase_service.dart | Supabase 클라이언트 |
| `RemoteConfigService` | remote_config_service.dart | 원격 설정 |

### 수익화

| 서비스 | 파일 | 설명 |
|--------|------|------|
| `AdService` | ad_service.dart | AdMob 광고 |
| `InAppPurchaseService` | in_app_purchase_service.dart | 인앱 결제/구독 |

### 알림 & 위젯

| 서비스 | 파일 | 설명 |
|--------|------|------|
| `NotificationService` | notification_service.dart | 알림 관리 |
| `HomeWidgetService` | home_widget_service.dart | 홈 위젯 관리 |

### 미디어 & 파일

| 서비스 | 파일 | 설명 |
|--------|------|------|
| `CameraService` | camera_service.dart | 카메라 접근 |
| `FileService` | file_service.dart | 파일 처리 |
| `ICloudService` | icloud_service.dart | iCloud 동기화 |

### 위치 서비스

| 서비스 | 파일 | 설명 |
|--------|------|------|
| `GeofenceService` | geofence_service.dart | 지오펜싱 |

### 유틸리티

| 서비스 | 파일 | 설명 |
|--------|------|------|
| `BadgeService` | badge_service.dart | 배지 시스템 |
| `FeatureFlagService` | feature_flag_service.dart | 기능 플래그 |
| `ABTestingProvider` | ab_testing_provider.dart | A/B 테스팅 |
| `SnackbarService` | snackbar_service.dart | 스낵바 표시 |

---

## Features 모듈

### auth/

| 파일 | 설명 |
|------|------|
| `views/authentication_view.dart` | 인증 메인 화면 |
| `views/login_view.dart` | 로그인 화면 |
| `view_models/auth_view_model.dart` | 인증 상태 관리 |

### home/

| 파일 | 설명 |
|------|------|
| `views/home_view.dart` | 홈 화면 |
| `view_models/home_view_model.dart` | 홈 상태 관리 |
| `models/home_model.dart` | 홈 데이터 모델 |

### settings/

| 파일 | 설명 |
|------|------|
| `views/settings_view.dart` | 설정 화면 |
| `views/feature_config_view.dart` | 기능 설정 화면 |
| `view_models/settings_view_model.dart` | 설정 상태 관리 |
| `widgets/notification_settings_widget.dart` | 알림 설정 위젯 |

### onboarding/

| 파일 | 설명 |
|------|------|
| `views/onboarding_view.dart` | 온보딩 화면 |
| `view_models/onboarding_view_model.dart` | 온보딩 상태 관리 |

### subscription/

| 파일 | 설명 |
|------|------|
| `views/subscription_view.dart` | 구독 화면 |
| `view_models/subscription_view_model.dart` | 구독 상태 관리 |

### splash/

| 파일 | 설명 |
|------|------|
| `views/splash_view.dart` | 스플래시 화면 |

### permission/

| 파일 | 설명 |
|------|------|
| `views/permission_request_view.dart` | 권한 요청 화면 |

---

## 디자인 시스템 (core/design/)

### 테마

- `AppTheme`: 라이트/다크 테마 정의
- `FlexColorScheme` 기반 동적 테마

### 색상

- `AppColors`: 앱 색상 팔레트
- `ColorScheme`: Material 3 색상 스킴

### 타이포그래피

- `AppTypography`: 텍스트 스타일
- Google Fonts 통합

### 스페이싱

- 일관된 간격 시스템

---

## 내부 패키지

### authentication/

인증 관련 공통 로직 패키지

### utils/

공통 유틸리티 함수 패키지

### ab_testing/

A/B 테스팅 기능 패키지

### geofence_foreground_service/

지오펜싱 포그라운드 서비스 패키지

### flutter_heatmap_calendar/

히트맵 캘린더 위젯 패키지

---

## Feature CLI로 새 컴포넌트 생성

```bash
# 새 Feature 모듈 생성
./feature generate -n [feature_name] --full

# 생성되는 구조:
# lib/features/[feature_name]/
#   ├── models/[feature_name]_model.dart
#   ├── view_models/[feature_name]_view_model.dart
#   ├── views/[feature_name]_view.dart
#   ├── widgets/
#   └── index.dart
```

---

*생성일: 2026-01-03*
