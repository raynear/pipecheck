import 'package:boilerplate_cli/core/coverage.dart';
import 'package:test/test.dart';

void main() {
  // 손작성 1줄(lf2/lh1) + freezed 생성코드(lf100/lh0)가 섞인 lcov.
  const mixed = '''
SF:lib/features/payment/payment_view_model.dart
DA:1,1
DA:2,0
LF:2
LH:1
end_of_record
SF:lib/features/payment/payment_model.freezed.dart
LF:100
LH:0
end_of_record
SF:lib/features/home/home_view_model.dart
LF:10
LH:9
end_of_record
''';

  group('LcovReport.isGenerated', () {
    test('생성 코드 경로를 식별한다', () {
      expect(LcovReport.isGenerated('a/b.g.dart'), isTrue);
      expect(LcovReport.isGenerated('a/b.freezed.dart'), isTrue);
      expect(LcovReport.isGenerated('a/b.drift.dart'), isTrue);
      expect(LcovReport.isGenerated('lib/generated/x.dart'), isTrue);
      expect(LcovReport.isGenerated('a/table_generator/x.dart'), isTrue);
    });

    test('손작성 경로는 생성 코드가 아니다', () {
      expect(LcovReport.isGenerated('lib/features/payment/payment_model.dart'),
          isFalse);
    });
  });

  group('LcovReport.parse + global', () {
    test('생성 코드를 제외하고 전역 커버리지를 계산한다', () {
      final report = LcovReport.parse(mixed);
      // 손작성: payment_vm(2/1) + home_vm(10/9) = lf12/lh10 = 83%.
      // freezed 섹션(lf100/lh0)이 분모에서 빠졌다는 증거 (포함 시 ≈9%로 추락).
      expect(report.globalCoverage(), closeTo(83.3, 0.5));
    });
  });

  group('LcovReport.featureCoverage', () {
    test('변경 기능의 손작성 라인만으로 커버리지를 낸다', () {
      final report = LcovReport.parse(mixed);
      // payment 손작성: 2/1 = 50% (freezed 제외, home 무관)
      expect(report.featureCoverage('payment'), closeTo(50.0, 0.1));
    });

    test('다른 기능은 섞이지 않는다', () {
      final report = LcovReport.parse(mixed);
      expect(report.featureCoverage('home'), closeTo(90.0, 0.1));
    });

    test('커버 가능한 손작성 라인이 없으면 null', () {
      final report = LcovReport.parse(mixed);
      expect(report.featureCoverage('nonexistent'), isNull);
    });

    test('경계값을 round 없이 정확한 double로 반환한다 (CI 절단과 동일 판정)', () {
      const lcov = 'SF:lib/features/x/x.dart\nLF:1255\nLH:1003\nend_of_record\n';
      final pct = LcovReport.parse(lcov).featureCoverage('x')!;
      // 79.92% — round(.round=80, 통과)이 아니라 pct<80(FAIL)이어야 CI(절단 79)와 일치
      expect(pct, closeTo(79.92, 0.01));
      expect(pct < 80, isTrue);
    });

    test('마지막 레코드에 end_of_record가 없어도 집계한다 (awk와 동일)', () {
      const lcov = 'SF:lib/features/x/x.dart\nLF:10\nLH:5';
      expect(LcovReport.parse(lcov).featureCoverage('x'), closeTo(50.0, 0.1));
    });
  });
}
