/// 딥링크 네이티브 매니페스트 주입기 (P2-23a Stage 1b).
///
/// AndroidManifest.xml의 `<intent-filter>`와 iOS Info.plist의
/// `CFBundleURLTypes`를 마커 블록으로 **멱등** 주입한다 — 재실행 시 기존
/// 블록을 교체하고, 없으면 적절한 위치에 삽입한다. 공유 파일을 편집하므로
/// privacy 매니페스트처럼 전체 덮어쓰기를 할 수 없다(그래서 마커 방식).
///
/// 순수 함수만 둔다(dart:io 없음) — 단위 테스트가 문자열로 검증한다.
library;

import 'dart:convert';

const String deeplinkBegin =
    '<!-- DEEPLINK-GENERATED:BEGIN (./run generate-deeplink — do not edit) -->';
const String deeplinkEnd = '<!-- DEEPLINK-GENERATED:END -->';

final RegExp _markerBlock = RegExp(
  '${RegExp.escape(deeplinkBegin)}[\\s\\S]*?${RegExp.escape(deeplinkEnd)}',
);

// ── 유니버설/앱링크 (P2-23a Stage 2) ──
// 커스텀 스킴(DEEPLINK-GENERATED)과 **별도 마커**를 쓴다 — Android는 둘 다
// MainActivity 안에 주입되므로 마커가 겹치면 한쪽이 다른쪽을 덮어쓴다.
// autoVerify intent-filter는 https 전용이라 스킴 필터와 반드시 분리한다.
const String universalBegin =
    '<!-- DEEPLINK-UNIVERSAL:BEGIN (./run generate-deeplink — do not edit) -->';
const String universalEnd = '<!-- DEEPLINK-UNIVERSAL:END -->';

final RegExp _universalMarkerBlock = RegExp(
  '${RegExp.escape(universalBegin)}[\\s\\S]*?${RegExp.escape(universalEnd)}',
);

/// 커스텀 스킴 Android intent-filter 블록(마커 포함).
///
/// 첫 줄(BEGIN)에는 들여쓰기가 없다 — 삽입/교체 지점이 이미 들여쓰기를
/// 갖고 있기 때문. 내부 줄은 12/16 스페이스로 자체 들여쓰기한다.
String androidSchemeBlock(String scheme) {
  final s = _escapeAttr(scheme);
  return '$deeplinkBegin\n'
      '            <intent-filter>\n'
      '                <action android:name="android.intent.action.VIEW" />\n'
      '                <category android:name="android.intent.category.DEFAULT" />\n'
      '                <category android:name="android.intent.category.BROWSABLE" />\n'
      '                <data android:scheme="$s" />\n'
      '            </intent-filter>\n'
      '            $deeplinkEnd';
}

/// AndroidManifest 내용에 커스텀 스킴 블록을 멱등 주입한다.
/// 마커 블록이 있으면 교체, 없으면 `.MainActivity`의 `</activity>` 앞에 삽입.
///
/// 첫 `</activity>`가 아니라 **.MainActivity의 닫는 태그**를 특정한다 — 포크가
/// 다른 액티비티(서비스 액티비티 등)를 먼저 선언해도 올바른 위치에 들어간다.
/// (액티비티는 중첩 불가 → `.MainActivity` 다음의 첫 `</activity>`가 그 닫힘.)
String injectAndroidScheme(String manifest, String scheme) {
  final block = androidSchemeBlock(scheme);
  if (_markerBlock.hasMatch(manifest)) {
    return manifest.replaceFirst(_markerBlock, block);
  }
  final nameIdx = manifest.indexOf('.MainActivity');
  if (nameIdx == -1) {
    throw const FormatException(
        'AndroidManifest.xml: .MainActivity를 찾을 수 없어 intent-filter 주입 불가');
  }
  final closeMatch =
      RegExp(r'([ \t]*)</activity>').firstMatch(manifest.substring(nameIdx));
  if (closeMatch == null) {
    throw const FormatException(
        'AndroidManifest.xml: MainActivity의 </activity>를 찾을 수 없음');
  }
  final indent = closeMatch.group(1) ?? '';
  final start = nameIdx + closeMatch.start;
  final before = manifest.substring(0, start);
  final after = manifest.substring(start + closeMatch.group(0)!.length);
  return '$before            $block\n$indent</activity>$after';
}

/// iOS Info.plist `CFBundleURLTypes` 블록(마커 포함, 탭 들여쓰기).
String iosUrlTypesBlock(String scheme, String bundleId) {
  final s = _escapeXml(scheme);
  final b = _escapeXml(bundleId);
  return '$deeplinkBegin\n'
      '\t<key>CFBundleURLTypes</key>\n'
      '\t<array>\n'
      '\t\t<dict>\n'
      '\t\t\t<key>CFBundleTypeRole</key>\n'
      '\t\t\t<string>Editor</string>\n'
      '\t\t\t<key>CFBundleURLName</key>\n'
      '\t\t\t<string>$b</string>\n'
      '\t\t\t<key>CFBundleURLSchemes</key>\n'
      '\t\t\t<array>\n'
      '\t\t\t\t<string>$s</string>\n'
      '\t\t\t</array>\n'
      '\t\t</dict>\n'
      '\t</array>\n'
      '\t$deeplinkEnd';
}

/// Info.plist 내용에 CFBundleURLTypes 블록을 멱등 주입한다.
/// 마커 블록이 있으면 교체, 없으면 루트 `</dict></plist>` 앞에 삽입.
String injectIosUrlTypes(String plist, String scheme, String bundleId) {
  final block = iosUrlTypesBlock(scheme, bundleId);
  if (_markerBlock.hasMatch(plist)) {
    return plist.replaceFirst(_markerBlock, block);
  }
  // 루트 dict 닫힘 = </plist> 바로 앞에 인접한 </dict>. 정규식이 </dict>와
  // </plist>의 인접을 요구하므로 중첩 dict(뒤에 </dict>/</array> 등이 따라옴)는
  // 매칭되지 않는다 — 루트만 정확히 잡는다.
  final rootClose = RegExp(r'</dict>(\s*)</plist>');
  final m = rootClose.firstMatch(plist);
  if (m == null) {
    throw const FormatException(
        'Info.plist: 루트 </dict></plist>를 찾을 수 없어 주입 불가');
  }
  final gap = m.group(1) ?? '\n';
  return plist.replaceFirst(rootClose, '\t$block\n</dict>$gap</plist>');
}

/// 유니버설 링크 Android autoVerify intent-filter 블록(마커 포함).
///
/// 모든 호스트를 하나의 `android:autoVerify="true"` 필터에 https `<data>`로
/// 묶는다(autoVerify는 필터 내 https 호스트 전부에 적용). 커스텀 스킴 필터와
/// 섞으면 검증이 깨지므로 **항상 분리된 intent-filter**다.
String androidUniversalBlock(List<String> hosts) {
  final dataTags = hosts
      .map((h) =>
          '                <data android:scheme="https" android:host="${_escapeAttr(h)}" />')
      .join('\n');
  return '$universalBegin\n'
      '            <intent-filter android:autoVerify="true">\n'
      '                <action android:name="android.intent.action.VIEW" />\n'
      '                <category android:name="android.intent.category.DEFAULT" />\n'
      '                <category android:name="android.intent.category.BROWSABLE" />\n'
      '$dataTags\n'
      '            </intent-filter>\n'
      '            $universalEnd';
}

/// AndroidManifest에 autoVerify intent-filter를 멱등 주입한다.
/// 유니버설 마커 블록이 있으면 교체, 없으면 `.MainActivity`의 `</activity>` 앞에 삽입.
/// 커스텀 스킴(injectAndroidScheme)과 별개로 공존한다.
String injectAndroidUniversal(String manifest, List<String> hosts) {
  final block = androidUniversalBlock(hosts);
  if (_universalMarkerBlock.hasMatch(manifest)) {
    return manifest.replaceFirst(_universalMarkerBlock, block);
  }
  final nameIdx = manifest.indexOf('.MainActivity');
  if (nameIdx == -1) {
    throw const FormatException(
        'AndroidManifest.xml: .MainActivity를 찾을 수 없어 autoVerify intent-filter 주입 불가');
  }
  final closeMatch =
      RegExp(r'([ \t]*)</activity>').firstMatch(manifest.substring(nameIdx));
  if (closeMatch == null) {
    throw const FormatException(
        'AndroidManifest.xml: MainActivity의 </activity>를 찾을 수 없음');
  }
  final indent = closeMatch.group(1) ?? '';
  final start = nameIdx + closeMatch.start;
  final before = manifest.substring(0, start);
  final after = manifest.substring(start + closeMatch.group(0)!.length);
  return '$before            $block\n$indent</activity>$after';
}

/// iOS associated-domains 엔트리 블록(마커 포함, 탭 들여쓰기).
/// Runner.entitlements의 루트 dict에 주입된다.
String iosAssociatedDomainsBlock(List<String> hosts) {
  final entries = hosts
      .map((h) => '\t\t<string>applinks:${_escapeXml(h)}</string>')
      .join('\n');
  return '$universalBegin\n'
      '\t<key>com.apple.developer.associated-domains</key>\n'
      '\t<array>\n'
      '$entries\n'
      '\t</array>\n'
      '\t$universalEnd';
}

/// Runner.entitlements에 associated-domains를 멱등 주입한다.
/// 유니버설 마커 블록이 있으면 교체, 없으면 루트 `</dict></plist>` 앞에 삽입.
String injectIosAssociatedDomains(String entitlements, List<String> hosts) {
  final block = iosAssociatedDomainsBlock(hosts);
  if (_universalMarkerBlock.hasMatch(entitlements)) {
    return entitlements.replaceFirst(_universalMarkerBlock, block);
  }
  final rootClose = RegExp(r'</dict>(\s*)</plist>');
  final m = rootClose.firstMatch(entitlements);
  if (m == null) {
    throw const FormatException(
        'Runner.entitlements: 루트 </dict></plist>를 찾을 수 없어 주입 불가');
  }
  final gap = m.group(1) ?? '\n';
  return entitlements.replaceFirst(rootClose, '\t$block\n</dict>$gap</plist>');
}

/// apple-app-site-association(AASA) JSON 본문(확장자 없이 호스팅).
/// appID = `<teamId>.<bundleId>`. 모든 경로(`*`)를 앱으로 라우팅한다.
String appleAppSiteAssociation(String teamId, String bundleId) {
  final appId = '$teamId.$bundleId';
  final map = <String, dynamic>{
    'applinks': <String, dynamic>{
      'details': <dynamic>[
        <String, dynamic>{
          'appIDs': <String>[appId],
          'components': <dynamic>[
            <String, dynamic>{'/': '*', 'comment': 'Route all paths into the app'}
          ],
        }
      ],
    },
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Android Digital Asset Links(assetlinks.json) 본문.
/// sha256Fingerprints는 Play 앱 서명 인증서 지문 — 레포에 없으므로 템플릿은
/// 빈 배열(placeholder), 포크가 배포 시 채운다.
String assetLinksJson(String packageName, List<String> sha256Fingerprints) {
  final list = <dynamic>[
    <String, dynamic>{
      'relation': <String>['delegate_permission/common.handle_all_urls'],
      'target': <String, dynamic>{
        'namespace': 'android_app',
        'package_name': packageName,
        'sha256_cert_fingerprints': sha256Fingerprints,
      },
    }
  ];
  return const JsonEncoder.withIndent('  ').convert(list);
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttr(String value) =>
    _escapeXml(value).replaceAll('"', '&quot;').replaceAll("'", '&apos;');
