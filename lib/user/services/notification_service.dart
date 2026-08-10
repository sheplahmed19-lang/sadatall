import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sadat_delivery_merged/main.dart' show navigatorKey;
import 'package:sadat_delivery_merged/user/main.dart' show openOffersTab;
import 'package:sadat_delivery_merged/user/screens/orders/order_details_screen.dart';
import 'package:sadat_delivery_merged/user/screens/chat/support_chat_tab.dart';
import 'package:sadat_delivery_merged/user/screens/chat/order_chat_screen.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'user_order_service.dart';

const Set<String> _kOrderNotificationTypes = {
  'NEW_ORDER',
  'COUNTER_OFFER',
  'ORDER_APPROVED',
  'DELIVERY_AVAILABLE',
  'CAPTAIN_ASSIGNED',
  'ORDER_CANCELLED',
  'ORDER_DELIVERED',
  'CAPTAIN_ARRIVED',
  'SPECIAL_ORDER',
};

@pragma('vm:entry-point')
Future<void> userFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  _handleUserNotificationData(message.data);
}

void _handleUserNotificationData(Map<String, dynamic> data) {
  final String? type = data['type'] as String?;
  final String? orderId = data['orderId'] as String?;
  final String? newStatus = data['status'] as String?;
  final String? captainName = data['captainName'] as String?;

  switch (type) {
    case 'order_status_update':
      ('Order status update for order: $orderId, new status: $newStatus');
      break;
    case 'new_order_confirmation':
      ('New order confirmation for order: $orderId');
      break;
    case 'captain_assigned':
      ('Captain $captainName assigned to order: $orderId');
      break;
    case 'order_delivered':
      ('Order delivered: $orderId');
      break;
    case 'order_cancelled':
      ('Order cancelled: $orderId');
      break;
    case 'ANNOUNCEMENT':
      openOffersTab.value = DateTime.now().millisecondsSinceEpoch;
      break;
    case 'chat_message':
      ('New chat message in chat: ${data['chatId']}');
      break;
  }
}

/// Handles a notification tap: if it carries an order-related type and an
/// orderId, fetches that order and pushes the order details screen. A
/// chat_message notification instead opens the relevant chat thread.
Future<void> _handleUserNotificationTap(Map<String, dynamic> data) async {
  final type = data['type'] as String?;

  if (type == 'chat_message') {
    _openChatFromNotification(data);
    return;
  }

  final orderId = data['orderId'] as String?;
  if (orderId == null || orderId.isEmpty) return;
  if (type != null && !_kOrderNotificationTypes.contains(type)) return;

  final navState = navigatorKey.currentState;
  if (navState == null) return;

  navState.push(
    MaterialPageRoute(builder: (_) => _OrderLoadingScreen(orderId: orderId)),
  );
}

void _openChatFromNotification(Map<String, dynamic> data) {
  final navState = navigatorKey.currentState;
  if (navState == null) return;
  final chatId = data['chatId'] as String?;
  if (chatId == null) return;

  if (chatId.startsWith('support_user_')) {
    navState.push(MaterialPageRoute(builder: (_) => const SupportChatTab()));
    return;
  }

  final orderId = data['orderId'] as String?;
  if (chatId.endsWith('_user_captain') &&
      orderId != null &&
      orderId.isNotEmpty) {
    navState.push(
      MaterialPageRoute(
        builder: (_) => _OrderChatLoadingScreen(orderId: orderId),
      ),
    );
  }
}

/// Loads the order (to get the captain's id/name) before opening the
/// order-scoped chat — mirrors _OrderLoadingScreen's fetch-then-navigate
/// pattern for order detail notifications.
class _OrderChatLoadingScreen extends StatefulWidget {
  final String orderId;
  const _OrderChatLoadingScreen({required this.orderId});

  @override
  State<_OrderChatLoadingScreen> createState() =>
      _OrderChatLoadingScreenState();
}

class _OrderChatLoadingScreenState extends State<_OrderChatLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final response = await UserOrderService().getOrderById(widget.orderId);
    if (!mounted) return;

    final captain = response.data?.captain;
    if (response.success && captain != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderChatScreen(
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

/// Lightweight screen shown immediately on notification tap while the full
/// order is fetched, then replaced with the real order details screen.
class _OrderLoadingScreen extends StatefulWidget {
  final String orderId;
  const _OrderLoadingScreen({required this.orderId});

  @override
  State<_OrderLoadingScreen> createState() => _OrderLoadingScreenState();
}

class _OrderLoadingScreenState extends State<_OrderLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final response = await UserOrderService().getOrderById(widget.orderId);
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  Future<void> initialize() async {
    // Request permission for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Create notification channel with image support
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'channel_id',
      'channel_name',
      description: 'channel_description',
      importance: Importance.max,
      showBadge: true,
      enableLights: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(
      userFirebaseMessagingBackgroundHandler,
    );

    // Handle notification tap when app is backgrounded
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleUserNotificationTap(message.data);
    });

    // Handle notification tap when app was launched from a terminated state
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleUserNotificationTap(initialMessage.data);
    }

    // Get the token
    _fcmToken = await _firebaseMessaging.getToken();
    if (_fcmToken != null) {
      ('FCM Token: $_fcmToken');
      // Send token to backend
      await _sendTokenToBackend(_fcmToken!);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      ('FCM Token refreshed: $newToken');
      // Send new token to backend
      await _sendTokenToBackend(newToken);
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      // Only send FCM token if user is logged in (has access token)
      final storageService = StorageService();
      final accessToken = await storageService.getAccessToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        final apiService = ApiService();
        await apiService.updateFCMToken(token);
        if (kDebugMode) {
          ('FCM token sent to backend successfully');
        }
      } else if (kDebugMode) {
        ('Skipping FCM token update - user not logged in');
      }
    } catch (e) {
      if (kDebugMode) {
        ('Error sending FCM token to backend: $e');
      }
    }
  }

  // Public method for sending FCM token to backend (used after login/signup)
  Future<void> sendTokenToBackend(String? token) async {
    if (token != null) {
      await _sendTokenToBackend(token);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    ('Foreground message received: ${message.notification?.title}');

    final imageUrl =
        message.data['imageUrl'] as String? ??
        message.notification?.android?.imageUrl;

    ('Foreground imageUrl: $imageUrl');

    await _showLocalNotification(
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      imageUrl: imageUrl,
      data: message.data,
    );

    _handleUserNotificationData(message.data);
  }

  void onDidReceiveNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    ('Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _handleUserNotificationTap(data);
    } catch (e) {
      if (kDebugMode) {
        ('Failed to parse notification payload: $e');
      }
    }
  }

  Future<void> _showLocalNotification(
    String title,
    String body, {
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    AndroidNotificationDetails androidNotificationDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final ByteArrayAndroidBitmap? bigPicture = await _loadNetworkImage(
        imageUrl,
      );
      androidNotificationDetails = AndroidNotificationDetails(
        'channel_id',
        'channel_name',
        channelDescription: 'channel_description',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: bigPicture != null
            ? BigPictureStyleInformation(
                bigPicture,
                contentTitle: title,
                summaryText: body,
              )
            : null,
      );
    } else {
      androidNotificationDetails = const AndroidNotificationDetails(
        'channel_id',
        'channel_name',
        channelDescription: 'channel_description',
        importance: Importance.max,
        priority: Priority.high,
      );
    }

    final notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  Future<ByteArrayAndroidBitmap?> _loadNetworkImage(String url) async {
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return ByteArrayAndroidBitmap(response.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getToken() async {
    return _fcmToken ?? await _firebaseMessaging.getToken();
  }

  void subscribeToTopic(String topic) {
    _firebaseMessaging.subscribeToTopic(topic);
  }

  void unsubscribeFromTopic(String topic) {
    _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  Future<void> clearAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
