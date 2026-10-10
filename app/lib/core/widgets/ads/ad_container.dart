import 'package:ads/ads.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdContainer extends ConsumerStatefulWidget {
  final Widget child;
  final String adKey; // 추가
  const AdContainer({
    super.key,
    required this.child,
    this.adKey = 'default', // 기본값 설정
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AdContainerState();
}

class _AdContainerState extends ConsumerState<AdContainer> {
  double _bannerAspectRatio = 6.4;
  Widget _bannerWidget = Image.asset('assets/images/fallback_banner.jpg');
  // 옛 소유자의 AdWidget State는 그것이 빠진 프레임 '끝'에야 dispose되므로, 소유권을 받은 프레임이나
  // 그 다음 프레임에 그리면 두 AdWidget이 잠깐 겹쳐 assertion이 난다. 프레임을 두 번 건너 그린다.
  bool _renderAd = false;
  bool _renderScheduled = false;

  @override
  void initState() {
    super.initState();
    // 광고가 활성화된 경우에만 배너 광고 로드
    if (AppFeatureConfig.isAdsEnabled) {
      _loadBannerAd();
      AdService().bannerAds.ownerChanges.addListener(_onOwnerChanged);
    }
  }

  // 같은 adKey를 쓰는 다른 컨테이너가 소유권을 가져가거나 돌려줄 때 다시 그린다.
  // 소유자가 해제돼 키가 비면(push했던 같은 키 화면이 pop됨) 광고도 해제됐으므로, 남은 컨테이너가
  // 소유권을 되찾아 다시 로드한다. 리스너는 차례로 도는데 create가 동기적으로 소유자를 잡으므로
  // 첫 컨테이너만 로드하고 나머지는 hasOwner가 true라 건너뛴다.
  void _onOwnerChanged() {
    if (!mounted) return;
    if (!AdService().bannerAds.hasOwner(widget.adKey) &&
        AppFeatureConfig.isAdsEnabled) {
      setState(() {
        _renderAd = false;
        _bannerWidget = Image.asset(
          'assets/images/fallback_banner.jpg',
        ); // 해제된 광고를 그리지 않는다
      });
      _loadBannerAd();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    if (AppFeatureConfig.isAdsEnabled) {
      AdService().bannerAds.ownerChanges.removeListener(_onOwnerChanged);
    }
    AdService().disposeBannerAd(widget.adKey, this);
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
    final (aspectRatio, bannerWidget) = await AdService().createBannerAd(
      widget.adKey,
      this,
    );
    if (mounted) {
      setState(() {
        _bannerAspectRatio = aspectRatio;
        _bannerWidget = bannerWidget;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isOwner = AdService().bannerAds.isOwner(widget.adKey, this);
    if (!isOwner) {
      _renderAd = false;
    } else if (!_renderAd && !_renderScheduled) {
      _renderScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 이 setState가 다음 프레임을 만들고, 그 프레임에서 옛 소유자가 빈 자리로 바뀐다.
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _renderScheduled = false;
          if (mounted) setState(() => _renderAd = true);
        });
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(child: widget.child),
        if (!settings.isSubscriptionActive && AppFeatureConfig.isAdsEnabled)
          AspectRatio(
            aspectRatio: _bannerAspectRatio,
            // 같은 BannerAd를 두 AdWidget이 그리면 assertion — 소유자만 그린다.
            child: isOwner && _renderAd
                ? _bannerWidget
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
