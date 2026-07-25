import 'package:flutter_test/flutter_test.dart';
import 'package:positioning/positioning.dart';

void main() {
  // 비활성 config 경로는 geolocator 플랫폼 채널을 건드리지 않고 조기 반환한다.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationConfig', () {
    test('disabled()는 locationEnabled false', () {
      expect(const LocationConfig.disabled().locationEnabled, isFalse);
    });

    test('config 값 보존', () {
      expect(const LocationConfig(locationEnabled: true).locationEnabled, isTrue);
    });
  });

  group('LocationService (비활성 config — 플랫폼 미접촉)', () {
    setUp(() {
      LocationService.configure(const LocationConfig.disabled());
    });

    test('싱글톤', () {
      expect(identical(LocationService(), LocationService()), isTrue);
    });

    test('getCurrentPosition은 null', () async {
      expect(await LocationService().getCurrentPosition(), isNull);
    });

    test('getLastKnownPosition은 null', () async {
      expect(await LocationService().getLastKnownPosition(), isNull);
    });

    test('positionStream은 빈 스트림', () async {
      expect(await LocationService().positionStream().isEmpty, isTrue);
    });
  });
}
