import 'package:args/args.dart';
import 'package:boilerplate_cli/core/command.dart';
import 'package:test/test.dart';

/// Command 추상 클래스 테스트를 위한 Mock 구현체.
class MockCommand extends Command {
  MockCommand({
    String name = 'mock',
    String description = 'Mock command for testing',
    int exitCode = 0,
  })  : _name = name,
        _description = description,
        _exitCode = exitCode;

  final String _name;
  final String _description;
  final int _exitCode;

  @override
  String get name => _name;

  @override
  String get description => _description;

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addFlag('test-flag', abbr: 't', help: 'Test flag');
  }

  @override
  Future<int> execute(ArgResults args) async {
    return _exitCode;
  }
}

void main() {
  group('Command', () {
    group('name property', () {
      test('returns correct name', () {
        final command = MockCommand(name: 'test-command');
        expect(command.name, equals('test-command'));
      });

      test('returns different names for different commands', () {
        final command1 = MockCommand(name: 'command-one');
        final command2 = MockCommand(name: 'command-two');

        expect(command1.name, equals('command-one'));
        expect(command2.name, equals('command-two'));
        expect(command1.name, isNot(equals(command2.name)));
      });
    });

    group('description property', () {
      test('returns correct description', () {
        final command = MockCommand(description: 'Test description');
        expect(command.description, equals('Test description'));
      });

      test('returns different descriptions for different commands', () {
        final command1 = MockCommand(description: 'Description one');
        final command2 = MockCommand(description: 'Description two');

        expect(command1.description, equals('Description one'));
        expect(command2.description, equals('Description two'));
      });
    });

    group('buildArgParser', () {
      test('returns an ArgParser instance', () {
        final command = MockCommand();
        final parser = command.buildArgParser();

        expect(parser, isA<ArgParser>());
      });

      test('parser contains defined options', () {
        final command = MockCommand();
        final parser = command.buildArgParser();

        expect(parser.options.containsKey('test-flag'), isTrue);
      });

      test('parser options have correct configuration', () {
        final command = MockCommand();
        final parser = command.buildArgParser();
        final option = parser.options['test-flag'];

        expect(option, isNotNull);
        expect(option!.abbr, equals('t'));
        expect(option.help, equals('Test flag'));
      });
    });

    group('execute', () {
      test('returns exit code 0 on success', () async {
        final command = MockCommand(exitCode: 0);
        final parser = command.buildArgParser();
        final args = parser.parse([]);

        final result = await command.execute(args);
        expect(result, equals(0));
      });

      test('returns exit code 1 on failure', () async {
        final command = MockCommand(exitCode: 1);
        final parser = command.buildArgParser();
        final args = parser.parse([]);

        final result = await command.execute(args);
        expect(result, equals(1));
      });

      test('returns custom exit code', () async {
        final command = MockCommand(exitCode: 42);
        final parser = command.buildArgParser();
        final args = parser.parse([]);

        final result = await command.execute(args);
        expect(result, equals(42));
      });
    });

    group('usage property', () {
      test('contains command description', () {
        final command = MockCommand(description: 'My test description');
        expect(command.usage, contains('My test description'));
      });

      test('contains command name', () {
        final command = MockCommand(name: 'my-command');
        expect(command.usage, contains('my-command'));
      });

      test('contains options section', () {
        final command = MockCommand();
        expect(command.usage, contains('Options:'));
      });
    });

    group('run method', () {
      test('returns 0 when --help is provided', () async {
        final command = MockCommand();
        final result = await command.run(['--help']);
        expect(result, equals(0));
      });

      test('returns 0 when -h is provided', () async {
        final command = MockCommand();
        final result = await command.run(['-h']);
        expect(result, equals(0));
      });

      test('returns 1 on invalid arguments', () async {
        final command = MockCommand();
        final result = await command.run(['--invalid-option']);
        expect(result, equals(1));
      });

      test('executes command and returns exit code', () async {
        final command = MockCommand(exitCode: 0);
        final result = await command.run([]);
        expect(result, equals(0));
      });
    });
  });
}
