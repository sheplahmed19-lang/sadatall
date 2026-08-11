import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:sadat_delivery_merged/captain/core/config/api_config.dart';
import 'package:sadat_delivery_merged/main.dart' show rootProviderContainer, navigatorKey;
import 'package:sadat_delivery_merged/captain/main_navigation.dart'
    show switchToCurrentOrderTab, switchToAvailableOrdersTab;
import 'package:sadat_delivery_merged/captain/features/chat/captain_support_chat_screen.dart';
import '../errors/app_exceptions.dart';
import '../network/api_client.dart';

const Set<String> _kAvailableOrderTypes = {
  'NEW_ORDER',
  'DELIVERY_AVAILABLE',
  'SPECIAL_ORDER',
  // The backend sends SPECIAL_ORDER_AVAILABLE for special-order pushes
  // (orderService.createSpecialOrder); without it those taps fell through
  // and left the captain on whatever tab they were already on.
  'SPECIAL_ORDER_AVAILABLE',
};

const Set<String> _kCurrentOrderTypes = {
  'CAPTAIN_ASSIGNED',
  'ORDER_APPROVED',
};

/// Switches the captain app's bottom tab based on an order notification's
/// `type`, using the root provider container (works without a BuildContext).
void _handleCaptainOrderNotification(Map<String, dynamic> data) {
  // New-order alerts arrive as type=NEW_ORDER_ALERT with the original
  // availability type preserved in `orderType` (the backend rewrites it).
  // Fall back to it so tapping still lands on the right tab.
  final type = (data['type'] as String?) == 'NEW_ORDER_ALERT'
      ? (data['orderType'] as String?) ?? 'DELIVERY_AVAILABLE'
      : data['type'] as String?;
  if (type == null) return;

  if (type == 'chat_message') {
    final chatId = data['chatId'] as String?;
    if (chatId != null && chatId.startsWith('support_captain_')) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const CaptainSupportChatScreen()),
      );
      return;
    }
    // Order-scoped chat (user or vendor side) — the chat entry buttons live
    // on the current-order screen, so route there.
    rootProviderContainer.read(switchToCurrentOrderTab)?.call();
    return;
  }

  if (_kAvailableOrderTypes.contains(type)) {
    rootProviderContainer.read(switchToAvailableOrdersTab)?.call();
  } else if (_kCurrentOrderTypes.contains(type)) {
    rootProviderContainer.read(switchToCurrentOrderTab)?.call();
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient();
  StreamSubscription<String>? _tokenSubscription;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      // Request permission for notifications
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        throw const NotificationException('Notification permission denied');
      }

      // Initialize local notifications
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings(
            '@mipmap/ic_launcher',
          ); // change icon if needed
      const DarwinInitializationSettings iosInitSettings =
          DarwinInitializationSettings();

      const InitializationSettings initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: iosInitSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          final payload =
              details.payload; // you passed this in _localNotifications.show()
          if (kDebugMode) {
            ('Notification tapped with payload: $payload');
          }

          if (payload != null) {
            _handleCaptainOrderNotification({'type': payload});
          }
        },
      );

      // Configure message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Handle notification when app is terminated
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Listen for token refreshes
      _tokenSubscription = _firebaseMessaging.onTokenRefresh.listen((token) {
        if (kDebugMode) {
          ('FCM Token refreshed: $token');
        }
        updateFCMTokenOnServer(token);
      });

      if (kDebugMode) {
        ('Notification service initialized successfully');
      }
    } catch (e) {
      throw NotificationException('Failed to initialize notifications: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      throw NotificationException('Failed to get FCM token: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        ('Subscribed to topic: $topic');
      }
    } catch (e) {
      throw NotificationException('Failed to subscribe to topic $topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        ('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      throw NotificationException(
        'Failed to unsubscribe from topic $topic: $e',
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[captain notif] foreground message ${message.messageId} data=${message.data}');

    // New-order alerts are sent data-only by the backend (no `notification`
    // block), so nothing is shown unless we raise a local notification here.
    final alertType = message.data['type'];
    if (alertType == 'NEW_ORDER_ALERT') {
      debugPrint('[captain notif] NEW_ORDER_ALERT received (foreground) — showing notification');
      await showNewOrderNotification(message.data);
      return;
    }
    // ORDER_TAKEN only existed to dismiss the ring alert; with notifications
    // only there is nothing to tear down.
    if (alertType == 'ORDER_TAKEN') {
      debugPrint('[captain notif] ORDER_TAKEN received (foreground) — ignored');
      return;
    }

    final notification = message.notification;
    if (notification != null) {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'default_channel', // channel id
            'General Notifications', // channel name
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('order_ping'),
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        sound: 'order_ping.mp3',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: message.data['type'], // pass type for navigation
      );
    }

    // Custom logic based on type
    final messageType = message.data['type'];
    switch (messageType) {
      case 'new_order':
        _handleNewOrderNotification(message);
        break;
      case 'request_reply':
        _handleRequestReplyNotification(message);
        break;
      case 'chat_message':
        // Local notification already shown above; navigation on tap is
        // handled by _handleCaptainOrderNotification via onMessageOpenedApp.
        break;
      default:
        if (kDebugMode) {
          ('Unknown notification type: $messageType');
        }
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      ('Message clicked: ${message.messageId}');
    }

    _handleCaptainOrderNotification(message.data);
  }

  void _handleNewOrderNotification(RemoteMessage message) {
    // Handle new order notification
    if (kDebugMode) {
      ('New order notification received');
    }
    // You can add local notification or update UI state here
  }

  void _handleRequestReplyNotification(RemoteMessage message) {
    // Handle request reply notification
    if (kDebugMode) {
      ('Request reply notification received');
    }
    // You can add local notification or update UI state here
  }

  /// Updates FCM token on the server
  Future<void> updateFCMTokenOnServer(String token) async {
    try {
      final response = await _apiClient.put(
        ApiConfig.captainsFcmToken,
        body: {'fcmToken': token},
      );

      if (response.success) {
        if (kDebugMode) {
          ('FCM token updated on server successfully');
        }
      } else {
        if (kDebugMode) {
          ('Failed to update FCM token on server: ${response.error}');
        }
      }
    } catch (e) {
      // FCM token updates should not trigger auth failures
      // This is a background operation that should fail silently
      if (kDebugMode) {
        ('Error updating FCM token on server: $e');
      }
    }
  }

  /// Sends a dummy token to server (for logout)
  Future<void> sendDummyTokenToServer() async {
    try {
      const dummyToken = 'dummy_token_logged_out';
      final response = await _apiClient.put(
        ApiConfig.captainsFcmToken,
        body: {'fcmToken': dummyToken},
      );

      if (response.success) {
        if (kDebugMode) {
          ('Dummy FCM token sent to server successfully');
        }
      } else {
        if (kDebugMode) {
          ('Failed to send dummy FCM token to server: ${response.error}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        ('Error sending dummy FCM token to server: $e');
      }
    }
  }

  Future<void> cancelTokenListener() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}

/// Raises the tray notification for a new available order.
///
/// These pushes are data-only (the backend omits the `notification` block so
/// the Flutter side is always woken), which means the OS shows nothing by
/// itself — this is what actually surfaces the order to the captain. Usable
/// from both the app isolate and the FCM background isolate, so it builds its
/// own plugin instance rather than relying on NotificationService's.
Future<void> showNewOrderNotification(Map<String, dynamic> data) async {
  final plugin = FlutterLocalNotificationsPlugin();
  // In the background isolate the plugin has never been initialized; doing it
  // again in the app isolate is harmless.
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('order_ping'),
    ),
    iOS: DarwinNotificationDetails(sound: 'order_ping.mp3'),
  );

  final vendorName = data['vendorName']?.toString() ?? '';
  final deliveryPrice = data['deliveryPrice']?.toString() ?? '';
  final body = [
    if (vendorName.isNotEmpty) vendorName,
    if (deliveryPrice.isNotEmpty) '$deliveryPrice جنيه',
  ].join(' - ');

  await plugin.show(
    // Keyed by order so repeated pushes for the same order replace rather
    // than stack, and different orders each get their own notification.
    data['orderId']?.toString().hashCode ?? DateTime.now().millisecondsSinceEpoch.hashCode,
    'طلب توصيل جديد',
    body.isNotEmpty ? body : 'اضغط لعرض التفاصيل',
    details,
    payload: (data['orderType'] ?? data['type'])?.toString(),
  );
}

/// Handles a captain-relevant order push from the FCM background isolate
/// (app backgrounded or fully killed). Safe to call for every background
/// message regardless of app mode — non-captain messages just won't match.
@pragma('vm:entry-point')
Future<void> handleCaptainBackgroundOrderAlert(RemoteMessage message) async {
  final type = message.data['type'];
  debugPrint('[captain notif] background message ${message.messageId} type=$type data=${message.data}');
  if (type == 'NEW_ORDER_ALERT') {
    debugPrint('[captain notif] NEW_ORDER_ALERT received (background) — showing notification');
    await showNewOrderNotification(message.data);
  }
}
