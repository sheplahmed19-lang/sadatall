import 'package:sadat_delivery_merged/user/core/config/api_config.dart';
import 'package:sadat_delivery_merged/user/services/api_service.dart';
import 'package:sadat_delivery_merged/user/services/notification_service.dart';
import 'package:sadat_delivery_merged/user/utils/time_utils.dart';

class AppInitializationService {
  /// Completes once the slow, network-bound part of startup has finished.
  /// Nothing needs to await this to draw the UI — it exists so callers that
  /// genuinely need a settled base URL can wait on it instead of racing.
  static Future<void>? _backgroundInit;
  static Future<void> get ready => _backgroundInit ?? Future.value();

  /// Fast, synchronous-enough setup that must happen before the first frame.
  ///
  /// Everything network-bound is deliberately NOT awaited here. It used to be:
  /// a Firestore base-URL fetch (8s timeout), ApiService init (5s), and
  /// notification/APNs registration (8s) all ran in sequence before runApp(),
  /// so a cold start showed up to 21 seconds of white screen before any pixel
  /// was drawn. On iOS, where APNs registration and the first network call get
  /// no warm cache, that regularly landed in the 10-15s range.
  ///
  /// None of it is needed to render: ApiService falls back to the cached base
  /// URL (and then a hardcoded default), and ApiConfigManager already calls
  /// back into ApiService.reinitialize() if the fetched URL turns out to
  /// differ. So the app now paints immediately and corrects itself a moment
  /// later, rather than making the user stare at nothing first.
  static Future<void> initializeApp() async {
    TimeUtils.initialize();

    // Firebase is already initialized in main.dart — skip re-init here.

    final apiConfigManager = ApiConfigManager();
    apiConfigManager.registerBaseUrlChangedCallback((newBaseUrl) {
      ApiService().reinitialize();
    });

    // Local-storage only (cached base URL, no network) — cheap enough to
    // await so the very first request already has a configured Dio client.
    try {
      await ApiService().initializeAsync().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    } catch (_) {}

    _backgroundInit = _initializeInBackground(apiConfigManager);
  }

  /// The slow half, kicked off without blocking the first frame.
  static Future<void> _initializeInBackground(
    ApiConfigManager apiConfigManager,
  ) async {
    try {
      await apiConfigManager.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (_) {}

    try {
      await NotificationService().initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (_) {}
  }
}
