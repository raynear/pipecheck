import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:utils/utils.dart';

enum SupportState {
  unknown,
  supported,
  unsupported,
}

enum AuthorizeState {
  authorized,
  notAuthorized,
  authenticating,
  error,
}

class Authentication {
  Authentication._internal();
  static final Authentication _instance = Authentication._internal();
  factory Authentication() {
    return _instance;
  }

  final LocalAuthentication auth = LocalAuthentication();
  SupportState supportState = SupportState.unknown;
  bool? canCheckBiometrics;
  List<BiometricType>? availableBiometrics;
  AuthorizeState authorized = AuthorizeState.notAuthorized;
  bool isAuthenticating = false;

  @override
  dynamic noSuchMethod(Invocation invocation) async {
    await initialize();
    return Function.apply(
      noSuchMethod,
      [invocation],
      invocation.namedArguments,
    );
  }

  Future<void> initialize() async {
    final isSupported = await auth.isDeviceSupported();
    supportState = isSupported ? SupportState.supported : SupportState.unsupported;
    await checkBiometrics();
    await getAvailableBiometrics();
  }

  Future<void> checkBiometrics() async {
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      canCheckBiometrics = false;
      logger.e(e);
    }
  }

  Future<void> getAvailableBiometrics() async {
    try {
      availableBiometrics = await auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      availableBiometrics = <BiometricType>[];
      logger.e(e);
    }
  }

  Future<bool> authenticate() async {
    bool authenticated = false;
    try {
      isAuthenticating = true;
      authorized = AuthorizeState.authenticating;
      authenticated = await auth.authenticate(
        localizedReason: 'Let OS determine authentication method',
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
      isAuthenticating = false;
    } on PlatformException catch (e) {
      logger.e(e);
      isAuthenticating = false;
      authorized = AuthorizeState.error;
      return false;
    }

    authorized = authenticated ? AuthorizeState.authorized : AuthorizeState.notAuthorized;

    return authenticated;
  }

  Future<bool> authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      isAuthenticating = true;
      authorized = AuthorizeState.authenticating;
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint (or face or whatever) to authenticate',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      isAuthenticating = false;
      authorized = AuthorizeState.authenticating;
    } on PlatformException catch (e) {
      logger.e(e);
      isAuthenticating = false;
      authorized = AuthorizeState.error;
      return false;
    }

    authorized = authenticated ? AuthorizeState.authorized : AuthorizeState.notAuthorized;

    return authenticated;
  }

  Future<void> cancelAuthentication() async {
    await auth.stopAuthentication();
    isAuthenticating = false;
  }
}
