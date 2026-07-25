import 'dart:io';

import 'package:test/test.dart';

/// 런타임 언어 변경 즉시 반영 가드.
///
/// `Text('key'.tr())` 처럼 raw [Text] 위젯에 context 없는 `String.tr()`를 직접
/// 넣으면, 그 위젯은 easy_localization 전역 인스턴스를 읽을 뿐 locale
/// InheritedWidget을 **구독하지 않는다**. 그래서 `context.setLocale()` 후에도
/// 라우터가 보존한 화면에서 옛 언어가 남는다(고질 버그).
///
/// 대신 공용 [SText]를 쓴다 — `SText('key')`. SText는 내부에서 `.tr()`를 하고
/// (키만 넘긴다, `.tr()` 붙이지 말 것 — 이중번역), locale을 구독해 즉시 갱신된다.
///
/// 같은 정규식이 `SText('key'.tr())`(이중번역 안티패턴)도 잡는다(`SText`가
/// `Text`를 포함하므로). 올바른 형태 `SText('key')`는 `.tr(`가 없어 통과한다.
///
/// 의도적 예외(예: 위젯이 아닌 곳, 동적 보간)는 해당 줄에 `// i18n-ignore`.
void main() {
  // Text( 또는 SText( 뒤에 곧바로 (문자열 리터럴 | 괄호로 감싼 삼항 키) + .tr(.
  // 두 번째 대안은 `Text((cond ? 'a' : 'b').tr())` 삼항 키 형태를 잡는다.
  // 괄호 대안은 그룹 안에 반드시 키 리터럴(따옴표)을 요구해 무관한 `.tr(`
  // 오탐을 피한다.
  final bannedTr = RegExp(
    r'''Text\(\s*(?:['"][^)]*|\([^;{}]*['"][^;{}]*)\.tr\(''',
  );

  test('lib/ 에 raw Text(\'key\'.tr()) / SText(\'key\'.tr()) 없다 (SText 키만 사용)',
      () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'flutter test는 app/ 에서 실행되어야 한다');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }
      // SText 정의 파일 자신은 data.tr()를 정당하게 호출한다.
      if (entity.path.endsWith('core/widgets/common/semantics.dart')) continue;

      final rel = entity.path.replaceFirst(RegExp(r'^lib[/\\]'), '');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('// i18n-ignore')) continue;
        // 3줄 창: `Text(`·키·`.tr(`가 dartfmt로 여러 줄로 갈린 경우도 잡는다
        // (삼항 키는 `.tr()`가 3번째 줄로 밀리기도 한다).
        final window = [
          line,
          if (i + 1 < lines.length) lines[i + 1].trimLeft(),
          if (i + 2 < lines.length) lines[i + 2].trimLeft(),
        ].join(' ');
        if (bannedTr.hasMatch(window)) {
          violations.add('$rel:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'raw Text(...tr()) / SText(...tr())를 SText(\'key\')로 바꿀 것 '
          '(런타임 언어 변경 즉시 반영). 정당한 예외는 // i18n-ignore.\n'
          '${violations.join('\n')}',
    );
  });
}
