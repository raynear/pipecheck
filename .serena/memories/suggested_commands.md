# Suggested Commands

## Code Generation (필수!)
모델, ViewModel, DB 테이블 변경 후 반드시 실행:
```bash
cd app
./build.sh
```
이 스크립트는:
1. `dart run build_runner build --delete-conflicting-outputs` 실행
2. 생성된 파일 정리 (organize_files.dart)
3. database.dart 동기화 (sync_database.dart)

## Flutter 기본 명령어
```bash
cd app
flutter pub get           # 의존성 설치
flutter analyze           # 코드 분석 (lint)
flutter test              # 테스트 실행
flutter run               # 앱 실행 (디버그)
flutter build ios         # iOS 빌드
flutter build apk         # Android APK 빌드
flutter build appbundle   # Android AAB 빌드
```

## Fastlane 명령어 (권장)
```bash
cd fastlane
bundle exec fastlane codegen          # 코드 생성
bundle exec fastlane test             # 테스트
bundle exec fastlane bump_version type:patch  # 버전 증가 (patch/minor/major)
bundle exec fastlane deploy           # 전체 배포
bundle exec fastlane setup_certs      # 인증서 설정
bundle exec fastlane validate         # 프로젝트 검증
bundle exec fastlane info             # 프로젝트 정보
bundle exec fastlane clean            # 클린
bundle exec fastlane run_app          # 앱 실행
bundle exec fastlane firebase_config  # Firebase 설정 업데이트
```

## Feature CLI
```bash
# 프로젝트 루트에서 실행
./feature generate -n [feature_name]           # 기본 구조 생성
./feature generate -n [feature_name] --full    # 전체 구조 생성
./feature status                               # 기능 상태 확인
./feature enable ads                           # 기능 활성화
./feature disable ads                          # 기능 비활성화
./feature list                                 # 사용 가능한 기능 목록
```

## 시스템 유틸리티 (Darwin/macOS)
```bash
ls -la                    # 파일 목록
find . -name "*.dart"     # 파일 검색
grep -r "keyword" .       # 텍스트 검색
cd /path/to/dir           # 디렉토리 이동
cat filename              # 파일 내용 보기
```

## Git 명령어
```bash
git status                # 상태 확인
git add .                 # 스테이징
git commit -m "message"   # 커밋
git push                  # 푸시
git pull                  # 풀
git checkout -b feature/name  # 브랜치 생성
```

## 개발 워크플로우
1. 새 기능 추가:
   ```bash
   ./feature generate -n my_feature --full
   ```
2. 코드 작성 후 코드 생성:
   ```bash
   cd app && ./build.sh
   ```
3. 분석 및 테스트:
   ```bash
   flutter analyze && flutter test
   ```
4. 빌드:
   ```bash
   cd fastlane && bundle exec fastlane deploy
   ```
