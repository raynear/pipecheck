import 'package:pipecheck/data/table_generator/annotations.dart';

/// 댓글 모델 예제 - 자기 참조(대댓글) 포함
@GenerateTable()
class Comment {
  @PrimaryKey(strategy: IdStrategy.autoIncrement)
  final int id;

  @Required()
  final String content;

  @References('posts')
  @Required()
  final String postId;

  @References('users')
  @Required()
  final String userId;

  // 자기 참조 - 대댓글을 위한 부모 댓글 ID
  @References('comments')
  @Column(nullable: true)
  final int? parentCommentId;

  @Column(defaultValue: 0)
  final int likeCount;

  @Column(defaultValue: false)
  final bool isEdited;

  @Column(nullable: true)
  final DateTime? editedAt;

  Comment({
    required this.id,
    required this.content,
    required this.postId,
    required this.userId,
    this.parentCommentId,
    this.likeCount = 0,
    this.isEdited = false,
    this.editedAt,
  });
}

// 생성 후 Repository에 추가 메서드 예제:
//
// PostRepository에 추가:
// ```dart
// Future<List<TagModel>> getPostTags(String postId) async {
//   final results = await _database.join(
//     'tags',
//     'post_tags',
//     'tags.id = post_tags.tag_id',
//     where: {'post_tags.post_id': postId},
//   );
//   return results.map((r) => TagModel.fromDatabaseMap(r)).toList();
// }
// ```
//
// CommentRepository에 추가:
// ```dart
// Future<List<CommentModel>> getReplies(int commentId) async {
//   final replies = await _database.findMany(
//     'comments',
//     where: {'parent_comment_id': commentId},
//     orderBy: 'created_at ASC',
//   );
//   return replies.map((r) => CommentModel.fromDatabaseMap(r)).toList();
// }
// ```
