import 'package:pipecheck/data/datasources/database_datasource.dart';
import 'package:pipecheck/data/datasources/local/database/drift_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 데이터베이스 Provider (일반화된 인터페이스)
///
/// local-only Drift가 공식 기본 (docs/MODULES.md §1-4). 원격 구현이
/// 필요하면 DatabaseDataSource 구현체를 만들어 여기서 교체.
final databaseProvider = Provider<DatabaseDataSource>((ref) {
  return DriftDatabase();
});

/// 초기화 Provider
/// 앱 시작 시 모든 데이터 소스를 초기화합니다
final dataSourceInitializerProvider = FutureProvider<void>((ref) async {
  final database = ref.read(databaseProvider);
  await database.initialize();
});
