/// drift 생성 파일에서 **레지스트리 조회 키**를 뽑는다.
///
/// **키는 repository의 `_tableName`을 통한 런타임 조회와 반드시 일치해야 한다.**
/// DatabaseDataSource(`_getTable`)는 `_tableRegistry[tableName.toLowerCase()]`로
/// 조회한다. 키를 클래스명(`$PostTags`)에서 **재유도**하면 다단어·약어·비-snake
/// 어노테이션 테이블명에서 어긋나 첫 쿼리에서 'Unknown table' 크래시가 난다.
///
/// 재유도 대신, 생성기가 두 곳에 **같은 `tableName` 문자열**을 심는 사실을 이용한다:
/// repository는 `static const String _tableName = '<name>'`(repository_generator),
/// drift 파일은 `String get tableName => '<name>'`(drift_table_generator). 이 리터럴을
/// 읽어 `_getTable`과 동일하게 `toLowerCase()`로 정규화하면 조회 키와 정확히 일치한다
/// (기본 경로 snake_case는 이미 소문자라 정규화가 무연산 — 대소문자 섞인 커스텀
/// 어노테이션명에서만 실질 효과).
library;

// `String get tableName => '<name>'` (또는 "..."). 여는/닫는 따옴표를 역참조로 맞춘다.
final _tableNameLiteral =
    RegExp(r'''String\s+get\s+tableName\s*=>\s*(['"])([^'"]+)\1''');

/// drift 생성 파일 내용에서 레지스트리 조회 키(`get tableName` 리터럴을 소문자화)를 뽑는다.
///
/// 생성기가 무조건 심으므로(단일 테이블/파일) 정상 파일에선 항상 매칭된다.
/// 없으면 null(호출자가 경고하고 건너뛴다) — 조용히 잘못된 키를 등록하지 않는다.
String? registryKeyFromDriftSource(String content) =>
    _tableNameLiteral.firstMatch(content)?.group(2)?.toLowerCase();
