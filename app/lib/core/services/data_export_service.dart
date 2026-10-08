import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pipecheck/core/services/restore_service.dart' show blobKey;
import 'package:pipecheck/data/core/repositories/repository_providers.dart';
import 'package:pipecheck/data/datasources/local/database/database.dart';
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
    this.schemaVersion,
  });

  /// 내보내는 DB의 스키마 버전 — 문서에 `schemaVersion`으로 기록해, 복원이 더 새
  /// 스키마의 백업을 거부할 수 있게 한다. null이면 기록하지 않는다.
  final int? schemaVersion;

  /// 내보낼 테이블 이름 목록.
  final List<String> Function() listTables;

  /// 테이블 이름 → 전체 행(列맵 리스트).
  final Future<List<Map<String, dynamic>>> Function(String table) readTable;

  /// 모든 테이블을 들여쓰기된 JSON 문자열로 직렬화한다.
  ///
  /// SQLite 원시 값(int/real/text/null)은 JSON-안전하다. BLOB(`Uint8List`)은
  /// `{"$base64": "..."}`로 감싸 복원이 바이트 그대로 되돌릴 수 있게 하고,
  /// 그 밖의 비표준 타입(DateTime 등)은 [_toEncodable]로 변환한다.
  Future<String> buildExportJson({DateTime? exportedAt}) async {
    final tables = <String, dynamic>{};
    for (final name in listTables()) {
      tables[name] = [
        for (final row in await readTable(name)) _encodeBlobs(row),
      ];
    }
    final doc = <String, dynamic>{
      'schema': 'local-drift',
      'schemaVersion': ?schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'tables': tables,
    };
    return JsonEncoder.withIndent('  ', _toEncodable).convert(doc);
  }

  /// JSON을 임시 디렉토리에 파일로 써서 경로를 반환한다.
  /// [timestamp]는 파일명에 쓰인다(테스트 결정성을 위해 주입 가능).
  ///
  /// DB 전체 사본이라 개인 데이터다 — 쓰기 전에 **이전 내보내기 파일을 지운다**
  /// (공유 시트가 끝난 뒤를 호출부가 알려 주지 않으므로, 사본이 임시 폴더에
  /// 쌓이지 않게 하는 지점이 여기다). 남는 건 가장 최근 1개뿐이다.
  Future<String> exportToFile({DateTime? timestamp}) async {
    final stamp = (timestamp ?? DateTime.now()).toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final json = await buildExportJson(exportedAt: timestamp);
    final dir = await getTemporaryDirectory();
    await _purgeStaleExports(dir);
    final file = File('${dir.path}/data-export-$stamp.json');
    await file.writeAsString(json);
    logger.d('DataExportService: wrote ${file.path}');
    return file.path;
  }

  /// 내보내기 사본을 만들어 [share]에 넘기고, 공유 성공·실패와 무관하게 사본을 지운다
  /// (DB 전체 사본이라 개인 데이터다. share_plus는 자체 캐시로 복사해 보낸다).
  Future<void> exportAndShare(Future<void> Function(String path) share) async {
    final path = await exportToFile();
    try {
      await share(path);
    } finally {
      await deleteExportFile(path);
    }
  }

  /// 내보내기 사본 하나를 지운다. 이미 없거나 지울 수 없어도 던지지 않는다.
  static Future<void> deleteExportFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (err) {
      logger.w('DataExportService: could not delete $path: $err');
    }
  }

  static final _exportName = RegExp(r'^data-export-.*\.json$');

  static Future<void> _purgeStaleExports(Directory dir) async {
    await for (final e in dir.list()) {
      if (e is File && _exportName.hasMatch(e.uri.pathSegments.last)) {
        try {
          await e.delete();
        } on FileSystemException catch (err) {
          logger.w('DataExportService: could not delete ${e.path}: $err');
        }
      }
    }
  }

  static Map<String, dynamic> _encodeBlobs(Map<String, dynamic> row) => {
    for (final e in row.entries)
      e.key: e.value is Uint8List
          ? {blobKey: base64Encode(e.value as Uint8List)}
          : e.value,
  };

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
    schemaVersion: appSchemaVersion,
  );
});
