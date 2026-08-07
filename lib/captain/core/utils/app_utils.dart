import 'dart:math';

import 'package:intl/intl.dart';
import '../errors/api_exception.dart';

class AppUtils {
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date.toLocal());
  }

  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${DateFormat('yyyy-MM-dd').format(local)} ${_formatTime12Hour(local)}';
  }

  static String formatTime(DateTime time) {
    return _formatTime12Hour(time.toLocal());
  }

  static String _formatTime12Hour(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final amPm = time.hour < 12 ? 'صباحاً' : 'مساءً';
    final hh = hour12.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm $amPm';
  }

  static String formatPrice(double price) {
    return '${price.toStringAsFixed(2)} ج.م';
  }

  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toInt()} م';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} كم';
    }
  }

  static String getOrderStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'في الانتظار';
      case 'COUNTER_OFFER_SENT':
        return 'تم إرسال العرض المقابل';
      case 'COUNTER_OFFER_ACCEPTED':
        return 'تم قبول العرض المقابل';
      case 'ACCEPTED_BY_CAPTAIN':
        return 'تم قبوله من الكابتن';
      case 'DELIVERED':
        return 'تم التسليم';
      case 'CANCELLED':
        return 'ملغى';
      default:
        return status;
    }
  }

  static String getRequestStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'في الانتظار';
      case 'APPROVED':
        return 'موافق عليه';
      case 'REJECTED':
        return 'مرفوض';
      default:
        return status;
    }
  }

  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth radius in meters

    final double lat1Rad = lat1 * (pi / 180);
    final double lat2Rad = lat2 * (pi / 180);
    final double deltaLatRad = (lat2 - lat1) * (pi / 180);
    final double deltaLonRad = (lon2 - lon1) * (pi / 180);

    final double a =
        pow(sin(deltaLatRad / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(deltaLonRad / 2), 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  static bool isRTL(String text) {
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text);
  }

  /// Converts error messages to user-friendly Arabic messages
  static String getLocalizedErrorMessage(dynamic error) {
    // If this is an ApiException, it already carries the backend's actual
    // error message (extracted from the response body's `error`/`message`
    // field) - show that real message directly instead of re-deriving a
    // generic one from keyword matching, which can discard or even mismatch
    // the true cause (e.g. any unrelated 404 used to become "accepted by
    // another captain").
    if (error is ApiException) {
      if (error.statusCode == 401) {
        // The backend returns 401 for several distinct reasons, not just an
        // expired session (e.g. "Captain is locked" when an admin locks the
        // account or the captain exceeds the max-earnings threshold, and
        // "Captain not found"). Surface the real reason instead of blanket
        // "session expired", which is misleading and hides the actual cause.
        final backendMessage = error.message.trim();
        final isLocked = backendMessage.toLowerCase().contains('locked');
        if (isLocked) {
          return 'حسابك مُعلق حالياً. يرجى التواصل مع الإدارة';
        }

        final looksLikeSessionProblem =
            backendMessage.isEmpty ||
            backendMessage.toLowerCase().contains('token') ||
            backendMessage.toLowerCase().contains('unauthorized') ||
            backendMessage.toLowerCase().contains('expired');
        if (looksLikeSessionProblem) {
          return 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى';
        }

        return backendMessage;
      }
      return error.message;
    }

    String errorString = error.toString().toLowerCase();

    // Network related errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable') ||
        errorString.contains('failed host lookup')) {
      return 'خطأ في الاتصال. تأكد من اتصالك بالإنترنت';
    }

    // Generic fallback for non-ApiException errors (e.g. socket/format
    // exceptions) where there's no clean backend message to show.
    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
  }
}
