import 'package:boilerplate/core/services/notification_service.dart';
import 'package:boilerplate/core/services/snackbar_service.dart';
import 'package:boilerplate/data/definitions/badge.dart';
import 'package:boilerplate/data/definitions/post.dart';
import 'package:boilerplate/data/generated/models/badge.model.dart';
import 'package:boilerplate/data/generated/models/post.model.dart';
import 'package:boilerplate/data/generated/repositories/badge.repository.dart';
import 'package:boilerplate/data/generated/repositories/post.repository.dart';
import 'package:boilerplate/data/generated/repositories/user.repository.dart';
import 'package:boilerplate/domain/models/action_result.dart';

/// 게시글 관련 액션들을 처리하는 도메인 클래스
class PostActions {
  final PostRepository _postRepository;
  final UserRepository _userRepository; // 향후 사용자 정보 조회용
  final BadgeRepository _badgeRepository;
  final NotificationService _notificationService;
  final SnackBarService _snackbarService;

  PostActions({
    required PostRepository postRepository,
    required UserRepository userRepository,
    required BadgeRepository badgeRepository,
    required NotificationService notificationService,
    required SnackBarService snackbarService,
  })  : _postRepository = postRepository,
        _userRepository = userRepository,
        _badgeRepository = badgeRepository,
        _notificationService = notificationService,
        _snackbarService = snackbarService;

  /// 게시글 작성 액션
  /// - 게시글 저장
  /// - 첫 게시글 배지 확인 및 부여
  /// - 팔로워에게 알림 발송 (미구현)
  /// - 성공 메시지 표시
  Future<ActionResult<PostModel>> createPost({
    required String userId,
    required String title,
    required String content,
    List<String>? tags,
  }) async {
    try {
      // 1. 게시글 생성
      final newPost = PostModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: userId,
        title: title,
        content: content,
        slug: title.toLowerCase().replaceAll(' ', '-'),
        status: PostStatus.published,
        isPublished: true,
        publishedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdPost = await _postRepository.create(newPost);

      // 2. 사용자의 첫 게시글인지 확인
      // TODO: getByAuthorId 메서드가 PostRepository에 필요함
      final allPosts = await _postRepository.getAll();
      final userPosts = allPosts.where((p) => p.authorId == userId).toList();
      if (userPosts.length == 1) {
        // 첫 게시글 배지 부여
        final firstPostBadge = BadgeModel(
          id: DateTime.now().millisecondsSinceEpoch,
          badgeId: 'first_post',
          title: '첫 게시글',
          description: '첫 번째 게시글을 작성한 회원',
          iconPath: 'assets/badges/first_post.png',
          isAchieved: true,
          earnedDate: DateTime.now(),
          type: BadgeType.first,
          condition: 'first_post',
          createdAt: DateTime.now(),
        );
        await _badgeRepository.create(firstPostBadge);

        // 배지 획득 알림
        await _notificationService.createNotificationNow(
          id: 200,
          title: '배지 획득!',
          body: '첫 게시글 배지를 획득했습니다!',
        );
      }

      // 3. 팔로워에게 알림 발송 (향후 구현)
      // TODO: 팔로워 시스템 구현 후 알림 발송

      // 4. 성공 메시지
      _snackbarService.showSuccess('게시글이 성공적으로 작성되었습니다!');

      return ActionResult.success(
        data: createdPost,
        message: '게시글 작성 완료',
      );
    } catch (e) {
      _snackbarService.showError('게시글 작성에 실패했습니다');
      return ActionResult.error(
        message: '게시글 작성 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 게시글 삭제 액션
  /// - 게시글 삭제
  /// - 관련 알림 제거
  /// - 삭제 메시지 표시
  Future<ActionResult<void>> deletePost({
    required String postId,
    required String userId,
  }) async {
    try {
      // 1. 게시글 소유자 확인
      final post = await _postRepository.getById(postId);
      if (post == null) {
        throw Exception('게시글을 찾을 수 없습니다');
      }

      if (post.authorId != userId) {
        throw Exception('게시글을 삭제할 권한이 없습니다');
      }

      // 2. 게시글 삭제
      await _postRepository.delete(postId);

      // 3. 관련 알림 제거 (향후 구현)
      // TODO: 게시글 관련 알림 제거

      // 4. 삭제 메시지
      _snackbarService.showInfo('게시글이 삭제되었습니다');

      return ActionResult.success(
        message: '게시글 삭제 완료',
      );
    } catch (e) {
      _snackbarService.showError('게시글 삭제에 실패했습니다');
      return ActionResult.error(
        message: '게시글 삭제 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 게시글 좋아요 액션
  /// - 좋아요 토글
  /// - 작성자에게 알림
  /// - 좋아요 10개 달성 시 배지 부여
  Future<ActionResult<bool>> toggleLike({
    required String postId,
    required String userId,
  }) async {
    try {
      // 1. 게시글 정보 가져오기
      final post = await _postRepository.getById(postId);
      if (post == null) {
        throw Exception('게시글을 찾을 수 없습니다');
      }

      // 2. 좋아요 토글 (실제로는 별도 좋아요 테이블 필요)
      // TODO: 좋아요 시스템 구현
      final isLiked = true; // 임시 구현

      if (isLiked && post.authorId != userId) {
        // 3. 작성자에게 알림
        await _notificationService.createNotificationNow(
          id: 300,
          title: '좋아요 알림',
          body: '누군가 회원님의 게시글을 좋아합니다!',
        );
      }

      // 4. 성공 메시지
      _snackbarService.showSuccess(isLiked ? '좋아요!' : '좋아요 취소');

      return ActionResult.success(
        data: isLiked,
        message: isLiked ? '좋아요 추가' : '좋아요 취소',
      );
    } catch (e) {
      _snackbarService.showError('좋아요 처리에 실패했습니다');
      return ActionResult.error(
        message: '좋아요 처리 중 오류가 발생했습니다: $e',
      );
    }
  }
}
