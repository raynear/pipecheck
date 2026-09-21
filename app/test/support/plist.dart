// Info.plist를 **문자열로** 읽는 계약 테스트용 헬퍼.
//
// plist 파싱기를 끌어오지 않는 이유: 테스트가 청구하는 건 값만이 아니라
// `$(PRODUCT_MODULE_NAME)` 같은 **미치환 빌드 변수**라 파서가 있어도 문자열을
// 그대로 봐야 하고, Xcode plist GUI가 주석을 지우는 이 레포 사정상 주석 유무가
// 검사 대상이기도 하다.

/// XML 주석을 제거한 사본. 주석 안의 키/값을 살아 있는 선언으로 오인하는 걸 막는다
/// (실측: 이 레포들의 Info.plist는 주석 블록을 1~3개씩 들고 있다).
String stripXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// `UIWindowSceneSessionRoleApplication` 롤의 `<array>…</array>` 본문.
/// 롤이 여러 개인 plist에서 **다른 롤의 값을 줍는 것**을 막는다.
String? applicationSceneRole(String infoPlist) => RegExp(
  r'<key>UIWindowSceneSessionRoleApplication</key>\s*<array>([\s\S]*?)</array>',
).firstMatch(stripXmlComments(infoPlist))?.group(1);
