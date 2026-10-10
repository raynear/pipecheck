// SettingsView.initState의 postFrame 콜백은 PackageInfo를 await한 뒤 setState를
// 불렀다. 그 사이에 화면이 닫히면(빠른 뒤로가기·탭 전환) mounted 확인이 없어
// "setState() called after dispose()"가 났다. 지연된 플랫폼 응답으로 그 창을 연다.

import 'dart:async';

import 'package:pipecheck/features/settings/views/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PackageInfo 응답 전에 화면이 닫혀도 예외 없이 끝난다', (tester) async {
    final reply = Completer<Map<String, dynamic>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (_) => reply.future,
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            null,
          );
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SettingsView()),
            ],
          ),
        ),
      ),
    );
    await tester.pump(); // postFrame 콜백이 PackageInfo 응답을 기다리는 중

    await tester.pumpWidget(const SizedBox.shrink()); // 화면 닫힘
    reply.complete({
      'appName': 'boilerplate',
      'packageName': 'com.example.boilerplate',
      'version': '1.2.3',
      'buildNumber': '4',
      'buildSignature': '',
    });
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
