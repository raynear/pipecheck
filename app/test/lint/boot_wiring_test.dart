import 'dart:io';

import 'package:test/test.dart';

/// 시니어 리뷰 1008 — main.dart/app_config.dart 부팅 배선 가드. main.dart 전체를 띄울 수 없어
/// 소스 구조로 못 박는다(iap_wiring_test.dart와 같은 방식). 지워도 컴파일·단위 테스트는 초록이다.
void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final config = File('lib/config/app_config.dart').readAsStringSync();

  String block(String src, RegExp re) => re.firstMatch(src)!.group(0)!;

  test('C1: app_start는 부팅 동의 적용(consentApplied) 뒤에 보낸다', () {
    final init = block(main, RegExp(r'void initState\(\)[\s\S]*?\n  \}'));
    expect(init, contains('consentApplied: AppConfig.consentApplied'));
    expect(init, contains('sendAppStartAfterConsent('));
  });

  test('C1: 비핵심 서비스 초기화는 동의 적용 직후 consentApplied를 완료시킨다', () {
    final fn = config.substring(config.indexOf('Future<void> _initializeNonCriticalServices()'));
    final apply = fn.indexOf('await applyBootConsent();');
    expect(apply, isNonNegative);
    expect(fn.indexOf('_consentApplied.complete()'), greaterThan(apply));
    expect(config, isNot(contains('CrashReporter.setCollectionEnabled(true)')),
        reason: '하드코딩 true가 저장된 동의를 덮어쓴다');
  });

  test('H6: 점검·강제 업데이트 검사는 main이 아니라 스플래시가 한다', () {
    expect(main, isNot(contains('showMaintenanceScreen')));
    expect(main, isNot(contains('showForceUpdateDialog')));
    expect(File('lib/features/splash/views/splash_view.dart').readAsStringSync(), contains('showMaintenanceScreen'));
  });

  test('M3/N4: 딥링크 핸들러는 navigateFromDeepLink(보류 슬롯 경유)로만 이동한다', () {
    final h = block(main, RegExp(r'void _handleDeepLink\(Uri uri\)[\s\S]*?\n  \}'));
    expect(h, contains('navigateFromDeepLink(uri, context.go)'));
    expect(h, isNot(contains('context.go(location)')));
  });

  test('N1: 알림 탭 핸들러도 보류 슬롯을 거친다 (직접 go 금지)', () {
    final m = block(main, RegExp(r'NotificationController\.onNavigate =[\s\S]*?;\n'));
    expect(m, contains('navigateFromNotification('));
    expect(m, isNot(contains('.go(route)')));
  });

  test('M1: 생명주기 콜백은 applyLockLifecycle로 잠금에 배선한다', () {
    final cb = block(main, RegExp(r'void didChangeAppLifecycleState[\s\S]*?\n  \}'));
    expect(cb, contains('applyLockLifecycle(state, ref.read(authStateProvider.notifier))'));
  });

  test('N3: 설정 화면은 exportToFile을 직접 부르지 않고 exportAndShare(사본 삭제 보장)를 쓴다', () {
    final v = File('lib/features/settings/views/settings_view.dart').readAsStringSync();
    expect(v, isNot(contains('.exportToFile()')));
    expect('exportAndShare('.allMatches(v).length, 2, reason: '내보내기·백업 둘 다');
  });

  test('M7: screen_view는 pageBuilder가 아니라 위치 변화 리스너 한 곳에서만 보낸다', () {
    final router = File('lib/core/router.dart').readAsStringSync();
    final page = block(router, RegExp(r'CupertinoExtendedPage<void> _logAndBuildPage\([\s\S]*?\n\}\n'));
    expect(page, isNot(contains('logScreenView')));
    expect(router, contains('ref.onDispose(attachScreenViewLogging(router))'));
    expect(File('lib/features/splash/views/splash_view.dart').readAsStringSync(), isNot(contains('logScreenView')));
  });

  test('LOW: 실행 횟수 증가는 메인 컨테이너의 notifier를 주입한다', () {
    expect(main, contains('settingsNotifier: ref.read(settingsProvider.notifier)'));
  });
}
