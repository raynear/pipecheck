import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:utils/utils.dart';

/// 딥링크 수신 서비스 (P2-23a).
///
/// 단일 [AppLinks] 인스턴스를 소유하고, 콜드 스타트 링크([getInitialLink])를
/// 한 번 비운 뒤 웜 링크 스트림([uriLinkStream])을 구독해, 들어온 각 `Uri`를
/// 주입된 [onUri] 콜백으로 넘긴다.
///
/// 라우터를 직접 참조하지 않는다 — 앱이 `rootNavigatorKey`로 해석하는
/// 콜백을 주입한다(NotificationController.onNavigate와 동일 패턴). 덕분에
/// 서비스는 라우터-무관하게 유지돼 추후 패키지로 추출 가능하다.
class DeepLinkService {
  DeepLinkService({required this.onUri, AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  /// 들어온 딥링크 URI 핸들러 (앱이 GoRouter 이동으로 변환해 주입).
  final void Function(Uri uri) onUri;

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// 콜드 스타트 링크를 먼저 처리한 뒤 웜 링크 스트림을 구독한다.
  ///
  /// 위젯 트리/라우터가 준비된 시점(첫 프레임 이후)에 호출해야 한다 — 너무
  /// 일찍 부르면 콜드 링크의 `go()`가 null context로 무음 처리된다.
  Future<void> start() async {
    if (_started) return; // 핫 리스타트/재진입 시 중복 리스너·재발사 방지
    _started = true;

    try {
      // 콜드 스타트 링크 먼저 — 스트림은 런치 URI를 재생하지 않으므로
      // getInitialLink를 비우지 않으면 콜드 링크를 놓친다.
      final initial = await _appLinks.getInitialLink();
      if (initial != null) onUri(initial);
    } catch (e) {
      logger.w('DeepLinkService: getInitialLink failed: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      onUri,
      onError: (Object e, StackTrace s) =>
          logger.w('DeepLinkService: uriLinkStream error: $e'),
    );
  }

  /// 동기 정리 — `State.dispose()`에서 await 없이 호출 가능해야 한다.
  /// `cancel()`은 즉시 이벤트 전달을 멈추므로(Future는 정리 완료 신호일 뿐)
  /// fire-and-forget로 충분하다.
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}

/// 스플래시가 끝나기 전에 도착한 딥링크를 보관하는 보류 슬롯 (콜드 스타트 링크 포함).
///
/// 스플래시는 동의·ATT·점검/강제업데이트·온보딩·잠금 분기를 소유한다. 그 전에
/// `go(location)`하면 스플래시가 사라지며 그 흐름을 전부 건너뛴다. 그래서 스플래시
/// 이동 전에는 [offer]가 링크를 보관하고, 스플래시가 이동한 뒤 [markReady]가
/// 보관된 링크를 꺼내 준다.
class PendingDeepLink {
  PendingDeepLink._();

  static bool _ready = false;
  static String? _pending;

  /// 위치를 바로 이동해도 되면 그대로 돌려주고, 아직이면 보관하고 null을 돌려준다.
  /// 마지막으로 도착한 링크만 남긴다.
  static String? offer(String location) {
    if (_ready) return location;
    _pending = location;
    return null;
  }

  /// 스플래시 이동이 끝났다. 보관된 링크가 있으면 돌려주고 비운다.
  static String? markReady() {
    _ready = true;
    final p = _pending;
    _pending = null;
    return p;
  }

  static String? _afterUnlock;

  /// 앱 잠금·온보딩 때문에 튕긴 원래 목적지를 잠금 해제(또는 온보딩 완료) 뒤까지 보관한다.
  static void holdForUnlock(String location) => _afterUnlock = location;

  /// 보관된 목적지를 꺼내지 않고 본다 (redirect의 "이미 인증됨" 분기용 — 꺼내는 곳은 한 곳뿐이다).
  static String? peekAfterUnlock() => _afterUnlock;

  /// 잠금이 풀렸다. 보관된 목적지가 있으면 그곳, 없으면 [fallback].
  static String takeAfterUnlock(String fallback) {
    final p = _afterUnlock ?? fallback;
    _afterUnlock = null;
    return p;
  }

  /// 테스트 격리용.
  static void reset() {
    _ready = false;
    _pending = null;
    _afterUnlock = null;
  }
}
