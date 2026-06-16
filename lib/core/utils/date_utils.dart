import 'package:intl/intl.dart';

class DateUtils {
  DateUtils._();

  static String groupLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(local.year, local.month, local.day);

    if (dateDay == today) return '今天';
    if (dateDay == yesterday) return '昨天';

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    if (dateDay.isAfter(weekStart.subtract(const Duration(days: 1)))) {
      return '本周';
    }

    return DateFormat('yyyy-MM-dd').format(local);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal());
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MM-dd HH:mm').format(date.toLocal());
  }
}
