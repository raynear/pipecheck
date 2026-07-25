import 'dart:io';

import 'package:boilerplate_cli/core/bootstrap.dart';
import 'package:test/test.dart';

void main() {
  group('readFastlaneRef (P1-10)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('bootstrap_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    void writeProjectYaml(String content) {
      File('${tmp.path}/project.yaml').writeAsStringSync(content);
    }

    test('따옴표 값', () {
      writeProjectYaml('tooling:\n  fastlane_ref: "v0.2.1"\n');
      expect(readFastlaneRef(tmp.path), 'v0.2.1');
    });

    test('따옴표 없는 값 + 후행 주석', () {
      writeProjectYaml('tooling:\n  fastlane_ref: main # 핀\n');
      expect(readFastlaneRef(tmp.path), 'main');
    });

    test('빈 값이면 다음 줄 토큰을 오캡처하지 않는다 (리뷰 발견 회귀)', () {
      writeProjectYaml('tooling:\n  fastlane_ref:\nother: value\n');
      expect(readFastlaneRef(tmp.path), isNull);
    });

    test('project.yaml 부재 시 null', () {
      expect(readFastlaneRef(tmp.path), isNull);
    });
  });

  group('findProjectRoot (P1-10)', () {
    late Directory tmp;
    late String savedCwd;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('bootstrap_root_');
      savedCwd = Directory.current.path;
    });

    tearDown(() {
      Directory.current = savedCwd;
      tmp.deleteSync(recursive: true);
    });

    test('서브디렉토리에서 상향 탐색으로 루트 발견', () {
      File('${tmp.path}/project.yaml').writeAsStringSync('name: x\n');
      final sub = Directory('${tmp.path}/app/lib')..createSync(recursive: true);
      Directory.current = sub.path;
      // macOS /tmp 심볼릭링크 정규화 차이 흡수
      expect(
        Directory(findProjectRoot()).resolveSymbolicLinksSync(),
        Directory(tmp.path).resolveSymbolicLinksSync(),
      );
    });

    test('project.yaml 없으면 cwd 반환', () {
      final sub = Directory('${tmp.path}/no/marker')..createSync(recursive: true);
      Directory.current = sub.path;
      expect(
        Directory(findProjectRoot()).resolveSymbolicLinksSync(),
        Directory(sub.path).resolveSymbolicLinksSync(),
      );
    });
  });
}
