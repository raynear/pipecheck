import 'package:biometric_auth/biometric_auth.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

/// 사용자 인증을 처리하는 서비스 클래스입니다.
///
/// 일반 인증과 생체 인증(지문, Face ID 등)을 지원합니다.
/// 인증 상태는 authStateProvider에서 관리합니다.
class AuthenticationService {
  /// 일반 인증을 수행합니다.
  ///
  /// Returns: 인증 성공 여부 (true: 성공, false: 실패)
  Future<bool> authenticate() async {
    if (!AppFeatureConfig.isAuthenticationEnabled) {
      logger.d('Authentication is disabled by AppFeatureConfig');
      return true;
    }

    return await Authentication().authenticate();
  }

  /// 생체 인증을 수행합니다.
  ///
  /// Returns: 인증 성공 여부 (true: 성공, false: 실패)
  Future<bool> authenticateWithBiometrics() async {
    if (!AppFeatureConfig.isAuthenticationEnabled || !AppFeatureConfig.isBiometricAuthEnabled) {
      logger.d('Biometric authentication is disabled by AppFeatureConfig');
      return true;
    }

    return await Authentication().authenticateWithBiometrics();
  }

  /// 기기에서 생체 인증을 실제로 쓸 수 있는지 (등록된 생체 정보 존재 여부 포함).
  ///
  /// PIN 분실 복구(P2-23h ③)에서 생체 복구 티어를 보여줄지 판단한다.
  Future<bool> canUseBiometrics() async {
    if (!AppFeatureConfig.isAuthenticationEnabled || !AppFeatureConfig.isBiometricAuthEnabled) {
      return false;
    }
    try {
      final auth = Authentication();
      await auth.initialize();
      return (auth.canCheckBiometrics ?? false) && (auth.availableBiometrics?.isNotEmpty ?? false);
    } catch (_) {
      return false;
    }
  }
}

/// AuthenticationService Provider
final authenticationServiceProvider = Provider<AuthenticationService>((ref) {
  return AuthenticationService();
});
