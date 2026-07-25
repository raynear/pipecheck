import 'dart:convert';
import 'dart:io';

import 'package:pipecheck/data/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utils/utils.dart';

/// 로컬 데이터를 JSON으로 내보내는 서비스 (GDPR 데이터 이동권, P2-23f).
///
/// 모든 로컬 Drift 테이블을 한 JSON 문서로 직렬화한다. 서버 코드 0줄
/// (backend-direction) — 모든 데이터가 기기 로컬이므로 내보내기도 로컬에서
/// 완결된다. 공유는 [shareFile]를 받은 호출부(ShareService)가 담당한다.
///
/// DB 인터페이스에 직접 결합하지 않도록 두 능력만 주입받는다([listTables]·
/// [readTable]) — 테스트가 람다로 트리비얼하게 가짜 데이터를 줄 수 있다.
class DataExportService {
  DataExportService({
    required this.listTables,
    required this.readTable,
  });

  /// 내보낼 테이블 이름 목록.
  final List<String> Function() listTables;

  /// 테이블 이름 → 전체 행(列맵 리스트).
  final Future<List<Map<String, dynamic>>> Function(String table) readTable;

  /// 모든 테이블을 들여쓰기된 JSON 문자열로 직렬화한다.
  ///
  /// SQLite 원시 값(int/real/text/null)은 JSON-안전하지만, 혹시 모를
  /// 비표준 타입(DateTime/Uint8List 등)도 [_toEncodable]로 안전하게 변환한다.
  Future<String> buildExportJson({DateTime? exportedAt}) async {
    final tables = <String, dynamic>{};
    for (final name in listTables()) {
      tables[name] = await readTable(name);
    }
    final doc = <String, dynamic>{
      'schema': 'local-drift',
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'tables': tables,
    };
    return JsonEncoder.withIndent('  ', _toEncodable).convert(doc);
  }

  /// JSON을 임시 디렉토리에 파일로 써서 경로를 반환한다.
  /// [timestamp]는 파일명에 쓰인다(테스트 결정성을 위해 주입 가능).
  Future<String> exportToFile({DateTime? timestamp}) async {
    final stamp = (timestamp ?? DateTime.now())
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final json = await buildExportJson(exportedAt: timestamp);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/data-export-$stamp.json');
    await file.writeAsString(json);
    logger.d('DataExportService: wrote ${file.path}');
    return file.path;
  }

  static Object? _toEncodable(Object? value) {
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }
}

/// 앱 DB(로컬 Drift)에 배선된 DataExportService.
final dataExportServiceProvider = Provider<DataExportService>((ref) {
  final db = ref.watch(databaseProvider);
  return DataExportService(
    listTables: () => db.tableNames,
    readTable: (table) => db.findMany(table),
  );
});
