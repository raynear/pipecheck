// lib/database.dart
import 'dart:io';

import 'package:pipecheck/data/generated/drift/badge.drift.dart';
import 'package:pipecheck/data/generated/drift/user.drift.dart';
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:utils/utils.dart';

part 'database.g.dart';

// 메타데이터 믹스인 클래스 정의
mixin TableWithTimestamps on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 현재 스키마 버전. 테이블·컬럼을 바꾸면 올리고 [AppDatabase.migration]의
/// `onUpgrade`에 단계를 더한다(위 안내). 백업/복원이 이 값을 기록·대조한다.
const int appSchemaVersion = 1;

@DriftDatabase(
  tables: [
    // Active tables with definitions in lib/data/definitions/
    $Badge,
    $User,
  ],
  // DAOs는 일반화된 DatabaseDataSource 인터페이스로 대체되어 더 이상 필요 없음
)
class AppDatabase extends _$AppDatabase {
  // 싱글톤 인스턴스를 위한 static 필드
  static AppDatabase? _instance;

  // 싱글톤 인스턴스를 반환하는 factory 생성자
  factory AppDatabase() {
    // 기존 인스턴스가 있으면 재사용 (싱글톤 패턴)
    return _instance ??= AppDatabase._internal();
  }

  // Hot reload 시 데이터베이스 재생성이 필요한 경우에만 호출
  static Future<void> resetForDevelopment() async {
    if (_instance != null) {
      logger.d('AppDatabase: Closing existing instance for recreation');
      await _instance!.close();
      _instance = null;
    }
  }

  // private 생성자를 사용하여 직접적인 인스턴스 생성을 막음
  AppDatabase._internal() : super(_openConnection());


  /// 테스트 전용 주입 경로 — 실행기를 갈아끼운 **별도** 인스턴스를 만든다.
  ///
  /// 싱글톤(`_instance`)에는 손대지 않으므로 프로덕션 경로는 그대로다.
  /// 보통 `AppDatabase.forTesting(NativeDatabase.memory())`로 쓴다.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);
  @override
  int get schemaVersion => appSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      logger.d('Database onCreate called');
      await m.createAll();
      logger.d('All tables created successfully');
    },
    // 출시 후 테이블·컬럼을 바꿀 때의 절차 (안 하면 기존 설치본에서 `no such table`):
    //  1. appSchemaVersion을 올린다.
    //  2. 아래에 단계를 더한다 — 예) 새 테이블:
    //       if (from < 2) await m.createTable($NewTable);   // 이 클래스의 테이블 접근자
    //     새 컬럼: `if (from < 3) await m.addColumn(table, table.col);`
    //  3. `dart run drift_dev schema dump lib/data/datasources/local/database/database.dart drift_schemas/`
    //     로 새 버전 덤프를 만들고 `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`
    //     를 다시 돌린다 — test/unit/drift_migration_test.dart가 덤프와 현재 스키마를 대조해
    //     이 절차를 빠뜨리면 빨개진다.
    onUpgrade: (Migrator m, int from, int to) async {
      logger.d('Database onUpgrade: $from -> $to');
    },
    beforeOpen: (details) async {
      logger.d('Database beforeOpen called');
      logger.d('Schema version: ${details.versionNow}');
      logger.d('Was created: ${details.wasCreated}');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = p.join(dbFolder.path, 'db.sqlite');

    // 데이터베이스 폴더가 존재하는지 확인하고 생성
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }

    // 디버깅을 위해 데이터베이스 경로 출력
    logger.d('Database path: $file');

    // 개발 모드에서 데이터베이스 재생성 옵션
    const forceRecreate = bool.fromEnvironment(
      'FORCE_DB_RECREATE',
      defaultValue: false,
    );
    if (forceRecreate) {
      final dbFile = File(file);
      if (await dbFile.exists()) {
        logger.d('Deleting existing database file for recreation');
        await dbFile.delete();
      }
    }

    return SqfliteQueryExecutor.inDatabaseFolder(
      path: file,
      logStatements: kDebugMode, // 디버그에서만 SQL 로깅 — 릴리스 로그에 사용자 데이터가 남지 않게
      singleInstance: true, // 단일 인스턴스 보장
    );
  });
}

extension ValueExtension<T> on T {
  Value<T> val() => Value<T>(this);
}

Value<T> empty<T>() => const Value.absent();
