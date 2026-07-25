import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 보안 키-값 저장소 추상화.
///
/// [PinService] 등 보안 민감 로직이 flutter_secure_storage 플러그인에 직접
/// 결합하지 않도록 최소 인터페이스만 노출한다. 단위 테스트는 인메모리 가짜
/// 구현으로 플러그인 없이 검증한다 (P2-23h).
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// flutter_secure_storage 기반 [SecureStore] 구현.
///
/// 플랫폼 옵션을 보안 기본값으로 고정한다:
/// - Android: 기본 custom-cipher 암호화(v10 기본 — 구 EncryptedSharedPreferences
///   파라미터는 v10에서 deprecated되어 무시되므로 지정하지 않는다).
/// - iOS: 최초 잠금 해제 후 접근 가능 + 기기 한정(다른 기기로 동기화 금지).
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore([
    this._storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
