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

  @override
  void initState() {
    super.initState();
    // 광고가 활성화된 경우에만 배너 광고 로드
    if (AppFeatureConfig.isAdsEnabled) {
      _loadBannerAd();
    }
  }

  @override
  void dispose() {
    AdService().disposeBannerAd(widget.adKey);
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
    final (aspectRatio, bannerWidget) = await AdService().createBannerAd(widget.adKey);
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
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(child: widget.child),
        if (!settings.isSubscriptionActive && AppFeatureConfig.isAdsEnabled)
          AspectRatio(
            aspectRatio: _bannerAspectRatio,
            child: _bannerWidget,
          ),
      ],
    );
  }
}
