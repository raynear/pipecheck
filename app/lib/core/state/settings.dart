import 'dart:convert';

import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/core/design/design_system_provider.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:orange/orange.dart';
import 'package:utils/utils.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// 사용자 인증 옵션 열거형
///
/// 앱에서 사용 가능한 인증 방법을 정의합니다.
enum UserAuthOption {
  /// 인증 없음
  none,

  /// 생체 인증 (지문, Face ID 등)
  biometric,

  /// PIN 인증
  pin
}

// 상수 정의
const defaultThemeColor = 'blue';
const defaultBodyFont = 'Noto Sans';
const defaultFontSize = 14;
const defaultLocale = Locale('en', 'US');

final List<Locale> supportedLocales = [defaultLocale];
final Map<String, Map<String, String>> languageFontList = {};

/// Locale 객체를 JSON으로 변환하는 컨버터
///
/// Freezed와 함께 사용되어 Locale 객체를 JSON으로 직렬화/역직렬화합니다.
/// 형식: "언어코드_국가코드" (예: "ko_KR", "en_US")
class LocaleConverter implements JsonConverter<Locale, String> {
  const LocaleConverter();

  @override
  Locale fromJson(String json) {
    final parts = json.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  }

  @override
  String toJson(Locale locale) => locale.toString();
}

/// TimeOfDay 객체를 JSON으로 변환하는 컨버터
///
/// Freezed와 함께 사용되어 TimeOfDay 객체를 JSON으로 직렬화/역직렬화합니다.
/// 형식: "시:분" (예: "9:30", "20:0")
class TimeOfDayConverter implements JsonConverter<TimeOfDay, String> {
  const TimeOfDayConverter();

  @override
  TimeOfDay fromJson(String json) {
    final parts = json.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  String toJson(TimeOfDay timeOfDay) => '${timeOfDay.hour}:${timeOfDay.minute}';
}

/// 앱의 전역 설정을 관리하는 모델 클래스
///
/// 사용자 설정, 테마, 언어, 알림, 구독 정보 등 앱의 모든 설정을 포함합니다.
/// Freezed를 사용하여 불변 객체로 관리되며, JSON 직렬화를 지원합니다.
///
/// 주요 설정:
/// - 디스플레이 설정: 테마, 폰트, 크기
/// - 사용자 설정: 인증 옵션, 언어
/// - 기능 설정: 알림, 리마인더, iCloud
/// - 구독 정보: 만료 날짜
/// - 앱 통계: 실행 횟수
@freezed
abstract class Settings with _$Settings {
  const factory Settings({
    required bool onBoard,
    required ThemeMode displayMode,
    required String themeColor,
    required String bodyFont,
    required int fontSize,
    required bool bold,
    @LocaleConverter() required Locale language,
    required UserAuthOption userAuthOption,
    required bool useICloud,
    required bool useNotification,
    required bool useReminder,
    @TimeOfDayConverter() required TimeOfDay reminderTime,
    DateTime? subscriptionExpiryDate,
    required int appLaunchCount,
    @Default(DesignSystemType.material3) DesignSystemType designSystem,
  }) = _Settings;

  factory Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);

  factory Settings.fromOrange() {
    try {
      final bool onBoard = Orange.getBool('onBoard') ?? false;
      final ThemeMode displayMode = ThemeMode.values[Orange.getInt('displayMode') ?? ThemeMode.light.index];
      final String themeColor = Orange.getString('themeColor') ?? defaultThemeColor;
      final String bodyFont = Orange.getString('bodyFont') ?? defaultBodyFont;
      final int fontSize = Orange.getInt('fontSize') ?? defaultFontSize;
      final bool bold = Orange.getBool('bold') ?? true;

      final prefLanguage = Orange.getString('language');
      final Locale language = supportedLocales.firstWhere((item) => item.languageCode == prefLanguage, orElse: () {
        final systemLocale = PlatformDispatcher.instance.locale;
        final deviceLocale = Locale(systemLocale.languageCode, systemLocale.countryCode);
        return supportedLocales.firstWhere(
          (locale) => locale.languageCode == deviceLocale.languageCode,
          orElse: () => defaultLocale,
        );
      });

      final UserAuthOption userAuthOption = UserAuthOption.values[Orange.getInt('userAuthOption') ?? 0];
      final bool useICloud = Orange.getBool('useICloud') ?? false;
      final bool useNotification = Orange.getBool('useNotification') ?? false;
      final bool useReminder = Orange.getBool('useReminder') ?? true;
      final int reminderHour = Orange.getInt('reminderHour') ?? TimeOfDay.now().hour;
      final int reminderMinute = Orange.getInt('reminderMinute') ?? TimeOfDay.now().minute;
      final TimeOfDay reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);

      final subscriptionExpiryDateString = Orange.getString('subscriptionExpiryDate');
      final DateTime? subscriptionExpiryDate =
          subscriptionExpiryDateString != null && subscriptionExpiryDateString.isNotEmpty
              ? DateTime.parse(subscriptionExpiryDateString)
              : null;

      final int appLaunchCount = Orange.getInt('appLaunchCount') ?? 0;

      final int designSystemIndex = Orange.getInt('designSystem') ?? 0;
      final DesignSystemType designSystem = DesignSystemType.values[designSystemIndex];

      return Settings(
        onBoard: onBoard,
        displayMode: displayMode,
        themeColor: themeColor,
        bodyFont: bodyFont,
        fontSize: fontSize,
        bold: bold,
        language: language,
        userAuthOption: userAuthOption,
        useICloud: useICloud,
        useNotification: useNotification,
        useReminder: useReminder,
        reminderTime: reminderTime,
        subscriptionExpiryDate: subscriptionExpiryDate,
        appLaunchCount: appLaunchCount,
        designSystem: designSystem,
      );
    } catch (e) {
      logger.e('Error occurred while loading settings from Orange: $e');
      return Settings.initial();
    }
  }

  factory Settings.initial() => Settings(
        onBoard: false,
        displayMode: ThemeMode.light,
        themeColor: defaultThemeColor,
        bodyFont: defaultBodyFont,
        fontSize: defaultFontSize,
        bold: false,
        language: defaultLocale,
        userAuthOption: UserAuthOption.none,
        useICloud: false,
        useNotification: false,
        useReminder: false,
        reminderTime: TimeOfDay.now(),
        subscriptionExpiryDate: AppConfig.getValue<String>('SUBSCRIPTION_EXPIRY_DATE') == null
            ? null
            : DateTime.parse(AppConfig.getValue<String>('SUBSCRIPTION_EXPIRY_DATE')!),
        appLaunchCount: 0,
        designSystem: DesignSystemType.material3,
      );

  static Future<List<Locale>> updateSupportedLocale() async {
    final String localesJson = await rootBundle.loadString('assets/languages/locales.json');
    final List<dynamic> localeFiles = json.decode(localesJson)['locales'];
    final List<Locale> locales = [];

    final allFontData = await extractFontData('config/default_font.json');

    for (var fileName in localeFiles) {
      final locale = fileName.split('.').first;
      final lang = locale.split('-').first;
      final country = locale.split('-').last;
      locales.add(Locale(lang, country));

      if (allFontData[locale] != null) {
        updateLanguageFontList(locale, allFontData[locale] as Map<String, dynamic>);
      }
    }

    supportedLocales.clear();
    supportedLocales.addAll(locales);

    return locales;
  }

  static Future<Map<String, dynamic>> extractFontData(String filePath) async {
    final contents = await rootBundle.loadString(filePath);
    return json.decode(contents) as Map<String, dynamic>;
  }

  static void updateLanguageFontList(String locale, Map<String, dynamic> fontData) {
    languageFontList[locale.split('-').first] = {
      'display': fontData['Display'] ?? 'Roboto',
      'headline': fontData['Headline'] ?? 'Roboto',
      'title': fontData['Title'] ?? 'Roboto',
      'body': fontData['Body'] ?? 'Roboto',
      'label': fontData['Label'] ?? 'Roboto'
    };
  }
}

// Settings 클래스에 대한 extension을 추가
extension SettingsExtension on Settings {
  Future<void> saveToOrange() async {
    try {
      Orange.setBool('onBoard', onBoard);
      Orange.setInt('displayMode', displayMode.index);
      Orange.setString('themeColor', themeColor);
      Orange.setString('bodyFont', bodyFont);
      Orange.setInt('fontSize', fontSize);
      Orange.setBool('bold', bold);
      Orange.setString('language', language.languageCode);
      Orange.setInt('userAuthOption', userAuthOption.index);
      Orange.setBool('useICloud', useICloud);
      Orange.setBool('useNotification', useNotification);
      Orange.setBool('useReminder', useReminder);
      Orange.setInt('reminderHour', reminderTime.hour);
      Orange.setInt('reminderMinute', reminderTime.minute);
      Orange.setString('subscriptionExpiryDate', subscriptionExpiryDate?.toIso8601String() ?? '');
      Orange.setInt('appLaunchCount', appLaunchCount);
      Orange.setInt('designSystem', designSystem.index);
    } catch (e) {
      logger.e('Failed to save settings to Orange: $e');
    }
  }

  bool get isSubscriptionActive {
    return subscriptionExpiryDate != null && subscriptionExpiryDate!.isAfter(DateTime.now());
  }
}

// 지원되는 로케일 초기화 제공자
final supportedLocalesProvider = FutureProvider<List<Locale>>((ref) async {
  return Settings.updateSupportedLocale();
});

/// 설정 상태를 관리하는 Notifier
///
/// 앱의 모든 설정을 관리하고 영구 저장소(Orange)와 동기화합니다.
/// 설정 변경 시 자동으로 저장되며, 앱 시작 시 저장된 설정을 불러옵니다.
///
/// 주요 기능:
/// - 설정 로드/저장
/// - 개별 설정 업데이트
/// - 앱 실행 횟수 추적
/// - 구독 상태 관리
class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    // 동기 로드 — Orange.init()은 runApp 전에 await된다(app_config.dart).
    // 로드를 microtask로 미루면 부팅 첫 read(라우터 redirect는 동기 실행)가
    // initial(userAuthOption=none)을 보게 되어 PIN/생체 잠금이 우회된다
    // (authState가 "잠금 없음"으로 자동 인증). fromOrange는 실패 시
    // 자체적으로 초기 기본값으로 폴백한다.
    return Settings.fromOrange();
  }

  Future<void> incrementAppLaunchCount() async {
    final newSettings = state.copyWith(appLaunchCount: state.appLaunchCount + 1);
    await changeSettings(newSettings);
    logger.d('앱 실행 횟수: ${newSettings.appLaunchCount}');
  }

  Future<void> clearSingleSetting({
    bool? subscriptionExpiryDate,
    bool? currentHabitExecution,
  }) async {
    if (subscriptionExpiryDate == true) {
      await changeSettings(state.copyWith(
        subscriptionExpiryDate: null,
      ));
    }
  }

  Future<void> updateSingleSetting({
    bool? onBoard,
    ThemeMode? displayMode,
    String? themeColor,
    String? bodyFont,
    int? fontSize,
    bool? bold,
    Locale? language,
    UserAuthOption? userAuthOption,
    bool? useICloud,
    bool? useNotification,
    bool? useReminder,
    TimeOfDay? reminderTime,
    DateTime? subscriptionExpiryDate,
    DesignSystemType? designSystem,
  }) async {
    final newSettings = Settings(
      onBoard: onBoard ?? state.onBoard,
      displayMode: displayMode ?? state.displayMode,
      themeColor: themeColor ?? state.themeColor,
      bodyFont: bodyFont ?? state.bodyFont,
      fontSize: fontSize ?? state.fontSize,
      bold: bold ?? state.bold,
      language: language ?? state.language,
      userAuthOption: userAuthOption ?? state.userAuthOption,
      useICloud: useICloud ?? state.useICloud,
      useNotification: useNotification ?? state.useNotification,
      useReminder: useReminder ?? state.useReminder,
      reminderTime: reminderTime ?? state.reminderTime,
      subscriptionExpiryDate: subscriptionExpiryDate ?? state.subscriptionExpiryDate,
      appLaunchCount: state.appLaunchCount,
      designSystem: designSystem ?? state.designSystem,
    );
    await changeSettings(newSettings);
  }

  Future<void> changeSettings(Settings newSettings) async {
    try {
      await newSettings.saveToOrange();
      state = newSettings;
    } catch (e) {
      logger.e('Failed to change settings: $e');
    }
  }

  Future<void> checkAndUpdateSubscription() async {}
}

// Future<void> checkAndUpdateSubscription() async {
//   try {
//     final purchases = await InAppPurchase.instance.();
//     final validSubscription = purchases.pastPurchases.firstWhereOrNull((purchase) =>
//         AppConfig.productIds.values.contains(purchase.productID) && purchase.status == PurchaseStatus.purchased);

//     if (validSubscription != null) {
//       // 유효한 구독이 있는 경우
//       final purchaseDate = DateTime.fromMillisecondsSinceEpoch(int.parse(validSubscription.transactionDate!));
//       final newExpiryDate = purchaseDate.add(const Duration(days: 31));

//       if (newExpiryDate.isAfter(DateTime.now())) {
//         // 새로운 만료 날짜가 현재보다 미래인 경우에만 업데이트
//         await changeSettings(state.copyWith(subscriptionExpiryDate: newExpiryDate));
//         logger.i('구독이 갱신되었습니다. 새 만료 날짜: $newExpiryDate');
//       } else {
//         // 구독이 이미 만료된 경우
//         await changeSettings(state.copyWith(subscriptionExpiryDate: null));
//         logger.i('구독이 만료되었습니다.');
//       }
//     } else {
//       // 유효한 구독이 없는 경우
//       await changeSettings(state.copyWith(subscriptionExpiryDate: null));
//       logger.i('활성 구독을 찾을 수 없습니다.');
//     }
//   } catch (e) {
//     logger.e('구독 상태 확인 중 오류 발생: $e');
//   }
// }
// }

/// 전역 설정 프로바이더
///
/// 앱 전체에서 설정 상태에 접근하고 수정할 수 있도록 하는 프로바이더입니다.
///
/// 사용 예시:
/// ```dart
/// // 설정 읽기
/// final settings = ref.watch(settingsProvider);
///
/// // 설정 변경
/// ref.read(settingsProvider.notifier).updateSingleSetting(themeMode: ThemeMode.dark);
/// ```
final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

/// 디스플레이 관련 설정만 추출한 모델 클래스
///
/// UI 렌더링에 필요한 설정만을 포함하여 불필요한 재빌드를 방지합니다.
@freezed
abstract class Display with _$Display {
  const factory Display({
    required ThemeMode displayMode,
    required String themeColor,
    required String bodyFont,
    required int fontSize,
    required bool bold,
    required Locale language,
  }) = _Display;
}

/// 디스플레이 설정 프로바이더
///
/// settingsProvider에서 UI 관련 설정만 추출하여 제공합니다.
/// UI 컴포넌트가 전체 설정이 아닌 디스플레이 관련 설정만 구독하도록 하여
/// 성능을 최적화합니다.
///
/// 사용 예시:
/// ```dart
/// final display = ref.watch(displayProvider);
/// final theme = Theme.of(context).copyWith(
///   brightness: display.displayMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
/// );
/// ```
final displayProvider = Provider<Display>((ref) {
  final settings = ref.watch(settingsProvider);
  return Display(
    displayMode: settings.displayMode,
    themeColor: settings.themeColor,
    bodyFont: settings.bodyFont,
    fontSize: settings.fontSize,
    bold: settings.bold,
    language: settings.language,
  );
});
