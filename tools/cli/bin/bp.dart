import 'dart:io';

import 'package:boilerplate_cli/core/bootstrap.dart';
import 'package:boilerplate_cli/core/cli_registry.dart';

/// 통합 CLI 진입점 (P1-10).
///
/// 템플릿 안에서는 루트 ./run이 이 파일을 path로 실행하고,
/// 파생 앱에서는 pub global activate로 `bp` 실행파일이 된다:
/// ```bash
/// dart pub global activate --source git \
///   --git-url https://github.com/raynear/boiler_plate.git \
///   --git-path tools/cli --git-ref <project.yaml tooling.cli_ref>
/// bp init
/// ```
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty ||
      arguments.first == '-h' ||
      arguments.first == '--help') {
    stdout.write(cliUsage);
    exit(0);
  }

  final name = arguments.first;
  final rest = arguments.sublist(1);
  // 글로벌 bp가 서브디렉토리에서 실행돼도 루트 기준으로 동작 (상향 탐색)
  final projectRoot = findProjectRoot();

  // 별도 패키지 위임
  if (name == 'feature') {
    exit(await runFeatureCli(projectRoot, rest));
  }

  final runner = commandRunners[name];
  if (runner == null) {
    stderr.writeln('Unknown command: $name');
    stderr.writeln("Run './run --help' for usage.");
    // 구 셸 ./run은 exit 1 — sysexits EX_USAGE(64)로 의도적 변경 (P1-10)
    exit(64);
  }

  if (fastlaneRequiringCommands.contains(name)) {
    await ensureFastlane(projectRoot);
  }

  exit(await runner(projectRoot, rest));
}
