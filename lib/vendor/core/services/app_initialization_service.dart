import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../utils/time_utils.dart';
import 'base_url_service.dart';

class AppInitializationService {
  static Future<void> initializeApp() async {
    TimeUtils.initialize();

    // Firebase is already initialized in main() — no need to call initializeApp again.

    final apiService = ApiService();
    apiService.initialize();

    try {
      await BaseUrlService.initializeBaseUrl().timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      debugPrint('BaseUrlService: Initialization completed.');
      if (BaseUrlService.isInitialized) {
        apiService.updateBaseUrl(BaseUrlService.baseUrl);
      }
    } catch (_) {}

    try {
      await NotificationService().initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
    } catch (_) {}
  }
}
