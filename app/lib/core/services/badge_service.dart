import 'package:boilerplate/data/generated/models/badge.model.dart';
import 'package:boilerplate/data/generated/repositories/badge.repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

/// 뱃지 서비스를 위한 프로바이더
final badgeServiceProvider = Provider<BadgeService>((ref) {
  return BadgeService(ref);
});

/// 새로 획득한 뱃지를 저장하는 상태 프로바이더
final newBadgesProvider = NotifierProvider<NewBadgesNotifier, List<BadgeModel>>(
  NewBadgesNotifier.new,
);

/// 새로 획득한 뱃지 목록을 관리하는 Notifier
class NewBadgesNotifier extends Notifier<List<BadgeModel>> {
  @override
  List<BadgeModel> build() {
    return [];
  }

  /// 뱃지 추가
  void addBadge(BadgeModel badge) {
    logger.d('NewBadgesNotifier.addBadge called with badge: ${badge.title}');
    logger.d('Current state length before add: ${state.length}');

    state = [...state, badge];

    logger.d('Current state length after add: ${state.length}');
    logger.d('NewBadgesNotifier.addBadge completed');
  }

  /// 뱃지 목록 설정
  void setBadges(List<BadgeModel> badges) {
    logger.d('NewBadgesNotifier.setBadges called with ${badges.length} badges');
    logger.d('Current state length before set: ${state.length}');

    state = badges;

    logger.d('Current state length after set: ${state.length}');
    logger.d('NewBadgesNotifier.setBadges completed');
  }

  /// 뱃지 목록 초기화
  void clearBadges() {
    logger.d('NewBadgesNotifier.clearBadges called');
    logger.d('Current state length before clear: ${state.length}');

    state = [];

    logger.d('Current state length after clear: ${state.length}');
    logger.d('NewBadgesNotifier.clearBadges completed');
  }
}

/// 뱃지 관련 서비스 - 뱃지 데이터 관리만 담당
class BadgeService {
  final Ref _ref;

  BadgeService(this._ref);

  /// 새로운 뱃지가 있는지 확인하고 자동으로 상태를 업데이트하는 메서드
  Future<void> checkAndUpdateBadges() async {
    logger.d('BadgeService.checkAndUpdateBadges called');
    final badgeRepository = _ref.read(badgeRepositoryProvider);

    // 획득한 뱃지 목록 가져오기
    final allBadges = await badgeRepository.getAll();
    final earnedBadges = allBadges.where((badge) => badge.isAchieved).toList();

    logger.d('earnedBadges count: ${earnedBadges.length}');
    if (earnedBadges.isNotEmpty) {
      logger.d('Found ${earnedBadges.length} earned badges');

      // 현재 newBadgesProvider 상태 확인
      final currentBadges = _ref.read(newBadgesProvider);
      logger.d('Current newBadgesProvider state length: ${currentBadges.length}');

      // 새로운 뱃지들만 필터링 (이미 알림에 있는 것 제외)
      final currentBadgeIds = currentBadges.map((b) => b.badgeId).toSet();
      final newBadges = earnedBadges.where((badge) => !currentBadgeIds.contains(badge.badgeId)).toList();

      if (newBadges.isNotEmpty) {
        logger.d('Adding ${newBadges.length} new badges to notifications');
        for (final badge in newBadges) {
          _ref.read(newBadgesProvider.notifier).addBadge(badge);
        }
      }
    } else {
      logger.d('No earned badges found');
    }
  }

  /// 단일 뱃지를 업데이트하고 newBadgesProvider에 추가하는 메서드
  Future<void> updateAndNotify(BadgeModel badge) async {
    logger.d('BadgeService.updateAndNotify called with badge: ${badge.title}');
    final badgeRepository = _ref.read(badgeRepositoryProvider);

    // 뱃지 업데이트
    final updatedBadge = await badgeRepository.update(badge);

    // 뱃지가 획득되었을 때만 알림
    if (updatedBadge.isAchieved) {
      logger.d('Badge is achieved, adding to newBadgesProvider: ${updatedBadge.title}');
      _ref.read(newBadgesProvider.notifier).addBadge(updatedBadge);

      // 현재 newBadgesProvider 상태 확인
      final currentBadges = _ref.read(newBadgesProvider);
      logger.d('Current newBadgesProvider state length after updateAndNotify: ${currentBadges.length}');
    } else {
      logger.d('Badge is not achieved, not adding to newBadgesProvider: ${updatedBadge.title}');
    }
  }

  /// 뱃지 생성 또는 업데이트
  Future<BadgeModel> createOrUpdateBadge(BadgeModel badge) async {
    logger.d('BadgeService.createOrUpdateBadge called with badge: ${badge.title}');
    final badgeRepository = _ref.read(badgeRepositoryProvider);

    // badge ID가 0이면 새로 생성, 아니면 업데이트
    if (badge.id == 0) {
      return await badgeRepository.create(badge);
    } else {
      return await badgeRepository.update(badge);
    }
  }
}
