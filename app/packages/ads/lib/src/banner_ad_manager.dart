import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:utils/utils.dart';

import 'ad_consent_manager.dart';
import 'ads_config.dart';

class BannerAdManager {
  static const double _fallbackAspectRatio = 6.4;

  final AdsConfig config;
  final String? bannerAdId;
  final Future<void> Function() ensureInitialized;

  // 배너 광고 관리 맵
  final Map<String, (BannerAd?, Widget)> _bannerAds = {};

  BannerAdManager({
    required this.config,
    required this.bannerAdId,
    required this.ensureInitialized,
  });

  // 키별 진행 중 로드 토큰 — 해제·dispose·같은 키의 새 로드가 일어나면 토큰이 사라지거나 바뀌어,
  // 늦게 끝난 로드가 자기 광고를 해제한다(해제된 매니저/키에 광고가 되살아나 누수되는 것을 막는다).
  final Map<String, Object> _loadTokens = {};
  // 키별 최신 소유자 — 퇴장 중인 옛 State의 dispose가 같은 키를 쓰는 새 소유자의 광고를 지우지 않게 한다.
  final Map<String, Object> _owners = {};
  bool _disposed = false;

  /// 소유자가 바뀔 때마다 값이 오른다 — 같은 키를 쓰는 컨테이너들이 다시 그릴지 판단하는 신호.
  final ValueNotifier<int> ownerChanges = ValueNotifier(0);

  /// 한 BannerAd는 한 AdWidget만 그릴 수 있다(둘이면 "AdWidget is already in the Widget tree").
  /// 컨테이너는 이게 true일 때만 광고 위젯을 그리고, 아니면 같은 크기의 빈 자리를 그린다.
  bool isOwner(String key, Object owner) => _owners[key] == owner;

  /// 키에 소유자가 없다 — 마지막 소유자가 해제됐으니 남은 컨테이너가 다시 불러야 한다.
  bool hasOwner(String key) => _owners.containsKey(key);

  void _notifyOwnerChanged() {
    // 호출자가 build/initState 중일 수 있어 — 리스너의 setState가 build 도중에 돌지 않게 미룬다.
    scheduleMicrotask(() {
      if (!_disposed) ownerChanges.value++;
    });
  }

  (double, Widget) get _emptyBanner =>
      (_fallbackAspectRatio, const SizedBox.shrink());

  /// 광고가 꺼졌거나 동의가 없거나 SDK 초기화가 실패하면 false — 호출자는 빈 배너를 돌려준다.
  bool _ready() {
    // 광고가 비활성화된 경우 빈 배너와 위젯 반환
    if (!config.adsEnabled) {
      logger.d('Ads are disabled - returning empty banner');
      return false;
    }

    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - returning empty banner');
      return false;
    }

    return true;
  }

  Future<bool> _initialized() async {
    try {
      await ensureInitialized();
    } catch (e) {
      logger.e('Ad SDK initialization failed - returning empty banner: $e');
      return false;
    }
    return !_disposed;
  }

  // 배너 광고 생성 (통합된 방식)
  Future<(double, Widget)> createBannerAd([
    String key = 'default',
    Object? owner,
  ]) async {
    if (owner != null && _owners[key] != owner) {
      _owners[key] = owner;
      _notifyOwnerChanged();
    }
    if (!_ready() || !await _initialized()) return _emptyBanner;

    // 이미 존재하는 광고가 있다면 반환
    if (_bannerAds.containsKey(key) && _bannerAds[key]!.$1 != null) {
      final cached = _bannerAds[key]!;
      return (cached.$1!.size.width / cached.$1!.size.height, cached.$2);
    }

    return _loadBanner(key);
  }

  // 배너 광고 해제
  /// [owner]를 주면 그 키의 최신 소유자일 때만 해제한다 (아니면 새 소유자가 쓰는 중이라 무시).
  void disposeBannerAd(String key, [Object? owner]) {
    if (owner != null) {
      if (_owners[key] != owner) return;
      _owners.remove(key);
      _notifyOwnerChanged(); // 같은 키의 다른 컨테이너가 소유권을 되찾아 다시 로드한다
    }
    _loadTokens.remove(key); // 로드 중이던 광고는 끝나는 즉시 스스로 해제한다
    final adPair = _bannerAds[key];
    if (adPair != null) {
      adPair.$1?.dispose();
      _bannerAds.remove(key);
      logger.d('Banner ad disposed for key: $key');
    }
  }

  // 배너 광고 새로고침 (화면 전환 시 호출)
  Future<(double, Widget)> refreshBannerAd(String key) async {
    if (!_ready()) return _emptyBanner;

    // 기존 배너 해제
    disposeBannerAd(key);

    // 새 배너 로드
    if (!await _initialized()) return _emptyBanner;

    return _loadBanner(key);
  }

  Future<(double, Widget)> _loadBanner(String key) async {
    final adId = bannerAdId;

    if (adId == null) {
      final fallbackWidget = Image.asset('assets/images/fallback_banner.jpg');
      _bannerAds[key] = (null, fallbackWidget);
      logger.w('Banner ad ID not found for key: $key, using fallback');
      return (_fallbackAspectRatio, fallbackWidget);
    }

    final token = Object();
    _loadTokens[key] = token;
    bool cancelled() => _disposed || _loadTokens[key] != token;

    final newBannerAd = BannerAd(
      adUnitId: adId,
      request: AdConsentManager.currentAdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          logger.d('Banner ad loaded successfully for key: $key');
        },
        onAdFailedToLoad: (ad, error) async {
          logger.e('Banner ad failed to load for key $key: $error');
          ad.dispose();
          if (identical(_bannerAds[key]?.$1, ad)) _bannerAds.remove(key);
        },
      ),
    );

    try {
      await newBannerAd.load();
      if (cancelled()) {
        newBannerAd.dispose();
        return _emptyBanner;
      }
      _loadTokens.remove(key);
      final adWidget = AdWidget(ad: newBannerAd);
      _bannerAds[key] = (newBannerAd, adWidget as Widget);
      return (
        newBannerAd.size.width / newBannerAd.size.height,
        adWidget as Widget,
      );
    } catch (e) {
      logger.e('Error loading banner ad for key $key: $e');
      newBannerAd.dispose();
      if (cancelled()) return _emptyBanner;
      _loadTokens.remove(key);
      final fallbackWidget = Image.asset('assets/images/fallback_banner.jpg');
      _bannerAds[key] = (null, fallbackWidget);
      return (_fallbackAspectRatio, fallbackWidget);
    }
  }

  // 리소스 해제
  void dispose() {
    _disposed = true;
    ownerChanges.dispose();
    _loadTokens.clear();
    _owners.clear();
    for (final entry in _bannerAds.entries) {
      entry.value.$1?.dispose();
    }
    _bannerAds.clear();
  }
}
