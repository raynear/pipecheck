# Flutter BoilerPlate Documentation Index

> AI 지원 개발을 위한 프로젝트 문서 인덱스

---

## 프로젝트 개요

- **유형**: Monorepo (Main App + 6 Packages)
- **주요 언어**: Flutter/Dart
- **아키텍처**: Clean Architecture + MVVM
- **상태 관리**: Riverpod 3.0

---

## 빠른 참조

| 항목 | 값 |
|------|-----|
| **Framework** | Flutter SDK >=3.8.0 |
| **Entry Point** | `app/lib/main.dart` |
| **Router** | `app/lib/core/router/router.dart` |
| **Feature Flags** | `app/lib/config/app_feature_config.dart` |
| **Build Script** | `app/build.sh` |

---

## 생성된 문서

### 프로젝트 구조

- [프로젝트 개요](./project-overview.md) - 프로젝트 전체 개요
- [소스 트리 분석](./reference/archive/source-tree-analysis.md) - 디렉토리 구조 상세 (아카이브)
- [기술 스택](./technology-stack.md) - 의존성 및 기술 상세

### 데이터 & 컴포넌트

- [데이터 모델](./data-models.md) - 데이터베이스 스키마 및 모델
- [컴포넌트 인벤토리](./component-inventory.md) - UI 컴포넌트 및 서비스 목록

---

## 기존 문서

### 시작하기

- [00-Prerequisites](./00-PREREQUISITES.md) - 사전 요구사항
- [01-Getting Started](./01-GETTING_STARTED.md) - 빠른 시작 가이드
- [02-Sprint Checklist](./02-SPRINT-CHECKLIST.md) - 4주 스프린트 체크리스트

### 가이드

- [Template Guide](./guides/TEMPLATE-GUIDE.md) - 아키텍처, 코드 패턴, 의존성 규칙
- [CLI Tools](./guides/CLI_TOOLS.md) - CLI 도구 (init, setup, deploy 등)
- [Feature Management](./guides/FEATURE_MANAGEMENT.md) - Feature CLI 사용법
- [Fastlane Setup](./guides/FASTLANE_SETUP.md) - 빌드/배포 자동화
- [External Setup](./guides/EXTERNAL_SETUP.md) - 외부 서비스 설정

### A/B 테스트

- [AB Test Guide](./AB_TEST_GUIDE.md) - 운영 가이드 (fastlane, Remote Config, GA4)
- [AB Test Lifecycle](./AB_TEST_LIFECYCLE.md) - 6단계 라이프사이클 (기획→정리)

### 기술 참조

- [Development](./reference/technical/development.md) - 개발 워크플로우
- [Deployment](./reference/technical/deployment.md) - 배포 프로세스
- [Setup](./reference/technical/setup.md) - 환경 설정

### 기획 참조

- [Product Requirements](./reference/planning/product-requirements.md) - 제품 요구사항
- [Marketing Guide](./reference/planning/marketing-guide.md) - 마케팅 가이드
- [Market Research](./reference/planning/market-research.md) - 시장 조사

---

## Parts (프로젝트 구성)

### Main App

| 항목 | 경로 |
|------|------|
| Root | `/Users/raynear/Project/boiler_plate/app` |
| Type | mobile (Flutter) |
| Architecture | Clean Architecture + MVVM |

### Packages

| 패키지 | 경로 | 설명 |
|--------|------|------|
| authentication | `packages/authentication` | 인증 로직 |
| utils | `packages/utils` | 유틸리티 |
| ab_testing | `packages/ab_testing` | A/B 테스팅 |
| geofence_foreground_service | `packages/geofence_foreground_service` | 지오펜싱 |
| flutter_heatmap_calendar | `packages/flutter_heatmap_calendar` | 히트맵 캘린더 |
| flutter_openmoji | (external) | OpenMoji 이모지 |

---

## 핵심 명령어

### 코드 생성
```bash
cd app && ./build.sh
```

### Feature CLI
```bash
./feature status              # 기능 상태
./feature enable [feature]    # 기능 활성화
./feature disable [feature]   # 기능 비활성화
./feature generate -n [name] --full  # 새 Feature 생성
```

### Fastlane
```bash
cd fastlane
bundle exec fastlane codegen      # 코드 생성
bundle exec fastlane test         # 테스트
# 배포는 프로젝트 루트에서 ./deploy (통합 오케스트레이터)
```

---

## AI 개발 지침

### PRD 작성 시

이 보일러플레이트를 Fork하여 새 프로젝트를 만들 때:

1. **이 인덱스 참조**: PRD 워크플로우에서 이 `index.md`를 참조
2. **기존 구조 활용**: 새 기능은 `features/` 디렉토리에 추가
3. **코드 패턴 준수**: `TEMPLATE-GUIDE.md` 패턴 따르기
4. **기능 플래그 활용**: 필요한 기능만 활성화

### 기능 개발 시

- **UI 전용**: `component-inventory.md` 참조
- **데이터 전용**: `data-models.md` 참조
- **Full-stack**: 두 문서 모두 참조

---

## 다음 단계

### 보일러플레이트 개선
1. 이 문서들을 기반으로 PRD 작성
2. 부족한 기능 식별 및 추가
3. Fastlane 배포 파이프라인 완성

### 새 프로젝트 시작
1. Fork 및 이름 변경
2. 필요한 기능 플래그 활성화
3. BMad Method로 PRD + UX + Architecture 작성

---

## 메타데이터

| 항목 | 값 |
|------|-----|
| 생성일 | 2026-01-03 |
| 스캔 레벨 | Exhaustive |
| 워크플로우 버전 | 1.2.0 |
| 문서 수 | 27+ (기존) + 5 (생성) |

---

*이 인덱스는 AI 지원 개발의 기본 진입점입니다.*
