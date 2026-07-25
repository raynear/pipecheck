#!/usr/bin/env dart

import 'dart:io';

import 'package:args/command_runner.dart';

import '../lib/commands/disable_command.dart';
import '../lib/commands/enable_command.dart';
import '../lib/commands/generate_command.dart';
import '../lib/commands/list_command.dart';
import '../lib/commands/status_command.dart';

/// Flutter BoilerPlate Feature CLI
///
/// 통합 기능 관리 도구
///
/// 사용법:
///   dart tools/feature_cli/bin/feature.dart <command> [options]
///
/// Commands:
///   generate   새 feature 스캐폴딩 생성
///   enable     기능 플래그 활성화
///   disable    기능 플래그 비활성화
///   status     현재 기능 상태 표시
///   list       사용 가능한 기능 목록
void main(List<String> arguments) async {
  final runner = CommandRunner<void>(
    'feature',
    'Flutter BoilerPlate Feature CLI - 통합 기능 관리 도구',
  )
    ..addCommand(GenerateCommand())
    ..addCommand(EnableCommand())
    ..addCommand(DisableCommand())
    ..addCommand(StatusCommand())
    ..addCommand(ListCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    print(e);
    exit(64);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
