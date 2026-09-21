// pbxproj 파싱 헬퍼 — 위젯 확장 계약 테스트(INV-H3 / INV-L1~L2)가 공유한다.
//
// 배선을 검사하려면 "이 문자열이 파일 어딘가에 있다"가 아니라 **어느 객체 안에
// 있는가**를 봐야 한다. PBXBuildFile 선언 주석(`/* x.swift in Sources */`)은 페이즈
// 소속을 뜻하지 않으므로, 선언만 남기고 페이즈에서 빼면 그 파일은 컴파일되지 않는데
// 선언 검사는 통과한다 (이슈 #234의 모양).

/// [needle]을 포함하는 pbxproj 객체 블록. `[^{}]`이라 중괄호를 넘지 못해
/// **그 객체 안**으로 범위가 갇힌다(다른 블록의 같은 키를 잘못 집지 않음).
String? blockContaining(String pbxproj, String needle) =>
    RegExp(r'\{[^{}]*?' + RegExp.escape(needle) + r'[^{}]*?\}')
        .firstMatch(pbxproj)
        ?.group(0);

/// [targetName] 타겟 **자신의** Sources 페이즈 `files` 본문.
///
/// 타겟 → `buildPhases` → Sources UUID → **그 페이즈 객체**를 따라간다. 타겟마다
/// 분해되므로 `sourcesFiles(p, 'Runner')`와 `sourcesFiles(p, 'widgetExtension')`은
/// 서로소 결과를 준다 — 그래야 "두 타겟 모두에서 컴파일된다"를 검사할 수 있다.
String? sourcesFiles(String pbxproj, String targetName) {
  final target = blockContaining(pbxproj, 'name = $targetName;');
  if (target == null) return null;
  final phases = RegExp(r'buildPhases = \(([\s\S]*?)\);').firstMatch(target);
  if (phases == null) return null;
  final sourcesId =
      RegExp(r'(\w{24}) /\* Sources \*/').firstMatch(phases.group(1)!);
  if (sourcesId == null) return null;
  // `= {`까지 앵커로 잡는다 — UUID+주석은 buildPhases 목록에도 나오므로
  // 그것만으로는 페이즈 객체가 아니라 타겟 블록을 도로 집는다.
  final block = RegExp(
    '${RegExp.escape('${sourcesId.group(1)} /* Sources */')} = \\{([^{}]*?)\\}',
  ).firstMatch(pbxproj);
  if (block == null) return null;
  return RegExp(r'files = \(([\s\S]*?)\);')
      .firstMatch(block.group(1)!)
      ?.group(1);
}

/// `name = "Embed Foundation Extensions"` 복사 단계 블록. 앞서 나오는
/// "Embed Frameworks" 단계를 잘못 집어 무조건 통과하는 걸 막는다.
String? embedPhase(String pbxproj) =>
    blockContaining(pbxproj, 'name = "Embed Foundation Extensions";');

/// 그 단계의 `files` 본문 — appex가 앱 번들에 실리는지의 유일한 근거.
String? embedPhaseFiles(String pbxproj) {
  final block = embedPhase(pbxproj);
  if (block == null) return null;
  return RegExp(r'files = \(([\s\S]*?)\);').firstMatch(block)?.group(1);
}
