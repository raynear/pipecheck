import 'package:test/test.dart';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  group('ProgressIndicator', () {
    group('constructor', () {
      test('creates instance with message', () {
        final indicator = ProgressIndicator(message: '처리 중');
        expect(indicator.message, equals('처리 중'));
        expect(indicator.total, equals(0));
      });

      test('creates instance with message and total', () {
        final indicator = ProgressIndicator(message: '처리 중', total: 10);
        expect(indicator.message, equals('처리 중'));
        expect(indicator.total, equals(10));
      });
    });

    group('start', () {
      test('outputs status message', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '파일 처리',
          output: output,
        );

        indicator.start();
        expect(output.toString(), contains('파일 처리'));
      });

      test('can be called multiple times without error', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '처리 중',
          output: output,
        );

        indicator.start();
        indicator.start(); // 중복 호출
        // 에러 없이 완료되어야 함
      });
    });

    group('update', () {
      test('outputs progress bar', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '처리 중',
          total: 10,
          output: output,
        );

        indicator.start();
        indicator.update(5);

        expect(output.toString(), contains('50%'));
        expect(output.toString(), contains('5/10'));
      });

      test('does nothing when not running', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '처리 중',
          total: 10,
          output: output,
        );

        indicator.update(5);
        // 시작 전에는 출력 없음
      });
    });

    group('tick', () {
      test('increments progress', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '처리 중',
          total: 10,
          output: output,
        );

        indicator.start();
        indicator.tick();
        indicator.tick();

        expect(output.toString(), contains('2/10'));
      });

      test('accepts custom message', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '처리 중',
          total: 5,
          output: output,
        );

        indicator.start();
        indicator.tick('파일 1 처리');

        expect(output.toString(), contains('파일 1 처리'));
      });
    });

    group('complete', () {
      test('outputs success message', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '빌드',
          output: output,
        );

        indicator.start();
        indicator.complete();

        expect(output.toString(), contains('✅'));
        expect(output.toString(), contains('빌드 완료'));
      });

      test('accepts custom completion message', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '빌드',
          output: output,
        );

        indicator.start();
        indicator.complete('모든 작업');

        expect(output.toString(), contains('✅'));
        expect(output.toString(), contains('모든 작업 완료'));
      });
    });

    group('fail', () {
      test('outputs error message', () {
        final output = StringBuffer();
        final indicator = ProgressIndicator(
          message: '빌드',
          output: output,
        );

        indicator.start();
        indicator.fail('컴파일 오류');

        expect(output.toString(), contains('❌'));
        expect(output.toString(), contains('빌드 실패'));
        expect(output.toString(), contains('컴파일 오류'));
      });
    });
  });

  group('StepProgress', () {
    group('constructor', () {
      test('creates instance with steps', () {
        final steps = ['단계 1', '단계 2', '단계 3'];
        final progress = StepProgress(steps: steps);
        expect(progress.steps, equals(steps));
      });
    });

    group('nextStep', () {
      test('outputs step information', () {
        final output = StringBuffer();
        final progress = StepProgress(
          steps: ['의존성 설치', '코드 생성'],
          output: output,
        );

        progress.nextStep();
        expect(output.toString(), contains('[1/2]'));
        expect(output.toString(), contains('의존성 설치'));
      });

      test('accepts custom message', () {
        final output = StringBuffer();
        final progress = StepProgress(
          steps: ['의존성 설치'],
          output: output,
        );

        progress.nextStep('커스텀 메시지');
        expect(output.toString(), contains('커스텀 메시지'));
      });

      test('handles overflow gracefully', () {
        final output = StringBuffer();
        final progress = StepProgress(
          steps: ['단계 1'],
          output: output,
        );

        progress.nextStep();
        progress.nextStep(); // 범위 초과
        // 에러 없이 완료
      });
    });

    group('completeStep', () {
      test('outputs completion message with checkmark', () {
        final output = StringBuffer();
        final progress = StepProgress(
          steps: ['테스트 실행'],
          output: output,
        );

        progress.nextStep();
        progress.completeStep();

        expect(output.toString(), contains('✅'));
        expect(output.toString(), contains('테스트 실행 완료'));
      });
    });

    group('failStep', () {
      test('outputs failure message with error', () {
        final output = StringBuffer();
        final progress = StepProgress(
          steps: ['빌드'],
          output: output,
        );

        progress.nextStep();
        progress.failStep('컴파일 실패');

        expect(output.toString(), contains('❌'));
        expect(output.toString(), contains('빌드 실패'));
        expect(output.toString(), contains('컴파일 실패'));
      });
    });

    group('complete', () {
      test('outputs final completion message', () {
        final output = StringBuffer();
        final progress = StepProgress(
          steps: ['단계 1', '단계 2'],
          output: output,
        );

        progress.complete();
        expect(output.toString(), contains('✅'));
        expect(output.toString(), contains('모든 단계가 완료되었습니다'));
      });
    });
  });
}
