import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Default fallback base URL
  static const String _defaultBaseUrl =
      'https://delivery-sadatcity.duckdns.org/api';
  static String _baseUrl = _defaultBaseUrl;

  // Getter for the current base URL
  static String get baseUrl => _baseUrl;

  // Getter for the default fallback base URL (public access for fallback logic)
  static String get defaultBaseUrl => _defaultBaseUrl;

  // Setter to update the base URL
  static set baseUrl(String value) {
    _baseUrl = value;
  }

  // Auth endpoints
  static const String authSignup = '/auth/signup/captain';
  static const String authLogin = '/auth/login/captain';
  static const String refreshTokenEndpoint = '/auth/refresh-token';
  static const String deleteAccount = '/captains/account';

  // Captain endpoints
  static const String captainsProfile = '/captains/profile';
  static const String captainsStatus = '/captains/status';
  static const String captainsLocation = '/captains/location';
  static const String captainsOrders = '/captains/orders';
  static const String captainsStats = '/captains/stats';
  static const String captainsFcmToken = '/captains/fcm-token';
  static const String captainsAvailability = '/captains/availability';

  // Order endpoints
  static const String ordersAvailable = '/orders/available';
  static const String ordersCaptain = '/orders/captain/orders';
  static const String orderAccept = '/orders/{id}/captain-approve';
  static const String orderReject = '/orders/{id}/captain-reject';
  static const String orderDelivered = '/orders/{id}/delivered';
  static const String orderArrived = '/orders/{id}/arrived';

  // Request endpoints
  static const String createRequest = '/captain-requests';
  static const String getRequests = '/captain-requests';

  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Tenant-ID': 'SADAT',
  };

  static Map<String, String> getAuthHeaders(String token) => {
    ...headers,
    'Authorization': 'Bearer $token',
  };

  // Methods for managing the base URL in local storage
  static Future<void> saveBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', baseUrl);
  }

  static Future<String> getBaseUrlFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_base_url') ?? _defaultBaseUrl;
  }

  static Future<void> setBaseUrlWithFallback(String newBaseUrl) async {
    _baseUrl = newBaseUrl;
    await saveBaseUrl(newBaseUrl);
  }
}
