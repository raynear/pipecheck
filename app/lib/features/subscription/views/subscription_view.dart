import 'package:boilerplate/config/app_config.dart';
import 'package:boilerplate/core/services/in_app_purchase_service.dart';
import 'package:boilerplate/core/widgets/buttons/adaptive_button.dart';
import 'package:boilerplate/core/widgets/buttons/analytics_buttons.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utils/utils.dart';

class SubscriptionView extends ConsumerStatefulWidget {
  const SubscriptionView({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends ConsumerState<SubscriptionView> {
  String _yearlyDiscount = '0';
  String _selectedSubscription = 'monthly';
  String _monthlyPrice = '0';
  String _yearlyPrice = '0';
  String _lifetimePrice = '0';

  @override
  void initState() {
    super.initState();
    _loadProductPrices();
  }

  void _loadProductPrices() {
    final products = AppConfig.products;
    if (products.length >= 3) {
      final appConfig = AppConfig();
      final monthly = products.firstWhere((p) => p.id == appConfig.productIds['monthly']);
      final yearly = products.firstWhere((p) => p.id == appConfig.productIds['yearly']);
      final lifetime = products.firstWhere((p) => p.id == appConfig.productIds['lifetime']);

      setState(() {
        _monthlyPrice = monthly.price;
        _yearlyPrice = yearly.price;
        _lifetimePrice = lifetime.price;
        _yearlyDiscount = ref.read(inAppPurchaseServiceProvider)?.calculateDiscount(monthly.price, yearly.price, 12) ?? '0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // // 첫 앱 출시를 위해서 subscription 기능 비활성화
    // if (true) {
    //   return Container(
    //     height: MediaQuery.of(context).size.height * 0.9,
    //     decoration: BoxDecoration(
    //       color: colorScheme.surface,
    //       borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    //     ),
    //     child: Column(
    //       children: [
    //         Container(
    //           height: 5,
    //           width: 40,
    //           margin: const EdgeInsets.symmetric(vertical: 10),
    //           decoration: BoxDecoration(
    //             color: colorScheme.onSurface.withValues(alpha: 0.1),
    //             borderRadius: BorderRadius.circular(2.5),
    //           ),
    //         ),
    //         Expanded(
    //           child: Column(
    //             mainAxisAlignment: MainAxisAlignment.center,
    //             children: [
    //               Image.asset(
    //                 'assets/images/subscription_image.png',
    //                 width: MediaQuery.of(context).size.width * 0.8,
    //               ),
    //               const SizedBox(height: 30),
    //               SText(
    //                 'Coming Soon!',
    //                 style: textTheme.headlineMedium?.copyWith(
    //                   fontWeight: FontWeight.bold,
    //                   color: colorScheme.primary,
    //                 ),
    //               ),
    //               const SizedBox(height: 16),
    //               Padding(
    //                 padding: const EdgeInsets.symmetric(horizontal: 32),
    //                 child: SText(
    //                   'Premium features are currently under development.\nStay tuned for exciting updates!',
    //                   textAlign: TextAlign.center,
    //                   style: textTheme.titleMedium?.copyWith(
    //                     color: colorScheme.onSurface.withValues(alpha: 0.8),
    //                     height: 1.5,
    //                   ),
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //   );
    // }

    return Container(
      height: MediaQuery.of(context).size.height * 1.0,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            height: 5,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Image.asset('assets/images/subscription_image.png'),
                  const SizedBox(height: 20),
                  SText(
                    // 카피 미설정 시 기본 번역 키 (P1-15: project.yaml iap.headline_copy)
                    AppConfig.subscriptionHeadline.isNotEmpty
                        ? AppConfig.subscriptionHeadline
                        : 'Enjoy premium features!',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SText(
                      AppConfig.subscriptionBenefits.isNotEmpty
                          ? AppConfig.subscriptionBenefits
                          : 'Unlimited habit tracking, advanced analytics, remove ads, etc.',
                      style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildSubscriptionOption(
                      'Monthly Subscription'.tr(), '{}/month'.tr(args: [_monthlyPrice]), 'monthly'),
                  const SizedBox(height: 10),
                  _buildSubscriptionOption(
                      'Yearly Subscription'.tr(),
                      '{}/year ({}% discount)'
                          .tr(args: [_yearlyPrice, (100 * double.parse(_yearlyDiscount)).floor().toString()]),
                      'yearly'),
                  const SizedBox(height: 10),
                  _buildSubscriptionOption('Lifetime Subscription'.tr(), _lifetimePrice, 'lifetime'),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SText('Subscription Terms:',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SText('• Purchases are made through your App Store account. You will automatically be charged for renewal unless you cancel. You can cancel anytime.',
                          style: textTheme.bodyMedium,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AdaptiveButton(
                              label: '',
                              onPressed: () => _launchURL(AppConfig.privacyPolicyUrl),
                              variant: ButtonVariant.text,
                              child: SText('Privacy Policy'),
                            ),
                            const SizedBox(width: 20),
                            AdaptiveButton(
                              label: '',
                              // 약관 URL 미설정 시 Apple 표준 EULA 폴백 (P1-15)
                              onPressed: () => _launchURL(
                                  AppConfig.termsOfServiceUrl.isNotEmpty
                                      ? AppConfig.termsOfServiceUrl
                                      : 'https://www.apple.com/legal/macapps/stdeula'),
                              variant: ButtonVariant.text,
                              child: SText('Terms of Use'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AdaptiveButton(
                    label: '',
                    onPressed: _subscribe,
                    variant: ButtonVariant.primary,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getSubscriptionButtonText(),
                          style: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary),
                        ),
                        SText(
                          'Join membership',
                          style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnalyticsInkWell(
                    eventName: 'restore_purchase',
                    onTap: () async {
                      await ref.read(inAppPurchaseServiceProvider)?.restorePurchase();
                    },
                    child: SText('Restore Purchase',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.primary, decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption(String title, String price, String subscriptionType) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedSubscription == subscriptionType;

    // 자동 갱신 텍스트 설정
    String renewalText = '';
    if (subscriptionType == 'monthly') {
      renewalText = 'Auto-renews monthly'.tr();
    } else if (subscriptionType == 'yearly') {
      renewalText = 'Auto-renews yearly'.tr();
    } else if (subscriptionType == 'lifetime') {
      renewalText = 'One-time purchase'.tr();
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubscription = subscriptionType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : null,
          border: Border.all(
            color: isSelected ? colorScheme.tertiary : colorScheme.onSurface.withValues(alpha: 0.2),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary.withValues(alpha: 0.8)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    renewalText,
                    style: textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary.withValues(alpha: 0.7)
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }

  void _subscribe() async {
    final products = AppConfig.products;
    if (products.isEmpty) {
      logger.e('Failed to load product information');
      return;
    }

    final appConfig = AppConfig();
    final productId = appConfig.productIds[_selectedSubscription];
    if (productId == null) {
      logger.e('Failed to find product ID for the selected subscription type');
      return;
    }

    final product = products.firstWhere((p) => p.id == productId);

    final inAppService = ref.read(inAppPurchaseServiceProvider);
    if (inAppService == null) {
      logger.w('In-App Purchase service is not available');
      return;
    }
    final success = await inAppService.buyProduct(product);
    if (success) {
      logger.d('Purchase successful');
      if (!mounted) return;
      context.pop();
    } else {
      logger.e('Purchase failed');
    }
  }

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  String _getSubscriptionButtonText() {
    switch (_selectedSubscription) {
      case 'monthly':
        return 'Start at {} for month'.tr(args: [_monthlyPrice]);
      case 'yearly':
        return 'Start at {} for year'.tr(args: [_yearlyPrice]);
      case 'lifetime':
        return 'Join lifetime membership at {}'.tr(args: [_lifetimePrice]);
      default:
        return '';
    }
  }
}
