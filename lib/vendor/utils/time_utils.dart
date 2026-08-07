
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class TimeUtils {
  static bool _isInitialized = false;
  static const String _cairoLocation = 'Africa/Cairo';
  static late final tz.Location _cairoTimeZone;

  /// Initialize the timezone data
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

  /// Convert a DateTime to Cairo timezone
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
  static String formatCairoDateTime(DateTime dateTime,
      {String format = 'dd/MM/yyyy HH:mm'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, format);
  }

  /// Format a TZDateTime in Cairo timezone with a readable format
  static String formatCairoTZDateTime(tz.TZDateTime cairoTime,
      {String format = 'dd/MM/yyyy HH:mm'}) {
    return _formatDateTime(cairoTime, format);
  }

  /// Helper method to format date time according to specified format
  static String _formatDateTime(tz.TZDateTime dateTime, String format) {
    String formatted = format;

    // Replace format placeholders with actual values
    formatted =
        formatted.replaceAll('yyyy', dateTime.year.toString().padLeft(4, '0'));
    formatted = formatted.replaceAll(
        'yy', dateTime.year.toString().substring(2).padLeft(2, '0'));
    formatted =
        formatted.replaceAll('MM', dateTime.month.toString().padLeft(2, '0'));
    formatted =
        formatted.replaceAll('dd', dateTime.day.toString().padLeft(2, '0'));
    
    // 24-hour format
    formatted =
        formatted.replaceAll('HH', dateTime.hour.toString().padLeft(2, '0'));
        
    // 12-hour format parts
    final hour12 = dateTime.hour > 12 
        ? dateTime.hour - 12 
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'مساءً' : 'صباحاً';
    
    formatted =
        formatted.replaceAll('hh', hour12.toString().padLeft(2, '0'));
    formatted =
        formatted.replaceAll('a', amPm);
        
    formatted =
        formatted.replaceAll('mm', dateTime.minute.toString().padLeft(2, '0'));
    formatted =
        formatted.replaceAll('ss', dateTime.second.toString().padLeft(2, '0'));

    return formatted;
  }

  // Additional methods for the new functionality
  /// Converts a DateTime from UTC to Cairo timezone (alternative method)
  static DateTime convertToCairoTime(DateTime dateTime) {
    final utcDateTime = dateTime.isUtc ? dateTime : dateTime.toUtc();
    final cairoTzDateTime = tz.TZDateTime.from(utcDateTime, _cairoTimeZone);
    return DateTime(
        cairoTzDateTime.year,
        cairoTzDateTime.month,
        cairoTzDateTime.day,
        cairoTzDateTime.hour,
        cairoTzDateTime.minute,
        cairoTzDateTime.second,
        cairoTzDateTime.millisecond,
        cairoTzDateTime.microsecond);
  }

  /// Converts a DateTime from Cairo timezone to UTC (alternative method)
  static DateTime convertFromCairoTime(DateTime dateTime) {
    final cairoTzDateTime = tz.TZDateTime.from(dateTime, _cairoTimeZone);
    return cairoTzDateTime.toUtc();
  }

  /// Formats a DateTime using Cairo timezone and Arabic locale
  static String formatCairoDateTimeLocalized(DateTime dateTime,
      {String pattern = 'dd/MM/yyyy - hh:mm a'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, pattern);
  }

  /// Formats a DateTime to Cairo date only
  static String formatCairoDate(DateTime dateTime,
      {String pattern = 'dd/MM/yyyy'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, pattern);
  }

  /// Formats a DateTime to Cairo time only
  static String formatCairoTimeLocalized(DateTime dateTime,
      {String pattern = 'hh:mm a'}) {
    final cairoTime = toCairoTime(dateTime);
    return _formatDateTime(cairoTime, pattern);
  }

  /// Gets the current time in Cairo timezone as DateTime
  static DateTime getCairoTimeNow() {
    final cairoTime = currentTimeInCairo;
    return DateTime(
        cairoTime.year,
        cairoTime.month,
        cairoTime.day,
        cairoTime.hour,
        cairoTime.minute,
        cairoTime.second,
        cairoTime.millisecond,
        cairoTime.microsecond);
  }

  /// Formats a DateTime to relative time in Arabic (e.g., منذ 2 ساعة)
  static String formatRelativeTime(DateTime dateTime) {
    final now = currentTimeInCairo;
    final difference = now.difference(dateTime);

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
      return formatCairoDate(dateTime);
    }
  }
}
