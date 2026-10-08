// ignore_for_file: library_private_types_in_public_api, directives_ordering
// 설정 화면 — 구독 상태·덮어쓰기 토글·잠금 방식·디버그 도구·데이터 내보내기/백업·삭제 흐름을
// 실제 위젯을 탭해 확인한다. 외부 의존(저장소·공유·스토어)은 가짜로 바꾼다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/cupertino.dart' show CupertinoDatePicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/design/design_system_provider.dart';
import 'package:pipecheck/core/services/badge_service.dart';
import 'package:pipecheck/core/services/data_export_service.dart';
import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/restore_service.dart';
import 'package:pipecheck/core/services/secure_store.dart';
import 'package:pipecheck/core/services/share_service.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/data/definitions/badge.dart';
import 'package:pipecheck/data/generated/models/badge.model.dart';
import 'package:pipecheck/data/generated/models/user.model.dart';
import 'package:pipecheck/data/generated/repositories/badge.repository.dart';
import 'package:pipecheck/data/generated/repositories/user.repository.dart';
import 'package:pipecheck/features/settings/views/settings_view.dart';

import '../../support/fake_snackbar.dart';
import '../../support/orange_harness.dart';

class _BadgeRepo extends Fake implements BadgeRepository {
  _BadgeRepo(this.items);
  List<BadgeModel> items;
  bool hideFromLookup = false;
  final deleted = <int>[];
  final updated = <BadgeModel>[];
  final created = <BadgeModel>[];

  @override
  Future<List<BadgeModel>> getAll() async => items;
  @override
  Future<List<BadgeModel>> findByField(String field, dynamic value) async =>
      hideFromLookup ? [] : items.where((b) => field == 'badge_id' && b.badgeId == value).toList();
  @override
  Future<BadgeModel?> getById(int id) async => items.where((b) => b.id == id).firstOrNull;
  @override
  Future<BadgeModel> update(BadgeModel model) async {
    updated.add(model);
    return model;
  }

  @override
  Future<BadgeModel> create(BadgeModel model) async {
    created.add(model);
    return model;
  }

  @override
  Future<bool> delete(int id) async {
    deleted.add(id);
    return true;
  }
}

class _UserRepo extends Fake implements UserRepository {
  final deleted = <String>[];
  @override
  Future<List<UserModel>> getAll() async => [UserModel(id: 'u1', email: 'a@b.c')];
  @override
  Future<bool> delete(String id) async {
    deleted.add(id);
    return true;
  }
}

class _BadgeService extends Fake implements BadgeService {
  final notified = <BadgeModel>[];
  @override
  Future<void> updateAndNotify(BadgeModel badge) async => notified.add(badge);
}

class _Share extends Fake implements ShareService {
  final files = <String>[];
  @override
  Future<void> shareFile(String path, {String? subject, String? text}) async => files.add(path);
}

class _Export extends Fake implements DataExportService {
  bool fail = false;
  @override
  Future<String> exportToFile({DateTime? timestamp}) async {
    if (fail) throw StateError('disk full');
    return '/tmp/export.json';
  }
}

class _Restore extends Fake implements RestoreService {
  Object? error;
  String? got;
  @override
  Future<RestoreSummary> restoreFromJson(String jsonString) async {
    got = jsonString;
    if (error != null) throw error!;
    return const RestoreSummary(inserted: 3, skipped: 1);
  }
}

class _Picker extends FilePicker with MockPlatformInterfaceMixin {
  String? path;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      path == null ? null : FilePickerResult([PlatformFile(name: 'b.json', size: 1, path: path)]);
}

class _Auth extends AuthStateNotifier {
  static bool result = true;
  @override
  Future<bool> deleteAccount() async => result;
}

class _Store implements SecureStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

BadgeModel _badge(int id, {bool achieved = false}) => BadgeModel(
      id: id,
      badgeId: 'achievement_count_1',
      title: 'Beginner',
      description: 'd',
      iconPath: 'p',
      isAchieved: achieved,
      type: BadgeType.values.first,
      condition: '{}',
    );

late Directory Function() _dirOf;
Directory get _dir => _dirOf();
late FakeSnack snack;
late _BadgeRepo badges;
late _UserRepo users;
late _BadgeService badgeService;
late _Share share;
late _Export export;
late _Restore restore;
late _Picker picker;
late ProviderContainer container;
late List<String> pushed;

void _flags() {
  AppFeatureConfig.isDarkModeEnabled = true;
  AppFeatureConfig.isMultiLanguageEnabled = true;
  AppFeatureConfig.isAuthenticationEnabled = true;
  AppFeatureConfig.isBiometricAuthEnabled = true;
  AppFeatureConfig.isPinAuthEnabled = true;
  AppFeatureConfig.isNotificationEnabled = false;
  AppFeatureConfig.isReminderEnabled = false;
  AppFeatureConfig.isAccountDeletionEnabled = true;
  AppFeatureConfig.isEmailAuthEnabled = true;
  AppFeatureConfig.isDataExportEnabled = true;
  AppFeatureConfig.isBackupRestoreEnabled = true;
  AppFeatureConfig.isAdsEnabled = false;
}

Future<void> _pump(WidgetTester tester, {PinService? pin, Settings? initial, Size size = const Size(900, 12000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (initial != null) await initial.saveToOrange();
  pushed = [];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SettingsView()),
      GoRoute(
        path: '/settings/pin',
        builder: (ctx, _) => Scaffold(
          body: Column(children: [
            TextButton(onPressed: () => ctx.pop(true), child: const Text('pin-done')),
            TextButton(onPressed: () => ctx.pop(), child: const Text('pin-cancel')),
          ]),
        ),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const Scaffold(body: Text('onboarding-page'))),
      GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home-page'))),
      GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('login-page'))),
      GoRoute(path: '/settings/feature-config', builder: (_, _) => const Scaffold(body: Text('feature-config-page'))),
    ],
  );
  container = ProviderContainer(overrides: [
    snackBarServiceProvider.overrideWithValue(snack),
    badgeRepositoryProvider.overrideWithValue(badges),
    userRepositoryProvider.overrideWithValue(users),
    badgeServiceProvider.overrideWithValue(badgeService),
    shareServiceProvider.overrideWithValue(share),
    dataExportServiceProvider.overrideWithValue(export),
    restoreServiceProvider.overrideWithValue(restore),
    pinServiceProvider.overrideWithValue(pin ?? PinService(_Store())),
    authStateProvider.overrideWith(_Auth.new),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// badges.json은 실제 에셋 I/O로 읽으므로 가짜 시계 밖에서 잠깐 기다린다.
Future<void> _io(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump();
}

/// 복원 확인 버튼 — 파일 읽기는 실제 I/O라 실제 시계 안에서 눌러야 끝난다.
Future<void> _confirmRestore(WidgetTester tester) async {
  final f = find.text('backup.restoreAction').last;
  await tester.runAsync(() async {
    await tester.tap(f);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _io(tester);
}

Finder _t(String s) => find.text(s);

void main() {
  _dirOf = setUpOrange('settings_view_test');

  setUpAll(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), (call) async => {
          'appName': 'app',
          'packageName': 'pkg',
          'version': '1.2.3',
          'buildNumber': '4',
        });
    // 첫 파일 I/O는 느려서(워커 기동) 복원 테스트가 시간 안에 못 끝날 수 있다 — 미리 데워 둔다.
    await File('${_dir.path}/warm').writeAsString('x');
    await File('${_dir.path}/warm').readAsString();
    dotenv.loadFromString(envString: 'TEST=1');
  });

  setUp(() async {
    // 에셋 문자열 캐시가 이전 테스트의 가짜 시계에 묶인 채 남지 않게 한다.
    rootBundle.evict('assets/data/badges.json');
    AppConfig.debugSetConfig({'MONTHLY': 'm', 'YEARLY': 'y', 'LIFETIME': 'l'});
    _flags();
    snack = FakeSnack();
    badges = _BadgeRepo([_badge(1), _badge(2, achieved: true)]);
    users = _UserRepo();
    badgeService = _BadgeService();
    share = _Share();
    export = _Export();
    restore = _Restore();
    picker = _Picker();
    FilePicker.platform = picker;
    _Auth.result = true;
    await Settings.initial().saveToOrange();
  });

  tearDown(() => devOverrideAllowed = kDebugMode);

  group('구독 상태', () {
    testWidgets('권리가 없으면 구독/복원 버튼과 프리미엄 전용 표시, 버전은 패키지 정보에서 온다', (tester) async {
      await _pump(tester);
      expect(_t('Subscribe'), findsOneWidget);
      expect(_t('Restore Purchase'), findsOneWidget);
      expect(_t('Premium only'), findsNWidgets(2));
      expect(_t('v1.2.3'), findsOneWidget);
    });

    testWidgets('평생 구매자는 Lifetime 한 줄만 보이고 구독 버튼이 없다', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(hasLifetime: true));
      expect(_t('Lifetime'), findsOneWidget);
      expect(_t('Subscribe'), findsNothing);
      expect(_t('Premium only'), findsNothing);
    });

    testWidgets('열린 구독(Google Play)은 날짜 없이 Active', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(subscriptionOpenEnded: true));
      expect(_t('Active'), findsOneWidget);
      expect(_t('Active until {}'), findsNothing);
    });

    testWidgets('만료일이 있는 구독은 그 날짜를 보여 준다', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(subscriptionExpiryDate: DateTime(2099, 11, 8)));
      expect(find.textContaining('2099-11-08'), findsOneWidget);
    });

    testWidgets('3일 유예 중(만료일이 이미 지남)에는 지난 날짜를 보이지 않고 Active만 보인다', (tester) async {
      final past = DateTime.now().subtract(const Duration(days: 1));
      await _pump(tester, initial: Settings.initial().copyWith(subscriptionExpiryDate: past));
      expect(_t('Active'), findsOneWidget);
      expect(find.textContaining('Active until'), findsNothing);
      expect(find.textContaining(DateFormat('yyyy-MM-dd').format(past)), findsNothing);
    });

    testWidgets('Subscribe와 프리미엄 전용 버튼은 구독 시트를 연다', (tester) async {
      await _pump(tester, size: const Size(900, 1800));
      await _tap(tester, _t('Subscribe'));
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('IAP가 꺼져 있으면 복원 버튼은 아무 일도 하지 않는다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Restore Purchase'));
      expect(tester.takeException(), isNull);
    });
  });

  group('개발 프리미엄 토글', () {
    testWidgets('Toggle Purchase는 devPremium만 뒤집고 실제 권리는 건드리지 않는다', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(hasLifetime: true));
      await _tap(tester, _t('Toggle Purchase'));
      var s = container.read(settingsProvider);
      expect(s.devPremium, isTrue);
      expect(s.hasLifetime, isTrue);
      await _tap(tester, _t('Toggle Purchase'));
      s = container.read(settingsProvider);
      expect(s.devPremium, isFalse);
      expect(s.hasLifetime, isTrue, reason: '끄기가 진짜 평생 권리를 지우면 안 된다');
    });

    testWidgets('켜면(허용 빌드) 프리미엄 전용 UI가 열린다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Toggle Purchase'));
      expect(_t('Premium only'), findsNothing);
    });

    testWidgets('허용 안 된 빌드에선 켜 둬도 그대로 잠겨 있다', (tester) async {
      devOverrideAllowed = false;
      await _pump(tester);
      await _tap(tester, _t('Toggle Purchase'));
      expect(container.read(settingsProvider).devPremium, isTrue);
      expect(_t('Premium only'), findsNWidgets(2));
    });
  });

  group('프리미엄 설정', () {
    Settings premium() => Settings.initial().copyWith(hasLifetime: true);

    testWidgets('다크 모드·테마 색을 고르면 설정에 저장된다', (tester) async {
      await _pump(tester, initial: premium());
      await _tap(tester, find.byType(DropdownButton<ThemeMode>));
      await _tap(tester, _t('Dark').last);
      expect(container.read(settingsProvider).displayMode, ThemeMode.dark);

      await _tap(tester, find.byType(DropdownButton<String>).first);
      final items = find.byType(DropdownMenuItem<String>);
      await _tap(tester, items.last);
      expect(container.read(settingsProvider).themeColor, isNot('blue'));
    });

    testWidgets('디자인 시스템 드롭다운도 설정을 바꾼다', (tester) async {
      await _pump(tester, initial: premium());
      final dd = find.byType(DropdownButton<DesignSystemType>);
      await _tap(tester, dd);
      final other = DesignSystemType.values.firstWhere((t) => t != DesignSystemType.material3);
      await _tap(tester, find.text(other.displayName).last);
      expect(container.read(settingsProvider).designSystem, other);
    });
  });

  group('앱 잠금', () {
    testWidgets('PIN이 없으면 설정 화면으로 보내고, 완료하면 방식을 바꾼다', (tester) async {
      await _pump(tester);
      await _tap(tester, find.byType(DropdownButton<UserAuthOption>));
      await _tap(tester, _t('auth.pin.lockPin').last);
      expect(_t('pin-done'), findsOneWidget);
      await _tap(tester, _t('pin-done'));
      expect(container.read(settingsProvider).userAuthOption, UserAuthOption.pin);
      expect(_t('auth.pin.changeAction'), findsOneWidget);
    });

    testWidgets('PIN 설정을 취소(pop)하면 방식이 바뀌지 않는다', (tester) async {
      await _pump(tester);
      await _tap(tester, find.byType(DropdownButton<UserAuthOption>));
      await _tap(tester, _t('auth.pin.lockPin').last);
      await _tap(tester, _t('pin-cancel'));
      expect(container.read(settingsProvider).userAuthOption, UserAuthOption.none);
    });

    testWidgets('이미 PIN이 있으면 바로 바뀌고, 없음으로 되돌릴 수 있다', (tester) async {
      final store = _Store();
      final pin = PinService(store);
      await pin.setPin('123456');
      await _pump(tester, pin: pin);
      await _tap(tester, find.byType(DropdownButton<UserAuthOption>));
      await _tap(tester, _t('auth.pin.lockPinBiometric').last);
      expect(container.read(settingsProvider).userAuthOption, UserAuthOption.biometric);

      await _tap(tester, find.byType(DropdownButton<UserAuthOption>));
      await _tap(tester, _t('auth.pin.lockNone').last);
      expect(container.read(settingsProvider).userAuthOption, UserAuthOption.none);
    });

    testWidgets('PIN 기능이 꺼진 포크의 생체 전용 라벨', (tester) async {
      AppFeatureConfig.isPinAuthEnabled = false;
      await _pump(tester, initial: Settings.initial().copyWith(userAuthOption: UserAuthOption.biometric));
      expect(_t('auth.pin.lockBiometric'), findsOneWidget);
    });

    testWidgets('PIN 변경 버튼은 PIN 화면으로 이동한다', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(userAuthOption: UserAuthOption.pin));
      await _tap(tester, _t('auth.pin.changeAction'));
      expect(_t('pin-done'), findsOneWidget);
    });
  });

  group('언어·안내·리뷰', () {
    testWidgets('언어 드롭다운은 지원 언어의 원어 이름을 보여 준다', (tester) async {
      await _pump(tester);
      expect(find.byType(DropdownButton<Locale>), findsOneWidget);
      expect(_t('English (United States)'), findsOneWidget);
    });

    testWidgets('사용 안내 다시 보기는 온보딩을 다시 켜고 이동한다', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(onBoard: true));
      await _tap(tester, _t('View Again'));
      expect(container.read(settingsProvider).onBoard, isFalse);
      expect(_t('onboarding-page'), findsOneWidget);
    });

    testWidgets('이용약관·개인정보 링크와 평점 버튼은 플러그인이 없어도 터지지 않는다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Terms of Use'));
      await _tap(tester, _t('Privacy Policy'));
      expect(tester.takeException(), isNull);
    });
  });

  group('디버그 도구', () {
    testWidgets('Feature Configuration으로 이동한다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Open'));
      expect(_t('feature-config-page'), findsOneWidget);
    });

    testWidgets('뱃지 목록: 켜면 지급하고 끄면 회수한다', (tester) async {
      await _pump(tester);
      expect(_t('Beginner'), findsNWidgets(2));
      final switches = find.byType(Switch);
      // 뱃지 스위치는 목록의 마지막 두 개 (1번 미획득, 2번 획득).
      await _tap(tester, switches.at(switches.evaluate().length - 2));
      await _io(tester);
      expect(badges.updated.where((b) => b.isAchieved), isNotEmpty);
      expect(badgeService.notified, isNotEmpty);
      expect(snack.log.last, startsWith('success:'));

      await _tap(tester, switches.at(switches.evaluate().length - 1));
      await _io(tester);
      expect(badges.updated.where((b) => !b.isAchieved), isNotEmpty);
      expect(snack.log.last, "success:Badge '2' removed");
    });

    testWidgets('DB에 없는 뱃지는 새로 만든다', (tester) async {
      // 목록에는 보이지만 badge_id 조회로는 못 찾는 상태(아직 DB에 없는 뱃지).
      badges = _BadgeRepo([_badge(9)])..hideFromLookup = true;
      await _pump(tester);
      final switches = find.byType(Switch);
      await _tap(tester, switches.at(switches.evaluate().length - 1));
      await _io(tester);
      expect(badges.created.single.condition, '{"count":1}');
      expect(badges.created.single.isAchieved, isTrue);
    });

    testWidgets('뱃지가 하나도 없으면 안내 문구', (tester) async {
      badges = _BadgeRepo([]);
      await _pump(tester);
      expect(_t('No badge data'), findsOneWidget);
    });

    testWidgets('데이터베이스 지우기: 확인하면 뱃지와 사용자를 모두 지우고 홈으로 간다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Clear Database'));
      await _tap(tester, _t('Clear'));
      expect(badges.deleted, [1, 2]);
      expect(users.deleted, ['u1']);
      expect(snack.log.last, startsWith('success:'));
      expect(_t('home-page'), findsOneWidget);
    });

    testWidgets('데이터베이스 지우기: 취소하면 아무것도 지우지 않는다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Clear Database'));
      await _tap(tester, _t('Cancel'));
      expect(badges.deleted, isEmpty);
    });
  });

  group('계정 삭제', () {
    testWidgets('성공하면 로그인으로 이동', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Delete Account').last);
      await _tap(tester, _t('Delete'));
      expect(snack.log.last, startsWith('success:'));
      expect(_t('login-page'), findsOneWidget);
    });

    testWidgets('실패하면 오류 알림만', (tester) async {
      _Auth.result = false;
      await _pump(tester);
      await _tap(tester, _t('Delete Account').last);
      await _tap(tester, _t('Delete'));
      expect(snack.log.last, startsWith('error:'));
      expect(_t('login-page'), findsNothing);
    });

    testWidgets('취소하면 호출하지 않는다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Delete Account').last);
      await _tap(tester, _t('Cancel'));
      expect(snack.log, isEmpty);
    });
  });

  group('내보내기·백업', () {
    testWidgets('내보내기는 파일을 만들어 공유한다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Export'));
      expect(share.files, ['/tmp/export.json']);
    });

    testWidgets('내보내기 실패는 오류 알림', (tester) async {
      export.fail = true;
      await _pump(tester);
      await _tap(tester, _t('Export'));
      expect(share.files, isEmpty);
      expect(snack.log.last, startsWith('error:'));
    });

    testWidgets('백업은 파일을 공유하고, 실패하면 백업 오류 알림', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('backup.backupAction'));
      expect(share.files, ['/tmp/export.json']);

      export.fail = true;
      await _tap(tester, _t('backup.backupAction'));
      expect(snack.log.last, 'error:backup.backupError');
    });
  });

  group('백업 복원', () {
    late File backup;
    setUp(() {
      backup = File('${_dir.path}/backup.json')..writeAsStringSync('{"tables":{}}');
    });

    Future<void> startRestore(WidgetTester tester) async {
      await _pump(tester);
      await _tap(tester, _t('backup.restoreAction').first);
    }

    testWidgets('파일을 고르고 확인하면 복원하고 결과 개수를 알린다', (tester) async {
      picker.path = backup.path;
      await startRestore(tester);
      await _confirmRestore(tester);
      expect(restore.got, '{"tables":{}}');
      expect(snack.log.last, startsWith('success:backup.restoreSuccess'));
    });

    testWidgets('파일 선택을 취소하면 아무것도 하지 않는다', (tester) async {
      picker.path = null;
      await startRestore(tester);
      expect(restore.got, isNull);
      expect(find.text('backup.confirmTitle'), findsNothing);
    });

    testWidgets('확인 창에서 취소하면 복원하지 않는다', (tester) async {
      picker.path = backup.path;
      await startRestore(tester);
      await _tap(tester, _t('common.cancel'));
      expect(restore.got, isNull);
    });

    testWidgets('백업 파일이 아니면(FormatException) 형식 오류, 그 밖의 실패는 일반 오류', (tester) async {
      picker.path = backup.path;
      restore.error = const FormatException('bad');
      await startRestore(tester);
      await _confirmRestore(tester);
      expect(snack.log.last, 'error:backup.restoreError');

      restore.error = StateError('db');
      await _tap(tester, _t('backup.restoreAction').first);
      await _confirmRestore(tester);
      expect(snack.log.last, 'error:backup.restoreFailed');
    });
  });

  group('알림·리마인더', () {
    var allowed = true;
    setUp(() {
      allowed = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('awesome_notifications'),
        (call) async => call.method == 'isNotificationAllowed' ? allowed : null,
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('awesome_notifications'), null);
    });

    testWidgets('알림 스위치를 켜면 테스트 알림 버튼이 생기고 보내면 성공 알림, 끄면 사라진다', (tester) async {
      AppFeatureConfig.isNotificationEnabled = true;
      await _pump(tester);
      expect(_t('Test Notification'), findsNothing);
      final sw = find.byType(Switch).first;
      await _tap(tester, sw);
      expect(container.read(settingsProvider).useNotification, isTrue);
      await _tap(tester, _t('Test Notification'));
      expect(snack.log.last, startsWith('success:'));
      await _tap(tester, sw);
      expect(container.read(settingsProvider).useNotification, isFalse);
      expect(_t('Test Notification'), findsNothing);
    });

    testWidgets('권한이 없으면 요청한 뒤 켠다', (tester) async {
      allowed = false;
      AppFeatureConfig.isNotificationEnabled = true;
      await _pump(tester);
      await _tap(tester, find.byType(Switch).first);
      expect(container.read(settingsProvider).useNotification, isTrue);
    });

    testWidgets('리마인더: 스위치로 켜고 끄며, 켜면 시간 선택(머티리얼)이 열린다', (tester) async {
      AppFeatureConfig.isReminderEnabled = true;
      await _pump(tester);
      expect(_t('Select Time'), findsNothing);
      await _tap(tester, find.byType(Switch).first);
      expect(container.read(settingsProvider).useReminder, isTrue);

      final timeButton = find.descendant(of: find.byType(ElevatedButton), matching: find.textContaining(RegExp(r'\d')));
      await _tap(tester, timeButton.first);
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await _tap(tester, _t('OK'));
      expect(find.byType(TimePickerDialog), findsNothing);

      await _tap(tester, find.byType(Switch).first);
      expect(container.read(settingsProvider).useReminder, isFalse);
    });

    testWidgets('리마인더 시간 선택(iOS): 확인하면 저장, 취소하면 그대로', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AppFeatureConfig.isReminderEnabled = true;
      await _pump(tester, initial: Settings.initial().copyWith(useReminder: true, reminderTime: const TimeOfDay(hour: 9, minute: 5)));
      final timeButton = find.text('9:05 AM');
      await _tap(tester, timeButton);
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await _tap(tester, _t('common.cancel'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(container.read(settingsProvider).reminderTime, const TimeOfDay(hour: 9, minute: 5));

      await _tap(tester, timeButton);
      await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 500));
      await _tap(tester, _t('common.confirm'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(container.read(settingsProvider).reminderTime, isNot(const TimeOfDay(hour: 9, minute: 5)),
          reason: '휠을 돌린 값이 저장돼야 한다');
      debugDefaultTargetPlatformOverride = null; // 테스트 불변식 검사는 tearDown보다 먼저 돈다
    });

    testWidgets('디버그 알림 도구는 알림이 꺼진 상태에서도 터지지 않는다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Remove All Notification'));
      await _tap(tester, _t('List Channel'));
      await _tap(tester, _t('List Notification'));
      expect(tester.takeException(), isNull);
    });
  });

  group('뱃지 지급 실패', () {
    testWidgets('badges.json에 없는 뱃지는 오류 알림', (tester) async {
      badges = _BadgeRepo([_badge(1).copyWith(badgeId: 'no_such_badge')]);
      await _pump(tester);
      final switches = find.byType(Switch);
      await _tap(tester, switches.at(switches.evaluate().length - 1));
      await _io(tester);
      expect(snack.log.last, startsWith('error:'));
    });
  });
}
