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
