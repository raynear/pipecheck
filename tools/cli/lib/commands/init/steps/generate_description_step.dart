import 'dart:convert';
import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Generates store descriptions in multiple languages via GPT-4o.
///
/// 산출물은 deliver/supply가 읽는 메타데이터 SSOT인 `<root>/metadata/`에
/// 기록한다 (P0-8 경로 SSOT). 과거 `fastlaneDir/metadata`(submodule)로 써서
/// 업로드 경로(deliver는 root metadata를 읽음)와 어긋나 생성 카피가 절대
/// 반영되지 않던 버그를 고친 것.
Future<StepResult> generateDescriptionStep({
  required String projectRoot,
  required ConfigLoader config,
  required bool hasConfig,
  required String appName,
  required bool verbose,
}) async {
  if (!hasConfig) {
    print('    -- 설정 파일 없음, 설명 생성 건너뛰기');
    return StepResult.skipped('설정 파일 없음');
  }

  final appDescription = config.description;
  if (appDescription.isEmpty) {
    print('    -- project.description 미설정, 설명 생성 건너뛰기');
    return StepResult.skipped('project.description 미설정');
  }

  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('    -- OPENAI_API_KEY 환경변수 미설정, 설명 생성 건너뛰기');
    return StepResult.skipped('OPENAI_API_KEY 환경변수 미설정');
  }

  print('    GPT-4o API로 스토어 설명 생성 중...');

  final category = config.category;
  final languages = ['en', 'ko', 'ja'];

  const androidLocaleMap = {
    'ko': 'ko-KR',
    'en': 'en-US',
    'ja': 'ja-JP',
  };
  const iosLocaleMap = {
    'ko': 'ko',
    'en': 'en-US',
    'ja': 'ja',
  };

  var succeeded = 0;
  final failedLangs = <String>[];
  for (final lang in languages) {
    try {
      final result = await _callGptForDescription(
        apiKey: apiKey,
        appName: appName,
        description: appDescription,
        category: category,
        language: lang,
        verbose: verbose,
      );

      final androidLocale = androidLocaleMap[lang] ?? lang;
      final iosLocale = iosLocaleMap[lang] ?? lang;

      await _writeDescriptionFiles(
          '$projectRoot/metadata/android/$androidLocale', result);
      await _writeDescriptionFiles(
          '$projectRoot/metadata/ios/$iosLocale', result);

      print('    $lang 설명 생성 완료');
      succeeded++;
    } catch (e) {
      print('    $lang 설명 생성 실패: $e');
      failedLangs.add(lang);
    }
  }

  if (succeeded == 0) {
    return StepResult.failed('GPT-4o 설명 생성 전부 실패 (${failedLangs.join(", ")})');
  }
  if (failedLangs.isNotEmpty) {
    return StepResult.skipped('일부 언어 실패: ${failedLangs.join(", ")}');
  }
  return const StepResult.done();
}

Future<Map<String, String>> _callGptForDescription({
  required String apiKey,
  required String appName,
  required String description,
  required String category,
  required String language,
  required bool verbose,
}) async {
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
        'Description: $description\n'
        'Category: $category\n'
        'Generate:\n'
        '1. Short description (under 80 chars)\n'
        '2. Full description (under 4000 chars)\n'
        '3. Keywords (comma-separated, max 100 chars)\n'
        '4. What\'s New text\n\n'
        'Format your response exactly as:\n'
        '[SHORT_DESCRIPTION]\n...\n[/SHORT_DESCRIPTION]\n'
        '[FULL_DESCRIPTION]\n...\n[/FULL_DESCRIPTION]\n'
        '[KEYWORDS]\n...\n[/KEYWORDS]\n'
        '[WHATS_NEW]\n...\n[/WHATS_NEW]';

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
      throw Exception('GPT API 호출 실패 (${response.statusCode})');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>;
    final content = choices[0]['message']['content'] as String;

    if (verbose) {
      CliLogger.debug('GPT 응답 ($language): ${content.substring(0, 100)}...');
    }

    return {
      'short_description': _extractSection(content, 'SHORT_DESCRIPTION'),
      'full_description': _extractSection(content, 'FULL_DESCRIPTION'),
      'keywords': _extractSection(content, 'KEYWORDS'),
      'whats_new': _extractSection(content, 'WHATS_NEW'),
    };
  } finally {
    client.close();
  }
}

String _extractSection(String content, String sectionName) {
  final pattern = RegExp(
    '\\[$sectionName\\]\\s*\\n(.*?)\\n\\s*\\[/$sectionName\\]',
    dotAll: true,
  );
  final match = pattern.firstMatch(content);
  return match?.group(1)?.trim() ?? '';
}

Future<void> _writeDescriptionFiles(
    String directory, Map<String, String> data) async {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }

  if (data['full_description']?.isNotEmpty == true) {
    await File('$directory/description.txt')
        .writeAsString(data['full_description']!);
  }
  if (data['short_description']?.isNotEmpty == true) {
    final isAndroid = directory.contains('/android/');
    final fileName = isAndroid ? 'short_description.txt' : 'subtitle.txt';
    await File('$directory/$fileName')
        .writeAsString(data['short_description']!);
  }
  if (data['keywords']?.isNotEmpty == true) {
    await File('$directory/keywords.txt')
        .writeAsString(data['keywords']!);
  }
  if (data['whats_new']?.isNotEmpty == true) {
    await File('$directory/release_notes.txt')
        .writeAsString(data['whats_new']!);
  }
}
