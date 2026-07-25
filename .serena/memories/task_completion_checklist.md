# Task Completion Checklist

## 코드 변경 후 필수 단계

### 1. 코드 생성 (모델/ViewModel/테이블 변경 시)
```bash
cd app
./build.sh
```

### 2. 코드 분석 (Lint)
```bash
cd app
flutter analyze
```
- 모든 린트 경고/에러 해결
- 생성된 파일(*.g.dart, *.freezed.dart, *.drift.dart)은 제외됨

### 3. 타입 체크
```bash
# flutter analyze에 포함됨
```

### 4. 테스트
```bash
cd app
flutter test
```
또는
```bash
cd fastlane
bundle exec fastlane test
```

### 5. 앱 실행 확인
```bash
cd app
flutter run
```
또는
```bash
cd fastlane
bundle exec fastlane run_app
```

## 새 기능 추가 체크리스트

1. ✅ Feature CLI로 구조 생성
   ```bash
   ./feature generate -n [name] --full
   ```

2. ✅ 모델 작성 (Freezed)
   - `features/[name]/models/[name]_model.dart`

3. ✅ ViewModel 작성 (Riverpod Generator)
   - `features/[name]/view_models/[name]_view_model.dart`

4. ✅ View 작성
   - `features/[name]/views/[name]_view.dart`

5. ✅ 코드 생성 실행
   ```bash
   cd app && ./build.sh
   ```

6. ✅ 라우트 등록
   - `lib/core/router.dart`에 GoRoute 추가

7. ✅ 린트 및 테스트
   ```bash
   flutter analyze && flutter test
   ```

## DB 테이블 추가 체크리스트

1. ✅ 테이블 정의 작성
   - `lib/data/definitions/[name]_table.dart`

2. ✅ 코드 생성 실행 (자동으로 database.dart 동기화)
   ```bash
   cd app && ./build.sh
   ```

3. ✅ Repository 구현
   - `lib/data/repositories/[name]_repository.dart`

## 외부 서비스 연동 체크리스트

1. ✅ `app_feature_config.dart`에서 플래그 활성화

2. ✅ `.env.debug` / `.env.release`에 API 키 추가

3. ✅ 해당 서비스 초기화 확인 (main.dart 또는 서비스 파일)

4. ✅ 필요 시 Android/iOS 설정 파일 수정

## 배포 전 체크리스트

1. ✅ 모든 테스트 통과
2. ✅ 린트 에러 없음
3. ✅ 버전 번호 업데이트
   ```bash
   cd fastlane && bundle exec fastlane bump_version type:patch
   ```
4. ✅ 릴리스 노트 작성
5. ✅ 인증서 유효성 확인
   ```bash
   cd fastlane && bundle exec fastlane validate_all_certificates
   ```
