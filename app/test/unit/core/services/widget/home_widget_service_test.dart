// HomeWidgetService — DI-seam 홈 위젯 래퍼 테스트.
//
// 파생 앱 voca가 재발명한 패턴(HomeWidgetClient seam + 플래그 게이트 + 비throw)을
// 이식. 순수 검증 핵심 3가지:
//   • 플래그 게이트: isHomeWidgetEnabled=false면 공개 메서드가 _client를 한 번도
//     건드리지 않고 즉시 실패값 반환 (배경/미설정 경로 no-op).
//   • 비throw(INV-H2): _client가 던져도 로깅 후 실패값 반환 — 앱 흐름 비차단.
//   • 채널 마샬링: FakeHomeWidgetClient가 인자/호출을 그대로 기록해 위임을 검증.
// (그룹 ID 문자열 일치 불변식은 *_app_group_contract_test.dart가 담당.)

import 'dart:async';

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/services/widget/home_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements HomeWidgetClient {
  _FakeClient({this.throwOnAll = false});

  bool throwOnAll;

  final List<String> calls = [];
  final Map<String, Object?> saved = {};
  String? lastGroupId;
  String? lastAndroidName;
  String? lastIOSName;
  Object? getReturn;
  Uri? initialReturn;

  final StreamController<Uri?> clicks = StreamController<Uri?>.broadcast();

  Never _boom() => throw StateError('plugin boom');

  @override
  Future<bool?> setAppGroupId(String groupId) async {
    calls.add('setAppGroupId');
    if (throwOnAll) _boom();
    lastGroupId = groupId;
    return true;
  }

  @override
  Stream<Uri?> get widgetClicked {
    if (throwOnAll) _boom();
    return clicks.stream;
  }

  @override
  Future<bool?> saveWidgetData(String key, Object? value) async {
    calls.add('saveWidgetData');
    if (throwOnAll) _boom();
    saved[key] = value;
    return true;
  }

  @override
  Future<bool?> updateWidget({String? androidName, String? iOSName}) async {
    calls.add('updateWidget');
    if (throwOnAll) _boom();
    lastAndroidName = androidName;
    lastIOSName = iOSName;
    return true;
  }

  @override
  Future<T?> getWidgetData<T>(String key) async {
    calls.add('getWidgetData');
    if (throwOnAll) _boom();
    return getReturn as T?;
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async {
    calls.add('initiallyLaunchedFromHomeWidget');
    if (throwOnAll) _boom();
    return initialReturn;
  }
}

void main() {
  late bool savedFlag;

  setUp(() {
    savedFlag = AppFeatureConfig.isHomeWidgetEnabled;
    AppFeatureConfig.isHomeWidgetEnabled = true;
  });

  tearDown(() {
    AppFeatureConfig.isHomeWidgetEnabled = savedFlag;
  });

  group('플래그 게이트 OFF → _client 무접촉 + 실패값', () {
    setUp(() => AppFeatureConfig.isHomeWidgetEnabled = false);

    test('initialize: setAppGroupId/구독 없음', () async {
      final c = _FakeClient();
      await HomeWidgetService(client: c).initialize();
      expect(c.calls, isEmpty);
    });

    test('saveData → false, 무접촉', () async {
      final c = _FakeClient();
      expect(await HomeWidgetService(client: c).saveData('k', 1), isFalse);
      expect(c.calls, isEmpty);
    });

    test('updateWidget → false, 무접촉', () async {
      final c = _FakeClient();
      expect(await HomeWidgetService(client: c).updateWidget(), isFalse);
      expect(c.calls, isEmpty);
    });

    test('saveAndUpdate → false, 무접촉', () async {
      final c = _FakeClient();
      expect(
          await HomeWidgetService(client: c).saveAndUpdate({'k': 1}), isFalse);
      expect(c.calls, isEmpty);
    });

    test('getData → null, 무접촉', () async {
      final c = _FakeClient();
      expect(await HomeWidgetService(client: c).getData<int>('k'), isNull);
      expect(c.calls, isEmpty);
    });

    test('getInitialUri → null, 무접촉', () async {
      final c = _FakeClient();
      expect(await HomeWidgetService(client: c).getInitialUri(), isNull);
      expect(c.calls, isEmpty);
    });
  });

  group('마샬링 (플래그 ON)', () {
    test('initialize: appGroupId 정확히 전달 + 초기화 1회', () async {
      final c = _FakeClient();
      final svc = HomeWidgetService(client: c);
      await svc.initialize();
      expect(c.lastGroupId, HomeWidgetService.appGroupId);
      expect(c.calls.where((e) => e == 'setAppGroupId').length, 1);
    });

    test('initialize 재호출 → 재초기화 안 함 (멱등)', () async {
      final c = _FakeClient();
      final svc = HomeWidgetService(client: c);
      await svc.initialize();
      await svc.initialize();
      expect(c.calls.where((e) => e == 'setAppGroupId').length, 1);
    });

    test('동시 initialize → widgetClicked 단일 구독 (재진입 가드)', () async {
      // setAppGroupId await 도중 두 번째 호출이 겹쳐도 in-flight future를 공유해
      // 구독이 한 번만 일어나야 한다(중복 시 탭 1회에 콜백 2회 발화).
      final c = _FakeClient();
      var callbackHits = 0;
      final svc =
          HomeWidgetService(client: c, onWidgetClick: (_) => callbackHits++);
      await Future.wait([svc.initialize(), svc.initialize()]);
      expect(c.calls.where((e) => e == 'setAppGroupId').length, 1);
      c.clicks.add(Uri.parse('app://tap'));
      await Future<void>.delayed(Duration.zero);
      expect(callbackHits, 1); // 단일 구독 → 1회만
    });

    test('saveData: key/value 그대로 저장', () async {
      final c = _FakeClient();
      expect(await HomeWidgetService(client: c).saveData('streak', 7), isTrue);
      expect(c.saved['streak'], 7);
    });

    test('updateWidget: androidName+iOSName 동시 전달 (Platform 분기 없음)',
        () async {
      final c = _FakeClient();
      expect(await HomeWidgetService(client: c).updateWidget(), isTrue);
      expect(c.lastAndroidName, HomeWidgetService.androidWidgetName);
      expect(c.lastIOSName, HomeWidgetService.iOSWidgetName);
    });

    test('saveAndUpdate: 전부 저장 후 갱신', () async {
      final c = _FakeClient();
      final ok = await HomeWidgetService(client: c)
          .saveAndUpdate({'a': 1, 'b': 'x'});
      expect(ok, isTrue);
      expect(c.saved, {'a': 1, 'b': 'x'});
      expect(c.calls, contains('updateWidget'));
    });

    test('getData: 플러그인 반환값 전달', () async {
      final c = _FakeClient()..getReturn = 'hello';
      expect(await HomeWidgetService(client: c).getData<String>('k'), 'hello');
    });

    test('getInitialUri: 플러그인 URI 전달', () async {
      final c = _FakeClient()..initialReturn = Uri.parse('app://open?x=1');
      expect(await HomeWidgetService(client: c).getInitialUri(),
          Uri.parse('app://open?x=1'));
    });
  });

  group('위젯 클릭 콜백', () {
    test('클릭 URI → onWidgetClick 위임', () async {
      final c = _FakeClient();
      Uri? got;
      final svc = HomeWidgetService(client: c, onWidgetClick: (u) => got = u);
      await svc.initialize();
      c.clicks.add(Uri.parse('app://tap?y=2'));
      await Future<void>.delayed(Duration.zero);
      expect(got, Uri.parse('app://tap?y=2'));
    });

    test('null URI → 콜백 안 부름', () async {
      final c = _FakeClient();
      var count = 0;
      final svc = HomeWidgetService(client: c, onWidgetClick: (_) => count++);
      await svc.initialize();
      c.clicks.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(count, 0);
    });
  });

  group('비throw 흡수 (INV-H2 — _client 예외가 앱 흐름 비차단)', () {
    test('initialize: setAppGroupId throw → 흡수, initialized=false 유지', () async {
      final c = _FakeClient(throwOnAll: true);
      final svc = HomeWidgetService(client: c);
      await svc.initialize(); // 던지지 않아야
      // 초기화 실패했으므로 재호출 시 다시 시도(멱등 가드 미설정).
      c.throwOnAll = false;
      await svc.initialize();
      expect(c.lastGroupId, HomeWidgetService.appGroupId);
    });

    test('saveData throw → false', () async {
      final c = _FakeClient(throwOnAll: true);
      expect(await HomeWidgetService(client: c).saveData('k', 1), isFalse);
    });

    test('updateWidget throw → false', () async {
      final c = _FakeClient(throwOnAll: true);
      expect(await HomeWidgetService(client: c).updateWidget(), isFalse);
    });

    test('saveAndUpdate throw → false', () async {
      final c = _FakeClient(throwOnAll: true);
      expect(await HomeWidgetService(client: c).saveAndUpdate({'k': 1}), isFalse);
    });

    test('getData throw → null', () async {
      final c = _FakeClient(throwOnAll: true);
      expect(await HomeWidgetService(client: c).getData<int>('k'), isNull);
    });

    test('getInitialUri throw → null', () async {
      final c = _FakeClient(throwOnAll: true);
      expect(await HomeWidgetService(client: c).getInitialUri(), isNull);
    });
  });
}
