import 'dart:convert';
import 'dart:math';

import 'package:boilerplate/core/services/secure_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PIN 길이 (단일 출처). 자릿수 변경은 여기 한 곳만.
const int kPinLength = 6;

/// PIN 검증 결과 종류.
enum PinVerifyOutcome {
  /// PIN 일치.
  success,

  /// PIN 불일치 (아직 잠금 전).
  wrong,

  /// 시도 제한 초과로 잠금 중.
  lockedOut,

  /// 설정된 PIN이 없음.
  noPin,
}

/// [PinService.verifyPin] 결과.
class PinVerifyResult {
  const PinVerifyResult(
    this.outcome, {
    this.attemptsRemaining = 0,
    this.lockRemaining,
  });

  final PinVerifyOutcome outcome;

  /// [PinVerifyOutcome.wrong]일 때 다음 잠금까지 남은 시도 횟수.
  final int attemptsRemaining;

  /// [PinVerifyOutcome.lockedOut]일 때 잠금 해제까지 남은 시간.
  final Duration? lockRemaining;

  bool get isSuccess => outcome == PinVerifyOutcome.success;
}

/// 로컬 PIN 인증 엔진 (P2-23h).
///
/// 서버 0줄 원칙(backend-direction)에 따라 PIN과 시도 제한 상태를 전부
/// [SecureStore](flutter_secure_storage)에 둔다.
///
/// 저장 형식: PIN은 평문이 아니라 per-install salt + SHA-256 해시로 저장한다.
/// 다만 6자리 PIN은 키 공간이 작아(10^6) 저장소가 통째로 유출되면 해시는
/// 사실상 오프라인 무차별 대입에 취약하다 — 실질 방어선은 (1) Keychain/
/// Keystore의 저장소 암호화와 (2) 아래 점진 잠금(온라인 시도 제한)이다.
/// 해시는 평문 노출/우발적 로깅을 막는 심층 방어 한 겹이다.
///
/// 잠금 정책(사용자 결정): 연속 5회 실패마다 잠그고, 배치마다 잠금 시간이
/// 길어진다(30s → 1m → 5m → 15m → 30m 상한). 에스컬레이션 레벨은 성공할
/// 때만 초기화되므로, 기기 시계를 앞당겨 쿨다운을 건너뛰어도 다음 잠금이
/// 더 길어진다(시계 조작에 대한 점근적 방어). 시계를 되돌리는 경우는
/// effectiveNow = max(now, lastAttempt)로 막는다.
class PinService {
  PinService(this._store, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final SecureStore _store;
  final DateTime Function() _now;

  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _kFail = 'pin_fail_count';
  static const _kLevel = 'pin_lock_level';
  static const _kUntil = 'pin_lock_until'; // epoch ms
  static const _kLast = 'pin_last_attempt'; // epoch ms (시계 되돌림 가드)
  static const _kLegacy = 'pin_code'; // 23h 이전 평문 (제거 대상)

  static const int _maxAttempts = 5;
  static const List<Duration> _lockDurations = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  /// 6자리 숫자 형식 여부.
  bool isValidFormat(String pin) =>
      pin.length == kPinLength && RegExp(r'^\d+$').hasMatch(pin);

  /// 설정된 PIN 존재 여부.
  Future<bool> hasPin() async => (await _store.read(_kHash)) != null;

  /// PIN 설정/재설정. 시도 제한 상태도 초기화한다.
  Future<void> setPin(String pin) async {
    if (!isValidFormat(pin)) {
      throw ArgumentError('PIN must be $kPinLength digits');
    }
    final salt = _generateSalt();
    await _store.write(_kSalt, salt);
    await _store.write(_kHash, _hash(pin, salt));
    await _resetAttempts();
    await _store.delete(_kLegacy);
  }

  /// PIN 검증. 잠금 정책과 시도 카운트를 갱신한다.
  Future<PinVerifyResult> verifyPin(String pin) async {
    final hash = await _store.read(_kHash);
    final salt = await _store.read(_kSalt);
    if (hash == null || salt == null) {
      return const PinVerifyResult(PinVerifyOutcome.noPin);
    }

    final lock = await _currentLock();
    if (lock != null) {
      return PinVerifyResult(PinVerifyOutcome.lockedOut, lockRemaining: lock);
    }

    await _store.write(_kLast, '${_now().millisecondsSinceEpoch}');

    if (_hash(pin, salt) == hash) {
      await _resetAttempts();
      return const PinVerifyResult(PinVerifyOutcome.success);
    }

    final fail = (int.tryParse(await _store.read(_kFail) ?? '0') ?? 0) + 1;
    if (fail >= _maxAttempts) {
      final level = int.tryParse(await _store.read(_kLevel) ?? '0') ?? 0;
      final dur = _lockDurations[level.clamp(0, _lockDurations.length - 1)];
      await _store.write(_kUntil, '${_now().add(dur).millisecondsSinceEpoch}');
      await _store.write(_kLevel, '${level + 1}');
      await _store.write(_kFail, '0');
      return PinVerifyResult(PinVerifyOutcome.lockedOut, lockRemaining: dur);
    }

    await _store.write(_kFail, '$fail');
    return PinVerifyResult(
      PinVerifyOutcome.wrong,
      attemptsRemaining: _maxAttempts - fail,
    );
  }

  /// 기존 PIN을 확인하고 새 PIN으로 변경. 성공 여부 반환.
  Future<bool> changePin(String oldPin, String newPin) async {
    final r = await verifyPin(oldPin);
    if (!r.isSuccess) return false;
    await setPin(newPin);
    return true;
  }

  /// PIN과 모든 시도 제한 상태 제거.
  Future<void> clearPin() async {
    for (final k in [_kHash, _kSalt, _kFail, _kLevel, _kUntil, _kLast, _kLegacy]) {
      await _store.delete(k);
    }
  }

  /// 시도 소모 없이 현재 잠금 잔여 시간 조회 (null = 잠금 없음).
  Future<Duration?> lockRemaining() => _currentLock();

  // ── 내부 ──────────────────────────────────────────────────────────

  Future<Duration?> _currentLock() async {
    final untilStr = await _store.read(_kUntil);
    final until = untilStr == null ? null : int.tryParse(untilStr);
    if (until == null) return null;

    // 시계 되돌림 가드: 실제 경과보다 잠금이 짧아지지 않게 한다.
    final lastMs = int.tryParse(await _store.read(_kLast) ?? '0') ?? 0;
    final nowMs = _now().millisecondsSinceEpoch;
    final effectiveNow = nowMs < lastMs ? lastMs : nowMs;

    final remainingMs = until - effectiveNow;
    if (remainingMs <= 0) {
      await _store.delete(_kUntil); // 레벨(_kLevel)은 유지 — 성공 시에만 초기화
      return null;
    }
    return Duration(milliseconds: remainingMs);
  }

  Future<void> _resetAttempts() async {
    for (final k in [_kFail, _kLevel, _kUntil, _kLast]) {
      await _store.delete(k);
    }
  }

  String _generateSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}

/// PinService Provider (프로덕션은 flutter_secure_storage 백엔드).
final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(const FlutterSecureStore()),
);
