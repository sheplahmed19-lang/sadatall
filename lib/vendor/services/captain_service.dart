import '../models/order.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// The captain's live position, read straight from the tracking endpoint
/// rather than from the (possibly stale) copy embedded in an order.
class CaptainLocation {
  final String id;
  final double longitude;
  final double latitude;

  CaptainLocation({
    required this.id,
    required this.longitude,
    required this.latitude,
  });

  factory CaptainLocation.fromJson(Map<String, dynamic> json) {
    return CaptainLocation(
      id: json['id']?.toString() ?? '',
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : 0.0,
      latitude:
          json['latitude'] is num ? (json['latitude'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'longitude': longitude, 'latitude': latitude};
  }
}

class CaptainService {
  static final CaptainService _instance = CaptainService._internal();
  factory CaptainService() => _instance;
  CaptainService._internal();

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  /// Fetches the captain's current coordinates. Mirrors the user app's
  /// implementation so both show the same live position.
  Future<ApiResponse<CaptainLocation>> getCaptainLocation(
      String captainId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<CaptainLocation>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/captains/$captainId/location',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null) {
          return ApiResponse<CaptainLocation>(
            success: true,
            data: CaptainLocation.fromJson(dataContainer),
            message: response.message ?? 'تم استرداد موقع الكابتن بنجاح',
          );
        }
        return ApiResponse<CaptainLocation>(
          success: false,
          error: 'بيانات موقع الكابتن غير صحيحة في الرد',
        );
      }
      return ApiResponse<CaptainLocation>(
        success: false,
        error: response.error ?? 'فشل في استرداد موقع الكابتن',
      );
    } catch (e) {
      if (kDebugMode) {
        ('CaptainService.getCaptainLocation error: $e');
      }
      return ApiResponse<CaptainLocation>(
        success: false,
        error: 'حدث خطأ أثناء استرداد موقع الكابتن: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Captain>> getCaptainProfile(String captainId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<Captain>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/captains/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null) {
          final captain = Captain.fromJson(dataContainer);
          return ApiResponse<Captain>(
            success: true,
            data: captain,
            message: response.message ?? 'تم استرداد بيانات الكابتن بنجاح',
          );
        } else {
          return ApiResponse<Captain>(
            success: false,
            error: 'بيانات الكابتن غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<Captain>(
          success: false,
          error: response.error ?? 'فشل في استرداد بيانات الكابتن',
        );
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return ApiResponse<Captain>(
        success: false,
        error: 'حدث خطأ أثناء استرداد بيانات الكابتن: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<CaptainStats>> getCaptainStats(String captainId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<CaptainStats>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/captains/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null) {
          final stats = CaptainStats.fromJson(dataContainer);
          return ApiResponse<CaptainStats>(
            success: true,
            data: stats,
            message: response.message ?? 'تم استرداد إحصائيات الكابتن بنجاح',
          );
        } else {
          return ApiResponse<CaptainStats>(
            success: false,
            error: 'إحصائيات الكابتن غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<CaptainStats>(
          success: false,
          error: response.error ?? 'فشل في استرداد إحصائيات الكابتن',
        );
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return ApiResponse<CaptainStats>(
        success: false,
        error: 'حدث خطأ أثناء استرداد إحصائيات الكابتن: ${e.toString()}',
      );
    }
  }
}

class CaptainStats {
  final int totalOrders;
  final int completedOrders;
  final double currentRating;
  final int totalRatings;

  CaptainStats({
    required this.totalOrders,
    required this.completedOrders,
    required this.currentRating,
    required this.totalRatings,
  });

  factory CaptainStats.fromJson(Map<String, dynamic> json) {
    return CaptainStats(
      totalOrders:
          json['totalOrders'] is num ? (json['totalOrders'] as num).toInt() : 0,
      completedOrders: json['completedOrders'] is num
          ? (json['completedOrders'] as num).toInt()
          : 0,
      currentRating: json['currentRating'] is num
          ? (json['currentRating'] as num).toDouble()
          : 0.0,
      totalRatings: json['totalRatings'] is num
          ? (json['totalRatings'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
      'currentRating': currentRating,
      'totalRatings': totalRatings,
    };
  }
}
