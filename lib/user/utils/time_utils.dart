import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class TimeUtils {
  static bool _isInitialized = false;
  static const String _cairoLocation = 'Africa/Cairo';
  static late final tz.Location _cairoTimeZone;

  static void initialize() {
    if (_isInitialized) return;
    tz_data.initializeTimeZones();
    _cairoTimeZone = tz.getLocation(_cairoLocation);
    _isInitialized = true;
  }

  /// Get current time in Cairo timezone
  static tz.TZDateTime get currentTimeInCairo {
    return tz.TZDateTime.now(_cairoTimeZone);
  }

  /// Convert a UTC DateTime to Cairo timezone
  static tz.TZDateTime toCairoTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, _cairoTimeZone);
  }

  /// Convert a Cairo time to UTC DateTime
  static DateTime toUtcTime(tz.TZDateTime cairoTime) {
    return cairoTime.toUtc();
  }

  /// Get Cairo timezone location
  static tz.Location getCairoLocation() {
    return _cairoTimeZone;
  }

  /// Format a DateTime in Cairo timezone with a readable format
  static String formatCairoDateTime(DateTime dateTime, {String pattern = 'dd/MM/yyyy HH:mm'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, pattern);
  }

  /// Format a DateTime in Cairo timezone (no locale)
  static String formatCairoDateTimeArabic(DateTime dateTime, {String pattern = 'dd/MM/yyyy - hh:mm a'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, pattern);
  }

  /// Format a TZDateTime in Cairo timezone (no locale)
  static String formatCairoTZDateTimeArabic(tz.TZDateTime cairoTime, {String pattern = 'dd/MM/yyyy - hh:mm a'}) {
    return _formatDateTime(cairoTime, pattern);
  }

  /// Format a DateTime to Cairo date only
  static String formatCairoDateArabic(DateTime dateTime, {String pattern = 'dd/MM/yyyy'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, pattern);
  }

  /// Format a DateTime to Cairo time only
  static String formatCairoTimeArabic(DateTime dateTime, {String pattern = 'hh:mm a'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, pattern);
  }

  /// Formats a DateTime to relative time in Arabic (e.g., منذ 2 ساعة)
  static String formatRelativeTimeArabic(DateTime dateTime) {
    final now = currentTimeInCairo;
    final cairoTime = toCairoTime(dateTime);
    final difference = now.difference(cairoTime);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'منذ $minutes دقيقة';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'منذ $hours ساعة';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return 'منذ $days يوم';
    } else {
      return formatCairoDateArabic(dateTime);
    }
  }

  /// Helper method to format date time according to specified format
  static String _formatDateTime(tz.TZDateTime dateTime, String pattern) {
    String formatted = pattern;

    // Get 12-hour format
    final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final amPm = dateTime.hour < 12 ? 'صباحاً' : 'مساءً';

    // Replace format placeholders with actual values
    formatted = formatted.replaceAll('yyyy', dateTime.year.toString().padLeft(4, '0'));
    formatted = formatted.replaceAll('yy', dateTime.year.toString().substring(2).padLeft(2, '0'));
    formatted = formatted.replaceAll('MM', dateTime.month.toString().padLeft(2, '0'));
    formatted = formatted.replaceAll('dd', dateTime.day.toString().padLeft(2, '0'));
    formatted = formatted.replaceAll('HH', dateTime.hour.toString().padLeft(2, '0'));
    formatted = formatted.replaceAll('hh', hour12.toString().padLeft(2, '0'));
    formatted = formatted.replaceAll('mm', dateTime.minute.toString().padLeft(2, '0'));
    formatted = formatted.replaceAll('ss', dateTime.second.toString().padLeft(2, '0'));
    formatted = formatted.replaceAll('a', amPm);

    return formatted;
  }
}