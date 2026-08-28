import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sadat_delivery_merged/main.dart' show navigatorKey;
import 'package:sadat_delivery_merged/vendor/screens/orders/order_details_screen.dart';
import 'dart:convert';
import 'order_service.dart';
import 'auth_service.dart';
import '../providers/auth_provider.dart';
import '../utils/time_utils.dart';
import '../screens/chat/vendor_support_chat_tab.dart';
import '../screens/chat/vendor_order_chat_screen.dart';

const Set<String> _kOrderNotificationTypes = {
  'NEW_ORDER',
  'ORDER_APPROVED',
  'DELIVERY_AVAILABLE',
  'CAPTAIN_ASSIGNED',
  'ORDER_CANCELLED',
  'ORDER_DELIVERED',
  'CAPTAIN_ARRIVED',
  'NEW_VENDOR_ORDER',
};

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final OrderService _orderService = OrderService();

  bool _isInitialized = false;
  String? _fcmToken;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      await _requestPermissions();

      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();

      // Get and save FCM token
      await _getFCMToken();

      _isInitialized = true;

      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  // Check for any stored background notifications and display them
  Future<void> checkStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications =
          prefs.getStringList('background_notifications') ?? [];

      if (notifications.isNotEmpty && navigatorKey.currentContext != null) {
        // Display all stored notifications
        for (final notificationStr in notifications) {
          try {
            final notificationData = jsonDecode(notificationStr);
            final title = notificationData['title'] as String?;
            final body = notificationData['body'] as String?;
            final data = notificationData['data'] as Map<String, dynamic>?;

            if (title != null || body != null) {
              // Show notification dialog
              await showDialog(
                context: navigatorKey.currentContext!,
                barrierDismissible: true,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(title ?? 'تنبيه جديد'),
                    content: Text(body ?? ''),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  );
                },
              );
            }
          } catch (e) {
            if (kDebugMode) {}
          }
        }

        // Clear stored notifications after displaying them
        await prefs.remove('background_notifications');
      }
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {}
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Configure message handling for foreground (this is key to show system notifications when app is in foreground)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, // Show alert notification in foreground
      badge: true, // Update badge number in foreground
      sound: true, // Play sound in foreground
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle initial message if app was opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// On iOS, getToken() throws "apns-token-not-set" if APNs registration has
  /// not finished yet — FCM derives its token from the APNs one. Registration
  /// with Apple can lag a moment after permission is granted, so poll briefly
  /// rather than giving up on the first miss. No-op off iOS, where
  /// getAPNSToken() simply returns null.
  Future<bool> _waitForApnsToken() async {
    if (!Platform.isIOS) return true;
    var apnsToken = await _messaging.getAPNSToken();
    for (var i = 0; i < 10 && apnsToken == null; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      apnsToken = await _messaging.getAPNSToken();
    }
    return apnsToken != null;
  }

  Future<void> _getFCMToken() async {
    try {
      if (!await _waitForApnsToken()) {
        if (kDebugMode) {
          debugPrint('APNs token unavailable — skipping FCM token fetch');
        }
        return;
      }
      _fcmToken = await _messaging.getToken();

      if (kDebugMode) {}

      // Only send token to backend if user is logged in
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        final authService = AuthService();
        final isLoggedIn = await authService.isLoggedIn();

        if (isLoggedIn) {
          final response = await _orderService.updateFCMToken(_fcmToken!);
          if (!response.success && kDebugMode) {}
        } else if (kDebugMode) {}
      }

      // Listen for token refresh - only send if user is logged in
      _messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        if (kDebugMode) {}

        if (newToken.isNotEmpty) {
          final authService = AuthService();
          final isLoggedIn = await authService.isLoggedIn();

          if (isLoggedIn) {
            final response = await _orderService.updateFCMToken(newToken);
            if (!response.success && kDebugMode) {}
          } else if (kDebugMode) {}
        }
      });
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {}

    // Show notification in a dialog or snackbar when app is in foreground
    if (navigatorKey.currentContext != null) {
      // Show in Snackbar first
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.notification?.title != null)
                Text(
                  message.notification!.title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (message.notification?.body != null)
                Text(message.notification!.body!),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );

      // Also show as dialog for better visibility
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationDialog(message);
      });
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {}

    _handleNotificationNavigation(message.data);
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;

    if (type == 'chat_message') {
      _openChatFromNotification(data);
      return;
    }

    if (orderId != null && (type == null || _kOrderNotificationTypes.contains(type))) {
      final navState = navigatorKey.currentState;
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => _VendorOrderLoadingScreen(orderId: orderId),
          ),
        );
      }
      return;
    }

    // Show a generic dialog for unknown/non-order notification types
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('تنبيه جديد'),
            content: const Text('لديك تنبيه جديد من النظام'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('موافق'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _openChatFromNotification(Map<String, dynamic> data) async {
    final navState = navigatorKey.currentState;
    if (navState == null) return;
    final chatId = data['chatId'] as String?;
    if (chatId == null) return;

    // Tapping this notification on a cold start (app process was killed)
    // fires via getInitialMessage() and can race ahead of the splash
    // screen's own AuthProvider.checkAuthStatus() — pushing the chat tab
    // immediately then hit a still-empty currentVendor and showed "please
    // log in" even though the vendor was, in fact, still logged in.
    final context = navigatorKey.currentContext;
    if (context != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentVendor == null) {
        await authProvider.checkAuthStatus();
      }
    }

    if (chatId.startsWith('support_vendor_')) {
      navState.push(MaterialPageRoute(builder: (_) => const VendorSupportChatTab()));
      return;
    }

    final orderId = data['orderId'] as String?;
    if (chatId.endsWith('_vendor_captain') && orderId != null && orderId.isNotEmpty) {
      navState.push(MaterialPageRoute(builder: (_) => _VendorOrderChatLoadingScreen(orderId: orderId)));
    }
  }

  // Show notification in a dialog for better visibility
  Future<void> _showNotificationDialog(RemoteMessage message) async {
    if (navigatorKey.currentContext == null) return;

    final title = message.notification?.title ?? 'تنبيه جديد';
    final body = message.notification?.body ?? 'لديك تنبيه جديد';

    // Don't show duplicate dialogs quickly
    await showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  // Public methods
  Future<void> showGeneralNotification({
    required String title,
    required String body,
    String? actionData,
  }) async {
    // Create the notification message
    final message = RemoteMessage(
      notification: RemoteNotification(
        title: title,
        body: body,
      ),
      data: actionData != null ? {'actionData': actionData} : {},
    );

    // Handle it as a foreground message
    _handleForegroundMessage(message);
  }

  Future<void> clearAllNotifications() async {
    // For Firebase Cloud Messaging, notifications are automatically cleared when tapped
    // This is a placeholder method to maintain API compatibility
    // If you need more control, you would need to implement platform-specific code
    if (kDebugMode) {}

    // Clear stored background notifications
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('background_notifications');
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  // Getter methods
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  // Topic subscription methods
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  // Public method to send FCM token (can be called after login)
  Future<void> sendFCMTokenIfNeeded() async {
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      await _sendFCMTokenToBackend(_fcmToken!);
    }
  }

  // Private method to send FCM token to backend - only if user is logged in
  Future<void> _sendFCMTokenToBackend(String token) async {
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();

      if (isLoggedIn) {
        final response = await _orderService.updateFCMToken(token);
        if (!response.success && kDebugMode) {
        } else if (kDebugMode) {}
      } else if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
    }
  }
}

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  // Note: Only initialize if not already initialized
  try {
    if (kDebugMode) {}

    // Store notification data for when app is opened
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications =
          prefs.getStringList('background_notifications') ?? [];
      final notificationData = jsonEncode({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'timestamp': TimeUtils.currentTimeInCairo.toUtc().toIso8601String(),
      });
      notifications.add(notificationData);

      // Keep only last 10 notifications to prevent storage bloat
      if (notifications.length > 10) {
        notifications.removeRange(0, notifications.length - 10);
      }

      await prefs.setStringList('background_notifications', notifications);
    } catch (e) {
      if (kDebugMode) {}
    }
  } catch (e) {
    if (kDebugMode) {}
  }
}

/// Lightweight screen shown immediately on notification tap while the full
/// order is fetched, then replaced with the real order details screen.
class _VendorOrderLoadingScreen extends StatefulWidget {
  final String orderId;
  const _VendorOrderLoadingScreen({required this.orderId});

  @override
  State<_VendorOrderLoadingScreen> createState() =>
      _VendorOrderLoadingScreenState();
}

class _VendorOrderLoadingScreenState extends State<_VendorOrderLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final response = await OrderService().getOrderById(widget.orderId);
    if (!mounted) return;

    if (response.success && response.data != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(order: response.data!),
        ),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.error ?? 'تعذر تحميل الطلب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Loads the order (to get the captain's id/name) before opening the
/// order-scoped chat.
class _VendorOrderChatLoadingScreen extends StatefulWidget {
  final String orderId;
  const _VendorOrderChatLoadingScreen({required this.orderId});

  @override
  State<_VendorOrderChatLoadingScreen> createState() => _VendorOrderChatLoadingScreenState();
}

class _VendorOrderChatLoadingScreenState extends State<_VendorOrderChatLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final response = await OrderService().getOrderById(widget.orderId);
    if (!mounted) return;

    final captain = response.data?.captain;
    if (response.success && captain != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VendorOrderChatScreen(
            orderId: widget.orderId,
            captainId: captain.id,
            captainName: captain.userName,
            orderStatus: response.data!.status,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
