// Google Play Data Safety CSV 렌더러 테스트.
//
// 골든/subset 검증: renderPlayCsv가 내보내는 모든 (Question ID, Response ID) 쌍이
// 실물 Play Console export 샘플(fixtures/fairemail_data_safety_export.csv)의
// ID 우주에 속하는지 대조한다 — 없는 ID를 지어내지 않음을 증명.

import 'dart:io';

import 'package:boilerplate_cli/commands/datasafety/data_safety_generator.dart';
import 'package:test/test.dart';

const _header =
    'Question ID (machine readable),Response ID (machine readable),'
    'Response value,Answer requirement,Human-friendly question label';

/// 실물 export 샘플에서 (col1, col2) ID 쌍의 우주를 읽어온다.
Set<String> _realExportIdUniverse() {
  final candidates = [
    'test/unit/datasafety/fixtures/fairemail_data_safety_export.csv',
    'tools/cli/test/unit/datasafety/fixtures/fairemail_data_safety_export.csv',
  ];
  final file =
      candidates.map(File.new).firstWhere((f) => f.existsSync(), orElse: () {
    throw StateError('fixture 샘플 CSV를 찾을 수 없음: $candidates');
  });
  final lines = file.readAsLinesSync().skip(1); // 헤더 제외
  final ids = <String>{};
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final cols = _parseCsvLine(line);
    if (cols.isEmpty) continue;
    final q = cols[0];
    final r = cols.length > 1 ? cols[1] : '';
    ids.add('$q|$r');
  }
  return ids;
}

/// 최소 CSV 라인 파서 (따옴표 필드 지원) — 앞 2개 컬럼만 필요.
List<String> _parseCsvLine(String line) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        sb.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  out.add(sb.toString());
  return out;
}

/// 렌더된 CSV에서 (q,r,value) 튜플 목록을 파싱한다.
List<List<String>> _rows(String csv) => csv
    .split('\n')
    .where((l) => l.trim().isNotEmpty)
    .skip(1) // 헤더
    .map(_parseCsvLine)
    .toList();

/// (questionId, responseId)로 Response value를 찾는다.
String? _valueOf(String csv, String q, String r) {
  for (final cols in _rows(csv)) {
    if (cols.length >= 3 && cols[0] == q && cols[1] == r) return cols[2];
  }
  return null;
}

DataSafetyInputs _inputs({
  bool ads = false,
  bool analytics = false,
  bool crash = false,
  bool email = false,
  bool subscription = false,
  bool notifications = false,
  bool location = false,
  bool accountDeletion = false,
}) =>
    DataSafetyInputs(
      adsEnabled: ads,
      analyticsEnabled: analytics,
      crashReportingEnabled: crash,
      emailAuthEnabled: email,
      subscriptionEnabled: subscription,
      notificationsEnabled: notifications,
      locationEnabled: location,
      accountDeletionEnabled: accountDeletion,
    );

void main() {
  group('renderPlayCsv', () {
    test('첫 줄은 Play Console export 헤더와 정확히 일치한다', () {
      final csv = renderPlayCsv(_inputs(analytics: true, crash: true));
      expect(csv.split('\n').first, _header);
    });

    test('내보내는 모든 ID 쌍이 실물 export 샘플 우주의 부분집합이다 (골든)', () {
      final universe = _realExportIdUniverse();
      // 모든 기능을 켜서 최대한 넓은 ID 표면을 만든다.
      final csv = renderPlayCsv(_inputs(
        ads: true,
        analytics: true,
        crash: true,
        email: true,
        subscription: true,
        notifications: true,
        location: true,
        accountDeletion: true,
      ));
      final emitted = _rows(csv)
          .map((c) => '${c[0]}|${c.length > 1 ? c[1] : ''}')
          .toSet();
      final unknown = emitted.difference(universe);
      expect(unknown, isEmpty,
          reason: '실물 export에 없는 ID를 지어냄: $unknown');
    });

    test('Response value 표기가 실물 export 어휘를 따른다 (골든)', () {
      // fixture 실측 어휘: 값 알파벳은 {true, false, ''} (소문자만, 대문자 없음).
      // choice형(MULTIPLE_CHOICE/SINGLE_CHOICE)은 미선택=빈값, false 금지.
      final csv = renderPlayCsv(_inputs(
        ads: true,
        analytics: true,
        crash: true,
        email: true,
        subscription: true,
        notifications: true,
        location: true,
        accountDeletion: true,
      ));
      for (final cols in _rows(csv)) {
        final value = cols[2];
        final requirement = cols[3];
        expect(value, isIn(['true', 'false', '']),
            reason: '실물 값 알파벳 밖: ${cols[0]},${cols[1]} = "$value"');
        if (requirement == 'MULTIPLE_CHOICE' || requirement == 'SINGLE_CHOICE') {
          expect(value, isIn(['true', '']),
              reason: 'choice형은 미선택=빈값 (false 금지): '
                  '${cols[0]},${cols[1]} = "$value"');
        }
      }
    });

    test('수집 데이터가 있으면 COLLECTS_PERSONAL_DATA=true', () {
      final csv = renderPlayCsv(_inputs(analytics: true));
      expect(_valueOf(csv, 'PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA', ''),
          'true');
    });

    test('수집 데이터가 없으면 COLLECTS_PERSONAL_DATA=false, 사용 블록 없음', () {
      final csv = renderPlayCsv(_inputs());
      expect(_valueOf(csv, 'PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA', ''),
          'false');
      expect(csv, isNot(contains('PSL_DATA_USAGE_RESPONSES')));
    });

    test('전 데이터 유형 스켈레톤: 수집=true, 미수집=빈값', () {
      final csv = renderPlayCsv(_inputs(analytics: true));
      // 수집: 앱 상호작용 + 기기 ID
      expect(_valueOf(csv, 'PSL_DATA_TYPES_APP_ACTIVITY', 'PSL_USER_INTERACTION'),
          'true');
      expect(_valueOf(csv, 'PSL_DATA_TYPES_IDENTIFIERS', 'PSL_DEVICE_ID'),
          'true');
      // 미수집 유형은 빈값 (실물 export 표기)
      expect(_valueOf(csv, 'PSL_DATA_TYPES_LOCATION', 'PSL_APPROX_LOCATION'),
          '');
      expect(_valueOf(csv, 'PSL_DATA_TYPES_PERSONAL', 'PSL_EMAIL'), '');
    });

    test('이메일 인증 → 이메일/유저ID 수집 + 계정관리 목적', () {
      final csv = renderPlayCsv(_inputs(email: true));
      expect(_valueOf(csv, 'PSL_DATA_TYPES_PERSONAL', 'PSL_EMAIL'), 'true');
      expect(_valueOf(csv, 'PSL_DATA_TYPES_PERSONAL', 'PSL_USER_ACCOUNT'),
          'true');
      expect(
          _valueOf(
              csv,
              'PSL_DATA_USAGE_RESPONSES:PSL_EMAIL:DATA_USAGE_COLLECTION_PURPOSE',
              'PSL_ACCOUNT_MANAGEMENT'),
          'true');
    });

    test('광고 → 기기ID가 수집+공유, 광고 목적, 공유 목적 행 존재', () {
      final csv = renderPlayCsv(_inputs(ads: true));
      expect(
          _valueOf(
              csv,
              'PSL_DATA_USAGE_RESPONSES:PSL_DEVICE_ID:PSL_DATA_USAGE_COLLECTION_AND_SHARING',
              'PSL_DATA_USAGE_ONLY_SHARED'),
          'true');
      expect(
          _valueOf(
              csv,
              'PSL_DATA_USAGE_RESPONSES:PSL_DEVICE_ID:DATA_USAGE_SHARING_PURPOSE',
              'PSL_ADVERTISING'),
          'true');
    });

    test('공유 안 하는 유형: ONLY_SHARED=빈값, 공유 목적 블록은 전부 빈값으로 존재', () {
      final csv = renderPlayCsv(_inputs(crash: true));
      expect(
          _valueOf(
              csv,
              'PSL_DATA_USAGE_RESPONSES:PSL_CRASH_LOGS:PSL_DATA_USAGE_COLLECTION_AND_SHARING',
              'PSL_DATA_USAGE_ONLY_SHARED'),
          '');
      // 실물 export는 미공유 타입에도 SHARING_PURPOSE 7행(전부 빈값)을 낸다.
      const sharingQ =
          'PSL_DATA_USAGE_RESPONSES:PSL_CRASH_LOGS:DATA_USAGE_SHARING_PURPOSE';
      final sharingRows =
          _rows(csv).where((c) => c[0] == sharingQ).toList();
      expect(sharingRows, hasLength(7));
      for (final r in sharingRows) {
        expect(r[2], '', reason: '미공유 타입의 공유 목적은 빈값: ${r[1]}');
      }
    });

    test('선택 수집(analytics) → OPTIONAL=true/REQUIRED=빈값, 필수 수집(notif)은 반대', () {
      final optCsv = renderPlayCsv(_inputs(analytics: true));
      const optQ =
          'PSL_DATA_USAGE_RESPONSES:PSL_USER_INTERACTION:DATA_USAGE_USER_CONTROL';
      expect(_valueOf(optCsv, optQ, 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL'),
          'true');
      expect(_valueOf(optCsv, optQ, 'PSL_DATA_USAGE_USER_CONTROL_REQUIRED'),
          '');

      final reqCsv = renderPlayCsv(_inputs(notifications: true));
      const reqQ =
          'PSL_DATA_USAGE_RESPONSES:PSL_DEVICE_ID:DATA_USAGE_USER_CONTROL';
      expect(_valueOf(reqCsv, reqQ, 'PSL_DATA_USAGE_USER_CONTROL_REQUIRED'),
          'true');
      expect(_valueOf(reqCsv, reqQ, 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL'),
          '');
    });

    test('기기ID는 여러 기능(ads+analytics+notif)이 합쳐 한 번만 선언된다', () {
      final csv = renderPlayCsv(
          _inputs(ads: true, analytics: true, notifications: true));
      final deviceIdDeclRows = _rows(csv).where((c) =>
          c[0] == 'PSL_DATA_TYPES_IDENTIFIERS' && c[1] == 'PSL_DEVICE_ID');
      expect(deviceIdDeclRows, hasLength(1));
      // 합쳐진 목적: 광고 + 분석 + 앱기능
      const purposeQ =
          'PSL_DATA_USAGE_RESPONSES:PSL_DEVICE_ID:DATA_USAGE_COLLECTION_PURPOSE';
      expect(_valueOf(csv, purposeQ, 'PSL_ADVERTISING'), 'true');
      expect(_valueOf(csv, purposeQ, 'PSL_ANALYTICS'), 'true');
      expect(_valueOf(csv, purposeQ, 'PSL_APP_FUNCTIONALITY'), 'true');
    });

    test('USER_REQUEST_DELETE는 accountDeletionEnabled를 반영한다', () {
      expect(
          _valueOf(renderPlayCsv(_inputs(email: true, accountDeletion: true)),
              'PSL_DATA_COLLECTION_USER_REQUEST_DELETE', ''),
          'true');
      expect(
          _valueOf(renderPlayCsv(_inputs(analytics: true)),
              'PSL_DATA_COLLECTION_USER_REQUEST_DELETE', ''),
          'false');
    });

    test('쉼표가 든 라벨은 따옴표로 이스케이프된다', () {
      // FRAUD_PREVENTION_SECURITY 라벨에 쉼표 포함 → 반드시 인용.
      final csv = renderPlayCsv(_inputs(analytics: true));
      expect(csv, contains('"'));
      // 파싱 후 컬럼 수가 정확히 5여야 함(따옴표 내 쉼표가 분리자로 새지 않음).
      for (final line in csv.split('\n').where((l) => l.trim().isNotEmpty)) {
        expect(_parseCsvLine(line), hasLength(5),
            reason: '컬럼 5개가 아님: $line');
      }
    });
  });
}
