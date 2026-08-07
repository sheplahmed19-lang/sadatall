
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/vendor.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/vendor_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  final VendorService _vendorService = VendorService();

  Vendor? _currentVendor;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isVendorLocked = false;
  String? _errorMessage;

  Vendor? get currentVendor => _currentVendor;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isVendorLocked => _isVendorLocked;
  String? get errorMessage => _errorMessage;

  Future<void> checkAuthStatus() async {
    _setLoading(true);

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        var vendor = await _authService.getCurrentVendor();
        // The cached vendor JSON can go missing or fail to parse (e.g. a
        // secure-storage decrypt issue that tends to show up right after
        // an app update) even though the access token itself is still
        // valid. Treating that as "not logged in" was wrong — it left
        // screens that read currentVendor (like the support chat tab)
        // stuck showing "please log in" while every other, API-driven
        // screen kept working fine since it wasn't logged out. Fall back
        // to fetching the profile fresh instead of giving up.
        if (vendor == null) {
          try {
            final response = await _vendorService.getProfile();
            if (response.success && response.data != null) {
              vendor = response.data;
              await _authService.cacheVendor(vendor!);
            }
          } catch (e) {
            // Offline/timeout here must not log the vendor out: the token is
            // still valid, we just could not refill the cache right now.
            debugPrint('checkAuthStatus: profile refetch failed: $e');
          }
        }

        if (vendor != null) {
          _currentVendor = vendor;
          // Check if the vendor is locked based on the isLocked field
          _isVendorLocked = vendor.isLocked == true;
          _isAuthenticated = true;
        } else {
          // Token is valid but we have no profile yet. Stay authenticated so
          // the app is usable, and let screens recover via ensureVendorLoaded.
          _isAuthenticated = true;
          debugPrint('checkAuthStatus: logged in but vendor profile unavailable');
        }
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      debugPrint('checkAuthStatus failed: $e');
      _isAuthenticated = false;
    }

    _setLoading(false);
  }

  Future<bool> login(String contactNumber, String password) async {
    _setLoading(true);
    
    try {
      final result = await _authService.login(
        contactNumber: contactNumber,
        password: password,
      );

      if (result.success && result.vendor != null) {
        _currentVendor = result.vendor;
        _isAuthenticated = true;
        _setLoading(false);
        
        // Send FCM token to backend after successful login
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure everything is initialized
        final notificationService = NotificationService();
        if (notificationService.fcmToken != null && notificationService.fcmToken!.isNotEmpty) {
          final response = await _orderService.updateFCMToken(notificationService.fcmToken!);
          if (kDebugMode) {
            (response.success 
                ? 'FCM token sent successfully after login' 
                : 'Failed to send FCM token: ${response.error}');
          }
        } else {
          if (kDebugMode) {
            ('FCM token not available yet, will send when ready');
          }
          // Set up a small delay and try again
          await Future.delayed(const Duration(seconds: 1));
          if (notificationService.fcmToken != null && notificationService.fcmToken!.isNotEmpty) {
            final response = await _orderService.updateFCMToken(notificationService.fcmToken!);
            if (kDebugMode) {
              (response.success 
                  ? 'FCM token sent successfully after delay' 
                  : 'Failed to send FCM token after delay: ${response.error}');
            }
          }
        }
        
        return true;
      } else {
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      // Show user-friendly error message instead of just returning false
      if (kDebugMode) {
        ('خطأ غير متوقع: ${e.toString()}');
      }
      return false;
    }
  }

  Future<bool> logout() async {
    _setLoading(true);

    try {
      await _authService.logout();
      _currentVendor = null;
      _isAuthenticated = false;
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      // Show user-friendly error message instead of just returning false
      if (kDebugMode) {
        ('خطأ غير متوقع أثناء تسجيل الخروج: ${e.toString()}');
      }
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _authService.deleteAccount();
      if (result.success) {
        _currentVendor = null;
        _isAuthenticated = false;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = result.error ?? 'تعذر حذف الحساب';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء حذف الحساب: ${e.toString()}';
      _setLoading(false);
      if (kDebugMode) {
        ('خطأ غير متوقع أثناء حذف الحساب: ${e.toString()}');
      }
      return false;
    }
  }

  Future<bool> signup({
    required String vendorName,
    required String contactNumber,
    required String password,
    required String address,
    required String description,
    required double latitude,
    required double longitude,
    required int neighborhoodId,
    required List<int> categories,
    required File image,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _authService.signup(
        vendorName: vendorName,
        contactNumber: contactNumber,
        password: password,
        address: address,
        description: description,
        latitude: latitude,
        longitude: longitude,
        neighborhoodId: neighborhoodId,
        categories: categories,
        image: image,
      );

      if (result.success && result.vendor != null) {
        _currentVendor = result.vendor;
        _isAuthenticated = true;
        _setLoading(false);

        return true;
      } else {
        _errorMessage = result.error ?? 'فشل إنشاء الحساب';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: ${e.toString()}';
      _setLoading(false);
      if (kDebugMode) {
        ('خطأ غير متوقع: ${e.toString()}');
      }
      return false;
    }
  }

  /// Re-fetches the vendor profile when [currentVendor] is null but the token
  /// is still valid — e.g. the app launched with no connectivity, so
  /// [checkAuthStatus] could neither read the cache nor reach the API.
  ///
  /// Without this a failed launch-time fetch left currentVendor null for the
  /// whole session, since checkAuthStatus only runs once from the splash
  /// screen. Returns true when a vendor is available afterwards.
  Future<bool> ensureVendorLoaded() async {
    if (_currentVendor != null) return true;
    if (!await _authService.isLoggedIn()) return false;

    try {
      var vendor = await _authService.getCurrentVendor();
      if (vendor == null) {
        final response = await _vendorService.getProfile();
        if (response.success && response.data != null) {
          vendor = response.data;
          await _authService.cacheVendor(vendor!);
        }
      }
      if (vendor == null) return false;

      _currentVendor = vendor;
      _isVendorLocked = vendor.isLocked == true;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ensureVendorLoaded failed: $e');
      return false;
    }
  }

  void updateVendor(Vendor vendor) {
    _currentVendor = vendor;
    // Check if the vendor is locked based on the isLocked field
    _isVendorLocked = vendor.isLocked == true;
    notifyListeners();
  }
  
  Vendor? get vendor => _currentVendor;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setVendorLockStatus(bool isLocked) {
    _isVendorLocked = isLocked;
    notifyListeners();
  }
}