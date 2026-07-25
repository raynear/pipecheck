import 'package:boilerplate/data/table_generator/annotations.dart';

/// 포스트-태그 다대다 관계 테이블
@GenerateTable(tableName: 'post_tag')
class PostTag {
  @PrimaryKey()
  final String id;

  @References('posts')
  @Required()
  final String postId;

  @References('tags')
  @Required()
  final String tagId;

  PostTag({
    required this.id,
    required this.postId,
    required this.tagId,
  });
}
