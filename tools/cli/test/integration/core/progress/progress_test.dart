import 'dart:io';

import 'package:test/test.dart';

/// 성능 최적화 기능 통합 테스트.
///
/// 실제 파일 시스템을 사용하여 ProgressIndicator 동작을 테스트합니다.
void main() {
  final cliPath = Directory.current.path;

  group('Performance Optimization Integration', () {
    group('ProgressIndicator class', () {
      test('ProgressIndicator class is exported', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final output = StringBuffer();
  final indicator = ProgressIndicator(
    message: '테스트 작업',
    total: 10,
    output: output,
  );
  print('INDICATOR_CREATED');
  print('MESSAGE: \${indicator.message}');
  print('TOTAL: \${indicator.total}');
}
''';
        final tempFile = File('$cliPath/test_progress_export_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('INDICATOR_CREATED'));
          expect(result.stdout.toString(), contains('MESSAGE: 테스트 작업'));
          expect(result.stdout.toString(), contains('TOTAL: 10'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('StepProgress class is exported', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final output = StringBuffer();
  final progress = StepProgress(
    steps: ['단계 1', '단계 2', '단계 3'],
    output: output,
  );
  print('STEP_PROGRESS_CREATED');
  print('STEPS_COUNT: \${progress.steps.length}');
}
''';
        final tempFile = File('$cliPath/test_step_progress_export_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('STEP_PROGRESS_CREATED'));
          expect(result.stdout.toString(), contains('STEPS_COUNT: 3'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });
  });
}
