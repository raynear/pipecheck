/// Apple Privacy Manifest (PrivacyInfo.xcprivacy) 생성기 (P1-13d).
///
/// 활성 기능 셋(광고/Firebase/Crashlytics)에서 매니페스트를 생성한다 —
/// correct-by-construction. 플러그인(SDK)들은 자기 매니페스트를 따로
/// 배포하므로, 여기서는 앱 바이너리 수준의 선언만 다룬다.
///
/// 파일 등록(pbxproj)은 템플릿에 1회 커밋되어 있고, 이 생성기는
/// 내용만 갱신한다.
library;

/// 수집 데이터 타입 선언 1건.
class CollectedDataType {
  const CollectedDataType({
    required this.type,
    required this.linked,
    required this.tracking,
    required this.purposes,
  });

  /// Apple 데이터 타입 상수 (예: NSPrivacyCollectedDataTypeDeviceID)
  final String type;

  /// 사용자 신원과 연결되는지
  final bool linked;

  /// 트래킹 목적으로 사용되는지
  final bool tracking;

  /// Apple 목적 상수 목록
  final List<String> purposes;
}

/// 활성 기능 셋 → 수집 데이터 타입 목록 매핑.
///
/// 보수적 기본값: 해당 기능이 켜져 있으면 그 SDK가 일반적으로 수집하는
/// 항목을 선언한다 (과소 선언은 리젝 사유, 과대 선언은 안전).
List<CollectedDataType> collectedDataTypesFor({
  required bool adsEnabled,
  required bool analyticsEnabled,
  required bool crashReportingEnabled,
}) {
  return [
    if (adsEnabled) ...[
      const CollectedDataType(
        type: 'NSPrivacyCollectedDataTypeDeviceID',
        linked: false,
        tracking: true,
        purposes: ['NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising'],
      ),
      const CollectedDataType(
        type: 'NSPrivacyCollectedDataTypeAdvertisingData',
        linked: false,
        tracking: true,
        purposes: ['NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising'],
      ),
    ],
    if (analyticsEnabled)
      const CollectedDataType(
        type: 'NSPrivacyCollectedDataTypeProductInteraction',
        linked: false,
        tracking: false,
        purposes: ['NSPrivacyCollectedDataTypePurposeAnalytics'],
      ),
    if (crashReportingEnabled) ...[
      const CollectedDataType(
        type: 'NSPrivacyCollectedDataTypeCrashData',
        linked: false,
        tracking: false,
        purposes: ['NSPrivacyCollectedDataTypePurposeAppFunctionality'],
      ),
      const CollectedDataType(
        type: 'NSPrivacyCollectedDataTypePerformanceData',
        linked: false,
        tracking: false,
        purposes: ['NSPrivacyCollectedDataTypePurposeAppFunctionality'],
      ),
    ],
  ];
}

/// PrivacyInfo.xcprivacy 전체 XML을 생성한다.
///
/// [tracking]: ATT 트래킹 사용 여부 (광고 활성화 시 true 권장)
/// [trackingDomains]: 앱 고유 트래킹 도메인 (project.yaml
///   privacy.tracking_domains — SDK 도메인은 SDK 매니페스트가 선언)
String generatePrivacyManifest({
  required bool tracking,
  required List<String> trackingDomains,
  required bool adsEnabled,
  required bool analyticsEnabled,
  required bool crashReportingEnabled,
}) {
  final dataTypes = collectedDataTypesFor(
    adsEnabled: adsEnabled,
    analyticsEnabled: analyticsEnabled,
    crashReportingEnabled: crashReportingEnabled,
  );

  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">')
    ..writeln('<plist version="1.0">')
    ..writeln('<dict>')
    ..writeln('\t<key>NSPrivacyTracking</key>')
    ..writeln(tracking ? '\t<true/>' : '\t<false/>')
    ..writeln('\t<key>NSPrivacyTrackingDomains</key>');

  if (trackingDomains.isEmpty) {
    buffer.writeln('\t<array/>');
  } else {
    buffer.writeln('\t<array>');
    for (final domain in trackingDomains) {
      buffer.writeln('\t\t<string>${_escapeXml(domain)}</string>');
    }
    buffer.writeln('\t</array>');
  }

  // 앱 바이너리 수준 필수 사유 API: UserDefaults (shared_preferences 경유)
  buffer
    ..writeln('\t<key>NSPrivacyAccessedAPITypes</key>')
    ..writeln('\t<array>')
    ..writeln('\t\t<dict>')
    ..writeln('\t\t\t<key>NSPrivacyAccessedAPIType</key>')
    ..writeln('\t\t\t<string>NSPrivacyAccessedAPICategoryUserDefaults</string>')
    ..writeln('\t\t\t<key>NSPrivacyAccessedAPITypeReasons</key>')
    ..writeln('\t\t\t<array>')
    ..writeln('\t\t\t\t<string>CA92.1</string>')
    ..writeln('\t\t\t</array>')
    ..writeln('\t\t</dict>')
    ..writeln('\t</array>')
    ..writeln('\t<key>NSPrivacyCollectedDataTypes</key>');

  if (dataTypes.isEmpty) {
    buffer.writeln('\t<array/>');
  } else {
    buffer.writeln('\t<array>');
    for (final dataType in dataTypes) {
      buffer
        ..writeln('\t\t<dict>')
        ..writeln('\t\t\t<key>NSPrivacyCollectedDataType</key>')
        ..writeln('\t\t\t<string>${dataType.type}</string>')
        ..writeln('\t\t\t<key>NSPrivacyCollectedDataTypeLinked</key>')
        ..writeln(dataType.linked ? '\t\t\t<true/>' : '\t\t\t<false/>')
        ..writeln('\t\t\t<key>NSPrivacyCollectedDataTypeTracking</key>')
        ..writeln(dataType.tracking ? '\t\t\t<true/>' : '\t\t\t<false/>')
        ..writeln('\t\t\t<key>NSPrivacyCollectedDataTypePurposes</key>')
        ..writeln('\t\t\t<array>');
      for (final purpose in dataType.purposes) {
        buffer.writeln('\t\t\t\t<string>$purpose</string>');
      }
      buffer
        ..writeln('\t\t\t</array>')
        ..writeln('\t\t</dict>');
    }
    buffer.writeln('\t</array>');
  }

  buffer
    ..writeln('</dict>')
    ..writeln('</plist>');

  return buffer.toString();
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
