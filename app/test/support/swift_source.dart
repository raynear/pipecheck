// Swift 소스에서 **한 메서드의 본문만** 떼어내는 헬퍼 — 네이티브 배선 계약
// 테스트가 공유한다(iOS 씬 게이트 · Live Activity INV-L2).
//
// 들여쓰기로 끊으면(`\n  }`) 두 방향으로 틀린다:
//   • 중첩 클로저가 같은 깊이로 닫히면 **일찍 끊긴다** → 거짓 FAIL.
//   • 클래스를 4칸으로 들여쓴 포크에는 메서드 안에 `\n  }`가 아예 없어
//     **뒤 메서드까지 삼킨다** → 거짓 PASS.
// "등록이 이 메서드 **안**에 있나"를 청구하는 게이트에서 후자는 치명적이므로
// 중괄호를 센다.

/// [signaturePrefix]로 시작하는 선언의 본문(중괄호 포함). 없으면 null.
///
// ponytail: 문자열 리터럴·주석 안의 중괄호는 세지 않는다. AppDelegate처럼
// 짧고 관용적인 파일이 대상이라 충분하다 — 어긋나면 그때 진짜 파서로 올린다.
String? swiftMethodBody(String source, String signaturePrefix) {
  final start = source.indexOf(signaturePrefix);
  if (start < 0) return null;
  final open = source.indexOf('{', start);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return null; // 닫히지 않았다 — 소스가 깨졌거나 잘린 것이다.
}
