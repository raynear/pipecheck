import 'dart:convert';

import 'package:boilerplate_cli/commands/deeplink/deeplink_native_generator.dart';
import 'package:test/test.dart';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
''';

const _plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleName</key>
\t<string>App</string>
\t<key>CFBundleVersion</key>
\t<string>1</string>
</dict>
</plist>
''';

const _entitlements = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
</dict>
</plist>
''';

const _entitlementsWithKeys = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>com.apple.security.application-groups</key>
\t<array>
\t\t<string>group.example</string>
\t</array>
</dict>
</plist>
''';

int _count(String haystack, String needle) =>
    needle.allMatches(haystack).length;

void main() {
  group('injectAndroidScheme', () {
    test('빈 매니페스트에 scheme intent-filter를 </activity> 앞에 삽입', () {
      final out = injectAndroidScheme(_manifest, 'myapp');
      expect(out, contains(deeplinkBegin));
      expect(out, contains(deeplinkEnd));
      expect(out, contains('android:scheme="myapp"'));
      expect(out, contains('android.intent.action.VIEW'));
      // 마커 블록이 </activity> 앞에 와야 한다
      expect(out.indexOf(deeplinkEnd), lessThan(out.indexOf('</activity>')));
      // 기존 LAUNCHER 필터는 보존
      expect(out, contains('android.intent.category.LAUNCHER'));
    });

    test('멱등 — 두 번 주입해도 마커 블록은 하나', () {
      final once = injectAndroidScheme(_manifest, 'myapp');
      final twice = injectAndroidScheme(once, 'myapp');
      expect(_count(twice, deeplinkBegin), 1);
      expect(twice, once);
    });

    test('스킴 변경 시 기존 블록을 교체(중복 아님)', () {
      final v1 = injectAndroidScheme(_manifest, 'myapp');
      final v2 = injectAndroidScheme(v1, 'otherapp');
      expect(_count(v2, deeplinkBegin), 1);
      expect(v2, contains('android:scheme="otherapp"'));
      expect(v2, isNot(contains('android:scheme="myapp"')));
    });

    test('</activity> 없으면 FormatException', () {
      expect(
        () => injectAndroidScheme('<manifest></manifest>', 'myapp'),
        throwsA(isA<FormatException>()),
      );
    });

    test('다른 액티비티가 먼저여도 MainActivity 닫힘에 주입', () {
      const multi = '''
<manifest>
    <application>
        <activity android:name=".OtherActivity">
        </activity>
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
''';
      final out = injectAndroidScheme(multi, 'myapp');
      // 블록은 .MainActivity 뒤, OtherActivity 닫힘 뒤에 와야 한다
      expect(out.indexOf(deeplinkBegin),
          greaterThan(out.indexOf('.MainActivity')));
      // OtherActivity에는 주입되지 않음
      final otherClose = out.indexOf('</activity>'); // 첫 번째 = OtherActivity
      expect(out.indexOf(deeplinkBegin), greaterThan(otherClose));
    });
  });

  group('injectIosUrlTypes', () {
    test('CFBundleURLTypes를 루트 </dict></plist> 앞에 삽입', () {
      final out = injectIosUrlTypes(_plist, 'myapp', 'com.x.app');
      expect(out, contains('<key>CFBundleURLTypes</key>'));
      expect(out, contains('<string>myapp</string>'));
      expect(out, contains('<string>com.x.app</string>'));
      expect(out, contains('</plist>'));
      expect(out.indexOf(deeplinkEnd), lessThan(out.lastIndexOf('</plist>')));
    });

    test('멱등 — 두 번 주입해도 블록 하나', () {
      final once = injectIosUrlTypes(_plist, 'myapp', 'com.x.app');
      final twice = injectIosUrlTypes(once, 'myapp', 'com.x.app');
      expect(_count(twice, deeplinkBegin), 1);
      expect(twice, once);
    });

    test('XML 특수문자 이스케이프', () {
      final out = injectIosUrlTypes(_plist, 'a&b', 'c<d');
      expect(out, contains('<string>a&amp;b</string>'));
      expect(out, contains('<string>c&lt;d</string>'));
    });

    test('루트 </dict></plist> 없으면 FormatException', () {
      expect(
        () => injectIosUrlTypes('<plist></plist>', 'myapp', 'com.x.app'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('injectAndroidUniversal', () {
    test('autoVerify https intent-filter를 </activity> 앞에 삽입', () {
      final out = injectAndroidUniversal(_manifest, ['myapp.web.app']);
      expect(out, contains(universalBegin));
      expect(out, contains(universalEnd));
      expect(out, contains('android:autoVerify="true"'));
      expect(out, contains('android:scheme="https"'));
      expect(out, contains('android:host="myapp.web.app"'));
      expect(out, contains('android.intent.action.VIEW'));
      expect(out.indexOf(universalEnd), lessThan(out.indexOf('</activity>')));
      expect(out, contains('android.intent.category.LAUNCHER')); // 기존 보존
    });

    test('멱등 — 두 번 주입해도 마커 블록은 하나', () {
      final once = injectAndroidUniversal(_manifest, ['myapp.web.app']);
      final twice = injectAndroidUniversal(once, ['myapp.web.app']);
      expect(_count(twice, universalBegin), 1);
      expect(twice, once);
    });

    test('호스트 변경 시 기존 블록을 교체(중복 아님)', () {
      final v1 = injectAndroidUniversal(_manifest, ['a.com']);
      final v2 = injectAndroidUniversal(v1, ['b.com']);
      expect(_count(v2, universalBegin), 1);
      expect(v2, contains('android:host="b.com"'));
      expect(v2, isNot(contains('android:host="a.com"')));
    });

    test('다중 호스트 — 하나의 필터에 모두', () {
      final out = injectAndroidUniversal(_manifest, ['a.com', 'b.com']);
      expect(out, contains('android:host="a.com"'));
      expect(out, contains('android:host="b.com"'));
      expect(_count(out, 'android:autoVerify="true"'), 1);
    });

    test('스킴 필터와 공존 — 각자 별도 마커, 둘 다 보존', () {
      final withScheme = injectAndroidScheme(_manifest, 'myapp');
      final both = injectAndroidUniversal(withScheme, ['myapp.web.app']);
      expect(_count(both, deeplinkBegin), 1); // 스킴 블록 보존
      expect(_count(both, universalBegin), 1); // 유니버설 블록 추가
      expect(both, contains('android:scheme="myapp"'));
      expect(both, contains('android:host="myapp.web.app"'));
      // 한쪽 재실행이 다른쪽을 건드리지 않음(멱등 독립)
      final reRun = injectAndroidScheme(both, 'myapp');
      expect(reRun, both);
    });

    test('</activity> 없으면 FormatException', () {
      expect(
        () => injectAndroidUniversal('<manifest></manifest>', ['a.com']),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('injectIosAssociatedDomains', () {
    test('associated-domains를 루트 </dict></plist> 앞에 삽입', () {
      final out = injectIosAssociatedDomains(_entitlements, ['myapp.web.app']);
      expect(out, contains('<key>com.apple.developer.associated-domains</key>'));
      expect(out, contains('<string>applinks:myapp.web.app</string>'));
      expect(out, contains(universalBegin));
      expect(out.indexOf(universalEnd), lessThan(out.lastIndexOf('</plist>')));
    });

    test('멱등 — 두 번 주입해도 블록 하나', () {
      final once = injectIosAssociatedDomains(_entitlements, ['myapp.web.app']);
      final twice = injectIosAssociatedDomains(once, ['myapp.web.app']);
      expect(_count(twice, universalBegin), 1);
      expect(twice, once);
    });

    test('기존 entitlements 내용 보존', () {
      final out =
          injectIosAssociatedDomains(_entitlementsWithKeys, ['myapp.web.app']);
      expect(out, contains('com.apple.security.application-groups'));
      expect(out, contains('<string>group.example</string>'));
      expect(out, contains('applinks:myapp.web.app'));
    });

    test('다중 호스트', () {
      final out = injectIosAssociatedDomains(_entitlements, ['a.com', 'b.com']);
      expect(out, contains('<string>applinks:a.com</string>'));
      expect(out, contains('<string>applinks:b.com</string>'));
    });

    test('루트 </dict></plist> 없으면 FormatException', () {
      expect(
        () => injectIosAssociatedDomains('<plist></plist>', ['a.com']),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('appleAppSiteAssociation', () {
    test('유효한 JSON + appID = teamId.bundleId + 모든 경로', () {
      final json = appleAppSiteAssociation('ABCDE12345', 'com.x.app');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final details =
          (decoded['applinks'] as Map)['details'] as List<dynamic>;
      final appIDs = (details.first as Map)['appIDs'] as List<dynamic>;
      expect(appIDs, ['ABCDE12345.com.x.app']);
      final components = (details.first as Map)['components'] as List<dynamic>;
      expect((components.first as Map)['/'], '*');
    });
  });

  group('assetLinksJson', () {
    test('유효한 JSON + package_name + 빈 지문(placeholder)', () {
      final json = assetLinksJson('com.x.app', const []);
      final decoded = jsonDecode(json) as List<dynamic>;
      final target = (decoded.first as Map)['target'] as Map<String, dynamic>;
      expect(target['namespace'], 'android_app');
      expect(target['package_name'], 'com.x.app');
      expect(target['sha256_cert_fingerprints'], isEmpty);
      final relation = (decoded.first as Map)['relation'] as List<dynamic>;
      expect(relation, ['delegate_permission/common.handle_all_urls']);
    });

    test('지문 전달 시 그대로 포함', () {
      final json = assetLinksJson('com.x.app', const ['AA:BB:CC']);
      final decoded = jsonDecode(json) as List<dynamic>;
      final target = (decoded.first as Map)['target'] as Map<String, dynamic>;
      expect(target['sha256_cert_fingerprints'], ['AA:BB:CC']);
    });
  });
}
