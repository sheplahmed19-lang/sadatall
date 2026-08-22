import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../config/api_config.dart';

class BaseUrlService {
  static String _baseUrl = AppConstants.baseUrl;
  static bool _initialized = false;

  static String get baseUrl => _baseUrl;

  static Future<void> initializeBaseUrl() async {
    if (!_initialized) {
      ('BaseUrlService: Starting initialization...');
      // Fetch the base URL from Firestore
      final fetchedBaseUrl = await ApiConfig.fetchBaseUrl();

      if (fetchedBaseUrl != null && fetchedBaseUrl.isNotEmpty) {
        _baseUrl = fetchedBaseUrl;
        _initialized = true;
        debugPrint(
          'BaseUrlService: Successfully initialized with fetched URL: $fetchedBaseUrl',
        );
      } else {
        ('BaseUrlService: Failed to fetch URL, using default: ${AppConstants.baseUrl}');
        // If fetching fails, it will continue using the default from AppConstants
      }
    } else {
      ('BaseUrlService: Already initialized with URL: $_baseUrl');
    }
  }

  static Future<void> updateBaseUrl(String newBaseUrl) async {
    _baseUrl = newBaseUrl;
    _initialized = true;
  }

  static bool get isInitialized => _initialized;
}
