import 'dart:io';

import 'package:boilerplate_cli/commands/rename_command.dart';
import 'package:test/test.dart';

void main() {
  group('RenameCommand 식별자 헬퍼', () {
    test('isValidBundleId — 점 구분 2세그먼트 이상만 허용', () {
      expect(RenameCommand.isValidBundleId('com.acme.myapp'), isTrue);
      expect(RenameCommand.isValidBundleId('com.acme'), isTrue);
      expect(RenameCommand.isValidBundleId('com.acme.my_app2'), isTrue);
      expect(RenameCommand.isValidBundleId('myapp'), isFalse,
          reason: '세그먼트 1개는 거부');
      expect(RenameCommand.isValidBundleId('com.Acme.app'), isFalse,
          reason: '대문자 거부');
      expect(RenameCommand.isValidBundleId('com.1acme.app'), isFalse,
          reason: '숫자 시작 세그먼트 거부');
      expect(RenameCommand.isValidBundleId('com..app'), isFalse);
    });

    test('defaultDartNameFor — 마지막 세그먼트', () {
      expect(RenameCommand.defaultDartNameFor('com.acme.myapp'),
          equals('myapp'));
      expect(RenameCommand.defaultDartNameFor('com.example.smokeapp'),
          equals('smokeapp'));
    });

    test('extractAndroidApplicationId — applicationId 우선, namespace 폴백', () {
      expect(
        RenameCommand.extractAndroidApplicationId('''
android {
    namespace = "com.raynear.boilerplate"
    defaultConfig {
        applicationId = "com.raynear.boilerplate"
    }
}'''),
        equals('com.raynear.boilerplate'),
      );
      expect(
        RenameCommand.extractAndroidApplicationId(
            "android { namespace 'com.foo.bar' }"),
        equals('com.foo.bar'),
      );
      expect(RenameCommand.extractAndroidApplicationId('nothing here'),
          isNull);
    });

    test('extractIosBaseBundleId — .dev/.RunnerTests 변형의 공통 베이스', () {
      const pbxproj = '''
PRODUCT_BUNDLE_IDENTIFIER = com.raynear.boilerplate.RunnerTests;
PRODUCT_BUNDLE_IDENTIFIER = com.raynear.boilerplate;
PRODUCT_BUNDLE_IDENTIFIER = com.raynear.boilerplate.dev;
''';
      expect(RenameCommand.extractIosBaseBundleId(pbxproj),
          equals('com.raynear.boilerplate'));
      expect(RenameCommand.extractIosBaseBundleId('no ids'), isNull);
    });
  });

  group('RenameCommand 통합 (합성 트리)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rename_test_');
      _writeFixtureTree(tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('전체 rename — 트리에서 현재 ID를 읽어 치환', () async {
      final command = RenameCommand(projectRoot: tempDir.path);
      final exitCode = await command.run(
          ['com.acme.newapp', '--name', 'New App', '--force']);
      expect(exitCode, equals(0));

      final root = tempDir.path;

      expect(_read('$root/app/pubspec.yaml'), contains('name: newapp'));
      expect(_read('$root/app/lib/main.dart'),
          contains('package:newapp/config.dart'));
      expect(_read('$root/app/build.yaml'),
          contains('newapp:table_generator'));
      expect(_read('$root/app/build.yaml'),
          contains('package:newapp/data/table_generator/builder.dart'));

      // examples/도 rename 동행 (P1-16c — 'boilerplate' 비의존화)
      expect(
          _read('$root/examples/optional_services/sample_service.dart'),
          contains('package:newapp/config/app_feature_config.dart'));

      final gradle = _read('$root/app/android/app/build.gradle');
      expect(gradle, contains('namespace = "com.acme.newapp"'));
      expect(gradle, contains('applicationId = "com.acme.newapp"'));
      expect(gradle, isNot(contains('com.raynear.oldapp')));

      // Kotlin: package 선언 치환 + 디렉토리 재배치 (불일치 디렉토리 해소)
      final movedKotlin = File(
          '$root/app/android/app/src/main/kotlin/com/acme/newapp/MainActivity.kt');
      expect(movedKotlin.existsSync(), isTrue,
          reason: 'package 선언 기준 새 경로로 이동');
      expect(movedKotlin.readAsStringSync(),
          contains('package com.acme.newapp'));
      expect(
          Directory('$root/app/android/app/src/main/kotlin/com/raynear')
              .existsSync(),
          isFalse,
          reason: '빈 구 디렉토리 제거');

      final pbxproj =
          _read('$root/app/ios/Runner.xcodeproj/project.pbxproj');
      expect(pbxproj,
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.newapp;'));
      expect(pbxproj,
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.newapp.dev;'));
      expect(
          pbxproj,
          contains(
              'PRODUCT_BUNDLE_IDENTIFIER = com.acme.newapp.RunnerTests;'));

      expect(_read('$root/app/ios/Runner/Runner.entitlements'),
          contains('group.com.acme.newapp'));

      // App Group 3자 일치 (INV-H1): 위젯 확장 entitlement + Dart 상수도 함께.
      expect(_read('$root/app/ios/widgetExtension.entitlements'),
          contains('group.com.acme.newapp'));
      expect(_read('$root/app/ios/widgetExtension.entitlements'),
          isNot(contains('oldapp')));
      final widgetDart = _read(
          '$root/app/lib/core/services/widget/home_widget_service.dart');
      expect(widgetDart, contains("'group.com.acme.newapp'"));
      expect(widgetDart, isNot(contains('oldapp')));

      expect(_read('$root/app/ios/Runner/Info.plist'),
          contains('com.acme.newapp.iOSBackgroundAppRefresh'));
      expect(_read('$root/app/ios/Runner/Info.plist'),
          contains('<string>New App</string>'));

      // 표시 이름: main strings.xml 생성 + debug strings.xml 갱신
      expect(
          _read(
              '$root/app/android/app/src/main/res/values/strings.xml'),
          contains('<string name="app_name">New App</string>'));
      expect(
          _read(
              '$root/app/android/app/src/debug/res/values/strings.xml'),
          contains('<string name="app_name">New App</string>'));

      // project.yaml writeback
      final projectYaml = _read('$root/project.yaml');
      expect(projectYaml, contains('package_name: "com.acme.newapp"'));
      expect(projectYaml, contains('name: "New App"'));
    });

    test('idempotent — 같은 인자로 재실행 시 no-op 성공', () async {
      final command = RenameCommand(projectRoot: tempDir.path);
      expect(
          await command
              .run(['com.acme.newapp', '--name', 'New App', '--force']),
          equals(0));
      expect(await command.run(['com.acme.newapp', '--force']), equals(0));
    });

    test('잘못된 번들 ID는 즉시 실패', () async {
      final command = RenameCommand(projectRoot: tempDir.path);
      expect(await command.run(['NotValid', '--force']), isNot(equals(0)));
    });
  });
}

String _read(String path) => File(path).readAsStringSync();

void _writeFixtureTree(String root) {
  void write(String relative, String content) {
    final file = File('$root/$relative');
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  write('project.yaml', '''
project:
  name: "Old App"
  package_name: "com.raynear.oldapp"
''');

  write('app/pubspec.yaml', '''
name: oldapp
environment:
  sdk: '>=3.8.0 <4.0.0'
''');

  write('app/lib/main.dart', '''
import 'package:oldapp/config.dart';

void main() {}
''');

  // examples/는 repo 루트의 복사용 레퍼런스 코드 — rename 동행 대상 (P1-16c)
  write('examples/optional_services/sample_service.dart', '''
import 'package:oldapp/config/app_feature_config.dart';

void sample() {}
''');

  write('app/build.yaml', '''
targets:
  \$default:
    builders:
      oldapp:table_generator:
        enabled: true
builders:
  table_generator:
    import: "package:oldapp/data/table_generator/builder.dart"
''');

  write('app/android/app/build.gradle', '''
android {
    namespace = "com.raynear.oldapp"
    defaultConfig {
        applicationId = "com.raynear.oldapp"
    }
    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
        }
    }
}
''');

  write('app/android/app/src/main/AndroidManifest.xml', '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="@string/app_name"/>
</manifest>
''');

  // 의도적 불일치: 디렉토리는 com/raynear/legacydir, package는 com.raynear.oldapp
  write('app/android/app/src/main/kotlin/com/raynear/legacydir/MainActivity.kt',
      '''
package com.raynear.oldapp

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
''');

  write('app/android/app/src/debug/res/values/strings.xml', '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Old App Debug</string>
</resources>
''');

  write('app/ios/Runner.xcodeproj/project.pbxproj', '''
PRODUCT_BUNDLE_IDENTIFIER = com.raynear.oldapp;
PRODUCT_BUNDLE_IDENTIFIER = com.raynear.oldapp.dev;
PRODUCT_BUNDLE_IDENTIFIER = com.raynear.oldapp.RunnerTests;
''');

  write('app/ios/Runner/Info.plist', '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
		<string>com.raynear.oldapp.iOSBackgroundAppRefresh</string>
	</array>
	<key>CFBundleDisplayName</key>
	<string>Old App</string>
	<key>CFBundleName</key>
	<string>oldapp</string>
</dict>
</plist>
''');

  write('app/ios/Runner/Runner.entitlements', '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.raynear.oldapp</string>
	</array>
</dict>
</plist>
''');

  // 위젯 확장 entitlement — App Group이 메인 앱과 정확히 일치해야 함 (INV-H1).
  write('app/ios/widgetExtension.entitlements', '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.raynear.oldapp</string>
	</array>
</dict>
</plist>
''');

  // Dart App Group 상수 — entitlement와 3자 일치해야 함 (INV-H1).
  write('app/lib/core/services/widget/home_widget_service.dart', '''
class HomeWidgetService {
  static const String appGroupId = 'group.com.raynear.oldapp';
}
''');

  write('README.md', '# oldapp\n\nOldapp template.\n');
}
