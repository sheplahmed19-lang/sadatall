import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:uuid/uuid.dart';
import 'package:sadat_delivery_merged/main.dart' show rootProviderContainer;
import 'package:sadat_delivery_merged/captain/main_navigation.dart'
    show switchToCurrentOrderTab;
import '../../features/orders/data/services/orders_service.dart';
// Pulled in only so the `overlayMain` entry point below is part of the
// compiled program's reachable set — flutter_overlay_window's native side
// looks it up by name at runtime (see OverlayService.java), and an
// @pragma('vm:entry-point') function that isn't imported from anywhere
// reachable from main() would never be compiled in at all, pragma or not.
// ignore: unused_import
import 'order_overlay_screen.dart';

/// Shows/dismisses the captain app's incoming-order ring alert and wires
/// accept/decline/timeout back to the backend. Runs both in the normal app
/// isolate and in the FCM background isolate.
///
/// Android and iOS use different presentations because of what each OS
/// actually allows a backgrounded/killed app to draw:
/// - Android: a custom half-screen overlay (order_overlay_screen.dart),
///   shown via flutter_overlay_window's "draw over other apps" window.
/// - iOS: real CallKit, full-screen — Apple allows no other mechanism for
///   a backgrounded/killed app to take over the screen at all, so
///   half-screen isn't an option there.
class OrderAlertService {
  OrderAlertService._();

  static final OrdersService _ordersService = OrdersService();
  static StreamSubscription<CallEvent?>? _eventSubscription;

  // iOS/CallKit requires `id` to be a real UUID (it's parsed natively with
  // `UUID(uuidString:)` and silently ignored otherwise), so we can't just
  // use the orderId as the call id. Track callId -> orderId to resolve it
  // back on accept/decline/timeout.
  static final Map<String, String> _callIdToOrderId = {};

  // Android overlay path — which order's overlay is currently showing, so
  // dismissIncomingOrderAlert() closes the right (or a still-relevant) one.
  static String? _currentOverlayOrderId;

  /// Registers the accept/decline/timeout listener (iOS) or requests the
  /// "draw over other apps" permission (Android). Safe to call multiple
  /// times. Call this once from NotificationService.initialize().
  static void initialize() {
    if (Platform.isIOS) {
      _eventSubscription ??= FlutterCallkitIncoming.onEvent.listen(_onEvent);
      return;
    }
    if (Platform.isAndroid) {
      _requestOverlayPermission();
    }
  }

  static Future<void> _requestOverlayPermission() async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        await FlutterOverlayWindow.requestPermission();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OrderAlertService overlay permission request failed: $e');
    }
  }

  /// Displays the incoming-order alert — a half-screen overlay on Android,
  /// full-screen CallKit on iOS.
  static Future<void> showIncomingOrderAlert(Map<String, dynamic> data) async {
    final orderId = data['orderId']?.toString();
    if (orderId == null) return;

    if (Platform.isAndroid) {
      await _showAndroidOverlay(orderId, data);
    } else {
      await _showIosCallKit(orderId, data);
    }
  }

  /// Ends the alert on this device — used when the order was already taken
  /// by another captain (ORDER_TAKEN push) or is otherwise stale.
  static Future<void> dismissIncomingOrderAlert(String orderId) async {
    if (Platform.isAndroid) {
      if (_currentOverlayOrderId != orderId) return;
      _currentOverlayOrderId = null;
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (e) {
        if (kDebugMode) debugPrint('OrderAlertService closeOverlay failed: $e');
      }
      return;
    }

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

  // ── Android: half-screen overlay ────────────────────────────────────────

  static Future<void> _showAndroidOverlay(String orderId, Map<String, dynamic> data) async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        debugPrint('[OrderAlertService] overlay permission not granted, skipping alert for orderId=$orderId');
        return;
      }

      // Best-effort: clear out any stale overlay from a previous order
      // before showing this one.
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}

      final view = ui.PlatformDispatcher.instance.views.first;
      final screenHeight = view.physicalSize.height / view.devicePixelRatio;
      final halfHeight = (screenHeight / 2).round();

      _currentOverlayOrderId = orderId;
      await FlutterOverlayWindow.showOverlay(
        height: halfHeight,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        visibility: NotificationVisibility.visibilityPublic,
        overlayTitle: 'طلب توصيل جديد',
        overlayContent: 'اضغط لعرض التفاصيل',
        enableDrag: false,
      );
      // The overlay runs in its own separate Flutter engine that needs a
      // moment to start up and register its own overlayListener — there's
      // no ready/ack handshake in this plugin, so this delay is the
      // pragmatic way to avoid shareData() arriving before anyone's
      // listening for it.
      await Future.delayed(const Duration(milliseconds: 600));
      await FlutterOverlayWindow.shareData(data);
      debugPrint('[OrderAlertService] Android overlay shown for orderId=$orderId');
    } catch (e, st) {
      debugPrint('[OrderAlertService] Android overlay FAILED for orderId=$orderId: $e\n$st');
    }
  }

  // ── iOS: CallKit ──────────────────────────────────────────────────────

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

  static Future<void> _showIosCallKit(String orderId, Map<String, dynamic> data) async {
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
}
