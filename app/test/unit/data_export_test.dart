// 데이터 내보내기(GDPR) 테스트 (P2-23f).
//
// DataExportService는 DB 인터페이스에 직접 결합하지 않고 listTables/readTable
// 람다만 받으므로 Firebase/Drift 없이 트리비얼하게 가짜 데이터로 검증한다.
// 파일 쓰기(exportToFile)는 path_provider 플러그인이 필요해 단위 테스트에서
// 제외 — 직렬화 본체(buildExportJson)만 고정한다.

import 'dart:convert';

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
