/// Google Play Data Safety / Apple Privacy Nutrition 답안지 생성기 (P1-13f).
///
/// 활성 기능 셋에서 결정적으로 생성한다 — correct-by-construction.
/// Play 콘솔 CSV 임포트 스키마는 공식 문서로 재현 불가(콘솔 export 전용)라
/// 사람이 콘솔에 옮기는 답안지(md) + 기계가독(json)을 생성한다.
/// CSV 자동화는 콘솔에서 export한 샘플을 확보한 뒤의 후속 작업.
library;

import 'dart:convert';

import 'package:boilerplate_cli/core/config_loader.dart';

/// 수집 데이터 항목 1건 (Play Data Safety 폼의 행에 대응).
class DataSafetyEntry {
  const DataSafetyEntry({
    required this.category,
    required this.dataType,
    required this.collected,
    required this.shared,
    required this.purposes,
    required this.source,
    required this.playType,
    this.optional = false,
    this.appleNutritionLabel,
  });

  /// Play 폼 카테고리 (예: 'Device or other IDs')
  final String category;

  /// Play 폼 데이터 유형 (예: 'Device or other IDs')
  final String dataType;

  /// 수집 여부
  final bool collected;

  /// 제3자 공유 여부 (광고 SDK 등)
  final bool shared;

  /// 목적 목록 (Play 폼 표현)
  final List<String> purposes;

  /// 이 항목을 유발한 기능 (가독성/추적용)
  final String source;

  /// 사용자가 수집을 거부할 수 있는지
  final bool optional;

  /// Play Data Safety CSV의 데이터 유형 Response ID (예: 'PSL_DEVICE_ID').
  /// renderPlayCsv가 이 값으로 CSV 행을 만든다 — _kPlayDataTypes에 존재해야 함.
  final String playType;

  /// Apple Privacy Nutrition 라벨 대응 (App Store Connect)
  final String? appleNutritionLabel;

  Map<String, dynamic> toJson() => {
        'category': category,
        'dataType': dataType,
        'collected': collected,
        'shared': shared,
        'purposes': purposes,
        'source': source,
        'optional': optional,
        if (appleNutritionLabel != null)
          'appleNutritionLabel': appleNutritionLabel,
      };
}

/// 생성기 입력 — 활성 기능 셋.
class DataSafetyInputs {
  const DataSafetyInputs({
    required this.adsEnabled,
    required this.analyticsEnabled,
    required this.crashReportingEnabled,
    required this.emailAuthEnabled,
    required this.subscriptionEnabled,
    required this.notificationsEnabled,
    required this.locationEnabled,
    required this.accountDeletionEnabled,
  });

  final bool adsEnabled;
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final bool emailAuthEnabled;
  final bool subscriptionEnabled;
  final bool notificationsEnabled;
  final bool locationEnabled;
  final bool accountDeletionEnabled;
}

/// 활성 기능 셋 → Data Safety 항목 목록.
List<DataSafetyEntry> entriesFor(DataSafetyInputs inputs) {
  return [
    if (inputs.adsEnabled) ...[
      const DataSafetyEntry(
        category: 'Device or other IDs',
        dataType: 'Device or other IDs (advertising ID)',
        playType: 'PSL_DEVICE_ID',
        collected: true,
        shared: true,
        purposes: ['Advertising or marketing'],
        source: 'AdMob (isAdsEnabled)',
        appleNutritionLabel: 'Identifiers → Device ID (Used to Track You)',
      ),
    ],
    if (inputs.analyticsEnabled) ...[
      const DataSafetyEntry(
        category: 'App activity',
        dataType: 'App interactions',
        playType: 'PSL_USER_INTERACTION',
        collected: true,
        shared: false,
        purposes: ['Analytics'],
        source: 'Firebase Analytics (isFirebaseAnalyticsEnabled)',
        optional: true, // 인하우스 동의(adConsent/analyticsConsent)로 거부 가능
        appleNutritionLabel: 'Usage Data → Product Interaction',
      ),
      const DataSafetyEntry(
        category: 'Device or other IDs',
        dataType: 'Device or other IDs (app instance ID)',
        playType: 'PSL_DEVICE_ID',
        collected: true,
        shared: false,
        purposes: ['Analytics'],
        source: 'Firebase Analytics (isFirebaseAnalyticsEnabled)',
        optional: true,
        appleNutritionLabel: 'Identifiers → Device ID',
      ),
    ],
    if (inputs.crashReportingEnabled) ...[
      const DataSafetyEntry(
        category: 'App info and performance',
        dataType: 'Crash logs',
        playType: 'PSL_CRASH_LOGS',
        collected: true,
        shared: false,
        purposes: ['Analytics', 'App functionality'],
        source: 'Firebase Crashlytics (isFirebaseCrashlyticsEnabled)',
        appleNutritionLabel: 'Diagnostics → Crash Data',
      ),
      const DataSafetyEntry(
        category: 'App info and performance',
        dataType: 'Diagnostics',
        playType: 'PSL_PERFORMANCE_DIAGNOSTICS',
        collected: true,
        shared: false,
        purposes: ['Analytics', 'App functionality'],
        source: 'Firebase Crashlytics (isFirebaseCrashlyticsEnabled)',
        appleNutritionLabel: 'Diagnostics → Performance Data',
      ),
    ],
    if (inputs.emailAuthEnabled) ...[
      const DataSafetyEntry(
        category: 'Personal info',
        dataType: 'Email address',
        playType: 'PSL_EMAIL',
        collected: true,
        shared: false,
        purposes: ['Account management'],
        source: 'Firebase Auth (isEmailAuthEnabled)',
        appleNutritionLabel: 'Contact Info → Email Address',
      ),
      const DataSafetyEntry(
        category: 'Personal info',
        dataType: 'User IDs',
        playType: 'PSL_USER_ACCOUNT',
        collected: true,
        shared: false,
        purposes: ['Account management', 'App functionality'],
        source: 'Firebase Auth (isEmailAuthEnabled)',
        appleNutritionLabel: 'Identifiers → User ID',
      ),
    ],
    if (inputs.subscriptionEnabled)
      const DataSafetyEntry(
        category: 'Financial info',
        dataType: 'Purchase history',
        playType: 'PSL_PURCHASE_HISTORY',
        collected: true,
        shared: false,
        purposes: ['App functionality'],
        source: 'IAP/Subscription (isSubscriptionEnabled)',
        appleNutritionLabel: 'Purchases → Purchase History',
      ),
    if (inputs.notificationsEnabled)
      const DataSafetyEntry(
        category: 'Device or other IDs',
        dataType: 'Device or other IDs (FCM token)',
        playType: 'PSL_DEVICE_ID',
        collected: true,
        shared: false,
        purposes: ['App functionality'],
        source: 'FCM Push (isNotificationEnabled)',
        appleNutritionLabel: 'Identifiers → Device ID',
      ),
    if (inputs.locationEnabled)
      const DataSafetyEntry(
        category: 'Location',
        dataType: 'Approximate location',
        playType: 'PSL_APPROX_LOCATION',
        collected: true,
        shared: false,
        purposes: ['App functionality'],
        source: 'Location (isLocationEnabled)',
        optional: true, // 런타임 권한으로 거부 가능
        appleNutritionLabel: 'Location → Coarse Location',
      ),
  ];
}

/// 기계가독 JSON 렌더링.
String renderJson(DataSafetyInputs inputs, {required String appName}) {
  final entries = entriesFor(inputs);
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert({
    'app': appName,
    'generator': 'boilerplate_cli generate-data-safety (P1-13f)',
    'dataDeletionPath': inputs.accountDeletionEnabled
        ? '설정 → Delete Account (delete-account 에지 함수)'
        : null,
    'entries': entries.map((e) => e.toJson()).toList(),
  });
}

/// 사람이 콘솔에 옮기는 답안지(markdown) 렌더링.
String renderMarkdown(DataSafetyInputs inputs, {required String appName}) {
  final entries = entriesFor(inputs);
  final buffer = StringBuffer()
    ..writeln('# $appName — Data Safety 답안지')
    ..writeln()
    ..writeln('> 활성 기능 셋에서 자동 생성 (`./run generate-data-safety`).')
    ..writeln('> 기능 구성이 바뀌면 재생성 후 양 스토어 콘솔에 반영할 것.')
    ..writeln()
    ..writeln('## Google Play — Data safety 폼')
    ..writeln();

  if (entries.isEmpty) {
    buffer.writeln('수집하는 데이터 없음 — "No data collected" 선택.');
  } else {
    buffer
      ..writeln('| 카테고리 | 데이터 유형 | 수집 | 공유 | 목적 | 선택가능 | 근거 기능 |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final e in entries) {
      buffer.writeln('| ${e.category} | ${e.dataType} | '
          '${e.collected ? "예" : "아니오"} | ${e.shared ? "예" : "아니오"} | '
          '${e.purposes.join(", ")} | ${e.optional ? "예" : "아니오"} | '
          '${e.source} |');
    }
  }

  buffer
    ..writeln()
    ..writeln('### 공통 질문')
    ..writeln('- 전송 중 암호화: **예** (전 구간 HTTPS/TLS)')
    ..writeln(inputs.accountDeletionEnabled
        ? '- 삭제 요청 경로: **예** — 인앱 설정 → Delete Account '
            '(서버 데이터 + 계정 삭제, P1-13b)'
        : '- 삭제 요청 경로: **아니오** — 서버 계정 기능 없음 '
            '(로컬 전용 데이터)')
    ..writeln()
    ..writeln('## App Store — Privacy Nutrition Labels')
    ..writeln();

  final appleLabels = entries
      .where((e) => e.appleNutritionLabel != null)
      .map((e) => '- ${e.appleNutritionLabel} (${e.source})')
      .toSet();
  if (appleLabels.isEmpty) {
    buffer.writeln('"Data Not Collected" 선택.');
  } else {
    appleLabels.forEach(buffer.writeln);
    if (inputs.adsEnabled) {
      buffer
        ..writeln()
        ..writeln('광고 활성화 앱: "Used to Track You" 섹션에 Device ID 포함 '
            '+ ATT 프롬프트 필수 (SplashView가 처리, P1-13a).');
    }
  }

  return buffer.toString();
}

/// app_config.yaml(ConfigLoader)에서 Data Safety/App Privacy 입력을 구성한다.
///
/// generate-data-safety 명령과 ./deploy의 App Privacy 업로드가 동일한 SSOT를
/// 쓰도록 추출한 공용 빌더 — 두 곳이 어긋나면 스토어 제출 데이터가 갈라진다.
DataSafetyInputs buildDataSafetyInputs(ConfigLoader? config) {
  final overrides = config?.featureOverrides ?? const <String, bool>{};
  // 서비스 레벨 토글은 yaml이 SSOT. 플래그 레벨(email auth/location/알림)은
  // features 오버라이드가 있으면 그 값, 없으면 프로파일 기본(전부 false).
  return DataSafetyInputs(
    adsEnabled: config?.adsEnabled ?? false,
    analyticsEnabled: config?.firebaseEnabled ?? true,
    crashReportingEnabled: config?.firebaseEnabled ?? true,
    emailAuthEnabled: overrides['isEmailAuthEnabled'] ?? false,
    subscriptionEnabled: config?.subscriptionEnabled ?? false,
    notificationsEnabled: overrides['isNotificationEnabled'] ?? false,
    locationEnabled: overrides['isLocationEnabled'] ?? false,
    // 계정 삭제는 서버 계정(Firebase Auth email)이 있는 구성에서만 의미.
    accountDeletionEnabled: (overrides['isAccountDeletionEnabled'] ?? true) &&
        (config?.firebaseEnabled ?? true) &&
        (overrides['isEmailAuthEnabled'] ?? false),
  );
}

/// 활성 기능 셋 → Apple App Privacy(`app_privacy_details.json`) 사용 항목.
///
/// 카테고리/목적/보호수준은 fastlane `upload_app_privacy_details_to_app_store`가
/// 받는 App Store Connect ID다 (spaceship AppDataUsage*, fastlane 2.233.0 검증).
class _AppleUsage {
  const _AppleUsage(
    this.category,
    this.purposes, {
    this.linked = false,
    this.tracking = false,
  });

  /// AppDataUsageCategory ID (예: DEVICE_ID, CRASH_DATA).
  final String category;

  /// AppDataUsagePurpose ID 목록 (예: ANALYTICS, APP_FUNCTIONALITY).
  final List<String> purposes;

  /// 사용자에게 연결되는 데이터인지 (linked vs not-linked).
  final bool linked;

  /// 추적(ATT) 목적 사용 여부.
  final bool tracking;
}

List<_AppleUsage> _appleUsagesFor(DataSafetyInputs i) {
  return [
    if (i.adsEnabled)
      const _AppleUsage('DEVICE_ID', ['THIRD_PARTY_ADVERTISING'],
          tracking: true),
    if (i.analyticsEnabled) ...[
      const _AppleUsage('PRODUCT_INTERACTION', ['ANALYTICS']),
      const _AppleUsage('DEVICE_ID', ['ANALYTICS']),
    ],
    if (i.crashReportingEnabled) ...[
      const _AppleUsage('CRASH_DATA', ['ANALYTICS', 'APP_FUNCTIONALITY']),
      const _AppleUsage('PERFORMANCE_DATA', ['ANALYTICS', 'APP_FUNCTIONALITY']),
    ],
    if (i.emailAuthEnabled) ...[
      const _AppleUsage('EMAIL_ADDRESS', ['APP_FUNCTIONALITY'], linked: true),
      const _AppleUsage('USER_ID', ['APP_FUNCTIONALITY'], linked: true),
    ],
    if (i.subscriptionEnabled)
      const _AppleUsage('PURCHASE_HISTORY', ['APP_FUNCTIONALITY'],
          linked: true),
    if (i.notificationsEnabled)
      const _AppleUsage('DEVICE_ID', ['APP_FUNCTIONALITY']),
    if (i.locationEnabled)
      const _AppleUsage('COARSE_LOCATION', ['APP_FUNCTIONALITY']),
  ];
}

/// Apple `app_privacy_details.json` 렌더링.
///
/// fastlane `upload_app_privacy_details_to_app_store`가 읽는 JSON 배열 포맷:
///   - 수집 없음: `[{"data_protections":["DATA_NOT_COLLECTED"]}]`
///   - 수집 시: 카테고리별 `{category, purposes[], data_protections[]}`
/// 같은 카테고리가 여러 기능에서 나오면 병합한다(purposes union, linked/tracking OR).
String renderAppPrivacyJson(DataSafetyInputs inputs) {
  const encoder = JsonEncoder.withIndent('  ');
  final usages = _appleUsagesFor(inputs);

  if (usages.isEmpty) {
    return encoder.convert([
      {
        'data_protections': ['DATA_NOT_COLLECTED'],
      }
    ]);
  }

  final byCategory = <String, _AppleUsage>{};
  for (final u in usages) {
    final existing = byCategory[u.category];
    if (existing == null) {
      byCategory[u.category] = u;
    } else {
      final purposes = <String>{...existing.purposes, ...u.purposes}.toList();
      byCategory[u.category] = _AppleUsage(
        u.category,
        purposes,
        linked: existing.linked || u.linked,
        tracking: existing.tracking || u.tracking,
      );
    }
  }

  final categories = byCategory.keys.toList()..sort();
  final json = categories.map((cat) {
    final u = byCategory[cat]!;
    final purposes = [...u.purposes]..sort();
    final protections = <String>[
      u.linked ? 'DATA_LINKED_TO_YOU' : 'DATA_NOT_LINKED_TO_YOU',
      if (u.tracking) 'DATA_USED_TO_TRACK_YOU',
    ];
    return {
      'category': cat,
      'purposes': purposes,
      'data_protections': protections,
    };
  }).toList();

  return encoder.convert(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Play Data Safety — Console CSV import 형식 (androidpublisher dataSafety)
//
// `POST .../applications/{package}/dataSafety` 의 safetyLabels 필드는 Play Console
// "Export to CSV"와 동일한 CSV 문자열이다. 아래 PSL_* 머신ID·구조는 실물 콘솔
// export 샘플에서 재현했다(테스트 fixture: fairemail_data_safety_export.csv).
// import는 머신 리더블 Question/Response ID로 동작하고 human 라벨은 무시한다.
// ─────────────────────────────────────────────────────────────────────────────

/// Play Data Safety 데이터 유형 (그룹 Question ID, Response ID, human 라벨).
/// Play Console export 순서대로 — 전체 스켈레톤을 내보내 실물 export와 정렬시킨다.
const List<List<String>> _kPlayDataTypes = [
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_NAME', 'Personal info / Name'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_EMAIL', 'Personal info / Email address'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_USER_ACCOUNT', 'Personal info / User IDs'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_ADDRESS', 'Personal info / Address'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_PHONE', 'Personal info / Phone number'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_RACE_ETHNICITY',
    'Personal info / Race and ethnicity'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_POLITICAL_RELIGIOUS',
    'Personal info / Political or religious beliefs'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_SEXUAL_ORIENTATION_GENDER_IDENTITY',
    'Personal info / Sexual orientation'],
  ['PSL_DATA_TYPES_PERSONAL', 'PSL_OTHER_PERSONAL', 'Personal info / Other info'],
  ['PSL_DATA_TYPES_FINANCIAL', 'PSL_CREDIT_DEBIT_BANK_ACCOUNT_NUMBER',
    'Financial info / User payment info'],
  ['PSL_DATA_TYPES_FINANCIAL', 'PSL_PURCHASE_HISTORY',
    'Financial info / Purchase history'],
  ['PSL_DATA_TYPES_FINANCIAL', 'PSL_CREDIT_SCORE', 'Financial info / Credit score'],
  ['PSL_DATA_TYPES_FINANCIAL', 'PSL_OTHER', 'Financial info / Other financial info'],
  ['PSL_DATA_TYPES_LOCATION', 'PSL_APPROX_LOCATION',
    'Location / Approximate location'],
  ['PSL_DATA_TYPES_LOCATION', 'PSL_PRECISE_LOCATION', 'Location / Precise location'],
  ['PSL_DATA_TYPES_SEARCH_AND_BROWSING', 'PSL_WEB_BROWSING_HISTORY',
    'Web browsing / Web browsing history'],
  ['PSL_DATA_TYPES_EMAIL_AND_TEXT', 'PSL_EMAILS', 'Messages / Emails'],
  ['PSL_DATA_TYPES_EMAIL_AND_TEXT', 'PSL_SMS_CALL_LOG', 'Messages / SMS or MMS'],
  ['PSL_DATA_TYPES_EMAIL_AND_TEXT', 'PSL_OTHER_MESSAGES',
    'Messages / Other in-app messages'],
  ['PSL_DATA_TYPES_PHOTOS_AND_VIDEOS', 'PSL_PHOTOS', 'Photos and videos / Photos'],
  ['PSL_DATA_TYPES_PHOTOS_AND_VIDEOS', 'PSL_VIDEOS', 'Photos and videos / Videos'],
  ['PSL_DATA_TYPES_AUDIO', 'PSL_AUDIO', 'Audio files / Voice or sound recordings'],
  ['PSL_DATA_TYPES_AUDIO', 'PSL_MUSIC', 'Audio files / Music files'],
  ['PSL_DATA_TYPES_AUDIO', 'PSL_OTHER_AUDIO', 'Audio files / Other audio files'],
  ['PSL_DATA_TYPES_HEALTH_AND_FITNESS', 'PSL_HEALTH',
    'Health and fitness / Health info'],
  ['PSL_DATA_TYPES_HEALTH_AND_FITNESS', 'PSL_FITNESS',
    'Health and fitness / Fitness info'],
  ['PSL_DATA_TYPES_CONTACTS', 'PSL_CONTACTS', 'Contacts / Contacts'],
  ['PSL_DATA_TYPES_CALENDAR', 'PSL_CALENDAR', 'Calendar / Calendar events'],
  ['PSL_DATA_TYPES_APP_PERFORMANCE', 'PSL_CRASH_LOGS',
    'App info and performance / Crash logs'],
  ['PSL_DATA_TYPES_APP_PERFORMANCE', 'PSL_PERFORMANCE_DIAGNOSTICS',
    'App info and performance / Diagnostics'],
  ['PSL_DATA_TYPES_APP_PERFORMANCE', 'PSL_OTHER_PERFORMANCE',
    'App info and performance / Other app performance data'],
  ['PSL_DATA_TYPES_FILES_AND_DOCS', 'PSL_FILES_AND_DOCS',
    'Files and docs / Files and docs'],
  ['PSL_DATA_TYPES_APP_ACTIVITY', 'PSL_USER_INTERACTION',
    'App activity / App interactions'],
  ['PSL_DATA_TYPES_APP_ACTIVITY', 'PSL_IN_APP_SEARCH_HISTORY',
    'App activity / In-app search history'],
  ['PSL_DATA_TYPES_APP_ACTIVITY', 'PSL_APPS_ON_DEVICE',
    'App activity / Installed apps'],
  ['PSL_DATA_TYPES_APP_ACTIVITY', 'PSL_USER_GENERATED_CONTENT',
    'App activity / Other user-generated content'],
  ['PSL_DATA_TYPES_APP_ACTIVITY', 'PSL_OTHER_APP_ACTIVITY',
    'App activity / Other actions'],
  ['PSL_DATA_TYPES_IDENTIFIERS', 'PSL_DEVICE_ID',
    'Device or other IDs / Device or other IDs'],
];

/// Play 목적 Response ID → human 라벨 (export 순서, 쉼표 포함 라벨은 이스케이프 검증용).
const List<List<String>> _kPlayPurposes = [
  ['PSL_APP_FUNCTIONALITY', 'App functionality'],
  ['PSL_ANALYTICS', 'Analytics'],
  ['PSL_DEVELOPER_COMMUNICATIONS', 'Developer communications'],
  ['PSL_FRAUD_PREVENTION_SECURITY',
    'Fraud prevention, security, and compliance'],
  ['PSL_ADVERTISING', 'Advertising or marketing'],
  ['PSL_PERSONALIZATION', 'Personalization'],
  ['PSL_ACCOUNT_MANAGEMENT', 'Account management'],
];

/// CSV 셀 이스케이프 (쉼표·따옴표·개행 포함 시 인용, 내부 따옴표는 이중화).
String _csvCell(String value) {
  if (!RegExp('[",\n\r]').hasMatch(value)) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// 한 데이터 유형의 Play 사용 방식 — entriesFor() 항목을 playType별로 병합한 것.
class _MergedPlayUsage {
  final collectionPurposes = <String>{};
  final sharingPurposes = <String>{};
  bool optional = true;
}

/// Play Data Safety CSV (androidpublisher dataSafety의 safetyLabels 값) 렌더링.
///
/// SSOT는 entriesFor() 하나 — 각 항목의 playType/purposes/shared/optional을
/// 그대로 소비한다(md/json/Apple 경로와 동일 원천, 평행 목록 없음).
/// 값 표기는 실물 콘솔 export(테스트 fixture) 실측: 불리언 질문은 소문자
/// true/false, choice형은 선택=true·미선택=빈값, EPHEMERAL은 명시적 false.
/// **라이브 import는 실 Play 앱 없이 검증 불가** — 실패 시 콘솔에서
/// "Export to CSV"로 내려받아 대조하라(레인이 안내).
// ponytail: import 성공은 실 Play 앱에서만 검증 가능 — soft-fail + export 대조 안내로 상한.
String renderPlayCsv(DataSafetyInputs inputs) {
  final purposeIdByLabel = {for (final p in _kPlayPurposes) p[1]: p[0]};

  // entriesFor() → playType별 병합 (목적 union, shared는 그 항목의 목적만
  // 공유 목적으로, optional은 AND — 하나라도 필수면 필수).
  final merged = <String, _MergedPlayUsage>{};
  for (final e in entriesFor(inputs)) {
    final ids = e.purposes.map((label) {
      final id = purposeIdByLabel[label];
      if (id == null) {
        throw StateError('Play 목적 매핑 없음: "$label" (entriesFor ↔ '
            '_kPlayPurposes 라벨 불일치 — ${e.source})');
      }
      return id;
    }).toList();
    final u = merged.putIfAbsent(e.playType, _MergedPlayUsage.new)
      ..collectionPurposes.addAll(ids)
      ..optional &= e.optional;
    if (e.shared) u.sharingPurposes.addAll(ids);
  }
  final anyData = merged.isNotEmpty;

  final rows = <List<String>>[
    ['Question ID (machine readable)', 'Response ID (machine readable)',
      'Response value', 'Answer requirement', 'Human-friendly question label'],
    ['PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA', '',
      anyData ? 'true' : 'false', 'REQUIRED',
      'Does your app collect or share any of the required user data types?'],
    ['PSL_DATA_COLLECTION_ENCRYPTED_IN_TRANSIT', '', 'true', 'MAYBE_REQUIRED',
      'Is all of the user data collected by your app encrypted in transit?'],
    ['PSL_DATA_COLLECTION_USER_REQUEST_DELETE', '',
      inputs.accountDeletionEnabled ? 'true' : 'false', 'MAYBE_REQUIRED',
      'Do you provide a way for users to request that their data is deleted?'],
  ];

  // 데이터 유형 스켈레톤 — 전체 유형: 수집=true, 미수집=빈값 (실물 export 표기).
  for (final t in _kPlayDataTypes) {
    rows.add([t[0], t[1], merged.containsKey(t[1]) ? 'true' : '',
      'MULTIPLE_CHOICE', t[2]]);
  }

  // 수집 유형별 사용 블록 (canonical 유형 순서).
  for (final t in _kPlayDataTypes) {
    final u = merged[t[1]];
    if (u == null) continue;
    final base = 'PSL_DATA_USAGE_RESPONSES:${t[1]}';
    final label = t[2].split(' / ').last;
    final shared = u.sharingPurposes.isNotEmpty;

    rows.add(['$base:PSL_DATA_USAGE_COLLECTION_AND_SHARING',
      'PSL_DATA_USAGE_ONLY_COLLECTED', 'true', 'MULTIPLE_CHOICE',
      '$label / Collected']);
    rows.add(['$base:PSL_DATA_USAGE_COLLECTION_AND_SHARING',
      'PSL_DATA_USAGE_ONLY_SHARED', shared ? 'true' : '',
      'MULTIPLE_CHOICE', '$label / Shared']);
    rows.add(['$base:PSL_DATA_USAGE_EPHEMERAL', '', 'false', 'MAYBE_REQUIRED',
      '$label / Processed ephemerally?']);
    rows.add(['$base:DATA_USAGE_USER_CONTROL',
      'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL', u.optional ? 'true' : '',
      'SINGLE_CHOICE', '$label / Users can choose whether this is collected']);
    rows.add(['$base:DATA_USAGE_USER_CONTROL',
      'PSL_DATA_USAGE_USER_CONTROL_REQUIRED', u.optional ? '' : 'true',
      'SINGLE_CHOICE', '$label / Data collection is required']);
    for (final p in _kPlayPurposes) {
      rows.add(['$base:DATA_USAGE_COLLECTION_PURPOSE', p[0],
        u.collectionPurposes.contains(p[0]) ? 'true' : '',
        'MULTIPLE_CHOICE', '$label collected for / ${p[1]}']);
    }
    // 실물 export는 미공유 타입에도 SHARING_PURPOSE 7행(전부 빈값)을 낸다.
    for (final p in _kPlayPurposes) {
      rows.add(['$base:DATA_USAGE_SHARING_PURPOSE', p[0],
        u.sharingPurposes.contains(p[0]) ? 'true' : '',
        'MULTIPLE_CHOICE', '$label shared for / ${p[1]}']);
    }
  }

  return '${rows.map((r) => r.map(_csvCell).join(',')).join('\n')}\n';
}
