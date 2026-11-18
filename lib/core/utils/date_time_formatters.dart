import 'package:intl/intl.dart';

class DateTimeFormatters {
  const DateTimeFormatters._();

  static final DateFormat displayDateFormat = DateFormat('dd/MM/yy');
  static final DateFormat storageDateFormat = DateFormat('yyyy-MM-dd');

  static final DateFormat displayTimeFormat = DateFormat('hh:mm a');
  static final DateFormat storageTimeFormat = DateFormat('HH:mm');

  /// Formats DateTime for display as dd/MM/yy (e.g. 18/11/26)
  static String formatDisplayDate(DateTime dateTime) {
    return displayDateFormat.format(dateTime);
  }

  /// Formats DateTime for storage as yyyy-MM-dd
  static String formatStorageDate(DateTime dateTime) {
    return storageDateFormat.format(dateTime);
  }

  /// Formats TimeOfDay/DateTime for display as hh:mm a (e.g. 05:43 PM)
  static String formatDisplayTime(DateTime dateTime) {
    return displayTimeFormat.format(dateTime);
  }

  /// Formats TimeOfDay/DateTime for storage as HH:mm
  static String formatStorageTime(DateTime dateTime) {
    return storageTimeFormat.format(dateTime);
  }

  /// Converts ISO storage date (yyyy-MM-dd) to display date (dd/MM/yy)
  static String storageToDisplayDate(String isoDate) {
    try {
      final parsed = storageDateFormat.parseStrict(isoDate);
      return displayDateFormat.format(parsed);
    } catch (_) {
      return isoDate;
    }
  }

  /// Converts ISO storage time (HH:mm) to display time (hh:mm a)
  static String storageToDisplayTime(String storageTime) {
    try {
      final parsed = storageTimeFormat.parseStrict(storageTime);
      return displayTimeFormat.format(parsed);
    } catch (_) {
      return storageTime;
    }
  }

  /// Parse display date string (dd/MM/yy) into DateTime with real-date validation
  static DateTime? parseDisplayDate(String input) {
    try {
      // Must match dd/MM/yy
      final parts = input.trim().split('/');
      if (parts.length != 3) return null;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final yearShort = int.tryParse(parts[2]);
      if (day == null || month == null || yearShort == null) return null;
      if (month < 1 || month > 12) return null;

      // Expand 2-digit year (assume 2000-2099)
      final fullYear = yearShort < 100 ? 2000 + yearShort : yearShort;
      final candidate = DateTime(fullYear, month, day);

      // Verify that candidate didn't roll over (e.g. 31/02/26 -> March 3)
      if (candidate.year == fullYear && candidate.month == month && candidate.day == day) {
        return candidate;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
