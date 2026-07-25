# Flutter BoilerPlate Documentation

> **PRD를 채우고, 한 문서를 따라, 스토어까지.**

---

## 시작하기 (이 순서로)

1. **[../prd.md](../prd.md)** — PRD 템플릿을 채운다. 앱 정의의 SSOT(이름·인증·수익화·플랫폼 등).
2. **[quick-start.md](./quick-start.md)** — **정전(正典) 가이드.** PRD → 설정 → `./init` →
   개발 → `./deploy`까지 전 과정을 순서대로. clone부터 첫 배포까지 약 25분.

> 🤖 **Claude Code**: 채워진 `../prd.md`를 읽고 `quick-start.md`의 Phase 0→6을 그대로 실행하면
> 프로젝트 생성·개발·배포가 끝난다. 두 문서가 진입점이다.

처음이라 더 천천히 보고 싶으면 → [00-PREREQUISITES](./00-PREREQUISITES.md) →
[01-GETTING_STARTED](./01-GETTING_STARTED.md) → [02-SPRINT-CHECKLIST](./02-SPRINT-CHECKLIST.md).

---

## 문서 구조

```
prd.md                          # (루트) PRD 템플릿 — 앱 정의 SSOT

docs/
├── quick-start.md              # ★ 정전 가이드: PRD → 배포 전 과정
├── 00-PREREQUISITES.md         # 사전 요구사항 (도구 설치)
├── 01-GETTING_STARTED.md       # 처음 쓰는 사람용 온보딩
├── 02-SPRINT-CHECKLIST.md      # 4주 스프린트 가이드
├── MODULES.md                  # 모듈 경계 + 기능 플래그 체계 (운영 기준)
├── AB_TEST_GUIDE.md            # A/B 테스트 운영
├── AB_TEST_LIFECYCLE.md        # A/B 6단계 라이프사이클
│
├── guides/                     # 앱 빌더 참조 (필요할 때)
│   ├── CLI_TOOLS.md            # CLI 명령 (init, build, deploy, feature)
│   ├── FEATURE_MANAGEMENT.md   # 기능 플래그 상세
│   ├── EXTERNAL_SETUP.md       # 외부 서비스 발급 (Firebase, AdMob, 인증서)
│   ├── FASTLANE_SETUP.md       # 배포 자동화 상세
│   ├── TROUBLESHOOTING.md      # 문제 해결
│   ├── VERSION_POLICY.md       # 버전/태그 정책
│   └── TEMPLATE-GUIDE.md       # 아키텍처/코드 패턴
│
└── reference/                  # 심화 참고
    ├── maintainer/             # 템플릿 유지보수·역사 (앱 만드는 데 불필요)
    │   ├── FASTLANE_REPO.md        #   fastlane 별도 repo 핀/레인 계약
    │   ├── DERIVED_APP_UPDATES.md  #   파생 앱에 템플릿 변경 전파
    │   ├── PACKAGE_AUTHORING.md    #   패키지 작성/추출
    │   ├── GOAL_AUDIT_ROADMAP.md   #   fork-to-ship 로드맵 (역사)
    │   ├── CAPABILITY_MATRIX.md    #   기능 전수 분류 (동결 스냅샷)
    │   ├── CONFIG_CONSOLIDATION_PLAN.md
    │   └── migrations/             #   breaking 변경 마이그레이션 기록
    ├── APP_STORE_REGISTRATION_CHECKLIST.md
    ├── BETA_DEPLOYMENT_GUIDE.md
    ├── GA_EVENT_DESIGN_GUIDE.md
    ├── planning/               # 기획/마케팅 템플릿
    ├── technical/              # 기술 심화
    └── archive/                # 동결된 역사 스냅샷
```

---

## 상세 가이드 (필요할 때 참조)

| 문서 | 용도 | 참조 시점 |
|------|------|----------|
| [CLI_TOOLS](./guides/CLI_TOOLS.md) | CLI 명령 사용법 | init, build, deploy, feature |
| [FEATURE_MANAGEMENT](./guides/FEATURE_MANAGEMENT.md) | 기능 플래그 상세 | 기능 추가/제거 |
| [EXTERNAL_SETUP](./guides/EXTERNAL_SETUP.md) | Firebase, AdMob, 인증서 발급 | 외부 서비스 연동 |
| [FASTLANE_SETUP](./guides/FASTLANE_SETUP.md) | 배포 자동화 설정 | 배포 설정 |
| [TROUBLESHOOTING](./guides/TROUBLESHOOTING.md) | 증상별 해결 | 막혔을 때 |
| [MODULES](./MODULES.md) | 모듈 경계 + 플래그 운영 기준 | 코드 구조 이해 |
| [TEMPLATE-GUIDE](./guides/TEMPLATE-GUIDE.md) | 아키텍처/코드 패턴 | 코드 구조 궁금할 때 |

> 템플릿 자체를 유지보수(패키지 추출·파생 앱 전파·fastlane 핀)하려면
> [reference/maintainer/](./reference/maintainer/) — 앱을 만드는 데는 필요 없다.

---

## 기술 스택

| 분류 | 기술 | 용도 |
|------|------|------|
| **Framework** | Flutter 3.x | 크로스플랫폼 개발 |
| **State** | Riverpod 3.0 (수동 Notifier) | 상태 관리 — `@riverpod` 코드 생성 안 함 |
| **Database** | Drift | 로컬 DB (local-only 기본) |
| **Backend** | Firebase | Analytics, Crashlytics, Auth(email), RC — 서버 코드 0줄 |
| **Automation** | Fastlane | 빌드/배포 자동화 |
| **Code Gen** | Freezed, JSON Serializable, Drift | 코드 생성 |

---

## 자주 묻는 질문

**Q: 어디서 시작하나요?**
> [../prd.md](../prd.md)를 채우고 [quick-start.md](./quick-start.md)를 순서대로 따라가세요.

**Q: Flutter를 잘 몰라요.**
> [02-SPRINT-CHECKLIST.md](./02-SPRINT-CHECKLIST.md)가 단계별로 설명합니다.

**Q: 코드 구조가 궁금해요.**
> [MODULES.md](./MODULES.md)와 [guides/TEMPLATE-GUIDE.md](./guides/TEMPLATE-GUIDE.md)를 보세요.

---

*"Launch fast, iterate faster"*
