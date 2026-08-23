import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Consumer;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// App mode
import 'app_mode.dart';
import 'firebase_options.dart';

// Mode selector
import 'mode_selector/mode_selector_screen.dart';

// ── Captain imports ──────────────────────────────────────────────────────────
import 'captain/core/theme/app_theme.dart' as captain_theme;
import 'captain/core/providers/theme_provider.dart' as captain_theme_provider;
import 'captain/core/services/notification_service.dart' as captain_notif;
import 'captain/core/services/firebase_config_service.dart';
import 'captain/features/auth/presentation/providers/auth_provider.dart'
    as captain_auth;
import 'captain/features/auth/presentation/screens/login_screen.dart'
    as captain_login;
import 'captain/features/auth/presentation/screens/captain_locked_screen.dart';
import 'captain/main_navigation.dart';

// ── Vendor imports ────────────────────────────────────────────────────────────
import 'vendor/theme/app_theme.dart' as vendor_theme;
import 'vendor/providers/auth_provider.dart' as vendor_auth;
import 'vendor/providers/theme_provider.dart' as vendor_theme_provider;
import 'vendor/services/api_service.dart';
import 'vendor/services/notification_service.dart' as vendor_notif;
import 'vendor/core/services/base_url_service.dart';
import 'vendor/screens/auth/login_screen.dart' as vendor_login;
import 'vendor/screens/auth/signup_screen.dart' as vendor_signup;
import 'vendor/screens/splash_screen.dart' as vendor_splash;
import 'vendor/screens/main/main_app_screen.dart' as vendor_main;
import 'vendor/utils/time_utils.dart';

// ── User imports ──────────────────────────────────────────────────────────────
import 'user/theme/app_theme.dart' as user_theme;
import 'user/providers/auth_provider.dart' as user_auth;
import 'user/providers/time_provider.dart';
import 'user/providers/theme_provider.dart' as user_theme_provider;
import 'user/core/config/app_initialization_service.dart';
import 'user/screens/auth/login_screen.dart' as user_login;
import 'user/screens/auth/signup_screen.dart' as user_signup;
import 'user/screens/splash_screen.dart' as user_splash;
import 'user/screens/main_screen.dart' as user_main;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Separate key for the mode selector so it never reuses a mode app's navigator state.
final GlobalKey<NavigatorState> _modeSelectorNavigatorKey =
    GlobalKey<NavigatorState>();

/// Root Riverpod container backing the whole widget tree (via
/// UncontrolledProviderScope below). Lets services without a BuildContext
/// (e.g. notification handlers) read/write the same providers the UI uses.
final rootProviderContainer = ProviderContainer();

// ─────────────────────────────────────────────────────────────────────────────
// SHARED FORCE-UPDATE HELPER
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the required version string if a force-update is needed,
/// or null if the app is up to date / the check could not be completed.
Future<String?> _checkForceUpdateForMode(String mode) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('delivery_app_config')
        .doc('base_url')
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('timeout'),
        );
    if (!snap.exists) return null;

    // iOS and Android ship on their own review/rollout schedules, so the
    // minimum version has to be tracked per platform — a single field would
    // force-update one store's users to a build that is not live there yet.
    // Falls back to version_user so an existing config (and any platform
    // without its own field) keeps working unchanged.
    final data = snap.data();
    final platformField = Platform.isIOS ? 'version_ios' : 'version_user';
    final required =
        (data?[platformField] as String?) ?? (data?['version_user'] as String?);
    debugPrint(
      'Force update check — field: $platformField, required: $required',
    );
    if (required == null || required.isEmpty) return null;
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    debugPrint('Force update check — current: $current');
    final c = current
        .trim()
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final r = required
        .trim()
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    while (c.length < 3) {
      c.add(0);
    }
    while (r.length < 3) {
      r.add(0);
    }
    for (int i = 0; i < 3; i++) {
      if (r[i] > c[i]) return required;
      if (r[i] < c[i]) return null;
    }
  } catch (e) {
    debugPrint('Force update check failed: $e');
  }
  return null;
}

Future<void> initializeAppMode(String mode) async {
  if (mode == AppMode.captain.name) {
    try {
      await FirebaseConfigService.getBaseUrlWithFallback();
    } catch (_) {}
    try {
      await captain_notif.NotificationService().initialize();
    } catch (_) {}
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } else if (mode == AppMode.vendor.name) {
    TimeUtils.initialize();
    final apiService = ApiService();
    apiService.initialize();
    try {
      await BaseUrlService.initializeBaseUrl().timeout(
        const Duration(seconds: 10),
      );
      if (BaseUrlService.isInitialized) {
        apiService.updateBaseUrl(BaseUrlService.baseUrl);
      }
    } catch (_) {}
    try {
      await vendor_notif.NotificationService().initialize().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {}
  } else if (mode == AppMode.user.name) {
    await AppInitializationService.initializeApp();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('selected_app_mode');

  // If savedMode is null, we can do some default initialization (like Captain background handler)
  if (savedMode == null) {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } else {
    await initializeAppMode(savedMode);
  }

  runApp(
    UncontrolledProviderScope(
      container: rootProviderContainer,
      child: RootApp(initialMode: savedMode),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await captain_notif.handleCaptainBackgroundOrderAlert(message);
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT ROUTER
// ─────────────────────────────────────────────────────────────────────────────

// Create provider instances once — never recreated on rebuild.
final _vendorAuthProvider = vendor_auth.AuthProvider();
final _vendorThemeProvider = vendor_theme_provider.ThemeProvider();
final _userAuthProvider = user_auth.AuthProvider();
final _timeProvider = TimeProvider();
final _userThemeProvider = user_theme_provider.ThemeProvider();

// Dedicated Riverpod container for captain — survives mode switches.
final _captainContainer = ProviderContainer();

class RootApp extends StatefulWidget {
  final String? initialMode;
  const RootApp({required this.initialMode});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  String? _initializedMode;

  @override
  void initState() {
    super.initState();
    _initializedMode = widget.initialMode;
    appModeNotifier.value = widget.initialMode;
    appModeNotifier.addListener(_onModeChanged);
    // Delay slightly so Firebase finishes settling after main() initialization.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _runForceUpdateCheck(widget.initialMode ?? '');
    });
  }

  @override
  void dispose() {
    appModeNotifier.removeListener(_onModeChanged);
    super.dispose();
  }

  Future<void> _runForceUpdateCheck(String mode) async {
    debugPrint('Running force update check for mode: $mode');
    final requiredVersion = await _checkForceUpdateForMode(mode);
    if (requiredVersion != null && mounted) {
      _showForceUpdateDialog(requiredVersion);
    }
  }

  Future<void> _showForceUpdateDialog(String requiredVersion) async {
    // Wait until the navigator is mounted (Firestore result may arrive before
    // the child MaterialApp finishes building its first frame).
    for (int i = 0; i < 20; i++) {
      if (navigatorKey.currentState?.overlay != null) break;
      if (_modeSelectorNavigatorKey.currentState?.overlay != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final nav = navigatorKey.currentState?.overlay != null
        ? navigatorKey.currentState
        : _modeSelectorNavigatorKey.currentState;
    if (nav == null || nav.overlay == null) {
      debugPrint('Force update dialog: navigator not available, skipping');
      return;
    }
    // Use navigator.push with a transparent route to avoid touching BuildContext
    // after an async gap (which triggers a lint warning).
    nav.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: AlertDialog(
                title: const Text('تحديث مطلوب', textAlign: TextAlign.center),
                content: Text(
                  'يتطلب التطبيق تحديثاً إلى الإصدار $requiredVersion أو أحدث.\n'
                  'يرجى تحديث التطبيق للمتابعة.',
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      // Send each platform to its own store. This used to be
                      // the Play Store URL unconditionally, so an iOS user who
                      // tapped "تحديث الآن" landed on a page they cannot
                      // install from — with no way past the blocking dialog.
                      final storeUrl = Platform.isIOS
                          ? 'https://apps.apple.com/app/id6775554417'
                          : 'https://play.google.com/store/apps/details?id=sadat.delivery.com';
                      final uri = Uri.parse(storeUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: const Text('تحديث الآن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onModeChanged() async {
    final newMode = appModeNotifier.value;
    if (newMode == _initializedMode) {
      if (mounted) setState(() {});
      return;
    }

    if (newMode == null) {
      if (mounted) {
        setState(() {
          _initializedMode = null;
        });
      }
      return;
    }

    // Fire initialization in the background and show the app immediately.
    // Each mode's splash/auth screen handles its own loading state.
    initializeAppMode(newMode).ignore();

    if (mounted) {
      setState(() {
        _initializedMode = newMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = appModeNotifier.value;
    if (mode == null) {
      return MaterialApp(
        navigatorKey: _modeSelectorNavigatorKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'SA'),
        supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ModeSelectorScreen(),
      );
    }
    switch (AppMode.values.byName(mode)) {
      case AppMode.captain:
        return _CaptainApp();
      case AppMode.vendor:
        return _VendorApp();
      case AppMode.user:
        return _UserApp();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAPTAIN APP
// ─────────────────────────────────────────────────────────────────────────────
class _CaptainApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(captain_theme_provider.themeModeProvider);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'تعالالي _T3alaly',
      theme: captain_theme.AppTheme.light,
      darkTheme: captain_theme.AppTheme.dark,
      themeMode: themeMode,
      home: const _CaptainAuthWrapper(),
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}

class _CaptainAuthWrapper extends ConsumerStatefulWidget {
  const _CaptainAuthWrapper();

  @override
  ConsumerState<_CaptainAuthWrapper> createState() =>
      _CaptainAuthWrapperState();
}

class _CaptainAuthWrapperState extends ConsumerState<_CaptainAuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(captain_auth.authStateProvider);
    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (authState.isLocked) return const CaptainLockedScreen();
    return authState.isAuthenticated
        ? const MainNavigation()
        : const captain_login.LoginScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VENDOR APP
// ─────────────────────────────────────────────────────────────────────────────
class _VendorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _vendorAuthProvider),
        ChangeNotifierProvider.value(value: _vendorThemeProvider),
      ],
      child: Consumer<vendor_theme_provider.ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: 'تعالالي _T3alaly',
          debugShowCheckedModeBanner: false,
          theme: vendor_theme.AppTheme.lightTheme,
          darkTheme: vendor_theme.AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const vendor_splash.SplashScreen(),
            '/login': (context) => const vendor_login.LoginScreen(),
            '/signup': (context) => const vendor_signup.SignupScreen(),
            '/main': (context) => const vendor_main.MainAppScreen(),
            '/dashboard': (context) => const vendor_main.MainAppScreen(),
          },
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER APP
// ─────────────────────────────────────────────────────────────────────────────
class _UserApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _userAuthProvider),
        ChangeNotifierProvider.value(value: _timeProvider),
        ChangeNotifierProvider.value(value: _userThemeProvider),
      ],
      child: Consumer<user_theme_provider.ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: 'تعالالي _T3alaly',
          debugShowCheckedModeBanner: false,
          theme: user_theme.AppTheme.lightTheme,
          darkTheme: user_theme.AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const user_splash.SplashScreen(),
            '/login': (context) => const user_login.LoginScreen(),
            '/signup': (context) => const user_signup.SignupScreen(),
            '/main': (context) => const user_main.MainScreen(),
            '/dashboard': (context) => const user_main.MainScreen(),
          },
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
  }
}
