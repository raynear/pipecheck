/// 위치(positioning) 엔진 (앱-무관, opt-in).
///
/// `geolocator` 래퍼 [LocationService](권한 + 현재 위치 + 위치 스트림)를 제공한다.
/// 위치를 쓰지 않는 포크는 이 패키지 의존을 제거하면 geolocator 네이티브가
/// 바이너리에 링크되지 않는다 (dependency 경계로 opt-in).
///
/// `geolocator`의 [LocationPermission]·[Position]·[LocationAccuracy]·
/// [LocationSettings]를 재노출해 앱이 geolocator를 직접 import하지 않아도 된다.
library;

export 'package:geolocator/geolocator.dart'
    show LocationPermission, Position, LocationAccuracy, LocationSettings;

export 'src/location_config.dart';
export 'src/location_service.dart';
