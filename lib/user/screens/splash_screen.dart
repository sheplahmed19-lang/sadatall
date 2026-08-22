import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/auth_provider.dart';

/// Launch screen for the user app: plays `assets/intro.mp4` once, then moves
/// on to the dashboard.
///
/// The auth check runs in parallel with playback rather than after it, so the
/// intro costs nothing beyond its own length. If the video cannot be loaded or
/// played (codec, corrupt asset, an emulator without the right decoder) the
/// screen shows a plain black frame with a spinner and moves on normally, so a
/// broken video can never strand the user on the splash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoFailed = false;

  /// Guards the navigation so the video finishing and the safety timeout
  /// cannot both push the dashboard.
  bool _navigated = false;

  /// Hard ceiling on how long this screen can ever be shown. Without it a
  /// video that stalls mid-playback would never fire its completion check and
  /// the app would sit here forever.
  static const Duration _maxSplashDuration = Duration(seconds: 20);

  /// Fallback duration when there is no video to time against.
  static const Duration _fallbackSplashDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeApp();
    });
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    _animationController.forward();

    // Kick the auth check off without awaiting it: it runs while the intro
    // plays instead of adding to the wait.
    final authFuture = _checkAuth();

    // Never let a stalled video trap the user here.
    Timer(_maxSplashDuration, _goToDashboard);

    await _initializeVideo();

    if (_videoFailed) {
      // No video: keep the old behaviour — brief splash, then continue once
      // auth has settled.
      await authFuture;
      await Future.delayed(_fallbackSplashDuration);
      _goToDashboard();
    }
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.checkAuthStatus().timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      );
    } catch (_) {
      // Auth failures are handled by the dashboard's own routing; they must
      // not block the intro from completing.
    }
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset('assets/intro.mp4');
    _videoController = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setVolume(1.0);
      controller.addListener(_onVideoTick);
      await controller.play();

      setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  /// VideoPlayer has no "completed" callback, so completion is detected by
  /// comparing position against duration on each tick.
  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;

    if (controller.value.position >= duration) {
      _goToDashboard();
    }
  }

  void _goToDashboard() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final showVideo = _videoReady && controller != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo)
              // Cover the screen without distorting the frame: scale the video
              // to its natural size inside a FittedBox rather than stretching
              // it to the viewport's aspect ratio.
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              // Plain black while the video initialises, and as the fallback
              // if it never does. The old entry.jpeg logo flashed for a beat
              // before the video appeared, which read as a broken frame.
              const ColoredBox(color: Colors.black),
            if (!showVideo)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                      strokeWidth: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
