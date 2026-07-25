// lib/database.dart
import 'dart:io';

import 'package:pipecheck/data/generated/drift/badge.drift.dart';
import 'package:pipecheck/data/generated/drift/user.drift.dart';
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:utils/utils.dart';

part 'database.g.dart';

// 메타데이터 믹스인 클래스 정의
mixin TableWithTimestamps on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      logger.d('Database onCreate called');
      await m.createAll();
      logger.d('All tables created successfully');
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
    const forceRecreate = bool.fromEnvironment('FORCE_DB_RECREATE', defaultValue: false);
    if (forceRecreate) {
      final dbFile = File(file);
      if (await dbFile.exists()) {
        logger.d('Deleting existing database file for recreation');
        await dbFile.delete();
      }
    }

    return SqfliteQueryExecutor.inDatabaseFolder(
      path: file,
      logStatements: true, // 디버깅을 위해 SQL 문을 로깅
      singleInstance: true, // 단일 인스턴스 보장
    );
  });
}

extension ValueExtension<T> on T {
  Value<T> val() => Value<T>(this);
}

Value<T> empty<T>() => const Value.absent();
