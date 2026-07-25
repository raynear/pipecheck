// 통합 테스트 시드 — 앱 부팅 스모크.
//
// 실행:
//   flutter test test/integration/app_boot_test.dart
// integration_test 바인딩을 쓰므로 동일 코드로 flutter drive(실기기)도 가능하다.
// 새 통합 시나리오는 이 파일을 복제해 작성한다. 트리비얼 단언(expect(true,...))이나
// skip:은 쓰지 말 것 — preflight no-skip 게이트에 걸린다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('통합: 앱 부팅', () {
    testWidgets('첫 프레임이 크래시 없이 렌더된다', (tester) async {
      // ponytail: TODO 실제 앱 부팅으로 교체하세요.
      //   import 'package:<your_package>/main.dart' as app;
      //   app.main();
      //   await tester.pumpAndSettle(const Duration(seconds: 3));
      // (main()이 EasyLocalization/Firebase 초기화를 포함하면
      //  test/screenshot/providers/mock_providers_base.dart의 override 패턴 참고.)
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: Text('BOOT')))),
      );
      await tester.pumpAndSettle();

      expect(find.text('BOOT'), findsOneWidget);
    });
  });
}
