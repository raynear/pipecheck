import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:flutter/material.dart';

class WeekNavigation extends StatelessWidget {
  final DateTime startDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const WeekNavigation({
    super.key,
    required this.startDate,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = startDate;
    final month = weekStart.month;
    final weekNumber = (weekStart.day / 7).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        SText('Month $month Week $weekNumber'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class MonthNavigation extends StatelessWidget {
  final DateTime startDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const MonthNavigation({
    super.key,
    required this.startDate,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final month = startDate.month;
    final year = startDate.year;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        SText('$year-${month.toString().padLeft(2, '0')}'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class YearNavigation extends StatelessWidget {
  final DateTime startDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const YearNavigation({
    super.key,
    required this.startDate,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final year = startDate.year;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        SText('$year'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}
