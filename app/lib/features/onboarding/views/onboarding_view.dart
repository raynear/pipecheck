import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/core/widgets/buttons/adaptive_button.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Subscription-related state
  String _selectedSubscription = 'monthly';
  String _monthlyPrice = '';
  String _yearlyPrice = '';
  String _lifetimePrice = '';
  String _yearlyDiscount = '0';

  @override
  void initState() {
    super.initState();
    // 온보딩 퍼널 계측(P2-23g). Analytics 미가용 시 FirebaseService가 no-op.
    FirebaseService.logEvent(name: 'onboarding_start');
    FirebaseService.logEvent(
      name: 'onboarding_step_view',
      parameters: {'step': 0},
    );
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
        });
        FirebaseService.logEvent(
          name: 'onboarding_step_view',
          parameters: {'step': page},
        );
      }
    });
    _loadProductPrices();
  }

  void _loadProductPrices() {
    if (!AppFeatureConfig.isSubscriptionEnabled) return;

    final products = AppConfig.products;
    if (products.length >= 3) {
      final appConfig = AppConfig();
      try {
        final monthly = products.firstWhere((p) => p.id == appConfig.productIds['monthly']);
        final yearly = products.firstWhere((p) => p.id == appConfig.productIds['yearly']);
        final lifetime = products.firstWhere((p) => p.id == appConfig.productIds['lifetime']);

        setState(() {
          _monthlyPrice = monthly.price;
          _yearlyPrice = yearly.price;
          _lifetimePrice = lifetime.price;
          _yearlyDiscount = ref.read(inAppPurchaseServiceProvider)?.calculateDiscount(monthly.price, yearly.price, 12) ?? '0';
        });
      } catch (_) {
        // Products not loaded yet
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showLanguageSelector(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SText(
                  'Select Language',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: supportedLocales.length,
                  itemBuilder: (context, index) {
                    final locale = supportedLocales[index];
                    final isSelected = settings.language == locale;
                    final languageName = LocaleNamesLocalizationsDelegate
                        .nativeLocaleNames[locale.toLanguageTag().replaceAll('-', '_')];

                    return ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? colorScheme.primary : Colors.grey,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      title: SText(
                        languageName ?? '',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                      subtitle: SText(
                        locale.toLanguageTag(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () async {
                        ref.read(settingsProvider.notifier).updateSingleSetting(language: locale);
                        context.setLocale(locale);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final onboardingPages = [
      _buildOnboardingPage(
        context,
        icon: Icons.rocket_launch,
        title: 'Welcome to BoilerPlate',
        description: 'Your powerful starting point for Flutter app development',
      ),
      _buildOnboardingPage(
        context,
        icon: Icons.palette,
        title: 'Beautiful Design',
        description: 'Choose from multiple themes and customize your experience',
      ),
      _buildOnboardingPage(
        context,
        icon: Icons.notifications_active,
        title: 'Smart Notifications',
        description: 'Stay updated with timely reminders and important updates',
      ),
      _buildOnboardingPage(
        context,
        icon: Icons.security,
        title: 'Secure & Private',
        description: 'Your data is protected with industry-standard security',
      ),
      // Subscription/Welcome page as the last page
      if (AppFeatureConfig.isSubscriptionEnabled)
        _buildSubscriptionPage(context, settings),
    ];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Language selector button in top right
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AdaptiveButton(
                  label: 'Language',
                  onPressed: () => _showLanguageSelector(context),
                  variant: ButtonVariant.text,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      SText(
                        LocaleNamesLocalizationsDelegate
                            .nativeLocaleNames[settings.language.toLanguageTag().replaceAll('-', '_')] ??
                            'Language',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    children: onboardingPages,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: onboardingPages.length,
                        effect: WormEffect(
                          dotHeight: 10,
                          dotWidth: 10,
                          activeDotColor: colorScheme.primary,
                          dotColor: colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentPage > 0)
                            AdaptiveButton(
                              label: 'Previous',
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              variant: ButtonVariant.text,
                              child: SText('Previous'),
                            )
                          else
                            const SizedBox(width: 80),

                          AdaptiveButton(
                            label: 'Skip',
                            onPressed: () async {
                              FirebaseService.logEvent(
                                name: 'onboarding_skip',
                                parameters: {'step': _currentPage},
                              );
                              await ref.read(settingsProvider.notifier)
                                  .updateSingleSetting(onBoard: true);
                              if (!context.mounted) return;
                              context.go('/home');
                            },
                            variant: ButtonVariant.text,
                            child: SText('Skip'),
                          ),

                          if (_currentPage < onboardingPages.length - 1)
                            AdaptiveButton(
                              label: 'Next',
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              variant: ButtonVariant.primary,
                              child: SText('Next'),
                            )
                          else
                            AdaptiveButton(
                              label: 'Get Started',
                              onPressed: () async {
                                FirebaseService.logEvent(
                                  name: 'onboarding_complete',
                                  parameters: {'method': 'get_started'},
                                );
                                await ref.read(settingsProvider.notifier)
                                    .updateSingleSetting(onBoard: true);
                                if (!context.mounted) return;
                                context.go('/home');
                              },
                              variant: ButtonVariant.primary,
                              child: SText('Get Started'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          SText(
            title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SText(
            description,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 구독 페이지 또는 이미 구독 중인 경우 환영 메시지 표시
  Widget _buildSubscriptionPage(BuildContext context, Settings settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 이미 구독 중인 경우 환영 메시지 표시
    if (settings.isSubscriptionActive) {
      return _buildWelcomePage(context);
    }

    // 구독 페이지 표시
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.workspace_premium,
                size: 50,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            SText('Unlock Premium Features',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SText('Get unlimited access to all features, remove ads, and more!',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildSubscriptionOption(
              'Monthly'.tr(),
              _monthlyPrice.isNotEmpty ? '{}/month'.tr(args: [_monthlyPrice]) : 'Loading...'.tr(),
              'monthly',
            ),
            const SizedBox(height: 8),
            _buildSubscriptionOption(
              'Yearly'.tr(),
              _yearlyPrice.isNotEmpty
                  ? '{}/year ({}% off)'.tr(args: [_yearlyPrice, (100 * double.parse(_yearlyDiscount)).floor().toString()])
                  : 'Loading...'.tr(),
              'yearly',
            ),
            const SizedBox(height: 8),
            _buildSubscriptionOption(
              'Lifetime'.tr(),
              _lifetimePrice.isNotEmpty ? _lifetimePrice : 'Loading...'.tr(),
              'lifetime',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AdaptiveButton(
                label: 'Subscribe',
                onPressed: _subscribe,
                variant: ButtonVariant.primary,
                child: SText('Subscribe Now',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AdaptiveButton(
              label: 'Restore',
              onPressed: () async {
                await ref.read(inAppPurchaseServiceProvider)?.restorePurchase();
              },
              variant: ButtonVariant.text,
              child: SText('Restore Purchase',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AdaptiveButton(
                  label: 'Privacy',
                  onPressed: () => _launchURL(AppConfig.privacyPolicyUrl),
                  variant: ButtonVariant.text,
                  child: SText('Privacy Policy',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                SText(' | ', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                AdaptiveButton(
                  label: 'Terms',
                  // 약관 URL 미설정 시 Apple 표준 EULA 폴백 (P1-15)
                  onPressed: () => _launchURL(AppConfig.termsOfServiceUrl.isNotEmpty
                      ? AppConfig.termsOfServiceUrl
                      : 'https://www.apple.com/legal/macapps/stdeula'),
                  variant: ButtonVariant.text,
                  child: SText('Terms of Use',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  /// 이미 구독 중인 사용자를 위한 환영 페이지
  Widget _buildWelcomePage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified,
              size: 60,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 40),
          SText('Welcome Back, Premium Member!',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SText('Thank you for your support! Enjoy all premium features without any limits.',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption(String title, String price, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = _selectedSubscription == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubscription = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : null,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SText(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
                SText(
                  price,
                  style: textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimary.withValues(alpha: 0.8)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe() async {
    final products = AppConfig.products;
    if (products.isEmpty) return;

    final appConfig = AppConfig();
    final productId = appConfig.productIds[_selectedSubscription];
    if (productId == null) return;

    try {
      final product = products.firstWhere((p) => p.id == productId);
      final inAppService = ref.read(inAppPurchaseServiceProvider);
      if (inAppService == null) return;

      final success = await inAppService.buyProduct(product);
      if (success && mounted) {
        // 구독 성공 시 onboarding 완료 처리
        FirebaseService.logEvent(
          name: 'onboarding_complete',
          parameters: {'method': 'subscribe'},
        );
        await ref.read(settingsProvider.notifier).updateSingleSetting(onBoard: true);
        if (!mounted) return;
        context.go('/home');
      }
    } catch (_) {
      // Product not found
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}