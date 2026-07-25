// init 결과 요약 로직 테스트 — soft-skip 은폐 제거 (StepResult/InitSummary).

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:test/test.dart';

void main() {
  group('StepResult', () {
    test('done은 ok=true, incomplete가 아님', () {
      const r = StepResult.done();
      expect(r.status, StepStatus.done);
      expect(r.ok, isTrue);
    });

    test('skipped/failed는 사유를 담고 ok=false', () {
      final s = StepResult.skipped('adlab 서버 미실행');
      final f = StepResult.failed('ASC API 키 없음');
      expect(s.status, StepStatus.skipped);
      expect(s.reason, 'adlab 서버 미실행');
      expect(s.ok, isFalse);
      expect(f.status, StepStatus.failed);
      expect(f.ok, isFalse);
    });
  });

  group('InitSummary', () {
    test('전부 done이면 allDone=true, incomplete 없음', () {
      final sum = InitSummary()
        ..add('코드 서명 설정', const StepResult.done())
        ..add('앱 아이콘 생성', const StepResult.done());
      expect(sum.allDone, isTrue);
      expect(sum.incomplete, isEmpty);
    });

    test('skip/fail가 있으면 allDone=false, incomplete에 수집', () {
      final sum = InitSummary()
        ..add('코드 서명 설정', const StepResult.done())
        ..add('앱 아이콘 생성', StepResult.skipped('adlab 서버 미실행'))
        ..add('스토어 앱 등록', StepResult.failed('ASC API 키 없음'));
      expect(sum.allDone, isFalse);
      expect(sum.incomplete.length, 2);
      expect(sum.incomplete.map((e) => e.step),
          containsAll(['앱 아이콘 생성', '스토어 앱 등록']));
    });

    test('render는 미완 스텝의 이름과 사유를 담는다', () {
      final sum = InitSummary()
        ..add('앱 아이콘 생성', StepResult.skipped('adlab 서버 미실행'))
        ..add('스토어 앱 등록', StepResult.failed('ASC API 키 없음'));
      final out = sum.render();
      expect(out, contains('앱 아이콘 생성'));
      expect(out, contains('adlab 서버 미실행'));
      expect(out, contains('스토어 앱 등록'));
      expect(out, contains('ASC API 키 없음'));
    });

    test('render는 failed=✗ / skipped=⊘ 마크를 구분하고 카운트를 찍는다', () {
      final sum = InitSummary()
        ..add('앱 아이콘 생성', StepResult.skipped('adlab 서버 미실행'))
        ..add('스토어 앱 등록', StepResult.failed('ASC API 키 없음'));
      final out = sum.render();
      expect(out, contains('2개 스텝이 완료되지 않았습니다'));
      expect(out, contains('⊘ 앱 아이콘 생성'));
      expect(out, contains('✗ 스토어 앱 등록'));
    });

    test('전부 done이면 render는 빈 문자열', () {
      final sum = InitSummary()..add('코드 서명 설정', const StepResult.done());
      expect(sum.render(), isEmpty);
    });
  });

  group('renderInitOutcome', () {
    InitSummary summaryWith(List<(String, StepResult)> rows) {
      final sum = InitSummary();
      for (final (step, r) in rows) {
        sum.add(step, r);
      }
      return sum;
    }

    test('정상 완료: "완료!" 헤더 + 다음 단계 안내', () {
      final out = renderInitOutcome(
        summary: summaryWith([('코드 서명 설정', const StepResult.done())]),
        appName: 'My App',
        packageName: 'com.acme.myapp',
        profile: 'standard',
      );
      expect(out, contains('프로젝트 초기화 완료!'));
      expect(out, contains('My App (com.acme.myapp)'));
      expect(out, contains('다음 단계'));
      expect(out, isNot(contains('중단')));
    });

    test('일부 미완(soft-skip): "일부 스텝 미완" + 미완 요약 + 다음 단계', () {
      final out = renderInitOutcome(
        summary: summaryWith([
          ('코드 서명 설정', const StepResult.done()),
          ('스토어 앱 등록', StepResult.skipped('ASC API 키 없음')),
        ]),
        appName: 'My App',
        packageName: 'com.acme.myapp',
        profile: 'standard',
      );
      expect(out, contains('일부 스텝 미완'));
      expect(out, contains('스토어 앱 등록'));
      expect(out, contains('ASC API 키 없음'));
      expect(out, contains('다음 단계'));
    });

    test('hard-fail: 중단 헤더 + 실패 스텝 요약 + 다음 단계 없음', () {
      // hard-fail 경로: 그때까지의 성공/미완 + 실패 스텝을 요약에 담아 넘긴다.
      final out = renderInitOutcome(
        summary: summaryWith([
          ('app_config.yaml 로드', const StepResult.done()),
          ('패키지명 설정', StepResult.failed('패키지명 변경 실패')),
        ]),
        appName: 'My App',
        packageName: 'com.acme.myapp',
        profile: 'standard',
        hardFailStep: '패키지명 설정',
      );
      expect(out, contains('중단'));
      expect(out, contains('패키지명 설정'));
      expect(out, contains('패키지명 변경 실패'));
      // 성공 안내(다음 단계)는 hard-fail에서 찍지 않는다.
      expect(out, isNot(contains('다음 단계')));
      expect(out, isNot(contains('초기화 완료')));
    });
  });
}
