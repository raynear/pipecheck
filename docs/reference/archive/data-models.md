# 데이터 모델 (Data Models)

> Flutter BoilerPlate의 데이터 레이어 구조 및 모델 정의

---

## 개요

이 프로젝트는 커스텀 테이블 생성기를 사용하여 데이터 모델을 자동으로 생성합니다.

**코드 생성 플로우:**
```
definitions/*.dart → build_runner → generated/*
                                    ├── models/*.model.dart
                                    ├── database/tables/*.drift.dart
                                    └── repositories/*.repository.dart
```

---

## 데이터베이스 구조

### Drift (로컬 SQLite)

| 테이블 | 설명 | 주요 필드 |
|--------|------|-----------|
| `user` | 사용자 정보 | id, email, name, profileImageUrl |
| `badge` | 배지 시스템 | id, name, description, iconUrl |
| `post` | 게시물 | id, title, content, authorId |
| `comment` | 댓글 | id, postId, authorId, content |
| `tag` | 태그 | id, name |
| `post_tag` | 게시물-태그 관계 | postId, tagId |

### Supabase (원격 PostgreSQL)

동일한 테이블 구조를 Supabase에서 사용. SQL 마이그레이션 파일이 자동 생성됩니다.

---

## 테이블 정의 (Definitions)

### User

`lib/data/definitions/user.dart`

```dart
@GenerateTable(
  tableName: 'user',
  timestamps: true,
  updateDatabase: true,
  updateProviders: true,
)
class User {
  @PrimaryKey(strategy: IdStrategy.uuid)
  final String id;

  @Required()
  final String email;

  @Column(nullable: true)
  final String? name;

  @Column(nullable: true)
  final String? profileImageUrl;

  @Column(defaultValue: false)
  final bool isEmailVerified;

  @Column(nullable: true)
  final DateTime? lastLoginAt;

  @Column(nullable: true)
  final String? metadata; // JSON 데이터 저장용

  @Column(defaultValue: false)
  final bool isDeleted;

  @Column(nullable: true)
  final DateTime? deletedAt;
}
```

### Post

`lib/data/definitions/post.dart`

```dart
@GenerateTable()
class Post {
  @PrimaryKey()
  final String id;

  @Required()
  final String title;

  @Required()
  @Column(description: 'Post content in markdown format')
  final String content;

  @References('users')
  @Required()
  final String authorId;

  @Column(defaultValue: false)
  final bool isPublished;

  @Column(nullable: true)
  final DateTime? publishedAt;

  @JsonField()
  final Map<String, dynamic>? metadata;

  @Index(unique: true)
  final String slug;

  @Column(defaultValue: 0)
  final int viewCount;

  @EnumField(PostStatus)
  final PostStatus status;
}

enum PostStatus {
  draft,
  published,
  archived,
  deleted,
}
```

### Badge

`lib/data/definitions/badge.dart`

배지 시스템용 테이블 정의. 사용자 성취 및 보상 추적.

### Comment

`lib/data/definitions/comment.dart`

게시물에 대한 댓글 테이블. `postId`와 `authorId`로 외래 키 참조.

### Tag / Post_Tag

`lib/data/definitions/tag.dart`, `lib/data/definitions/post_tag.dart`

다대다 관계를 위한 태그 시스템.

---

## 테이블 생성기 어노테이션

### 주요 어노테이션

| 어노테이션 | 용도 |
|------------|------|
| `@GenerateTable()` | 테이블 생성 활성화 |
| `@PrimaryKey()` | 기본 키 지정 |
| `@Required()` | 필수 필드 |
| `@Column()` | 컬럼 속성 (nullable, defaultValue) |
| `@References()` | 외래 키 참조 |
| `@Index()` | 인덱스 생성 |
| `@JsonField()` | JSON 필드 |
| `@EnumField()` | Enum 필드 |

### GenerateTable 옵션

```dart
@GenerateTable(
  tableName: 'custom_name',     // 커스텀 테이블명
  timestamps: true,              // createdAt, updatedAt 자동 추가
  paths: OutputPaths(...),       // 출력 경로 커스터마이징
  updateDatabase: true,          // database.dart 자동 업데이트
  updateProviders: true,         // providers 자동 업데이트
)
```

---

## 생성된 파일

### Models (Freezed)

`lib/data/generated/models/`

```dart
// user.model.dart
@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? name,
    // ...
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
```

### Database Tables (Drift)

`lib/data/generated/database/`

Drift 테이블 클래스와 DAO가 생성됩니다.

### Repositories

`lib/data/generated/repositories/`

CRUD 작업을 위한 Repository 클래스가 생성됩니다.

---

## 데이터 레이어 아키텍처

```
┌───────────────────────────────────────────────┐
│              Presentation Layer               │
│           (Views, ViewModels)                 │
├───────────────────────────────────────────────┤
│                 Domain Layer                  │
│           (Actions, Use Cases)                │
├───────────────────────────────────────────────┤
│               Data Layer                      │
│  ┌─────────────────────────────────────────┐  │
│  │          Repository (Abstraction)       │  │
│  └────────────┬──────────────┬─────────────┘  │
│               │              │                │
│  ┌────────────▼───┐  ┌───────▼────────────┐  │
│  │   Drift (Local) │  │  Supabase (Remote) │  │
│  │    SQLite DB    │  │    PostgreSQL      │  │
│  └─────────────────┘  └────────────────────┘  │
└───────────────────────────────────────────────┘
```

---

## 사용 방법

### 1. 새 테이블 정의

`lib/data/definitions/` 에 새 파일 생성:

```dart
import 'package:boilerplate/data/table_generator/annotations.dart';

@GenerateTable()
class MyEntity {
  @PrimaryKey()
  final String id;

  @Required()
  final String name;
}
```

### 2. 코드 생성

```bash
cd app
./build.sh
```

### 3. 생성된 파일 확인

- `lib/data/generated/models/my_entity.model.dart`
- `lib/data/generated/database/tables/my_entity.drift.dart`
- `lib/data/generated/repositories/my_entity.repository.dart`

### 4. Provider 등록 (자동 또는 수동)

```dart
final myEntityRepositoryProvider = Provider<MyEntityRepository>((ref) {
  return MyEntityRepository(
    database: ref.watch(databaseProvider),
  );
});
```

---

## 데이터 동기화

### 오프라인 우선 전략

1. 모든 데이터는 먼저 로컬 Drift DB에 저장
2. 네트워크 연결 시 Supabase와 동기화
3. 충돌 해결: `updatedAt` 타임스탬프 기반

### 동기화 플래그

`AppFeatureConfig.isDatabaseSyncEnabled`로 동기화 기능 ON/OFF

---

*생성일: 2026-01-03*
