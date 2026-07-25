import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// 프로젝트 구조 및 의존성 검증 통합 테스트.
///
/// Story 2-6: 프로젝트 구조 및 의존성 설정
void main() {
  // tests run from tools/cli directory, so parent.parent is project root
  final projectRoot = Directory.current.parent.parent.path;

  group('Project Structure Integration', () {
    group('directory structure', () {
      test('tools/cli/ directory exists', () {
        final cliDir = Directory('$projectRoot/tools/cli');
        expect(cliDir.existsSync(), isTrue);
      });

      test('.husky/ directory exists', () {
        final huskyDir = Directory('$projectRoot/.husky');
        expect(huskyDir.existsSync(), isTrue);
      });

      test('.husky/pre-commit hook exists', () {
        final preCommit = File('$projectRoot/.husky/pre-commit');
        expect(preCommit.existsSync(), isTrue);
      });

      test('.husky/commit-msg hook exists', () {
        final commitMsg = File('$projectRoot/.husky/commit-msg');
        expect(commitMsg.existsSync(), isTrue);
      });
    });

    group('pubspec.yaml dependencies', () {
      late YamlMap pubspec;

      setUpAll(() {
        final pubspecFile = File('$projectRoot/tools/cli/pubspec.yaml');
        final content = pubspecFile.readAsStringSync();
        pubspec = loadYaml(content) as YamlMap;
      });

      test('has args dependency', () {
        final deps = pubspec['dependencies'] as YamlMap;
        expect(deps.containsKey('args'), isTrue);
      });

      test('has path dependency', () {
        final deps = pubspec['dependencies'] as YamlMap;
        expect(deps.containsKey('path'), isTrue);
      });

      test('has io dependency', () {
        final deps = pubspec['dependencies'] as YamlMap;
        expect(deps.containsKey('io'), isTrue);
      });

      test('has cli_util dependency', () {
        final deps = pubspec['dependencies'] as YamlMap;
        expect(deps.containsKey('cli_util'), isTrue);
      });

      test('has yaml dependency', () {
        final deps = pubspec['dependencies'] as YamlMap;
        expect(deps.containsKey('yaml'), isTrue);
      });
    });

    group('package.json', () {
      late Map<String, dynamic> packageJson;

      setUpAll(() {
        final packageFile = File('$projectRoot/package.json');
        expect(packageFile.existsSync(), isTrue,
            reason: 'package.json should exist');
        final content = packageFile.readAsStringSync();
        packageJson =
            Map<String, dynamic>.from(_parseJson(content) as Map);
      });

      test('has husky devDependency', () {
        final devDeps =
            Map<String, dynamic>.from(packageJson['devDependencies'] as Map);
        expect(devDeps.containsKey('husky'), isTrue);
      });

      test('has lint-staged devDependency', () {
        final devDeps =
            Map<String, dynamic>.from(packageJson['devDependencies'] as Map);
        expect(devDeps.containsKey('lint-staged'), isTrue);
      });

      test('has lint-staged configuration', () {
        expect(packageJson.containsKey('lint-staged'), isTrue);
      });
    });

    group('.gitignore', () {
      late String gitignoreContent;

      setUpAll(() {
        final gitignoreFile = File('$projectRoot/.gitignore');
        gitignoreContent = gitignoreFile.readAsStringSync();
      });

      test('includes .boilerplate/', () {
        expect(gitignoreContent, contains('.boilerplate/'));
      });

      test('includes .local/', () {
        expect(gitignoreContent, contains('.local/'));
      });

      test('includes node_modules/', () {
        expect(gitignoreContent, contains('node_modules/'));
      });
    });

    group('firebase.json hosting (P2-23a Stage 2b)', () {
      late Map<String, dynamic> hosting;

      setUpAll(() {
        final file = File('$projectRoot/firebase.json');
        expect(file.existsSync(), isTrue, reason: 'firebase.json should exist');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        hosting = Map<String, dynamic>.from(json['hosting'] as Map);
      });

      test('public은 docs/legal', () {
        expect(hosting['public'], 'docs/legal');
      });

      test('ignore가 .well-known dotdir를 제외하지 않음 (App Links 회귀 가드)', () {
        final ignore =
            (hosting['ignore'] as List).map((e) => e.toString()).toList();
        // "**/.*"는 .well-known dotdir를 deploy에서 제외해 App Links 검증을 깬다
        expect(ignore.contains('**/.*'), isFalse,
            reason: '**/.* 는 .well-known dotdir를 배포에서 제외함');
      });

      test('AASA를 application/json으로 서빙하는 Content-Type 헤더 룰', () {
        final headers = hosting['headers'] as List;
        final aasaRule = headers.cast<Map>().firstWhere(
              (h) => h['source']
                  .toString()
                  .contains('apple-app-site-association'),
              orElse: () => <String, dynamic>{},
            );
        expect(aasaRule.isNotEmpty, isTrue,
            reason: 'AASA 경로 헤더 룰이 있어야 함');
        final ct = (aasaRule['headers'] as List).cast<Map>().firstWhere(
              (h) => h['key'].toString().toLowerCase() == 'content-type',
              orElse: () => <String, dynamic>{},
            );
        expect(ct['value'], 'application/json');
      });
    });
  });
}

/// JSON 문자열을 파싱합니다.
dynamic _parseJson(String content) {
  // 간단한 JSON 파싱 (dart:convert 대신 직접 구현)
  // 실제로는 dart:convert의 jsonDecode를 사용하지만,
  // 여기서는 테스트 목적으로 간단한 파싱을 합니다.
  try {
    return _JsonParser(content).parse();
  } catch (e) {
    throw FormatException('Invalid JSON: $e');
  }
}

/// 간단한 JSON 파서.
class _JsonParser {
  _JsonParser(this._source) : _index = 0;

  final String _source;
  int _index;

  dynamic parse() {
    _skipWhitespace();
    final result = _parseValue();
    _skipWhitespace();
    if (_index < _source.length) {
      throw FormatException('Unexpected character at position $_index');
    }
    return result;
  }

  dynamic _parseValue() {
    _skipWhitespace();
    if (_index >= _source.length) {
      throw FormatException('Unexpected end of input');
    }

    final char = _source[_index];
    switch (char) {
      case '{':
        return _parseObject();
      case '[':
        return _parseArray();
      case '"':
        return _parseString();
      case 't':
      case 'f':
        return _parseBoolean();
      case 'n':
        return _parseNull();
      default:
        if (char == '-' || (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57)) {
          return _parseNumber();
        }
        throw FormatException('Unexpected character: $char at $_index');
    }
  }

  Map<String, dynamic> _parseObject() {
    final result = <String, dynamic>{};
    _index++; // skip '{'
    _skipWhitespace();

    if (_source[_index] == '}') {
      _index++;
      return result;
    }

    while (true) {
      _skipWhitespace();
      final key = _parseString();
      _skipWhitespace();
      if (_source[_index] != ':') {
        throw FormatException('Expected ":" at $_index');
      }
      _index++;
      _skipWhitespace();
      result[key] = _parseValue();
      _skipWhitespace();

      if (_source[_index] == '}') {
        _index++;
        return result;
      }
      if (_source[_index] != ',') {
        throw FormatException('Expected "," or "}" at $_index');
      }
      _index++;
    }
  }

  List<dynamic> _parseArray() {
    final result = <dynamic>[];
    _index++; // skip '['
    _skipWhitespace();

    if (_source[_index] == ']') {
      _index++;
      return result;
    }

    while (true) {
      result.add(_parseValue());
      _skipWhitespace();

      if (_source[_index] == ']') {
        _index++;
        return result;
      }
      if (_source[_index] != ',') {
        throw FormatException('Expected "," or "]" at $_index');
      }
      _index++;
      _skipWhitespace();
    }
  }

  String _parseString() {
    if (_source[_index] != '"') {
      throw FormatException('Expected string at $_index');
    }
    _index++;

    final buffer = StringBuffer();
    while (_index < _source.length && _source[_index] != '"') {
      if (_source[_index] == '\\') {
        _index++;
        if (_index >= _source.length) {
          throw FormatException('Unexpected end of string');
        }
        switch (_source[_index]) {
          case '"':
          case '\\':
          case '/':
            buffer.write(_source[_index]);
          case 'n':
            buffer.write('\n');
          case 'r':
            buffer.write('\r');
          case 't':
            buffer.write('\t');
          default:
            buffer.write(_source[_index]);
        }
      } else {
        buffer.write(_source[_index]);
      }
      _index++;
    }

    if (_index >= _source.length) {
      throw FormatException('Unterminated string');
    }
    _index++; // skip closing '"'
    return buffer.toString();
  }

  num _parseNumber() {
    final start = _index;
    if (_source[_index] == '-') _index++;

    while (_index < _source.length &&
        _source[_index].codeUnitAt(0) >= 48 &&
        _source[_index].codeUnitAt(0) <= 57) {
      _index++;
    }

    if (_index < _source.length && _source[_index] == '.') {
      _index++;
      while (_index < _source.length &&
          _source[_index].codeUnitAt(0) >= 48 &&
          _source[_index].codeUnitAt(0) <= 57) {
        _index++;
      }
    }

    final numberStr = _source.substring(start, _index);
    if (numberStr.contains('.')) {
      return double.parse(numberStr);
    }
    return int.parse(numberStr);
  }

  bool _parseBoolean() {
    if (_source.substring(_index).startsWith('true')) {
      _index += 4;
      return true;
    }
    if (_source.substring(_index).startsWith('false')) {
      _index += 5;
      return false;
    }
    throw FormatException('Expected boolean at $_index');
  }

  Object? _parseNull() {
    if (_source.substring(_index).startsWith('null')) {
      _index += 4;
      return null;
    }
    throw FormatException('Expected null at $_index');
  }

  void _skipWhitespace() {
    while (_index < _source.length &&
        (_source[_index] == ' ' ||
            _source[_index] == '\n' ||
            _source[_index] == '\r' ||
            _source[_index] == '\t')) {
      _index++;
    }
  }
}
