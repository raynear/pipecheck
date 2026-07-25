import 'package:boilerplate/data/table_generator/annotations.dart';

/// 블로그 포스트 모델 예제
///
/// 이 파일을 저장하고 build_runner를 실행하면 자동으로 생성됩니다:
/// - post.drift.dart: Drift 테이블 정의
/// - post.model.dart: Freezed 모델
/// - post.repository.dart: Repository 구현
/// - supabase/migrations/create_posts_table.sql: Supabase 테이블 생성 SQL
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

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    this.isPublished = false,
    this.publishedAt,
    this.metadata,
    required this.slug,
    this.viewCount = 0,
    this.status = PostStatus.draft,
  });
}

/// 포스트 상태 Enum
enum PostStatus {
  draft,
  published,
  archived,
  deleted,
}

// 사용법:
// 1. 이 파일을 저장
// 2. 터미널에서 실행: dart run build_runner build
// 3. 생성된 파일들 확인:
//    - lib/data/models/post.drift.dart
//    - lib/data/models/post.model.dart  
//    - lib/data/models/post.repository.dart
//    - supabase/migrations/create_posts_table.sql
//
// 4. drift_database.dart의 _registerAllTables()에 추가:
//    _tableRegistry['posts'] = _db.posts;
//
// 5. database.dart의 @DriftDatabase에 추가:
//    @DriftDatabase(tables: [Users, Badges, Posts])
//
// 6. Supabase 사용 시 생성된 SQL 실행
//
// 7. Repository Provider 생성:
//    final postRepositoryProvider = Provider<PostRepository>((ref) {
//      return PostRepository(
//        apiClient: ref.watch(apiClientProvider),
//        database: ref.watch(databaseProvider),
//        localStorage: ref.watch(localStorageProvider),
//      );
//    });