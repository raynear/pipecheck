// drift 생성 파일에서 레지스트리 조회 키 추출 테스트.
//
// 회귀: 레지스트리 키는 반드시 런타임 조회(`_tableRegistry[tableName.toLowerCase()]`,
// drift_database._getTable)와 같아야 한다. 과거엔 클래스명(`$PostTags`)에서 키를
// 재유도했는데, 다단어·약어·비-snake 어노테이션명에서 어긋나 'Unknown table'
// 크래시를 냈다. 이제 drift 파일이 심는 `String get tableName => '...'` 리터럴을
// 읽어 `_getTable`과 동일하게 소문자 정규화한다 — repository `_tableName`과 같은
// 문자열이라 재유도 없이 정확하다.

import 'package:pipecheck/data/table_generator/table_name_util.dart';
import 'package:flutter_test/flutter_test.dart';

// drift_table_generator가 실제로 심는 형태의 최소 파일 조각.
String driftSource(String className, String tableName) => '''
class \$$className extends Table with TableWithTimestamps {
  @override
  String get tableName => '$tableName';
  // ...컬럼 정의...
}
''';

void main() {
  group('registryKeyFromDriftSource — 런타임 조회 키 추출', () {
    test('다단어 테이블명 (핵심 회귀)', () {
      expect(registryKeyFromDriftSource(driftSource('PostTags', 'post_tags')),
          'post_tags');
      expect(registryKeyFromDriftSource(driftSource('PrayerLog', 'prayer_log')),
          'prayer_log');
    });

    test('단일어', () {
      expect(registryKeyFromDriftSource(driftSource('User', 'user')), 'user');
    });

    test('약어 등 재유도로는 못 맞출 리터럴도 정확', () {
      // 클래스명 재유도(camel-경계 분리)는 \$ApiKey→api_key처럼 어긋나지만,
      // 리터럴을 읽으면 생성기가 실제로 쓴 값 그대로 — 이것이 이 방식의 요점.
      expect(registryKeyFromDriftSource(driftSource('ApiKey', 'a_p_i_key')),
          'a_p_i_key');
    });

    test('대소문자 섞인 커스텀 어노테이션명 → 소문자 정규화 (런타임 일치)', () {
      // _getTable은 tableName.toLowerCase()로 조회하므로 키도 소문자여야 한다.
      // 원시 리터럴 'fooBar'를 그대로 등록하면 런타임 'foobar' 조회와 어긋나 크래시.
      expect(registryKeyFromDriftSource(driftSource('FooBar', 'fooBar')),
          'foobar');
    });

    test('공백/따옴표 변형 허용', () {
      expect(registryKeyFromDriftSource("String get tableName=>'sessions';"),
          'sessions');
      expect(registryKeyFromDriftSource('String get tableName => "badges";'),
          'badges');
    });

    test('리터럴이 없으면 null (조용히 잘못된 키를 등록하지 않음)', () {
      expect(registryKeyFromDriftSource('class \$X extends Table {}'), isNull);
      expect(registryKeyFromDriftSource(''), isNull);
    });
  });
}
