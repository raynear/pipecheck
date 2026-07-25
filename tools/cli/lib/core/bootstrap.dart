import 'dart:io';

/// 런처 부트스트랩 (P1-10) — 기존 셸 ./run의 ensure_fastlane/ensure_dart_deps를
/// Dart로 이전. 셸 런처는 tools/cli pub get + bp.dart exec만 남긴다.

/// fastlane/ 확보. 이 repo는 fastlane을 git submodule로 둔다(.gitmodules):
/// 등록돼 있으면 `git submodule update --init`로 핀된 커밋을 체크아웃하고,
/// submodule이 없는(복사 기반 파생 앱 등) 컨텍스트에선 project.yaml
/// tooling.fastlane_ref 핀으로 클론한다. URL은 FASTLANE_REPO로 오버라이드 가능.
Future<void> ensureFastlane(String projectRoot) async {
  // Fastfile 존재 = 이미 확보. submodule 미초기화 시 빈 디렉토리일 수 있어
  // 디렉토리 존재만으론 부족하다.
  if (File('$projectRoot/fastlane/Fastfile').existsSync()) {
    return;
  }

  // 1) submodule로 등록돼 있으면 핀된 커밋으로 초기화.
  final gitmodules = File('$projectRoot/.gitmodules');
  if (gitmodules.existsSync() &&
      gitmodules.readAsStringSync().contains('path = fastlane')) {
    stdout.writeln('[bp] fastlane submodule 초기화 (git submodule update --init)');
    final sm = await Process.run(
      'git',
      ['submodule', 'update', '--init', '--recursive', 'fastlane'],
      workingDirectory: projectRoot,
    );
    if (sm.exitCode == 0 &&
        File('$projectRoot/fastlane/Fastfile').existsSync()) {
      return;
    }
    stderr.writeln(sm.stderr.toString());
    // 초기화 실패 시 아래 클론 폴백.
  }

  // 2) 폴백: 핀 태그로 클론 (submodule 미사용 컨텍스트).
  final repo = Platform.environment['FASTLANE_REPO'] ??
      'https://github.com/raynear/flutter-fastlane.git';
  final ref = readFastlaneRef(projectRoot) ?? 'main';

  stdout.writeln('[bp] fastlane/ 부재 — $repo ($ref) 클론');
  final result = await Process.run(
    'git',
    ['clone', '--branch', ref, '--depth', '1', repo, 'fastlane'],
    workingDirectory: projectRoot,
  );
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr.toString());
    stderr.writeln(
        '[bp] fastlane 확보 실패. 프라이빗 repo 접근 권한을 확인하거나 '
        'FASTLANE_REPO로 URL을 지정하세요.');
    exit(1);
  }
}

/// project.yaml에서 tooling.fastlane_ref를 읽는다 (셸 grep과 동일한 보수적 파싱
/// — ConfigLoader 전체 로드 없이 핀 하나만 필요).
/// 콜론 뒤 공백은 [ \t]만 허용 — \s는 개행을 포함해 빈 값일 때
/// 다음 줄 토큰을 오캡처한다 (P1-10 리뷰 발견).
String? readFastlaneRef(String projectRoot) {
  final file = File('$projectRoot/project.yaml');
  if (!file.existsSync()) {
    return null;
  }
  final match =
      RegExp(r'^[ \t]*fastlane_ref:[ \t]*"?([^"#\s]+)', multiLine: true)
          .firstMatch(file.readAsStringSync());
  return match?.group(1);
}

/// cwd부터 상향 탐색으로 project.yaml이 있는 디렉토리를 프로젝트 루트로 결정.
/// 글로벌 `bp`를 서브디렉토리(app/ 등)에서 실행해도 fastlane 클론·설정 로드가
/// 루트를 향하도록 한다. 못 찾으면 cwd 반환 (기존 ./run 동작 보존).
String findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/project.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current.path;
    }
    dir = parent;
  }
}

/// 별도 패키지(tools/feature_cli)로 위임 — pub get 가드 후 inheritStdio 실행.
Future<int> runFeatureCli(String projectRoot, List<String> args) async {
  final dir = '$projectRoot/tools/feature_cli';
  if (!Directory(dir).existsSync()) {
    stderr.writeln('[bp] $dir 부재 — feature CLI를 사용할 수 없습니다.');
    return 1;
  }
  await _ensureDartDeps(dir);
  final process = await Process.start(
    'dart',
    ['run', '$dir/bin/feature.dart', ...args],
    workingDirectory: projectRoot,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

Future<void> _ensureDartDeps(String dir) async {
  final marker = File('$dir/.dart_tool/package_config.json');
  final pubspec = File('$dir/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('[bp] $dir에 pubspec.yaml이 없습니다.');
    exit(1);
  }
  final stale = !marker.existsSync() ||
      pubspec.lastModifiedSync().isAfter(marker.lastModifiedSync());
  if (stale) {
    stdout.writeln('[bp] $dir 의존성 설치 (dart pub get)');
    final result =
        await Process.run('dart', ['pub', 'get'], workingDirectory: dir);
    if (result.exitCode != 0) {
      stderr.writeln(result.stderr.toString());
      exit(1);
    }
  }
}
