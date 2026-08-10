import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:vibration/vibration.dart';

import '../../features/orders/data/services/orders_service.dart';

/// Entry point for the overlay's own, separate Flutter engine — invoked
/// natively by flutter_overlay_window when FlutterOverlayWindow.showOverlay()
/// is called from the main app (foreground or the FCM background isolate).
/// This engine has no connection to the main app's state; it fetches its
/// order data via FlutterOverlayWindow.overlayListener and, on
/// accept/decline, calls the backend itself directly (it's a fully live
/// Dart isolate with normal network access, unlike the main app which may
/// be backgrounded or killed at this point).
// flutter_overlay_window's native Android side hardcodes the dart
// entrypoint function name to exactly "overlayMain" (see OverlayService.java
// / FlutterOverlayWindowPlugin.java, DartExecutor.DartEntrypoint(bundlePath,
// "overlayMain")) — it is not configurable, so this name is required.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OrderOverlayScreen(),
  ));
}

class OrderOverlayScreen extends StatefulWidget {
  const OrderOverlayScreen({super.key});

  @override
  State<OrderOverlayScreen> createState() => _OrderOverlayScreenState();
}

class _OrderOverlayScreenState extends State<OrderOverlayScreen> {
  final _ordersService = OrdersService();
  final _player = AudioPlayer();
  StreamSubscription? _listenerSub;
  Timer? _countdownTimer;

  Map<String, dynamic>? _data;
  int _secondsLeft = 10;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _listenerSub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (_data != null || event is! Map) return;
      final data = Map<String, dynamic>.from(event);
      final duration = int.tryParse(data['durationSeconds']?.toString() ?? '') ?? 10;
      setState(() {
        _data = data;
        _secondsLeft = duration;
      });
      _startRinging();
      _startCountdown();
    });
  }

  void _startRinging() {
    _player.setReleaseMode(ReleaseMode.loop);
    _player.play(AssetSource('captain/sounds/order_ping.mp3'));
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: const [0, 1000, 1000], repeat: 1);
      }
    });
  }

  void _stopRinging() {
    _player.stop();
    Vibration.cancel();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _respond('EXPIRED');
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  Future<void> _respond(String action) async {
    if (_responding || _data == null) return;
    _responding = true;
    _stopRinging();
    _countdownTimer?.cancel();

    final orderId = _data!['orderId']?.toString();
    try {
      if (orderId != null) {
        if (action == 'ACCEPT') {
          await _ordersService.acceptOrder(orderId);
        } else {
          await _ordersService.rejectOrder(orderId, reason: action);
        }
      }
    } catch (_) {
      // Nothing meaningful to show on a transient overlay — the order
      // simply stays available/unclaimed server-side if this failed, and
      // the next NEW_ORDER_ALERT resend picks the captain back up.
    } finally {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  @override
  void dispose() {
    _listenerSub?.cancel();
    _countdownTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: data == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.delivery_dining, color: Color(0xFF0955fa), size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data['vendorName']?.toString().isNotEmpty == true
                                ? data['vendorName'].toString()
                                : 'طلب توصيل جديد',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_secondsLeft',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if ((data['deliveryPrice']?.toString() ?? '').isNotEmpty)
                      Text(
                        'سعر التوصيل: ${data['deliveryPrice']} جنيه',
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _responding ? null : () => _respond('REJECTED'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('رفض', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _responding ? null : () => _respond('ACCEPT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('قبول', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
