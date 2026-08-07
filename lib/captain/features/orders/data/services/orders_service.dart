import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../models/order_model.dart';

class OrdersService {
  final ApiClient _apiClient = ApiClient();

  Future<List<OrderModel>> getAvailableOrders({
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.ordersAvailable,
      queryParams: {'page': page.toString(), 'limit': limit.toString()},
      fromJson: (data) => (data['orders'] as List)
          .map((order) => OrderModel.fromJson(order))
          .toList(),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      // ApiException (not a bare Exception) so AppUtils.getLocalizedErrorMessage
      // upstream preserves this real backend message instead of falling
      // back to its fully generic string.
      throw ApiException(message: response.error ?? 'Failed to fetch available orders');
    }
  }

  Future<List<OrderModel>> getCaptainOrders({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      ApiConfig.ordersCaptain,
      queryParams: queryParams,
      fromJson: (data) => (data['orders'] as List)
          .map((order) => OrderModel.fromJson(order))
          .toList(),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw ApiException(message: response.error ?? 'Failed to fetch captain orders');
    }
  }

  Future<bool> acceptOrder(String orderId, {double? deliveryPrice}) async {
    final endpoint = ApiConfig.orderAccept.replaceAll('{id}', orderId);

    final Map<String, dynamic>? body = deliveryPrice != null
        ? {'deliveryPrice': deliveryPrice}
        : null;

    final response = await _apiClient.put(
      endpoint,
      body: body,
      fromJson: (data) => data,
    );
    if (response.success) {
      return true;
    } else {
      throw ApiException(message: response.error ?? 'Failed to accept order');
    }
  }

  /// Dismisses this order's incoming ring alert for the current captain —
  /// either an explicit decline or a local countdown timeout. The order
  /// stays available to every other captain; this just stops it being
  /// re-offered to this one.
  Future<void> rejectOrder(String orderId, {String reason = 'REJECTED'}) async {
    final endpoint = ApiConfig.orderReject.replaceAll('{id}', orderId);

    final response = await _apiClient.put(
      endpoint,
      body: {'reason': reason},
    );

    if (!response.success) {
      throw ApiException(message: response.error ?? 'Failed to dismiss order');
    }
  }

  Future<OrderModel> markDelivered(String orderId) async {
    final endpoint = ApiConfig.orderDelivered.replaceAll('{id}', orderId);

    final response = await _apiClient.put(
      endpoint,
      fromJson: (data) => OrderModel.fromJson(data),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw ApiException(message: response.error ?? 'Failed to mark order as delivered');
    }
  }

  Future<void> notifyArrived(String orderId) async {
    final endpoint = ApiConfig.orderArrived.replaceAll('{id}', orderId);

    final response = await _apiClient.put(endpoint);

    if (!response.success) {
      throw ApiException(message: response.error ?? 'Failed to notify arrival');
    }
  }

  Future<OrderModel?> getCurrentOrder() async {
    final orders = await getCaptainOrders(
      status: OrderStatus.acceptedByCaptain.value,
      limit: 1,
    );

    return orders.isNotEmpty ? orders.first : null;
  }

  Future<List<OrderModel>> getDeliveredOrders({
    int page = 1,
    int limit = 10,
  }) async {
    return getCaptainOrders(
      page: page,
      limit: limit,
      status: OrderStatus.delivered.value,
    );
  }
}
