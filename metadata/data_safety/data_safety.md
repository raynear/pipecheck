# My App — Data Safety 답안지

> 활성 기능 셋에서 자동 생성 (`./run generate-data-safety`).
> 기능 구성이 바뀌면 재생성 후 양 스토어 콘솔에 반영할 것.

## Google Play — Data safety 폼

| 카테고리 | 데이터 유형 | 수집 | 공유 | 목적 | 선택가능 | 근거 기능 |
|---|---|---|---|---|---|---|
| Device or other IDs | Device or other IDs (advertising ID) | 예 | 예 | Advertising or marketing | 아니오 | AdMob (isAdsEnabled) |
| App activity | App interactions | 예 | 아니오 | Analytics | 예 | Firebase Analytics (isFirebaseAnalyticsEnabled) |
| Device or other IDs | Device or other IDs (app instance ID) | 예 | 아니오 | Analytics | 예 | Firebase Analytics (isFirebaseAnalyticsEnabled) |
| App info and performance | Crash logs | 예 | 아니오 | Analytics, App functionality | 아니오 | Firebase Crashlytics (isFirebaseCrashlyticsEnabled) |
| App info and performance | Diagnostics | 예 | 아니오 | Analytics, App functionality | 아니오 | Firebase Crashlytics (isFirebaseCrashlyticsEnabled) |
| Financial info | Purchase history | 예 | 아니오 | App functionality | 아니오 | IAP/Subscription (isSubscriptionEnabled) |

### 공통 질문
- 전송 중 암호화: **예** (전 구간 HTTPS/TLS)
- 삭제 요청 경로: **아니오** — 서버 계정 기능 없음 (로컬 전용 데이터)

## App Store — Privacy Nutrition Labels

- Identifiers → Device ID (Used to Track You) (AdMob (isAdsEnabled))
- Usage Data → Product Interaction (Firebase Analytics (isFirebaseAnalyticsEnabled))
- Identifiers → Device ID (Firebase Analytics (isFirebaseAnalyticsEnabled))
- Diagnostics → Crash Data (Firebase Crashlytics (isFirebaseCrashlyticsEnabled))
- Diagnostics → Performance Data (Firebase Crashlytics (isFirebaseCrashlyticsEnabled))
- Purchases → Purchase History (IAP/Subscription (isSubscriptionEnabled))

광고 활성화 앱: "Used to Track You" 섹션에 Device ID 포함 + ATT 프롬프트 필수 (SplashView가 처리, P1-13a).
