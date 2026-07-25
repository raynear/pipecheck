import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyLastSeenVersion = 'whats_new_last_seen_version';

/// 업데이트 후 '새로운 기능' 다이얼로그를 1회 띄울지 판단하는 서비스 (P2-24).
///
/// **마이너 이상** 버전 변경(1.1→1.2, 2.0 등)에만 표시하고 패치(1.2.0→1.2.1)는
/// 건너뛴다(사용자 결정). 서버 코드 0줄: 마지막으로 본 버전은 로컬
/// SharedPreferences에 저장한다. 콘텐츠는 i18n `whatsNew.*` 키(앱이 버전 올릴 때
/// 갱신)다 — 이 서비스는 '언제 띄울지'만 결정한다([WhatsNewDialog]가 표시 담당).
///
/// 능력만 주입받아([readVersion]/[readLastSeen]/[writeLastSeen]) 플러그인 없이
/// 단위 테스트한다.
class WhatsNewService {
  WhatsNewService({
    required this.readVersion,
    required this.readLastSeen,
    required this.writeLastSeen,
  });

  /// 현재 앱 버전 ("1.2.0" — 빌드 메타 `+N`은 무시).
  final Future<String> Function() readVersion;

  /// 마지막으로 what's-new를 본 버전 (없으면 null).
  final Future<String?> Function() readLastSeen;

  /// 마지막으로 본 버전을 저장한다.
  final Future<void> Function(String version) writeLastSeen;

  /// 마이너 이상 버전 업 후 첫 호출에서만 true. 첫 실행/미파싱은 false.
  Future<bool> shouldShow() async {
    final current = _MinorVersion.tryParse(await readVersion());
    if (current == null) return false;
    final last = _MinorVersion.tryParse(await readLastSeen() ?? '');
    if (last == null) return false;
    return current.isMinorOrAbove(last);
  }

  /// 현재 버전을 '본 것'으로 기록한다(다음 마이너 업까지 다시 안 뜸).
  /// 파싱 불가한 버전은 저장하지 않는다(쓰레기 기준선 방지).
  Future<void> markSeen() async {
    final version = await readVersion();
    if (_MinorVersion.tryParse(version) != null) {
      await writeLastSeen(version);
    }
  }
}

/// major.minor만 비교하는 경량 버전 (패치/빌드/프리릴리스 무시).
class _MinorVersion {
  const _MinorVersion(this.major, this.minor);

  final int major;
  final int minor;

  static _MinorVersion? tryParse(String raw) {
    final core = raw.split('+').first.split('-').first.trim();
    final parts = core.split('.');
    if (parts.length < 2) return null;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    if (major == null || minor == null) return null;
    return _MinorVersion(major, minor);
  }

  bool isMinorOrAbove(_MinorVersion other) =>
      major > other.major || (major == other.major && minor > other.minor);
}

/// 앱(package_info + SharedPreferences)에 배선된 WhatsNewService.
final whatsNewServiceProvider = Provider<WhatsNewService>((ref) {
  return WhatsNewService(
    readVersion: () async => (await PackageInfo.fromPlatform()).version,
    readLastSeen: () async =>
        (await SharedPreferences.getInstance()).getString(_keyLastSeenVersion),
    writeLastSeen: (v) async => (await SharedPreferences.getInstance())
        .setString(_keyLastSeenVersion, v),
  );
});
