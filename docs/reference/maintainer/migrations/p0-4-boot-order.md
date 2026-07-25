# P0-4 마이그레이션 노트 — 부팅 순서 / 기능 플래그

> 대상: 이 템플릿에서 파생된 앱 (flowmodoro, nofon 등 4개)

## 무엇이 바뀌었나

**release 빌드가 더 이상 모든 기능 플래그를 강제 ON하지 않습니다.**

| | 이전 | 이후 |
|---|---|---|
| release 플래그 | `applyProductionConfig()` = `enableAllFeatures()` — 서비스 init **후** 전 플래그 강제 ON | `app_config.yaml`의 `profile` + `features`가 서비스 init **전에** 적용 |
| debug 플래그 | `applyDevelopmentConfig()` 하드코딩 셋 | release와 동일 (빌드 모드는 `isDebugMode` 등 개발자 플래그 3종만 결정) |
| 전달 경로 | main.dart의 kDebugMode 분기 | app_config.yaml → `./build`(gen-env) → `.env.*`의 `APP_PROFILE`/`FF_*` → `AppFeatureConfig.applyBootConfig()` |

이전 구조는 release에서 AdService 등 초기화되지 않은 서비스의 플래그를 켜서
`LateInitializationError` 크래시를 만들었습니다 (감사 보고서 최대 블로커).

## 파생 앱이 해야 할 일

1. **profile 선택** — `app_config.yaml`:
   ```yaml
   profile: "premium"   # minimal | standard | premium | enterprise
   ```
   프로필별 활성 기능은 `app/lib/config/app_feature_config.dart`의
   `AppProfile` enum 참조.

2. **개별 플래그 오버라이드** — 프로필과 다른 플래그만 `features:`에:
   ```yaml
   features:
     force_update: true        # snake_case → isForceUpdateEnabled
     isAdsEnabled: false       # 필드명 그대로도 허용
   ```

3. **이전 release 동작(전부 ON)을 유지하고 싶다면**:
   ```yaml
   profile: "enterprise"
   ```
   단, 이는 권장되지 않습니다 — 미설정 서비스(광고 ID 없는 AdService 등)의
   플래그가 켜지면 이전과 같은 크래시 경로가 살아납니다.

4. `./build` 실행해서 env 산출물 재생성 (자동으로 `APP_PROFILE`/`FF_*` 포함).

## 삭제된 API

- `AppFeatureConfig.applyProductionConfig()` — 호출부가 있으면 컴파일 에러.
  `AppProfile.<x>.apply()` 또는 `applyBootConfig()`로 교체.
- `AppFeatureConfig.applyDevelopmentConfig()` — 동일.

## 주의

- `enableAllFeatures()`/`disableAllFeatures()`는 유지 (enterprise 프로필,
  개발용 FeatureConfigView에서 사용).
- 플래그 의존성 규칙(`resolveDependencies`)은 applyBootConfig가 마지막에
  실행하므로 오버라이드가 부모 플래그를 끄면 자식도 함께 꺼집니다.
