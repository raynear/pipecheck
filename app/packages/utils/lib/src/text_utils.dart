/// 텍스트 유틸리티 클래스
/// 텍스트 가공과 관련된 다양한 도구를 제공합니다.
class TextUtils {
  /// 텍스트를 지정된 길이로 자르고 필요시 말줄임표 추가
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// 첫 글자를 대문자로 변환
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// 각 단어의 첫 글자를 대문자로 변환
  static String titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  /// HTML 태그 제거
  static String stripHtml(String htmlString) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  /// 텍스트가 너무 길 경우 축약된 버전 반환
  static String getAbbreviatedText(String text, int maxLength) {
    if (text.length <= maxLength) return text;

    final words = text.split(' ');
    String result = '';

    for (final word in words) {
      if (('$result $word').length <= maxLength) {
        result += (result.isEmpty) ? word : ' $word';
      } else {
        break;
      }
    }

    return '$result...';
  }
}
