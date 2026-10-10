// Drift 마이그레이션 게이트.
//
// 출시 후 테이블·컬럼을 바꾸고 `schemaVersion`/`onUpgrade`를 손대지 않으면, 기존 설치본은
// 새 테이블이 없는 채로 열려 `no such table`이 반복된다(새로 깐 기기에서는 onCreate가
// 전부 만들어 줘서 개발 중엔 절대 안 보인다). 이 테스트는 `drift_schemas/`의 버전별
// 덤프(= 출시된 스키마의 기록)를 정본으로 삼아 두 가지를 청구한다.
//
//  1. 현재 코드의 스키마가 `appSchemaVersion` 덤프와 **정확히 같다.** 테이블을 추가했는데
//     버전을 안 올렸거나 덤프를 안 갱신했으면 여기서 빨개진다.
//  2. 덤프가 있는 **모든 이전 버전**에서 현재 버전으로 `onUpgrade`를 태워 스키마가 같아진다.
//
// 절차(database.dart의 onUpgrade 주석 참고):
//   dart run drift_dev schema dump lib/data/datasources/local/database/database.dart \
//       drift_schemas/drift_schema_v<N>.json
//   dart run drift_dev schema generate drift_schemas/ test/generated_migrations/

import 'package:pipecheck/data/datasources/local/database/database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('덤프에 현재 appSchemaVersion이 있다', () {
    expect(
      GeneratedHelper.versions,
      contains(appSchemaVersion),
      reason:
          'appSchemaVersion=$appSchemaVersion 덤프가 없다 — '
          'drift_dev schema dump + schema generate를 다시 돌릴 것 (이 파일 머리말)',
    );
  });

  test('현재 코드의 스키마 == v$appSchemaVersion 덤프 (버전·덤프 갱신 누락 탐지)', () async {
    final schema = await verifier.schemaAt(appSchemaVersion);
    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);

    // migrateAndValidate(db, v)는 기준을 v 덤프로 잡고 실제 값을 db에서 읽는다 — 덤프로 연
    // db를 같은 덤프로 검증하면 현재 코드의 스키마는 어디서도 읽지 않아 항상 초록이다.
    // validateDatabaseSchema()가 db(= 덤프로 만든 DB)와 **현재 코드가 생성하는 스키마**를 대조한다.
    await db.validateDatabaseSchema();
  });

  for (final from in GeneratedHelper.versions.where(
    (v) => v < appSchemaVersion,
  )) {
    test('v$from → v$appSchemaVersion 마이그레이션이 현재 스키마에 도달한다', () async {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, appSchemaVersion);
    });
  }
}
