import '../models/order.dart';
import '../models/attachment.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<ApiResponse<Order>> getOrderById(String orderId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<Order>(success: false, error: 'غير مصرح للوصول');
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/orders/$orderId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        final orderJson = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (orderJson != null) {
          return ApiResponse<Order>(
            success: true,
            data: Order.fromJson(orderJson),
            message: response.message ?? 'تم استرداد الطلب بنجاح',
          );
        }
      }
      return ApiResponse<Order>(
        success: false,
        error: response.error ?? 'فشل في استرداد الطلب',
      );
    } catch (e) {
      if (kDebugMode) {}
      return ApiResponse<Order>(
        success: false,
        error: 'حدث خطأ أثناء استرداد الطلب: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<List<Order>>> getVendorOrders({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<List<Order>>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (status != null && status.isNotEmpty) {
        queryParameters['status'] = status;
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        AppConstants.vendorOrdersEndpoint,
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        // Extract data from nested structure according to schema
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null && dataContainer.containsKey('orders')) {
          final ordersData = dataContainer['orders'] as List;
          final orders =
              ordersData.map((order) => Order.fromJson(order)).toList();

          return ApiResponse<List<Order>>(
            success: true,
            data: orders,
            message: response.message ?? 'تم استرداد الطلبات بنجاح',
          );
        } else {
          return ApiResponse<List<Order>>(
            success: false,
            error: 'بيانات الطلبات غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<List<Order>>(
          success: false,
          error: response.error ?? 'فشل في استرداد الطلبات',
        );
      }
    } catch (e) {
      if (kDebugMode) {}
      return ApiResponse<List<Order>>(
        success: false,
        error: 'حدث خطأ أثناء استرداد الطلبات: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Order>> createOrderByVendor({
    required String description,
    String? additionalNotes,
    required String userAddress,
    required String phoneNumber,
    required int neighborhoodId,
    double? price,
    int? waitingTime,
    List<Attachment>? attachments,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<Order>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final requestData = <String, dynamic>{
        'description': description,
        'userAddress': userAddress,
        'phoneNumber': phoneNumber,
        'neighborhoodId': neighborhoodId,
      };

      if (additionalNotes != null && additionalNotes.isNotEmpty) {
        requestData['additionalNotes'] = additionalNotes;
      }

      if (price != null) {
        requestData['price'] = price;
      }

      if (waitingTime != null) {
        requestData['waitingTime'] = waitingTime;
      }

      // Files are already in Wasabi by this point (AttachmentListWidget
      // uploads on pick), so only the object keys travel here.
      if (attachments != null && attachments.isNotEmpty) {
        requestData['attachments'] =
            attachments.map((a) => a.toJson()).toList();
      }

      if (kDebugMode) {}

      final response = await _apiService.post<Map<String, dynamic>>(
        AppConstants.createOrderByVendorEndpoint,
        data: requestData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        // Extract order data from nested structure according to schema
        final orderData = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (orderData != null) {
          final order = Order.fromJson(orderData);
          return ApiResponse<Order>(
            success: true,
            data: order,
            message: response.message ?? 'تم إنشاء الطلب بنجاح',
          );
        } else {
          return ApiResponse<Order>(
            success: false,
            error: 'بيانات الطلب غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<Order>(
          success: false,
          error: response.error ?? 'فشل في إنشاء الطلب',
        );
      }
    } catch (e) {
      if (kDebugMode) {}
      return ApiResponse<Order>(
        success: false,
        error: 'حدث خطأ أثناء إنشاء الطلب: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Order>> sendCounterOffer({
    required int orderId,
    required String description,
    String? additionalNotes,
    required double price,
    int? waitingTime,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<Order>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final requestData = <String, dynamic>{
        'description': description,
        'price': price,
      };

      if (additionalNotes != null && additionalNotes.isNotEmpty) {
        requestData['additionalNotes'] = additionalNotes;
      }

      // Persisted by the backend's vendorCounterOffer and surfaced to the
      // captain as "الوقت التقديري" on the order screens.
      if (waitingTime != null) {
        requestData['waitingTime'] = waitingTime;
      }

      if (kDebugMode) {}

      final response = await _apiService.put<Map<String, dynamic>>(
        '${AppConstants.ordersEndpoint}/$orderId/vendor-counter-offer',
        data: requestData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        // Extract order data from nested structure according to schema
        final orderData = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (orderData != null) {
          final order = Order.fromJson(orderData);
          return ApiResponse<Order>(
            success: true,
            data: order,
            message: response.message ?? 'تم إرسال العرض بنجاح',
          );
        } else {
          return ApiResponse<Order>(
            success: false,
            error: 'بيانات الطلب غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<Order>(
          success: false,
          error: response.error ?? 'فشل في إرسال العرض',
        );
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return ApiResponse<Order>(
        success: false,
        error: 'حدث خطأ أثناء إرسال العرض: ${e.toString()}',
      );
    }
  }

  /// [waitingTime], in minutes, tells the captain how long until the order is
  /// ready for pickup — the same value the counter-offer flow collects. Left
  /// out, the order keeps whatever waiting time it already had.
  Future<ApiResponse<Order>> acceptOrder(int orderId, {int? waitingTime}) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<Order>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final requestData = <String, dynamic>{};
      if (waitingTime != null) {
        requestData['waitingTime'] = waitingTime;
      }

      final response = await _apiService.put<Map<String, dynamic>>(
        '${AppConstants.ordersEndpoint}/$orderId/vendor-accept',
        data: requestData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        // Extract order data from nested structure according to schema
        final orderData = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (orderData != null) {
          final order = Order.fromJson(orderData);
          return ApiResponse<Order>(
            success: true,
            data: order,
            message: response.message ?? 'تم قبول الطلب بنجاح',
          );
        } else {
          return ApiResponse<Order>(
            success: false,
            error: 'بيانات الطلب غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<Order>(
          success: false,
          error: response.error ?? 'فشل في قبول الطلب',
        );
      }
    } catch (e) {
      if (kDebugMode) {}
      return ApiResponse<Order>(
        success: false,
        error: 'حدث خطأ أثناء قبول الطلب: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Order>> rejectOrder(int orderId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<Order>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final response = await _apiService.put<Map<String, dynamic>>(
        '${AppConstants.ordersEndpoint}/$orderId/vendor-reject',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success && response.data != null) {
        // Extract order data from nested structure according to schema
        final orderData = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (orderData != null) {
          final order = Order.fromJson(orderData);
          return ApiResponse<Order>(
            success: true,
            data: order,
            message: response.message ?? 'تم رفض الطلب بنجاح',
          );
        } else {
          return ApiResponse<Order>(
            success: false,
            error: 'بيانات الطلب غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<Order>(
          success: false,
          error: response.error ?? 'فشل في رفض الطلب',
        );
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return ApiResponse<Order>(
        success: false,
        error: 'حدث خطأ أثناء رفض الطلب: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<void>> updateFCMToken(String fcmToken) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'غير مصرح للوصول',
        );
      }

      final response = await _apiService.put<Map<String, dynamic>>(
        AppConstants.fcmTokenEndpoint,
        data: {'fcmToken': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.success) {
        return ApiResponse<void>(
          success: true,
          message: response.message ?? 'تم تحديث رمز الإشعارات بنجاح',
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: response.error ?? 'فشل في تحديث رمز الإشعارات',
        );
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return ApiResponse<void>(
        success: false,
        error: 'حدث خطأ أثناء تحديث رمز الإشعارات: ${e.toString()}',
      );
    }
  }
}
