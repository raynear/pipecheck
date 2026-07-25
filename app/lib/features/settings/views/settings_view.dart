import 'dart:convert';
import 'dart:io';

import 'package:ads/ads.dart';
import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/design/design_system_provider.dart';
import 'package:pipecheck/core/router.dart';
import 'package:pipecheck/core/services/badge_service.dart';
import 'package:pipecheck/core/services/data_export_service.dart';
import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/services/notification/notification.dart';
import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/restore_service.dart';
import 'package:pipecheck/core/services/share_service.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/core/widgets/buttons/adaptive_button.dart';
import 'package:pipecheck/core/widgets/buttons/analytics_buttons.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:pipecheck/core/widgets/navigation/adaptive_app_bar.dart';
import 'package:pipecheck/core/widgets/toggles/adaptive_toggle.dart';
import 'package:pipecheck/data/definitions/badge.dart';
import 'package:pipecheck/data/generated/models/badge.model.dart';
import 'package:pipecheck/data/generated/repositories/badge.repository.dart';
import 'package:pipecheck/data/generated/repositories/user.repository.dart';
import 'package:pipecheck/features/permission/views/permission_request_view.dart';
import 'package:pipecheck/features/subscription/views/subscription_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:panara_dialogs/panara_dialogs.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utils/utils.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsView> {
  bool useNotification = false;
  bool useReminder = false;
  TimeOfDay reminderTime = TimeOfDay.now();
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = ref.watch(settingsProvider);
      setState(() {
        useNotification = settings.useNotification;
        useReminder = settings.useReminder;
      });
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      setState(() {
        _packageInfo = packageInfo;
      });
      ref.read(settingsProvider.notifier).checkAndUpdateSubscription();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  ThemeMode strToThemeMode(String str) {
    switch (str) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String themeModeToStr(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System';
    }
  }

  Future<void> _awardBadge(String badgeId) async {
    final badgeRepository = ref.read(badgeRepositoryProvider);
    final String jsonString = await rootBundle.loadString('assets/data/badges.json');
    final List<dynamic> badgesData = json.decode(jsonString);

    final badgeData = badgesData.firstWhere((badge) => badge['id'] == badgeId, orElse: () => null);
    if (badgeData != null) {
      final existingBadge = await badgeRepository.getById(badgeData['id']);
      if (existingBadge != null) {
        // 뱃지 업데이트
        if (!mounted) return;
        final updatedBadge = existingBadge.copyWith(
          isAchieved: true,
          earnedDate: DateTime.now(),
        );
        await badgeRepository.update(updatedBadge);

        // BadgeService에 알림
        await ref.read(badgeServiceProvider).updateAndNotify(updatedBadge);
      } else {
        // 뱃지가 데이터베이스에 없는 경우 새로운 BadgeModel 생성
        final newBadge = BadgeModel(
          id: 0, // 자동 생성될 것임
          badgeId: badgeData['id'],
          title: badgeData['title'],
          description: badgeData['description'],
          iconPath: badgeData['iconPath'],
          type: BadgeType.values[badgeData['type'] as int],
          isAchieved: true,
          earnedDate: DateTime.now(),
          condition: badgeData['condition'],
          createdAt: DateTime.now(),
        );

        // DB에 생성
        if (!mounted) return;
        await badgeRepository.create(newBadge);

        // BadgeService에 알림
        await ref.read(badgeServiceProvider).updateAndNotify(newBadge);
      }
      if (!mounted) return;
      ref.read(snackBarServiceProvider).showSuccess("Badge '${badgeData['title']}' awarded");
    } else {
      if (!mounted) return;
      ref.read(snackBarServiceProvider).showError('Badge not found'.tr());
    }
  }

  Future<void> _removeBadge(int badgeId) async {
    final badgeRepository = ref.read(badgeRepositoryProvider);
    final badge = await badgeRepository.getById(badgeId);
    if (badge != null) {
      final updatedBadge = badge.copyWith(isAchieved: false);
      await badgeRepository.update(updatedBadge);
    }
    if (!mounted) return;
    ref.read(snackBarServiceProvider).showSuccess("Badge '$badgeId' removed");
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // final identity = ref.watch(identityProvider); // Identity를 가져오는 Provider

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: SText('Settings'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SingleChildScrollView(
            child: Column(children: [
              if (AppFeatureConfig.isDarkModeEnabled) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Display',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Dark Mode *'),
                if (settings.isSubscriptionActive)
                  DropdownButton<ThemeMode>(
                    value: settings.displayMode,
                    onChanged: (newTheme) async {
                      if (newTheme != null) {
                        ref.read(settingsProvider.notifier).updateSingleSetting(displayMode: newTheme);
                      }
                    },
                    items: ThemeMode.values.map((ThemeMode mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: SText(themeModeToStr(mode),
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                      );
                    }).toList(),
                  )
                else
                  AdaptiveButton(
                    label: '',
                    onPressed: () {
                      _showSubscriptionView();
                    },
                    child: SText('Premium only'),
                  ),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Theme Color *'),
                if (settings.isSubscriptionActive)
                  DropdownButton<String>(
                    value: themeColors.containsKey(settings.themeColor) ? settings.themeColor : 'blue',
                    itemHeight: kMinInteractiveDimension,
                    onChanged: (newThemeColor) async {
                      if (newThemeColor != null) {
                        ref.read(settingsProvider.notifier).updateSingleSetting(themeColor: newThemeColor);
                      }
                    },
                    items: themeColors.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            alignment: AlignmentDirectional.center,
                            value: entry.key,
                            child: Container(
                              padding: EdgeInsets.zero,
                              color: entry.value.colors(Brightness.light).primary,
                              child: SizedBox(width: 70, height: 30),
                            ),
                          ),
                        )
                        .toList(),
                  )
                else
                  AdaptiveButton(
                    label: '',
                    onPressed: () {
                      _showSubscriptionView();
                    },
                    child: SText('Premium only'),
                  ),
              ]),
              const Divider(thickness: 2),
            ],
              // TODO: 언어 선택시 notification 재 설정 필요
              if (AppFeatureConfig.isMultiLanguageEnabled) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Language',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Language'),
                DropdownButton<Locale>(
                  value: settings.language,
                  onChanged: (newLang) async {
                    if (newLang != null) {
                      ref.read(settingsProvider.notifier).updateSingleSetting(language: newLang);
                      context.setLocale(newLang);
                    }
                  },
                  items: supportedLocales.map((Locale lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: SText(
                          LocaleNamesLocalizationsDelegate
                              .nativeLocaleNames[lang.toLanguageTag().replaceAll('-', '_')]!,
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                    );
                  }).toList(),
                ),
              ]),
              const Divider(thickness: 2),
            ],
              // 보안: 앱 잠금 방식 + PIN 설정/변경 (P2-23h ②)
              if (AppFeatureConfig.isAuthenticationEnabled &&
                  (AppFeatureConfig.isBiometricAuthEnabled || AppFeatureConfig.isPinAuthEnabled)) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('auth.pin.securitySection',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('auth.pin.appLock'),
                DropdownButton<UserAuthOption>(
                  value: _authOptions().contains(settings.userAuthOption)
                      ? settings.userAuthOption
                      : UserAuthOption.none,
                  onChanged: _onAuthOptionChanged,
                  items: _authOptions().map((UserAuthOption option) {
                    return DropdownMenuItem<UserAuthOption>(
                      value: option,
                      child: SText(_authOptionLabelKey(option),
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                    );
                  }).toList(),
                ),
              ]),
              if (AppFeatureConfig.isPinAuthEnabled &&
                  (settings.userAuthOption == UserAuthOption.pin ||
                      settings.userAuthOption == UserAuthOption.biometric))
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  SText('auth.pin.changeTitle'),
                  AdaptiveButton(
                    label: '',
                    onPressed: () => context.push('/settings/pin'),
                    child: SText('auth.pin.changeAction'),
                  ),
                ]),
              const Divider(thickness: 2),
            ],
              if (AppFeatureConfig.isNotificationEnabled) ...[
              const Divider(thickness: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Notification',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Use Notification'),
                AdaptiveSwitch(
                  value: useNotification,
                  onChanged: (value) async {
                    if (value) {
                      final isAllowed =
                          await RaynearNotification().isNotificationAllowedRaw();
                      if (!isAllowed) {
                        await RaynearNotification().requestPermissionRaw();
                      }
                      RaynearNotification().resumeAppNotification();
                    } else {
                      RaynearNotification().pauseAppNotification();
                    }
                    setState(() {
                      useNotification = value;
                    });
                    ref.read(settingsProvider.notifier).updateSingleSetting(useNotification: value);
                  },
                ),
              ]),
              if (useNotification)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(),
                  SElevatedButton(
                    onPressed: () async {
                      try {
                        await RaynearNotification().createNotificationNow(
                          title: 'Test Notification'.tr(),
                          body: 'This is a test notification to verify your settings are working properly.'.tr(),
                        );
                        if (!mounted) return;
                        ref.read(snackBarServiceProvider).showSuccess('Test notification sent successfully!'.tr());
                      } catch (e) {
                        logger.e('Test notification failed: $e');
                        if (!mounted) return;
                        ref.read(snackBarServiceProvider).showError('Failed to send test notification: $e'.tr());
                      }
                    },
                    child: SText('Test Notification'),
                  ),
                ]),
              ],
              if (AppFeatureConfig.isReminderEnabled) ...[
              const Divider(thickness: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Reminder',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Use Reminder'),
                Switch(
                  value: settings.useReminder,
                  onChanged: (value) async {
                    setState(() {
                      useReminder = value;
                    });
                    ref.read(settingsProvider.notifier).updateSingleSetting(useReminder: value);
                    if (value) {
                      RaynearNotification().setReminderNotification();
                    } else {
                      RaynearNotification().deleteReminderNotification();
                    }
                  },
                ),
              ]),
              if (useReminder)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(),
                  SElevatedButton(
                      onPressed: () {
                        _selectTime(context, settings.reminderTime);
                      },
                      child: settings.useReminder == true
                          ? SText(settings.reminderTime.format(context))
                          : SText('Select Time'))
                ]),
              ],
              // (iCloud 동기화 UI는 P1-16에서 삭제 — icloud_storage 의존성이
              //  주석 처리돼 기능 자체가 없음. 복원 시 examples 참조)
              const Divider(thickness: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('App Usage Guide',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('App Usage Guide'),
                SElevatedButton(
                    onPressed: () async {
                      await ref.read(settingsProvider.notifier).updateSingleSetting(onBoard: false);
                      if (!context.mounted) return;
                      context.push('/onboarding');
                    },
                    child: SText('View Again')),
              ]),
              const Divider(thickness: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('App Review',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Please rate this app'),
                SElevatedButton(
                  onPressed: () async {
                    if (await InAppReview.instance.isAvailable()) {
                      await InAppReview.instance.requestReview();
                      logger.d('In-app review requested - Direct request from settings screen');
                    } else {
                      logger.e('In-app review is not available');
                    }
                  },
                  child: SText('Rate'),
                ),
              ]),

              const Divider(thickness: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Info',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                Container(),
              ]),
              settings.isSubscriptionActive
                  ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      SText('Subscription Status'),
                      SText('Active until {}',
                          args: [DateFormat('yyyy-MM-dd').format(settings.subscriptionExpiryDate!)]),
                    ])
                  : Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        SText('Premium license'),
                        SElevatedButton(
                          onPressed: () async {
                            await _showSubscriptionView();
                          },
                          child: SText('Subscribe'),
                        )
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Container(),
                        SElevatedButton(
                          onPressed: () async {
                            await ref.read(inAppPurchaseServiceProvider)?.restorePurchase();
                          },
                          child: SText('Restore Purchase'),
                        )
                      ]),
                    ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                SText('Current App Version'),
                SText('v{}', args: [_packageInfo?.version ?? '0.0.0']),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                InkWell(
                  onTap: () async {
                    // 약관 URL 미설정 시 Apple 표준 EULA 폴백 (P1-15)
                    final url = Uri.parse(AppConfig.termsOfServiceUrl.isNotEmpty
                        ? AppConfig.termsOfServiceUrl
                        : 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  child:
                      SText('Terms of Use', style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                ),
                InkWell(
                  onTap: () async {
                    if (AppConfig.privacyPolicyUrl.isEmpty) return;
                    final url = Uri.parse(AppConfig.privacyPolicyUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  child: SText('Privacy Policy',
                      style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                ),
              ]),
              if (kDebugMode)
                Column(
                  children: [
                    const Divider(thickness: 2),
                    SElevatedButton(
                        onPressed: () {
                          RaynearNotification().deleteAppNotification();
                        },
                        child: SText('Remove All Notification')),
                    SElevatedButton(
                        onPressed: () {
                          for (final element in RaynearNotification().channels) {
                            logger.i('----------------------------------------');
                            logger.i('Channel Key: ${element.channelKey}');
                            logger.i('Channel Name: ${element.channelName}');
                            logger.i('Channel Group Key: ${element.channelGroupKey}');
                            logger.i('Channel Description: ${element.channelDescription}');
                            logger.i('Importance: ${element.importance}');
                            logger.i('Channel Show Badge: ${element.channelShowBadge}');
                            logger.i('Default Color: ${element.defaultColor}');
                            logger.i('LED Color: ${element.ledColor}');
                            logger.i('----------------------------------------');
                          }
                        },
                        child: SText('List Channel')),
                    SElevatedButton(
                        onPressed: () async {
                          for (final element in await RaynearNotification().getAppNotifications()) {
                            logger.i('Notification: $element');
                          }
                        },
                        child: SText('List Notification')),
                    // FileService removed - add archive & icloud_storage packages to use
                    // SElevatedButton(
                    //     onPressed: () { deleteEverythingInAppDocDir(); },
                    //     child: SText('Remove TestFiles')),
                    // SElevatedButton(
                    //     onPressed: () { getRootDirectoryTree(); },
                    //     child: SText('Get Directory Tree')),
                    // GeofenceService removed - add geofence_foreground_service package to use
                    // SElevatedButton(
                    //     onPressed: () { GeofenceService().removeAllGeofences(); },
                    //     child: SText('Remove All Geofences')),
                    SElevatedButton(
                        onPressed: () {
                          final settings = ref.read(settingsProvider);
                          if (settings.isSubscriptionActive) {
                            ref.read(settingsProvider.notifier).clearSingleSetting(subscriptionExpiryDate: true);
                          } else {
                            final expiryDate = DateTime.now().add(const Duration(days: 30));
                            ref.read(settingsProvider.notifier).updateSingleSetting(subscriptionExpiryDate: expiryDate);
                          }
                        },
                        child: SText('Toggle Purchase')),
                    const Divider(thickness: 2),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      SText('Debug',
                          style:
                              textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      Container(),
                    ]),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      SText('Design System'),
                      DropdownButton<DesignSystemType>(
                        value: settings.designSystem,
                        onChanged: (newDesignSystem) async {
                          if (newDesignSystem != null) {
                            ref.read(settingsProvider.notifier).updateSingleSetting(designSystem: newDesignSystem);
                          }
                        },
                        items: DesignSystemType.values.map((DesignSystemType type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SText(type.displayName,
                                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                SText(type.description,
                                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                    const Divider(),
                    if (kDebugMode) ...[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        SText('Feature Configuration'),
                        SElevatedButton(
                          onPressed: () {
                            context.push('/settings/feature-config');
                          },
                          child: SText('Open'),
                        ),
                      ]),
                      const Divider(),
                    ],
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      SText('Permission Request'),
                      SElevatedButton(
                        onPressed: () async {
                          final result = await requestPermissions(
                            context: context,
                            permissionMap: {
                              PermissionType.location: 'settings.permissionDemo.locationDesc'.tr(),
                              PermissionType.camera: 'settings.permissionDemo.cameraDesc'.tr(),
                              PermissionType.notification: 'settings.permissionDemo.notificationDesc'.tr(),
                              PermissionType.microphone: 'settings.permissionDemo.microphoneDesc'.tr(),
                            },
                            mainTitle: 'settings.permissionDemo.title'.tr(),
                            description: 'settings.permissionDemo.description'.tr(),
                            // permanentlyDeniedMessage 생략 = 기본값(permission.permanentlyDeniedMessage)
                            // 사용. 명시 전달 시 requestPermissions의 hasCustomMessage(!= null)가
                            // true가 되어 전영구거부 시에도 설정 유도 화면을 띄운다(PR3a 동작 보존).
                            settingsButtonText: 'settings.permissionDemo.settingsButton'.tr(),
                          );
                          logger.i('Permission Request Result: $result');
                        },
                        child: SText('Request'),
                      ),
                    ]),
                    const Divider(),
                    ListTile(
                      title: SText('Database Management'),
                      subtitle: SText('Clear all data'),
                      trailing: FilledButton(
                        onPressed: () => _showClearDatabaseDialog(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                        ),
                        child: SText(
                          'Clear Database',
                          style: TextStyle(color: colorScheme.onError),
                        ),
                      ),
                    ),
                    const Divider(),
                    // 계정 삭제 (스토어 컴플라이언스) — 서버 계정(email auth)
                    // 구성에서만 노출. 백엔드는 P1-16.5b에서 Firebase Auth
                    // 클라이언트 직접 삭제로 재배선 (그 전까지 email auth
                    // 기본 OFF라 비노출). social auth 게이트는 P2-21.5 재도입.
                    if (AppFeatureConfig.isAccountDeletionEnabled &&
                        AppFeatureConfig.isEmailAuthEnabled) ...[
                      ListTile(
                        title: SText('Delete Account'),
                        subtitle: SText('Permanently delete your account and all server data'),
                        trailing: FilledButton(
                          onPressed: () => _showDeleteAccountDialog(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                          ),
                          child: SText(
                            'Delete Account',
                            style: TextStyle(color: colorScheme.onError),
                          ),
                        ),
                      ),
                      const Divider(),
                    ],
                    // 데이터 내보내기 (GDPR 이동권, P2-23f) — 로컬 Drift 데이터를
                    // JSON 파일로 직렬화해 시스템 공유 시트로 내보낸다.
                    if (AppFeatureConfig.isDataExportEnabled) ...[
                      ListTile(
                        title: SText('Export Data'),
                        subtitle: SText('Export your data as a JSON file'),
                        trailing: FilledButton(
                          onPressed: () => _exportData(context),
                          child: SText('Export'),
                        ),
                      ),
                      const Divider(),
                    ],
                    // 백업 및 복원 (P2-24) — 백업=로컬 Drift→JSON 파일 공유,
                    // 복원=백업 파일 선택 후 merge(현재 우선). opt-in 기본 OFF.
                    if (AppFeatureConfig.isBackupRestoreEnabled) ...[
                      ListTile(
                        title: SText('backup.backupTitle'),
                        subtitle: SText('backup.backupSubtitle'),
                        trailing: FilledButton(
                          onPressed: () => _backupData(context),
                          child: SText('backup.backupAction'),
                        ),
                      ),
                      ListTile(
                        title: SText('backup.restoreTitle'),
                        subtitle: SText('backup.restoreSubtitle'),
                        trailing: FilledButton(
                          onPressed: () => _restoreData(context),
                          child: SText('backup.restoreAction'),
                        ),
                      ),
                      const Divider(),
                    ],
                    // 광고 개인화 재설정 (UMP 정책: 동의가 required인 지역에서는
                    // 프라이버시 옵션 재진입점 노출이 의무)
                    if (AppFeatureConfig.isAdsEnabled &&
                        AppFeatureConfig.isUmpConsentEnabled)
                      FutureBuilder<bool>(
                        future: AdService().consentManager.isPrivacyOptionsRequired(),
                        builder: (context, snapshot) {
                          if (snapshot.data != true) {
                            return const SizedBox.shrink();
                          }
                          return Column(children: [
                            ListTile(
                              title: SText('Ad Privacy Options'),
                              subtitle: SText('Manage your ad consent choices'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  AdService().consentManager.showPrivacyOptionsForm(),
                            ),
                            const Divider(),
                          ]);
                        },
                      ),
                    SText('Badge Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    FutureBuilder<List<BadgeModel>>(
                      future: ref.read(badgeRepositoryProvider).getAll(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: SpinKitThreeBounce(
                              color: colorScheme.onPrimary,
                              size: 20.0,
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(child: SText('Error: {}', args: [snapshot.error.toString()]));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(child: SText('No badge data'));
                        } else {
                          final badges = snapshot.data!;
                          return Column(
                            children: badges.map((badge) {
                              return ListTile(
                                title: Text(badge.title),
                                trailing: Switch(
                                  value: badge.isAchieved == true,
                                  onChanged: (value) async {
                                    if (value) {
                                      await _awardBadge(badge.badgeId);
                                      setState(() {});
                                    } else {
                                      await _removeBadge(badge.id!);
                                      setState(() {});
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        }
                      },
                    ),
                  ],
                ),
            ]),
          ),
        ),
      ),
    );
  }

  /// 활성화된 능력에 맞는 잠금 방식 목록 (P2-23h ②).
  List<UserAuthOption> _authOptions() => [
        UserAuthOption.none,
        if (AppFeatureConfig.isBiometricAuthEnabled) UserAuthOption.biometric,
        if (AppFeatureConfig.isPinAuthEnabled) UserAuthOption.pin,
      ];

  String _authOptionLabelKey(UserAuthOption option) {
    switch (option) {
      case UserAuthOption.none:
        return 'auth.pin.lockNone';
      case UserAuthOption.biometric:
        // PIN 기능이 켜져 있으면 "PIN + 생체"(가속), 아니면 레거시 생체 전용.
        return AppFeatureConfig.isPinAuthEnabled
            ? 'auth.pin.lockPinBiometric'
            : 'auth.pin.lockBiometric';
      case UserAuthOption.pin:
        return 'auth.pin.lockPin';
    }
  }

  /// 잠금 방식 변경. PIN을 처음 선택하면 설정 플로우를 먼저 거치고,
  /// 사용자가 설정을 취소하면 방식을 바꾸지 않는다.
  Future<void> _onAuthOptionChanged(UserAuthOption? value) async {
    if (value == null) return;
    // pin은 항상, biometric은 PIN 기능이 켜진 경우 PIN을 폴백으로 요구한다
    // (PIN 기반 + 생체 가속, P2-23h ④). PIN 기능이 꺼진 포크의 biometric은
    // 레거시 생체 전용.
    final needsPin = value == UserAuthOption.pin ||
        (value == UserAuthOption.biometric && AppFeatureConfig.isPinAuthEnabled);
    if (needsPin) {
      final hasPin = await ref.read(pinServiceProvider).hasPin();
      if (!hasPin) {
        if (!mounted) return;
        final ok = await context.push<bool>('/settings/pin');
        if (ok != true) return;
      }
    }
    if (!mounted) return;
    await ref.read(settingsProvider.notifier).updateSingleSetting(userAuthOption: value);
  }

  Future<void> _showSubscriptionView() async {
    await AnalyticsModalBottomSheet(eventName: 'show_subscription_view').show(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 1.0,
          maxChildSize: 1.0,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: controller,
              child: const SubscriptionView(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showClearDatabaseDialog(BuildContext context) async {
    await PanaraConfirmDialog.show(
      context,
      title: 'Clear Database'.tr(),
      message: 'This will delete all data. This action cannot be undone. Are you sure?'.tr(),
      confirmButtonText: 'Clear'.tr(),
      cancelButtonText: 'Cancel'.tr(),
      onTapCancel: () {
        Navigator.pop(context);
      },
      onTapConfirm: () async {
        context.pop();
        try {
          // 모든 데이터 삭제
          final badgeRepository = ref.read(badgeRepositoryProvider);
          final userRepository = ref.read(userRepositoryProvider);

          // 뱃지 데이터 삭제
          final allBadges = await badgeRepository.getAll();
          for (final badge in allBadges) {
            await badgeRepository.delete(badge.id!);
          }

          // 사용자 데이터 삭제
          final allUsers = await userRepository.getAll();
          for (final user in allUsers) {
            await userRepository.delete(user.id);
          }

          // 캐시 초기화
          // await badgeRepository.refreshCache();

          if (context.mounted) {
            ref.read(snackBarServiceProvider).showSuccess('Database cleared successfully'.tr());
            context.go('/home');
          }
        } catch (e) {
          if (context.mounted) {
            ref.read(snackBarServiceProvider).showError('Failed to clear database: $e'.tr());
          }
        }
      },
      panaraDialogType: PanaraDialogType.warning,
      barrierDismissible: false,
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    await PanaraConfirmDialog.show(
      context,
      title: 'Delete Account'.tr(),
      message:
          'This will permanently delete your account and all server data. This action cannot be undone. Are you sure?'
              .tr(),
      confirmButtonText: 'Delete'.tr(),
      cancelButtonText: 'Cancel'.tr(),
      onTapCancel: () {
        Navigator.pop(context);
      },
      onTapConfirm: () async {
        context.pop();
        final deleted = await ref.read(authStateProvider.notifier).deleteAccount();
        if (!context.mounted) return;

        if (deleted) {
          ref.read(snackBarServiceProvider).showSuccess('Account deleted'.tr());
          context.go(Routes.login);
        } else {
          ref.read(snackBarServiceProvider).showError('Failed to delete account'.tr());
        }
      },
      panaraDialogType: PanaraDialogType.error,
      barrierDismissible: false,
    );
  }

  /// 로컬 데이터를 JSON 파일로 내보내 공유 시트로 전달 (GDPR 이동권, P2-23f).
  Future<void> _exportData(BuildContext context) async {
    try {
      final path = await ref.read(dataExportServiceProvider).exportToFile();
      if (!context.mounted) return;
      await ref.read(shareServiceProvider).shareFile(
            path,
            subject: 'Data Export'.tr(),
          );
    } catch (e) {
      if (!context.mounted) return;
      ref.read(snackBarServiceProvider).showError('Failed to export data: $e'.tr());
    }
  }

  /// 로컬 데이터를 JSON 파일로 백업해 공유 시트로 전달 (P2-24).
  Future<void> _backupData(BuildContext context) async {
    try {
      final path = await ref.read(dataExportServiceProvider).exportToFile();
      if (!context.mounted) return;
      await ref.read(shareServiceProvider).shareFile(
            path,
            subject: 'backup.backupSubject'.tr(),
          );
    } catch (e) {
      if (!context.mounted) return;
      ref.read(snackBarServiceProvider).showError('backup.backupError'.tr());
    }
  }

  /// 백업 파일을 골라 merge(현재 우선)로 복원 (P2-24).
  Future<void> _restoreData(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return; // 취소했거나 경로 미지원
    if (!context.mounted) return;

    await PanaraConfirmDialog.show(
      context,
      title: 'backup.confirmTitle'.tr(),
      message: 'backup.confirmMessage'.tr(),
      confirmButtonText: 'backup.restoreAction'.tr(),
      cancelButtonText: 'common.cancel'.tr(),
      onTapCancel: () => Navigator.pop(context),
      onTapConfirm: () async {
        context.pop();
        try {
          final json = await File(path).readAsString();
          final summary =
              await ref.read(restoreServiceProvider).restoreFromJson(json);
          if (!context.mounted) return;
          ref.read(snackBarServiceProvider).showSuccess(
                'backup.restoreSuccess'.tr(namedArgs: {
                  'inserted': '${summary.inserted}',
                  'skipped': '${summary.skipped}',
                }),
              );
        } on FormatException {
          // 백업 파일이 아니거나 손상됨
          if (!context.mounted) return;
          ref.read(snackBarServiceProvider).showError('backup.restoreError'.tr());
        } catch (e) {
          // 파일 읽기/DB 등 그 외 실패
          if (!context.mounted) return;
          ref.read(snackBarServiceProvider).showError('backup.restoreFailed'.tr());
        }
      },
      panaraDialogType: PanaraDialogType.warning,
      barrierDismissible: false,
    );
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay currentTime) async {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // Cupertino 스타일 다이얼로그
      await AnalyticsModalBottomSheet(eventName: 'set_reminder_time').show(
        context: context,
        useRootNavigator: true,
        builder: (BuildContext builder) {
          DateTime selectedDateTime = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            currentTime.hour,
            currentTime.minute,
          );

          return Container(
            height: MediaQuery.of(context).copyWith().size.height / 3,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AdaptiveButton(
                      label: '',
                      onPressed: () => Navigator.of(context).pop(),
                      variant: ButtonVariant.text,
                      child: SText('common.cancel'),
                    ),
                    AdaptiveButton(
                      label: '',
                      onPressed: () {
                        final selectedTime = TimeOfDay(
                          hour: selectedDateTime.hour,
                          minute: selectedDateTime.minute,
                        );
                        ref.read(settingsProvider.notifier).updateSingleSetting(
                              reminderTime: selectedTime,
                            );
                        Navigator.of(context).pop();
                      },
                      variant: ButtonVariant.text,
                      child: SText('common.confirm'),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: selectedDateTime,
                    onDateTimeChanged: (DateTime newDateTime) {
                      selectedDateTime = newDateTime;
                    },
                    use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Material 스타일 다이얼로그 (Android 등)
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: currentTime,
      );

      if (picked != null && picked != currentTime) {
        ref.read(settingsProvider.notifier).updateSingleSetting(
              reminderTime: picked,
            );
      }
    }

    RaynearNotification().setReminderNotification();
  }
}
