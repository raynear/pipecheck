// 자동증가 정수 PK 테이블이 restoreNaturalKeys에 빠지면, 복원이 기기마다 다른
// 대리키(id)로 병합해 서로 다른 행을 "이미 있다"로 조용히 버린다.
// 파생 앱이 `IdStrategy.autoIncrement` 테이블을 추가하고 이 등록을 잊는 순간을
// 여기서 잡는다 — 실제 스키마(PRAGMA)를 읽으므로 정의 파일 파싱에 기대지 않는다.

import 'package:pipecheck/core/services/data_export_service.dart';
import 'package:pipecheck/core/services/restore_service.dart';
import 'package:pipecheck/data/datasources/local/database/drift_database.dart';
import 'package:pipecheck/data/datasources/local/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> columns(String table) async => [
    for (final r in await db.customSelect("PRAGMA table_info('$table')").get())
      r.data,
  ];

  test('정수 id PK 테이블은 모두 자연키가 등록돼 있고, 그 컬럼이 실제로 있다', () async {
    final intPkTables = <String>[];
    for (final t in db.allTables) {
      final cols = await columns(t.actualTableName);
      final id = cols.where((c) => c['name'] == 'id' && c['pk'] == 1).toList();
      if (id.isNotEmpty &&
          (id.single['type'] as String).toUpperCase() == 'INTEGER') {
        intPkTables.add(t.actualTableName);
      }
    }
    expect(
      intPkTables,
      isNotEmpty,
      reason: '템플릿 badge가 자동증가 PK — 탐지가 공허하면 안 된다',
    );

    for (final table in intPkTables) {
      final key = restoreNaturalKeys[table];
      expect(
        key,
        isNotNull,
        reason: '$table: 자동증가 id 테이블인데 restoreNaturalKeys에 자연키가 없다',
      );
      expect(
        (await columns(table)).map((c) => c['name']),
        contains(key),
        reason: '$table: 자연키 컬럼 $key가 테이블에 없다',
      );
    }
  });

  test('등록된 자연키는 모두 실제 테이블이다 (오타·삭제된 테이블 방지)', () {
    final actual = db.allTables.map((t) => t.actualTableName).toSet();
    expect(actual, containsAll(restoreNaturalKeys.keys));
  });

  test('실제 SQLite 왕복 — 다른 기기의 같은 id 배지가 버려지지 않는다', () async {
    Future<void> badge(DriftDatabase d, String badgeId) => d.insert('badge', {
      'badge_id': badgeId,
      'title': 't',
      'description': 'd',
      'icon_path': 'i',
      'is_achieved': false,
      'type': 0,
      'condition': 'c',
    });

    final source = DriftDatabase(db);
    await badge(source, 'from-device-a'); // id=1
    final json = await DataExportService(
      listTables: () => source.tableNames,
      readTable: (t) => source.findMany(t),
      schemaVersion: appSchemaVersion,
    ).buildExportJson();

    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);
    final target = DriftDatabase(other);
    await badge(target, 'from-device-b'); // 역시 id=1

    final summary = await RestoreService(
      listTables: () => target.tableNames,
      readTable: (t) => target.findMany(t),
      insertRows: (t, rows) async => target.insertMany(t, rows),
      naturalKeys: restoreNaturalKeys,
      schemaVersion: appSchemaVersion,
    ).restoreFromJson(json);

    expect(summary.inserted, 1);
    final ids = (await target.findMany('badge')).map((r) => r['badge_id']);
    expect(ids, unorderedEquals(['from-device-a', 'from-device-b']));
  });
}
