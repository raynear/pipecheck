// Orange(영구 설정 저장소)를 임시 디렉터리에 올리는 공용 setUpAll/tearDownAll.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orange/orange.dart';

/// 테스트 파일의 main() 맨 앞에서 부른다. 돌려주는 함수는 임시 디렉터리를 준다.
Directory Function() setUpOrange(String name) {
  late Directory dir;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp(name);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    await Orange.init();
  });
  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException catch (_) {}
  });
  return () => dir;
}
