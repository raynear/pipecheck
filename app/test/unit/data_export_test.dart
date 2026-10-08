// 데이터 내보내기(GDPR) 테스트 (P2-23f).
//
// DataExportService는 DB 인터페이스에 직접 결합하지 않고 listTables/readTable
// 람다만 받으므로 Firebase/Drift 없이 트리비얼하게 가짜 데이터로 검증한다.
// 파일 쓰기(exportToFile)는 path_provider 채널을 임시 디렉터리로 스텁해 실제 파일로 고정한다.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/data_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataExportService.buildExportJson', () {
    test('모든 테이블 행을 schema/exportedAt와 함께 직렬화', () async {
      final service = DataExportService(
        listTables: () => ['user', 'badge'],
        readTable: (t) async => switch (t) {
          'user' => [
              {'id': '1', 'name': 'Kim', 'age': 30},
            ],
          'badge' => [
              {'id': 'b1', 'achieved': 1},
              {'id': 'b2', 'achieved': 0},
            ],
          _ => <Map<String, dynamic>>[],
        },
      );

      final json = await service.buildExportJson(
        exportedAt: DateTime.utc(2026, 6, 14, 9),
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['schema'], 'local-drift');
      expect(decoded['exportedAt'], '2026-06-14T09:00:00.000Z');
      final tables = decoded['tables'] as Map<String, dynamic>;
      expect(tables.keys, containsAll(['user', 'badge']));
      expect((tables['user'] as List), hasLength(1));
      expect((tables['badge'] as List), hasLength(2));
      expect((tables['user'] as List).first['name'], 'Kim');
    });

    test('테이블이 없으면 빈 tables 객체', () async {
      final service = DataExportService(
        listTables: () => [],
        readTable: (t) async => [],
      );
      final decoded =
          jsonDecode(await service.buildExportJson()) as Map<String, dynamic>;
      expect((decoded['tables'] as Map), isEmpty);
    });

    test('비표준 타입(DateTime)도 안전하게 직렬화', () async {
      final service = DataExportService(
        listTables: () => ['events'],
        readTable: (t) async => [
          {'at': DateTime.utc(2026, 1, 2, 3, 4, 5)},
        ],
      );
      final decoded =
          jsonDecode(await service.buildExportJson()) as Map<String, dynamic>;
      final row = (decoded['tables']['events'] as List).first;
      expect(row['at'], '2026-01-02T03:04:05.000Z');
    });

    test('BLOB(Uint8List)은 {\$base64: ...}로 감싸 바이트 그대로 왕복', () async {
      final service = DataExportService(
        listTables: () => ['files'],
        readTable: (t) async => [
          {'data': Uint8List.fromList([0, 1, 254, 255])},
        ],
      );
      final decoded =
          jsonDecode(await service.buildExportJson()) as Map<String, dynamic>;
      final cell = (decoded['tables']['files'] as List).first['data'];
      expect(cell, {r'$base64': 'AAH+/w=='});
    });

    test('schemaVersion을 주면 문서에 기록하고, 안 주면 키 자체가 없다', () async {
      DataExportService make({int? v}) => DataExportService(
        listTables: () => [],
        readTable: (t) async => [],
        schemaVersion: v,
      );
      final withV =
          jsonDecode(await make(v: 3).buildExportJson()) as Map<String, dynamic>;
      final without =
          jsonDecode(await make().buildExportJson()) as Map<String, dynamic>;
      expect(withV['schemaVersion'], 3);
      expect(without.containsKey('schemaVersion'), isFalse);
    });
  });

  group('DataExportService.exportToFile', () {
    late Directory tmp;
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      tmp = Directory.systemTemp.createTempSync('data_export_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path,
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      tmp.deleteSync(recursive: true);
    });

    DataExportService service() => DataExportService(
      listTables: () => ['user'],
      readTable: (_) async => [
        {'id': '1', 'name': 'Kim'},
      ],
    );

    test('임시 디렉토리에 실제로 파일을 쓰고 경로를 돌려준다', () async {
      final path = await service().exportToFile(
        timestamp: DateTime.utc(2026, 6, 14, 9, 30, 15),
      );
      final file = File(path);
      expect(file.existsSync(), isTrue);
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect((decoded['tables']['user'] as List).first['name'], 'Kim');
      expect(path.split(Platform.pathSeparator).last,
          'data-export-2026-06-14T09-30-15-000Z.json');
    });

    test('새 내보내기는 이전 내보내기 사본을 지운다 (임시 폴더에 DB 사본이 쌓이지 않는다)', () async {
      final s = service();
      final a = await s.exportToFile(timestamp: DateTime.utc(2026, 1, 1));
      final b = await s.exportToFile(timestamp: DateTime.utc(2026, 1, 2));
      expect(a, isNot(b));
      expect(File(a).existsSync(), isFalse, reason: '이전 사본이 남아 있다');
      expect(File(b).existsSync(), isTrue);
    });

    test('N3: exportAndShare는 공유가 성공해도 사본을 지운다', () async {
      String? shared;
      await service().exportAndShare((path) async {
        shared = path;
        expect(File(path).existsSync(), isTrue, reason: '공유 시점에는 있어야 한다');
      });
      expect(File(shared!).existsSync(), isFalse);
    });

    test('N3: 공유가 던져도 사본을 지우고 예외는 그대로 전파한다', () async {
      String? shared;
      await expectLater(
        service().exportAndShare((path) async {
          shared = path;
          throw StateError('share failed');
        }),
        throwsStateError,
      );
      expect(File(shared!).existsSync(), isFalse);
    });

    test('N3: deleteExportFile은 없는 파일에도 던지지 않는다', () async {
      await DataExportService.deleteExportFile('${tmp.path}/nope.json');
    });

    test('내보내기와 무관한 임시 파일은 건드리지 않는다', () async {
      final other = File('${tmp.path}/unrelated-keep.json')..writeAsStringSync('{}');
      await service().exportToFile(timestamp: DateTime.utc(2026, 1, 2));
      expect(other.existsSync(), isTrue);
    });
  });

  group('isDataExportEnabled 플래그 배선', () {
    test('minimal 프로파일에서도 기본 ON (로컬 데이터 기본 기능)', () {
      AppFeatureConfig.applyBootConfig(profileName: 'minimal');
      expect(AppFeatureConfig.isDataExportEnabled, true);
    });

    test('FF_ override로 끌 수 있다', () {
      AppFeatureConfig.applyBootConfig(
        profileName: 'minimal',
        overrides: {'isDataExportEnabled': false},
      );
      expect(AppFeatureConfig.isDataExportEnabled, false);
    });
  });
}
