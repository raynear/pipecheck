import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/error_handler.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';

/// 앱 스토어 설명 생성 명령어.
///
/// OpenAI GPT API를 사용하여 다국어 앱 스토어 설명을 생성합니다.
///
/// ## 사용법
/// ```bash
/// ./scripts/generate-description --app-name "MyApp" --features "calendar,todo,reminder" --api-key $OPENAI_API_KEY
/// ```
///
/// ## 옵션
/// - `--app-name`, `-n`: 앱 이름 (필수)
/// - `--features`, `-f`: 쉼표로 구분된 기능 목록 (필수)
/// - `--api-key`: OpenAI API 키 (환경변수 OPENAI_API_KEY 사용 가능)
/// - `--languages`, `-l`: 쉼표로 구분된 언어 목록 (기본값: ko,en,ja)
/// - `--tone`: 설명 톤 (기본값: professional)
/// - `--output`, `-o`: 출력 디렉토리 (기본값: metadata/ — P0-8 경로 SSOT)
/// - `--verbose`, `-v`: 자세한 로그를 출력합니다
/// - `--help`, `-h`: 도움말을 표시합니다
///
/// ## 실행 단계
/// 1. API 키 검증
/// 2. 각 언어별 GPT API 호출
/// 3. 응답 파싱 및 Fastlane 메타데이터 구조로 저장
class GenerateDescriptionCommand extends Command {
  /// 생성자.
  GenerateDescriptionCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  /// 언어 코드와 Android 로케일 매핑.
  static const Map<String, String> _androidLocaleMap = {
    'ko': 'ko-KR',
    'en': 'en-US',
    'ja': 'ja-JP',
  };

  /// 언어 코드와 iOS 로케일 매핑.
  static const Map<String, String> _iosLocaleMap = {
    'ko': 'ko',
    'en': 'en-US',
    'ja': 'ja',
  };

  @override
  String get name => 'generate-description';

  @override
  String get description => '앱 스토어 설명을 생성합니다.\n\n'
      '실행 단계:\n'
      '  1. OpenAI API 키 검증\n'
      '  2. 각 언어별 GPT API 호출\n'
      '  3. Fastlane 메타데이터 구조로 저장';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption(
        'app-name',
        abbr: 'n',
        help: '앱 이름 (필수)',
      )
      ..addOption(
        'features',
        abbr: 'f',
        help: '쉼표로 구분된 기능 목록 (필수)',
      )
      ..addOption(
        'api-key',
        help: 'OpenAI API 키 (환경변수 OPENAI_API_KEY 사용 가능)',
      )
      ..addOption(
        'languages',
        abbr: 'l',
        help: '쉼표로 구분된 언어 목록',
        defaultsTo: 'ko,en,ja',
      )
      ..addOption(
        'tone',
        help: '설명 톤',
        defaultsTo: 'professional',
        allowed: ['professional', 'casual', 'playful', 'corporate'],
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: '출력 디렉토리',
        defaultsTo: 'metadata/',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: '자세한 실행 로그를 출력합니다.',
      );
  }

  @override
  Future<int> execute(ArgResults args) async {
    final appName = args['app-name'] as String?;
    final features = args['features'] as String?;
    final apiKeyArg = args['api-key'] as String?;
    final languages = args['languages'] as String;
    final tone = args['tone'] as String;
    final outputDir = args['output'] as String;
    final isVerbose = args['verbose'] as bool;

    // 로거 초기화
    await CliLogger.init(verbose: isVerbose);

    if (isVerbose) {
      CliLogger.debug('GenerateDescription 명령어를 시작합니다...');
      CliLogger.debug('  Project Root: $projectRoot');
      CliLogger.debug('  Languages: $languages');
      CliLogger.debug('  Tone: $tone');
      CliLogger.debug('  Output: $outputDir');
    }

    // 앱 이름 검증
    if (appName == null || appName.isEmpty) {
      throw CliException(
        '앱 이름이 필요합니다',
        solution: '--app-name 옵션으로 앱 이름을 입력하세요\n'
            '예: --app-name "MyApp"',
      );
    }

    // 기능 목록 검증
    if (features == null || features.isEmpty) {
      throw CliException(
        '기능 목록이 필요합니다',
        solution: '--features 옵션으로 기능 목록을 입력하세요\n'
            '예: --features "calendar,todo,reminder"',
      );
    }

    // API 키 검증
    final apiKey = apiKeyArg ?? Platform.environment['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw CliException(
        'OpenAI API 키가 필요합니다',
        solution: '--api-key 옵션으로 API 키를 전달하거나\n'
            'OPENAI_API_KEY 환경변수를 설정하세요',
      );
    }

    // 언어 목록 파싱
    final languageList =
        languages.split(',').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    print('');
    print('📝 앱 스토어 설명 생성을 시작합니다...');
    print('');

    final stopwatch = Stopwatch()..start();

    // 단계 목록 구성
    final steps = <String>[
      for (final lang in languageList) '$lang 설명 생성',
      '메타데이터 저장',
    ];

    final progress = StepProgress(steps: steps);

    // 각 언어별 GPT API 호출
    final results = <String, Map<String, String>>{};

    for (final lang in languageList) {
      progress.nextStep();
      try {
        final result = await _callGptApi(
          apiKey: apiKey,
          appName: appName,
          features: features,
          language: lang,
          tone: tone,
          isVerbose: isVerbose,
        );
        results[lang] = result;
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        rethrow;
      }
    }

    // 메타데이터 저장
    progress.nextStep();
    try {
      await _saveMetadata(
        results: results,
        outputDir: outputDir,
        isVerbose: isVerbose,
      );
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds / 1000;

    // 성공 메시지
    _printSuccessMessage(elapsed, outputDir, languageList);

    return 0;
  }

  /// GPT API를 호출하여 앱 스토어 설명을 생성합니다.
  Future<Map<String, String>> _callGptApi({
    required String apiKey,
    required String appName,
    required String features,
    required String language,
    required String tone,
    required bool isVerbose,
  }) async {
    if (isVerbose) {
      print('    GPT API 호출 중 ($language)...');
    }

    final client = HttpClient();

    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final request = await client.postUrl(uri);

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $apiKey');

      final systemPrompt =
          'You are an expert app store listing writer. '
          'Generate a compelling app store description in $language.';

      final userPrompt =
          'App Name: $appName\n'
          'Key Features: $features\n'
          'Tone: $tone\n'
          'Generate:\n'
          '1. Short description (under 80 chars)\n'
          '2. Full description (under 4000 chars)\n'
          '3. Keywords (comma-separated, max 100 chars)\n'
          '4. What\'s New text\n\n'
          'Format your response exactly as:\n'
          '[SHORT_DESCRIPTION]\n'
          '...\n'
          '[/SHORT_DESCRIPTION]\n'
          '[FULL_DESCRIPTION]\n'
          '...\n'
          '[/FULL_DESCRIPTION]\n'
          '[KEYWORDS]\n'
          '...\n'
          '[/KEYWORDS]\n'
          '[WHATS_NEW]\n'
          '...\n'
          '[/WHATS_NEW]';

      final body = jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
      });

      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        final errorJson = jsonDecode(responseBody) as Map<String, dynamic>;
        final errorMessage = errorJson['error']?['message'] ?? '알 수 없는 오류';
        throw CliException(
          'GPT API 호출에 실패했습니다 (${response.statusCode})',
          solution: '다음을 확인하세요:\n'
              '  1. API 키가 유효한지 확인\n'
              '  2. OpenAI 계정에 크레딧이 있는지 확인\n'
              '  3. API 사용 한도를 초과하지 않았는지 확인\n\n'
              '오류 내용: $errorMessage',
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      final content = choices[0]['message']['content'] as String;

      if (isVerbose) {
        CliLogger.debug('GPT 응답 ($language): $content');
      }

      return _parseGptResponse(content);
    } catch (e) {
      if (e is CliException) rethrow;
      throw CliException(
        'GPT API 호출 중 오류가 발생했습니다 ($language)',
        solution: '네트워크 연결을 확인하세요\n'
            '오류 내용: $e',
      );
    } finally {
      client.close();
    }
  }

  /// GPT 응답을 파싱합니다.
  Map<String, String> _parseGptResponse(String content) {
    final result = <String, String>{};

    result['short_description'] = _extractSection(content, 'SHORT_DESCRIPTION');
    result['full_description'] = _extractSection(content, 'FULL_DESCRIPTION');
    result['keywords'] = _extractSection(content, 'KEYWORDS');
    result['whats_new'] = _extractSection(content, 'WHATS_NEW');

    return result;
  }

  /// 응답에서 특정 섹션을 추출합니다.
  String _extractSection(String content, String sectionName) {
    final pattern = RegExp(
      '\\[$sectionName\\]\\s*\\n(.*?)\\n\\s*\\[/$sectionName\\]',
      dotAll: true,
    );
    final match = pattern.firstMatch(content);
    return match?.group(1)?.trim() ?? '';
  }

  /// 메타데이터를 Fastlane 구조로 저장합니다.
  Future<void> _saveMetadata({
    required Map<String, Map<String, String>> results,
    required String outputDir,
    required bool isVerbose,
  }) async {
    for (final entry in results.entries) {
      final lang = entry.key;
      final data = entry.value;

      // Android 메타데이터 저장
      final androidLocale = _androidLocaleMap[lang] ?? lang;
      final androidDir = '$projectRoot/$outputDir/android/$androidLocale';
      await _writeMetadataFiles(
        directory: androidDir,
        data: data,
        platform: 'android',
        isVerbose: isVerbose,
      );

      // iOS 메타데이터 저장
      final iosLocale = _iosLocaleMap[lang] ?? lang;
      final iosDir = '$projectRoot/$outputDir/ios/$iosLocale';
      await _writeMetadataFiles(
        directory: iosDir,
        data: data,
        platform: 'ios',
        isVerbose: isVerbose,
      );
    }
  }

  /// 메타데이터 파일을 작성합니다.
  Future<void> _writeMetadataFiles({
    required String directory,
    required Map<String, String> data,
    required String platform,
    required bool isVerbose,
  }) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    // description.txt
    if (data['full_description']?.isNotEmpty == true) {
      await File('$directory/description.txt')
          .writeAsString(data['full_description']!);
    }

    // short_description.txt (Android) / subtitle.txt (iOS)
    if (data['short_description']?.isNotEmpty == true) {
      final shortDescFile = platform == 'android'
          ? 'short_description.txt'
          : 'subtitle.txt';
      await File('$directory/$shortDescFile')
          .writeAsString(data['short_description']!);
    }

    // keywords.txt
    if (data['keywords']?.isNotEmpty == true) {
      await File('$directory/keywords.txt')
          .writeAsString(data['keywords']!);
    }

    // release_notes.txt
    if (data['whats_new']?.isNotEmpty == true) {
      await File('$directory/release_notes.txt')
          .writeAsString(data['whats_new']!);
    }

    if (isVerbose) {
      print('    ✓ 메타데이터 저장 완료: $directory');
    }
  }

  /// 성공 메시지를 출력합니다.
  void _printSuccessMessage(
    double elapsed,
    String outputDir,
    List<String> languages,
  ) {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  ✅ 앱 스토어 설명 생성이 완료되었습니다!');
    print('');
    print('     소요 시간: ${elapsed.toStringAsFixed(1)}초');
    print('     생성 언어: ${languages.join(", ")}');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  📌 생성된 파일 구조:');
    print('');
    for (final lang in languages) {
      final androidLocale = _androidLocaleMap[lang] ?? lang;
      final iosLocale = _iosLocaleMap[lang] ?? lang;
      print('  • $outputDir/android/$androidLocale/');
      print('  • $outputDir/ios/$iosLocale/');
    }
    print('');
    print('  📄 각 디렉토리에 포함된 파일:');
    print('');
    print('  • description.txt - 전체 설명');
    print('  • short_description.txt / subtitle.txt - 짧은 설명');
    print('  • keywords.txt - 키워드');
    print('  • release_notes.txt - 변경 사항');
    print('');
    print('  💡 fastlane deliver 또는 fastlane supply로 업로드할 수 있습니다.');
    print('');
  }
}
