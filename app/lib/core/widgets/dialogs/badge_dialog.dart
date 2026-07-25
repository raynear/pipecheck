import 'dart:math';

import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:pipecheck/data/generated/models/badge.model.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// 뱃지 획득 다이얼로그를 표시하는 위젯
class BadgeAcquiredDialog extends StatefulWidget {
  final BadgeModel badge;
  final ConfettiController? confettiController;

  const BadgeAcquiredDialog({
    super.key,
    required this.badge,
    this.confettiController,
  });

  @override
  State<BadgeAcquiredDialog> createState() => _BadgeAcquiredDialogState();

  /// 뱃지 획득 다이얼로그를 표시하는 정적 메서드
  static Future<void> show({
    required BuildContext context,
    required BadgeModel badge,
    ConfettiController? confettiController,
  }) async {
    final localConfettiController = confettiController ?? ConfettiController(duration: const Duration(seconds: 5));

    if (confettiController == null) {
      localConfettiController.play();
    } else {
      confettiController.play();
    }

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return BadgeAcquiredDialog(
          badge: badge,
          confettiController: localConfettiController,
        );
      },
    );

    if (confettiController == null) {
      localConfettiController.dispose();
    }
  }
}

class _BadgeAcquiredDialogState extends State<BadgeAcquiredDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.9,
              minWidth: screenWidth * 0.7,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '🏆',
                        style: TextStyle(
                          fontSize: 60,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SText('badges.congratulations',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.badge.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.badge.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: SText('utils.close'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          left: MediaQuery.of(context).size.width / 2,
          child: ConfettiWidget(
            confettiController: widget.confettiController!,
            blastDirection: -pi / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            maxBlastForce: 5,
            minBlastForce: 2,
            gravity: 0.05,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            createParticlePath: _drawCircle,
          ),
        ),
      ],
    );
  }

  /// 뱃지 다이얼로그의 원형 파티클 생성
  Path _drawCircle(Size size) {
    final double radius = size.width / 4;
    final Path path = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius));
    return path;
  }
}
