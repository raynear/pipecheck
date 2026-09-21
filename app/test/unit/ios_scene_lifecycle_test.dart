// iOS 26 SDK로 빌드한 UIKit 앱이 UIScene 생명주기를 채택하지 않으면 iOS 26+
// 기기에서 **실행 직후 강제 종료**된다(iOS 26.5는 아직 살려 준다 — 유예일 뿐이다).
//
// 이 게이트가 필요한 이유: 죽는 자리는 네이티브 런타임이라 `flutter analyze`도
// `flutter test`도 컴파일조차 건드리지 않는다. 포크가 Info.plist를 손대거나
// (Xcode plist GUI는 주석을 지운다) SceneDelegate를 빼면 **빌드는 초록인 채**
// 스토어로 나가고 iOS 26+ 사용자에겐 아이콘을 눌러도 아무 일도 안 일어난다.
//
// **델리게이트 모양은 두 가지가 다 유효하다.** Flutter 템플릿은 서브클래스를
// 출하하지만(`$(PRODUCT_MODULE_NAME).SceneDelegate`), `FlutterSceneDelegate`는
// ObjC 클래스라 매니페스트가 **직접 지목**해도 동작한다. 그래서 이름을 못박지
// 않고 plist에서 읽어와, 그 이름이 실제로 존재하는지를 청구한다 — 실제로 어떤
// 파생 앱은 있지도 않은 `<모듈>.SceneDelegate`를 지목한 채 초록이었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/pbxproj.dart';
import '../support/plist.dart';
import '../support/swift_source.dart';

void main() {
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final pbxproj = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

  /// Application 롤이 지목한 `UISceneDelegateClassName` 값.
  ///
  /// **롤 안으로 범위를 좁혀서** 읽는다 — plist 어디서나 첫 매치를 집으면 롤이
  /// 둘 이상일 때 엉뚱한 값을 줍고, 주석에 남은 옛 선언도 줍는다(실측: 이
  /// 레포들의 plist는 주석 블록을 1~3개씩 들고 있다).
  String? declaredDelegate() {
    final role = applicationSceneRole(infoPlist);
    if (role == null) return null;
    return RegExp(
      r'<key>UISceneDelegateClassName</key>\s*<string>([^<]*)</string>',
    ).firstMatch(role)?.group(1);
  }

  group('UIScene 생명주기를 채택한다 (iOS 26+ 즉사 방지)', () {
    test('Info.plist가 씬 델리게이트 클래스를 지목한다', () {
      // `<key>…</key>` 통째로 청구한다 — 맨 문자열 contains는 키 이름 뒤에
      // 아무 글자나 붙은 오타(`…ManifestX`)도 접두사로 매치해 통과시킨다(실측).
      expect(
        infoPlist,
        contains('<key>UIApplicationSceneManifest</key>'),
        reason: '이 키가 없으면 iOS 26+가 실행 직후 앱을 죽인다.',
      );
      // 롤 키까지 청구한다 — 매니페스트가 있어도 Application 롤 설정이 없으면
      // 씬이 델리게이트를 못 받는다(실측: 롤 키만 바꾼 뮤턴트가 통과했다).
      expect(
        infoPlist,
        contains('<key>UIWindowSceneSessionRoleApplication</key>'),
        reason: 'Application 롤 설정이 없으면 매니페스트가 있어도 무의미하다.',
      );
      expect(
        declaredDelegate(),
        isNotNull,
        reason: 'UISceneDelegateClassName이 없으면 델리게이트가 지정되지 않는다.',
      );
    });

    test('지목한 델리게이트 클래스가 실제로 존재한다', () {
      final declared = declaredDelegate();
      // `!`로 바로 까면 매니페스트가 없는 앱에서 "Null check operator used on a
      // null value"만 남는다 — 정작 그 앱이 이 수정이 필요한 앱이다.
      expect(
        declared,
        isNotNull,
        reason: '씬 매니페스트의 Application 롤에 UISceneDelegateClassName이 없다.',
      );
      // **분기 전에** 모양을 청구한다. 예전 판은 FlutterSceneDelegate 경로에서
      // 그냥 return해 **단언 0개로 통과**했고, 실측상 파생 앱 10개 중 8개가 그
      // 경로다 — 전파 대상 대부분에서 게이트가 공허했다.
      // (`./preflight`의 no-skip 검사는 skip/markTestSkipped/expect(true,isTrue)
      //  세 리터럴만 보므로 맨 `return;`을 잡지 못한다.)
      expect(
        declared,
        anyOf(
          equals('FlutterSceneDelegate'),
          matches(r'^\$\(PRODUCT_MODULE_NAME\)\.\w+$'),
        ),
        reason:
            'UISceneDelegateClassName이 "$declared"다 — 엔진이 출하하는 '
            'FlutterSceneDelegate이거나 `\$(PRODUCT_MODULE_NAME).<클래스>` '
            '꼴이어야 한다.',
      );

      // FlutterSceneDelegate는 엔진이 출하하는 ObjC 클래스라 더 볼 게 없다.
      if (declared == 'FlutterSceneDelegate') return;

      // 서브클래스를 지목했다면 그 클래스가 실재하고 컴파일돼야 한다.
      final name = RegExp(
        r'^\$\(PRODUCT_MODULE_NAME\)\.(\w+)$',
      ).firstMatch(declared!)!.group(1)!;
      final src = File('ios/Runner/$name.swift');
      expect(
        src.existsSync(),
        isTrue,
        reason:
            'ios/Runner/$name.swift가 없다 — 매니페스트가 존재하지 않는 '
            '클래스를 지목하고 있다(빌드는 초록이다).',
      );
      // 선언으로 청구한다 — 이름만 찾으면 **주석에 적힌 한 번**으로 통과한다(실측).
      expect(
        RegExp(
          'class\\s+$name\\s*:\\s*FlutterSceneDelegate\\b',
        ).hasMatch(src.readAsStringSync()),
        isTrue,
        reason: 'FlutterSceneDelegate를 상속하지 않으면 엔진↔씬 배선이 없다.',
      );
      // 컴파일되지 않으면 매니페스트가 지목한 클래스가 런타임에 없다.
      // 파일 존재만 보면 pbxproj에서 빠진 상태를 통과시킨다(이슈 #234의 모양).
      expect(
        sourcesFiles(pbxproj, 'Runner'),
        contains('/* $name.swift in Sources */'),
        reason: '$name.swift가 Runner 타겟에서 컴파일되지 않는다.',
      );
    });

    test('플러그인 등록이 엔진 초기화 콜백에 있다', () {
      // 프로토콜 채택을 따로 청구한다 — 메서드만 있고 채택이 없으면 **컴파일은
      // 통과하고 콜백은 영원히 안 불린다**. GeneratedPluginRegistrant도 안 돌아
      // 전 플러그인이 죽는데 빌드는 초록이다(실측 뮤턴트가 통과했다).
      expect(
        RegExp(
          r'class\s+AppDelegate\s*:[^{]*FlutterImplicitEngineDelegate',
        ).hasMatch(appDelegate),
        isTrue,
        reason: 'FlutterImplicitEngineDelegate를 채택하지 않으면 콜백이 호출되지 않는다.',
      );
      // 콜백 **본문**을 떼어내 청구한다. 파일 전체에 대고 문자열 존재만 보면
      // 등록이 didFinishLaunching에 남아 있어도 통과한다 — 죽는 배선이 정확히 그것이다.
      final body = swiftMethodBody(
        appDelegate,
        'func didInitializeImplicitFlutterEngine(',
      );
      expect(
        body,
        isNotNull,
        reason: 'FlutterImplicitEngineDelegate 콜백이 없으면 등록 시점이 없다.',
      );
      expect(
        body,
        contains('GeneratedPluginRegistrant.register('),
        reason: '이 등록이 콜백 밖에 있거나 없으면 모든 Flutter 플러그인이 죽는다.',
      );
    });
  });
}
