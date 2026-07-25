// HomeWidgetService — iOS WidgetKit / Android App Widget 얇은 래퍼.
//
// 파생 앱 voca에서 승격. 원본(examples/optional_services/home_widget_service.dart)
// 대비 개선점:
//   • DI seam(HomeWidgetClient): 정적 HomeWidget.* 호출을 인터페이스 뒤로 숨겨
//     플랫폼 채널 없이 순수 단위 테스트 가능(voca 재발명 → 공통화).
//   • 플랫폼 분기 제거: setAppGroupId/updateWidget을 Platform.isX 없이 항상 호출
//     (home_widget 플러그인이 무관 플랫폼에서 no-op) → 호스트에서 배선 검증 가능.
//   • App Group ID 3자 결합을 계약 테스트로 못박음(INV-H1) — 원본은 Dart 상수만
//     있고 메인 앱 entitlement엔 App Group이 아예 없어 데이터 공유가 깨져 있었다.
//
// [AppFeatureConfig.isHomeWidgetEnabled]가 false면 모든 공개 메서드가 _client를
// 건드리지 않고 즉시 실패값을 반환한다(배경/미설정 경로 no-op). _client 호출이
// throw하면 로깅 후 실패값 반환(INV-H2 — 앱 흐름 비차단).

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:home_widget/home_widget.dart';
import 'package:utils/utils.dart';

/// 6-API seam — home_widget 정적 표면을 1:1로 감싼다. abstract(실행 라인 0)이라
/// 커버리지 무영향. 계약/단위 테스트의 FakeHomeWidgetClient가 이 인터페이스로
/// 주입된다.
abstract class HomeWidgetClient {
  Future<bool?> setAppGroupId(String groupId);
  Stream<Uri?> get widgetClicked;
  Future<bool?> saveWidgetData(String key, Object? value);
  Future<bool?> updateWidget({String? androidName, String? iOSName});
  Future<T?> getWidgetData<T>(String key);
  Future<Uri?> initiallyLaunchedFromHomeWidget();
}

/// home_widget 정적 API로 바로 위임하는 실제 구현. 채널 경계 검증은 통합/기기
/// 테스트가 담당한다(순수 단위 테스트는 Fake로 대체).
class _RealHomeWidgetClient implements HomeWidgetClient {
  const _RealHomeWidgetClient();

  @override
  Future<bool?> setAppGroupId(String groupId) =>
      HomeWidget.setAppGroupId(groupId);

  @override
  Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;

  @override
  Future<bool?> saveWidgetData(String key, Object? value) =>
      HomeWidget.saveWidgetData(key, value);

  @override
  Future<bool?> updateWidget({String? androidName, String? iOSName}) =>
      HomeWidget.updateWidget(androidName: androidName, iOSName: iOSName);

  @override
  Future<T?> getWidgetData<T>(String key) => HomeWidget.getWidgetData<T>(key);

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();
}

class HomeWidgetService {
  HomeWidgetService({HomeWidgetClient? client, this.onWidgetClick})
      : _client = client ?? const _RealHomeWidgetClient();

  final HomeWidgetClient _client;

  /// 위젯 탭 콜백 URI 수신자 — 라우팅은 호출부(main.dart)가 GoRouter로 수행.
  final void Function(Uri uri)? onWidgetClick;

  /// App Group ID — 메인 앱/위젯 확장 entitlement와 **정확히 일치**해야 한다
  /// (INV-H1, home_widget_app_group_contract_test.dart가 3자 일치를 강제).
  /// 값은 iOS 번들 ID(com.raynear.boilerplate)에 맞춘 placeholder이며 ./init의
  /// 리네임이 세 위치를 함께 바꾼다.
  static const String appGroupId = 'group.com.raynear.boilerplate';

  /// Android receiver 클래스명(AndroidManifest.xml)과 일치해야 함.
  static const String androidWidgetName = 'HomeWidgetReceiver';

  /// WidgetKit `kind` 식별자 — iOS widget.swift의 kind 및
  /// HomeWidget.updateWidget(iOSName:)과 동일해야 함.
  static const String iOSWidgetName = 'widget';

  bool _initialized = false;
  Future<void>? _initializing;

  /// App Group 설정 + 위젯 탭 콜백 구독. setAppGroupId는 Platform 분기 없이 항상
  /// 호출한다(플러그인이 무관 플랫폼에서 no-op — 호스트 배선을 늘 테스트 가능).
  ///
  /// 재진입 가드: setAppGroupId await 도중 두 번째 호출이 들어와도 in-flight
  /// future를 공유해 widgetClicked를 **한 번만** 구독한다(중복 구독 시 탭 1회에
  /// 콜백 2회 발화). 실패(설정 throw) 시 _initialized는 false로 남아 다음 호출이
  /// 재시도한다 — _run이 예외를 흡수하므로 in-flight future는 거부되지 않는다.
  Future<void> initialize() {
    if (!AppFeatureConfig.isHomeWidgetEnabled) return Future<void>.value();
    if (_initialized) return Future<void>.value();
    return _initializing ??=
        _runInitialize().whenComplete(() => _initializing = null);
  }

  Future<void> _runInitialize() async {
    try {
      await _client.setAppGroupId(appGroupId);
      _client.widgetClicked.listen(_handleWidgetClick);
      _initialized = true;
    } catch (e) {
      logger.e('Failed to initialize Home Widget service: $e');
    }
  }

  /// [key]/[value]를 App Group에 저장.
  Future<bool> saveData(String key, Object? value) async {
    if (!AppFeatureConfig.isHomeWidgetEnabled) return false;
    try {
      await _client.saveWidgetData(key, value);
      return true;
    } catch (e) {
      logger.e('Failed to save widget data: $e');
      return false;
    }
  }

  /// 위젯 갱신 — androidName/iOSName 동시 전달(Platform 분기 금지).
  Future<bool> updateWidget() async {
    if (!AppFeatureConfig.isHomeWidgetEnabled) return false;
    try {
      await _client.updateWidget(
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );
      return true;
    } catch (e) {
      logger.e('Failed to update widget: $e');
      return false;
    }
  }

  /// 데이터 일괄 저장 후 갱신.
  Future<bool> saveAndUpdate(Map<String, Object?> data) async {
    if (!AppFeatureConfig.isHomeWidgetEnabled) return false;
    try {
      for (final entry in data.entries) {
        await _client.saveWidgetData(entry.key, entry.value);
      }
      return await updateWidget();
    } catch (e) {
      logger.e('Failed to save and update widget: $e');
      return false;
    }
  }

  /// App Group에서 [key] 읽기.
  Future<T?> getData<T>(String key) async {
    if (!AppFeatureConfig.isHomeWidgetEnabled) return null;
    try {
      return await _client.getWidgetData<T>(key);
    } catch (e) {
      logger.e('Failed to get widget data: $e');
      return null;
    }
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri == null) return;
    logger.d('Widget clicked with URI: $uri');
    onWidgetClick?.call(uri);
  }

  /// 앱이 위젯 탭으로 최초 실행됐을 때의 URI.
  Future<Uri?> getInitialUri() async {
    if (!AppFeatureConfig.isHomeWidgetEnabled) return null;
    try {
      return await _client.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      logger.e('Failed to get initial URI: $e');
      return null;
    }
  }
}
