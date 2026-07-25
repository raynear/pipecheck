import 'dart:convert';
import 'dart:io';

import '../../core/adlab_client.dart';
import 'screenshot_enhance.dart';

/// adlab `store_screenshot` **라이브 경로** 스모크.
///
/// enhance는 mock provider로만 검증됐고 Gemini 실호출(4K 생성 → 리사이즈 →
/// 다운로드 → 크기검증) 경로는 실사용 전까지 한 번도 안 터졌다. 이 스모크는
/// 더미 PNG 1장을 실제 adlab에 제출해 그 경로를 저비용으로 태운다.
///
/// - **enhance 파이프라인 전체를 재사용** — 스크래치 임시 디렉토리에 더미를 두고
///   [ScreenshotEnhancer.enhance]를 그대로 돌린다(제출/폴링/다운로드/크기검증).
/// - 산출물은 임시 디렉토리에만 쓰고 finally에서 삭제 — `screenshots/`·metadata 불변.
/// - exit: PASS 0 / FAIL 1.
class ScreenshotSmoke {
  ScreenshotSmoke._();

  /// 더미 입력: 320×640 단색(#128A7B) RGB PNG, base64.
  /// Gemini가 입력을 디코드하므로 유효한 실 PNG여야 한다 — 이 바이트는
  /// 라이브 스모크 PASS로 검증된 것이다. 실제 기기 캡처 불필요.
  static const dummyPngB64 =
      'iVBORw0KGgoAAAANSUhEUgAAAUAAAAKACAIAAABi8jbUAAAHUUlEQVR4nO3TQQ0AIBDAsNOA'
      'XRygGg98yJImFbDPZp0NRM33AuCZgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMw'
      'hBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEG'
      'hjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHM'
      'wBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCE'
      'GRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaG'
      'MANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczA'
      'EGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZ'
      'GMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYw'
      'A0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQ'
      'ZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkY'
      'wgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjAD'
      'Q5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBm'
      'YAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjC'
      'DAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMAND'
      'mIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZg'
      'CDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIM'
      'DGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OY'
      'gSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAI'
      'MzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwM'
      'YQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iB'
      'IczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgz'
      'MIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxh'
      'BoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEh'
      'zMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMw'
      'hBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEG'
      'hjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHM'
      'wBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCE'
      'GRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaG'
      'MANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczA'
      'EGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZ'
      'GMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYw'
      'A0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkYwgwMYQaGMANDmIEhzMAQ'
      'ZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjADQ5iBIczAEGZgCDMwhBkY'
      'wgwMYQaGMANDmIEhzMAQZmAIMzCEGRjCDAxhBoYwA0OYgSHMwBBmYAgzMIQZGMIMDGEGhjAD'
      'Q5iBIczAEGZgCDMwhBkYwgwMYRfOAhMZUpHDTQAAAABJRU5ErkJggg==';

  static Future<int> run({
    required AdlabClient client,
    required String app,
    required bool isVerbose,
  }) async {
    if (!await client.isUp()) {
      stderr.writeln('❌ adlab 서버에 연결할 수 없습니다 (${client.base})');
      stderr.writeln(AdlabClient.startHint);
      return 1;
    }

    final tmp = Directory.systemTemp.createTempSync('adlab_smoke');
    try {
      File('${tmp.path}/shots/ios/en/smoke.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(base64Decode(dummyPngB64));

      print('');
      print('🔥 adlab store_screenshot 라이브 스모크 (320x640 더미 1장)');
      print('   비용: Gemini 이미지 생성 1건'
          '(+비전 저지; 결함 판정 시 최대 3회 재생성).');
      print('   서버: ${client.base}');
      print('');

      final report = await ScreenshotEnhancer.enhance(
        client: client,
        app: app,
        projectRoot: tmp.path,
        outputDir: 'shots',
        isVerbose: isVerbose,
      );

      // 생성·다운로드·리사이즈·크기검증이 모두 통과하면 라이브 경로는 정상이다.
      // flagged(저지 미통과)도 그 4단계는 성공한 것이므로 PASS로 본다.
      final passed = report.enhanced + report.flagged.length;
      if (passed >= 1) {
        print('✅ SMOKE PASS — 라이브 경로 정상 '
            '(생성 ${report.enhanced}, 저지격리 ${report.flagged.length}).');
        if (report.flagged.isNotEmpty) {
          print('   (저지는 미통과했으나 생성·다운로드·리사이즈·크기검증은 성공)');
        }
        return 0;
      }
      print('❌ SMOKE FAIL — 라이브 목업화 실패 (${report.failed.length}개).');
      print('   adlab 서버 로그를 확인하세요 '
          '(GEMINI_API_KEY 설정/쿼터 포함).');
      return 1;
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }
}
