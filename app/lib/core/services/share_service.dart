import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:utils/utils.dart';

/// Service for sharing content via the platform share sheet
///
/// Wraps the `share_plus` package with convenience methods for
/// common sharing scenarios like text, URIs, and app promotion.
class ShareService {
  /// Share plain text content
  ///
  /// [text] - the text content to share
  /// [subject] - optional subject line (used by email clients)
  Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(text, subject: subject ?? '');
      logger.d('ShareService: text shared successfully');
    } catch (e) {
      logger.e('ShareService: failed to share text: $e');
    }
  }

  /// Share a URI
  ///
  /// [uri] - the URI to share
  Future<void> shareUri(Uri uri) async {
    try {
      await Share.shareUri(uri);
      logger.d('ShareService: URI shared successfully');
    } catch (e) {
      logger.e('ShareService: failed to share URI: $e');
    }
  }

  /// Share a file via the platform share sheet.
  ///
  /// [path] - absolute path of the file to share
  /// [subject] - optional subject (used by email clients)
  /// [text] - optional accompanying text
  ///
  /// Used by the GDPR data export flow (P2-23f). Rethrows so callers can
  /// surface failures to the user (unlike the fire-and-forget text/uri helpers).
  Future<void> shareFile(String path, {String? subject, String? text}) async {
    try {
      await Share.shareXFiles([XFile(path)], subject: subject, text: text);
      logger.d('ShareService: file shared successfully');
    } catch (e) {
      logger.e('ShareService: failed to share file: $e');
      rethrow;
    }
  }

  /// Share app promotion message
  ///
  /// Generates a "Check out [appName]!" message with an optional store URL.
  ///
  /// [appName] - the name of the app to promote
  /// [storeUrl] - optional store URL to include in the message
  Future<void> shareApp({
    required String appName,
    String? storeUrl,
  }) async {
    final buffer = StringBuffer('Check out $appName!');
    if (storeUrl != null) {
      buffer.write('\n$storeUrl');
    }
    await shareText(buffer.toString(), subject: appName);
  }
}

/// Provider for ShareService
final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService();
});
