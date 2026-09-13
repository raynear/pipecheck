// 생성된 Drift 스키마를 **진짜 SQLite에 올려서** 검증한다.
//
// 왜 산출물 문자열 검사로는 부족한가: 이 결함들은 `flutter analyze`도
// 기존 테스트 스위트도 통과한다.
//  ① `gen_random_uuid()`는 Postgres 함수다. SQLite는 `CREATE TABLE`은
//     받아 주고 **INSERT의 prepare 단계에서** `unknown function`으로 죽는다.
//  ② `abs(random())%4`는 `random()`이 `-9223372036854775808`을 낼 때
//     `integer overflow`로 INSERT를 죽인다(2^-64 — 테스트로는 못 잡는다).
// 둘 다 `CREATE TABLE`을 통과시키므로 스키마는 멀쩡해 보인다.
// 그래서 이 게이트는 스키마를 만들고 **id를 생략한 채 실제로 INSERT 한다**.
//
// 기존 테스트가 이걸 못 잡은 이유: 전부 id를 직접 넣어서 DEFAULT 식을
// 한 번도 실행하지 않는다.
import 'package:pipecheck/data/datasources/local/database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('스키마가 비어 있지 않다', () {
    // 양성 대조군. 스키마가 비면 아래 INSERT 테스트는 `no such table: user`로
    // 죽는데, 그 메시지는 uuid 기본값 결함과 구분이 안 된다 — 원인을 갈라 준다.
    expect(
      db.allSchemaEntities,
      isNotEmpty,
      reason: 'database.g.dart가 빈 껍데기다. ./build 2차 패스를 확인하라',
    );
    expect(db.allTables.map((t) => t.actualTableName), contains('user'));
  });

  test('uuid 기본키를 생략한 INSERT가 실제 SQLite에서 통과한다', () async {
    await db.into(db.$User).insert($UserCompanion.insert(email: 'a@b.c'));

    final rows = await db.select(db.$User).get();
    expect(rows, hasLength(1));
    // UUID v4 문자열 형식. 값은 **SQL DEFAULT 식**이 채운다 —
    // Dart쪽 `clientDefault`는 drift가 표현식 소스를 database.g.dart(part)로
    // 복사하는 탓에 `Not a constant expression`이 되어 기각했다. 되돌리지 말 것.
    expect(
      rows.single.id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
      reason: 'gen_random_uuid() 같은 비-SQLite 기본값이 남아 있다',
    );
  });

  test('uuid 기본값이 **모든** 테이블에 같게 들어간다', () async {
    // 위 INSERT 테스트는 한 테이블만 친다 — 뮤테이션으로 확인했다: 나머지
    // uuid 테이블을 전부 `gen_random_uuid()`로 되돌려도 게이트가 초록이었다.
    // 생성기는 테이블마다 같은 상수를 쓰지만 이 게이트가 재는 대상은 생성기가
    // 아니라 **앱마다 재생성되는 산출물** database.g.dart다. 그래서 런타임 DDL
    // 전수를 읽어 청구한다.
    final ddl = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type = 'table'"
          " AND sql IS NOT NULL",
        )
        .get();
    expect(ddl, isNotEmpty, reason: '스키마에 테이블이 하나도 없다');

    String sqlOf(QueryRow r) => r.read<String>('sql');
    String nameOf(QueryRow r) => r.read<String>('name');

    // Postgres 함수는 어느 테이블에도 있으면 안 된다.
    expect(
      ddl.where((r) => sqlOf(r).contains('gen_random_uuid')).map(nameOf),
      isEmpty,
      reason: 'SQLite에 없는 gen_random_uuid()가 남은 테이블이 있다 — '
          'id를 생략한 INSERT가 그 테이블에서만 터진다',
    );

    // id 컬럼에 DEFAULT가 걸린 테이블은 전부 SQLite v4 식이어야 한다.
    final withIdDefault = ddl
        .where(
          (r) => RegExp(
            r'\bid\b[^,]*DEFAULT',
            caseSensitive: false,
          ).hasMatch(sqlOf(r)),
        )
        .toList();
    expect(
      withIdDefault,
      isNotEmpty,
      reason: '양성 대조군: id에 DEFAULT가 걸린 테이블이 하나도 없다면 '
          '생성기가 .withDefault()를 아예 안 붙인 것이다',
    );
    for (final r in withIdDefault) {
      expect(
        sqlOf(r),
        contains('randomblob'),
        reason: '${nameOf(r)}의 id DEFAULT가 SQLite v4 식이 아니다',
      );
    }
  });

  test('같은 행을 두 번 넣으면 서로 다른 id를 받는다', () async {
    await db.into(db.$User).insert($UserCompanion.insert(email: 'a@b.c'));
    await db.into(db.$User).insert($UserCompanion.insert(email: 'a@b.c'));

    final ids = (await db.select(db.$User).get()).map((r) => r.id).toSet();
    expect(ids, hasLength(2), reason: 'id 기본값이 상수라 기본키가 충돌한다');
  });
}
