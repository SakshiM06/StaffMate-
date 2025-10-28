// lib/utils/date_time_formatter.dart
import 'package:intl/intl.dart';

class DateTimeFormatter {
  static String formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd-MM-yyyy hh:mm a').format(dateTime);
  }
}