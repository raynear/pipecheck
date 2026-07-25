import 'package:args/args.dart';

import 'error_handler.dart';

/// CLI 명령어의 기본 추상 클래스.
///
/// 모든 CLI 명령어는 이 클래스를 상속받아 구현해야 합니다.
/// Command Pattern을 적용하여 일관된 인터페이스로 새 명령어를 쉽게 추가할 수 있습니다.
///
/// ## 사용 예시
/// ```dart
/// class MyCommand extends Command {
///   @override
///   String get name => 'my-command';
///
///   @override
///   String get description => '내 명령어 설명';
///
///   @override
///   ArgParser buildArgParser() {
///     return ArgParser()
///       ..addFlag('verbose', abbr: 'v', help: '자세한 출력');
///   }
///
///   @override
///   Future<int> execute(ArgResults args) async {
///     // 명령어 로직 구현
///     return 0; // 성공
///   }
/// }
/// ```
abstract class Command {
  /// 명령어 이름.
  ///
  /// CLI에서 사용되는 명령어의 이름입니다.
  /// 예: 'setup', 'rename', 'build'
  String get name;

  /// 명령어 설명.
  ///
  /// --help 옵션에서 표시되는 명령어의 설명입니다.
  String get description;

  /// 명령어 인자 파서를 빌드합니다.
  ///
  /// 명령어에서 사용할 플래그, 옵션, 인자 등을 정의합니다.
  /// [ArgParser]를 사용하여 CLI 인자를 파싱합니다.
  ///
  /// ## 예시
  /// ```dart
  /// ArgParser buildArgParser() {
  ///   return ArgParser()
  ///     ..addFlag('force', abbr: 'f', help: '강제 실행')
  ///     ..addOption('output', abbr: 'o', help: '출력 경로');
  /// }
  /// ```
  ArgParser buildArgParser();

  /// 명령어를 실행합니다.
  ///
  /// [args]는 파싱된 명령행 인자입니다.
  ///
  /// ## 반환 값
  /// - 0: 성공
  /// - 1 이상: 실패 (에러 코드)
  ///
  /// ## 예시
  /// ```dart
  /// Future<int> execute(ArgResults args) async {
  ///   final isVerbose = args['verbose'] as bool;
  ///   // ... 명령어 로직
  ///   return 0;
  /// }
  /// ```
  Future<int> execute(ArgResults args);

  /// --help 옵션 처리를 위한 도움말 메시지를 생성합니다.
  String get usage {
    final parser = buildArgParser();
    return '''
$description

Usage: $name [options]

Options:
${parser.usage}
''';
  }

  /// 명령어를 인자와 함께 실행합니다.
  ///
  /// [arguments]는 원시 명령행 인자 목록입니다.
  /// --help 플래그 처리와 에러 처리를 자동으로 수행합니다.
  ///
  /// ## 에러 처리
  /// - [CliException]: 사용자 친화적 에러 메시지 출력
  /// - [FormatException]: 잘못된 인자 에러 처리
  /// - 기타 예외: 일반 에러 메시지로 변환
  ///
  /// ## 반환 값
  /// - 0: 성공 (--help 포함)
  /// - 1 이상: 실패
  Future<int> run(List<String> arguments) async {
    final parser = buildArgParser();

    // --help 플래그 추가 (중복 방지)
    if (!parser.options.containsKey('help')) {
      parser.addFlag('help', abbr: 'h', negatable: false, help: '도움말 표시');
    }

    // --verbose 플래그 존재 여부 확인
    final hasVerbose = parser.options.containsKey('verbose');

    try {
      final results = parser.parse(arguments);

      // --help 처리
      if (results['help'] as bool) {
        print(usage);
        return 0;
      }

      return await execute(results);
    } on CliException catch (e) {
      // CliException: 구조화된 에러 메시지 출력
      print(e.formatError());
      return 1;
    } on FormatException catch (e) {
      // FormatException: 잘못된 인자 에러
      final error = CliException(
        '잘못된 명령어 인자: ${e.message}',
        solution: '--help 옵션으로 사용 가능한 옵션을 확인하세요',
      );
      print(error.formatError());
      print('');
      print(usage);
      return 1;
    } catch (e, stackTrace) {
      // 기타 예외: 일반 에러로 변환
      final error = wrapException(e, stackTrace);
      print(error.formatError(includeStackTrace: hasVerbose));
      return 1;
    }
  }
}
