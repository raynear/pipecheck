/// Screenshot Driver for flutter_driver integration
library;

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      // Parse screenshot path: platform/language/name
      final parts = screenshotName.split('/');

      if (parts.length < 3) {
        print('[Screenshot] Invalid screenshot name format: $screenshotName');
        print('[Screenshot] Expected format: {outputDir}/{platform}/{language}/{name}');
        print('[Screenshot] Example: ../screenshots/ios/ko/01_home_idle');
        return false;
      }

      // Extract path components
      // Format: {outputDir}/platform/language/name — outputDir 기본은
      // ../screenshots (cwd=app → <root>/screenshots, P1-17b SSOT)
      final pathWithoutName = parts.sublist(0, parts.length - 1).join('/');
      final fileName = parts.last;

      try {
        // Create directory if it doesn't exist
        final directory = Directory(pathWithoutName);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          print('[Screenshot] Created directory: $pathWithoutName');
        }

        // Save the screenshot
        final filePath = '$pathWithoutName/$fileName.png';
        final file = File(filePath);
        await file.writeAsBytes(screenshotBytes);

        print('[Screenshot] Saved: $filePath');
        return true;
      } catch (e) {
        print('[Screenshot] Failed to save $screenshotName: $e');
        return false;
      }
    },
  );
}
