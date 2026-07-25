// RemoteConfigService 엔진은 firebase_services 패키지로 이전됨 (P2-20c).
// 이 파일은 앱 바인딩 — 패키지의 클래스를 재노출하고 Riverpod provider를
// 앱에 유지한다 (provider 바인딩은 앱 책임, 패키지는 firebase 무관 엔진).
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:firebase_services/firebase_services.dart'
    show RemoteConfigService;

// Provider
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService.instance;
});

// Example usage providers
final subscriptionVariantProvider = Provider<String>((ref) {
  final service = ref.watch(remoteConfigServiceProvider);
  return service.subscriptionVariant;
});
