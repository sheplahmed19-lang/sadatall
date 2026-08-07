import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';
import 'package:sadat_delivery_merged/main.dart' show rootProviderContainer;
import 'package:sadat_delivery_merged/captain/main_navigation.dart'
    show switchToCurrentOrderTab;
import '../../features/orders/data/services/orders_service.dart';

/// Shows/dismisses the captain app's incoming-order "ring" alert via
/// flutter_callkit_incoming's call-like full-screen UI, and wires its
/// accept/decline/timeout events to the backend. Runs both in the normal
/// app isolate and in the FCM background isolate (its calls are plain
/// platform-channel calls, no app/provider state required to show/dismiss).
class OrderAlertService {
  OrderAlertService._();

  static final OrdersService _ordersService = OrdersService();
  static StreamSubscription<CallEvent?>? _eventSubscription;

  // CallKit requires `id` to be a real UUID (iOS parses it with
  // `UUID(uuidString:)` and silently ignores the call otherwise), so we
  // can't just use the orderId as the call id. Track callId -> orderId to
  // resolve it back on accept/decline/timeout.
  static final Map<String, String> _callIdToOrderId = {};

  /// Registers the accept/decline/timeout listener. Safe to call multiple
  /// times — only subscribes once. Call this once from the captain
  /// NotificationService.initialize() (foreground/app-isolate context).
  static void initialize() {
    _eventSubscription ??= FlutterCallkitIncoming.onEvent.listen(_onEvent);
  }

  static Future<void> _onEvent(CallEvent? event) async {
    debugPrint('[OrderAlertService] event: $event');
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        await _handleAccept(callKitParams.id, callKitParams.extra);
        break;
      case CallEventActionCallDecline(:final callKitParams):
        await _handleDismiss(callKitParams.id, reason: 'REJECTED');
        break;
      case CallEventActionCallTimeout(:final id):
        await _handleDismiss(id, reason: 'EXPIRED');
        break;
      default:
        break;
    }
  }

  static Future<void> _handleAccept(String callId, Map<String, dynamic>? extra) async {
    final orderId = extra?['orderId']?.toString() ?? _callIdToOrderId[callId];
    _callIdToOrderId.remove(callId);
    if (orderId == null) return;

    try {
      await _ordersService.acceptOrder(orderId);
      rootProviderContainer.read(switchToCurrentOrderTab)?.call();
    } catch (e) {
      if (kDebugMode) debugPrint('OrderAlertService accept failed: $e');
    }
  }

  static Future<void> _handleDismiss(String callId, {required String reason}) async {
    final orderId = _callIdToOrderId.remove(callId);
    if (orderId == null) return;

    try {
      await _ordersService.rejectOrder(orderId, reason: reason);
    } catch (e) {
      if (kDebugMode) debugPrint('OrderAlertService dismiss($reason) failed: $e');
    }
  }

  /// Displays the ringing incoming-order screen from a NEW_ORDER_ALERT
  /// FCM data payload (orderId, vendorName, deliveryPrice, durationSeconds).
  static Future<void> showIncomingOrderAlert(Map<String, dynamic> data) async {
    final orderId = data['orderId']?.toString();
    if (orderId == null) return;

    final callId = const Uuid().v4();
    _callIdToOrderId[callId] = orderId;

    final durationSeconds = int.tryParse(data['durationSeconds']?.toString() ?? '') ?? 10;
    final deliveryPrice = data['deliveryPrice']?.toString() ?? '';
    final vendorName = data['vendorName']?.toString().isNotEmpty == true
        ? data['vendorName'].toString()
        : 'طلب توصيل جديد';

    final params = CallKitParams(
      id: callId,
      nameCaller: vendorName,
      handle: deliveryPrice.isNotEmpty ? '$deliveryPrice جنيه' : '',
      type: 0,
      duration: durationSeconds * 1000,
      extra: <String, dynamic>{'orderId': orderId, ...data},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isFullScreen: true,
        ringtonePath: 'order_ping',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'تنبيه طلب جديد',
        isShowCallID: false,
        textAccept: 'قبول',
        textDecline: 'رفض',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
      ),
    );

    debugPrint('[OrderAlertService] showCallkitIncoming callId=$callId orderId=$orderId duration=${params.duration}');
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('[OrderAlertService] showCallkitIncoming succeeded for orderId=$orderId');
    } catch (e, st) {
      debugPrint('[OrderAlertService] showCallkitIncoming FAILED for orderId=$orderId: $e\n$st');
    }
  }

  /// Ends the ring alert on this device — used when the order was already
  /// taken by another captain (ORDER_TAKEN push) or is otherwise stale.
  static Future<void> dismissIncomingOrderAlert(String orderId) async {
    final callId = _callIdToOrderId.entries
        .firstWhere(
          (entry) => entry.value == orderId,
          orElse: () => const MapEntry('', ''),
        )
        .key;
    if (callId.isEmpty) return;

    _callIdToOrderId.remove(callId);
    await FlutterCallkitIncoming.endCall(callId);
  }
}
