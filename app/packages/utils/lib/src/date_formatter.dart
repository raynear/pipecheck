import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DateFormatter {
  static final DateFormatter _instance = DateFormatter._internal();

  factory DateFormatter() {
    return _instance;
  }

  DateFormatter._internal();

  String formatWeekdays(String? weekdays) {
    final weekdaysList = jsonDecode(weekdays ?? '[true, true, true, true, true, true, true]');

    if (weekdays == null || weekdays.isEmpty) return '';

    final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final selectedDays = weekdaysList
        .asMap()
        .entries
        .where((entry) => entry.value as bool)
        .map((entry) => weekdayNames[entry.key])
        .join(', ');

    if (selectedDays == 'Sun, Mon, Tue, Wed, Thu, Fri, Sat') {
      return 'Everyday'.tr();
    } else if (selectedDays == 'Mon, Tue, Wed, Thu, Fri') {
      return 'Weekdays'.tr();
    } else if (selectedDays == 'Sun, Sat') {
      return 'Weekends'.tr();
    } else {
      return selectedDays.split(', ').map((String day) => day.tr()).join(', ');
    }
  }

  TimeOfDay? minutesToTimeOfDay(int? minutes) {
    if (minutes == null) return null;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int? timeOfDayToMinutes(TimeOfDay? time) {
    if (time == null) return null;
    return time.hour * 60 + time.minute;
  }

  String formatTriggerTime(TimeOfDay? time) {
    if (time == null) return '';

    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final formattedHour = (hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0');

    return '$period $formattedHour:$minute';
  }

  String formatTime(TimeOfDay? time) {
    if (time == null) return '';

    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final formattedHour = (hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0');

    return '$formattedHour:$minute $period';
  }

  String formatTimeShort(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 두 날짜가 같은 날인지 확인
  bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  /// 날짜를 원하는 형식으로 포맷팅
  String formatDate(DateTime date, {String format = 'yyyy-MM-dd'}) {
    final formatter = DateFormat(format);
    return formatter.format(date);
  }

  /// 날짜 + 시간 포맷팅
  String formatDateTime(DateTime date, {String format = 'yyyy-MM-dd HH:mm'}) {
    final formatter = DateFormat(format);
    return formatter.format(date);
  }

  /// 상대적 시간 표시 (예: "5분 전", "3일 전")
  String formatRelativeTime(DateTime date, {DateTime? base}) {
    final now = base ?? DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays >= 365) {
      return '${(difference.inDays / 365).floor()}년 전'.tr();
    } else if (difference.inDays >= 30) {
      return '${(difference.inDays / 30).floor()}개월 전'.tr();
    } else if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()}주 전'.tr();
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}일 전'.tr();
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}시간 전'.tr();
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}분 전'.tr();
    } else {
      return '방금 전'.tr();
    }
  }

  /// 해당 월의 첫 날 구하기
  DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// 해당 월의 마지막 날 구하기
  DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// 해당 주의 첫 날 구하기 (일요일 기준)
  DateTime startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  /// 현재 날짜로부터 1년 전 날짜 구하기
  DateTime oneYearBefore(DateTime date) {
    return DateTime(date.year - 1, date.month, date.day);
  }
}
