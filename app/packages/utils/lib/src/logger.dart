import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:easy_logger/easy_logger.dart';

Logger get logger => Log.instance;

class DeveloperConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    final StringBuffer buffer = StringBuffer();
    event.lines.forEach(buffer.writeln);
    log(buffer.toString(), name: 'habit');
  }
}

class Log extends Logger {
  Log._()
      : super(
          level: _getLogLevel(),
          printer: PrefixPrinter(
            PrettyPrinter(
              methodCount: 0, // Number of method calls to be displayed
              errorMethodCount: 8, // Number of method calls if chain trace is provided
              lineLength: 120, // Width of the output
              colors: true, // Colorful log messages
              printEmojis: true, // Print an emoji for each log message
              dateTimeFormat: DateTimeFormat.none, // Should each log print contain a timestamp
              noBoxingByDefault: true,
            ),
            // info: 'I',
            // warning: 'W',
            // error: 'E',
            // debug: 'D',
            // trace: 'T',
            // fatal: 'F',
          ),
          output: MultiOutput([DeveloperConsoleOutput()]),
          filter: ProductionFilter(),
        );

  static final instance = Log._();

  static Level _getLogLevel() {
    if (kReleaseMode) {
      return Level.error;
    }

    if (kReleaseMode) {
      // release
      return Level.error;
    } else {
      // debug, profile
      return kDebugMode ? Level.debug : Level.info;
    }
  }
}

EasyLogPrinter customLogPrinter = (
  Object object, {
  String? name,
  StackTrace? stackTrace,
  LevelMessages? level,
}) {
  log(object.toString(), name: 'Easy localization', level: level!.index);
} as EasyLogPrinter;

EasyLogger easyLogger = EasyLogger(printer: customLogPrinter);
