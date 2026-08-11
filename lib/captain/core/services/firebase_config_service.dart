import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debug, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';

class FirebaseConfigService {
  static const String _collectionName = 'delivery_app_config';
  static const String _documentName = 'base_url';
  static const String _fieldName = 'value';
  static const String _versionFieldName = 'version_captain';

  /// Returns true if [required] version is strictly greater than [current].
  /// Both strings must be in "MAJOR.MINOR.PATCH" format.
  static bool _isUpdateRequired(String current, String required) {
    final currentParts = current.trim().split('.').map(int.tryParse).toList();
    final requiredParts = required.trim().split('.').map(int.tryParse).toList();

    while (currentParts.length < 3) currentParts.add(0);
    while (requiredParts.length < 3) requiredParts.add(0);

    for (int i = 0; i < 3; i++) {
      final c = currentParts[i] ?? 0;
      final r = requiredParts[i] ?? 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Checks Firestore for a minimum required version and compares it to
  /// the installed app version. Returns the required version string if a
  /// force update is needed, or null if the app is up to date or the check
  /// could not be completed (fail-open on network errors).
  static Future<String?> checkForceUpdate() async {
    try {
      final app = _getOrUseDefaultApp();

      final firestore = FirebaseFirestore.instanceFor(app: app);
      final docSnapshot = await firestore
          .collection(_collectionName)
          .doc(_documentName)
          .get()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('timeout'),
          );

      if (!docSnapshot.exists) return null;

      final requiredVersion = docSnapshot.data()?[_versionFieldName] as String?;
      if (requiredVersion == null || requiredVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint(
        'Force update check — current: $currentVersion, required: $requiredVersion',
      );

      if (_isUpdateRequired(currentVersion, requiredVersion)) {
        return requiredVersion;
      }
    } catch (e) {
      debugPrint('Force update check failed (non-blocking): $e');
    }
    return null;
  }

  /// Returns the named app if it exists, otherwise the default app.
  /// Never calls initializeApp — avoids triggering didReinitializeFirebaseCore.
  static FirebaseApp _getOrUseDefaultApp() {
    try {
      return Firebase.app('delivery_app_config');
    } catch (_) {
      return Firebase.app();
    }
  }

  /// Fetch the base URL from Firestore
  static Future<String?> fetchBaseUrl() async {
    try {
      final app = _getOrUseDefaultApp();

      final firestore = FirebaseFirestore.instanceFor(app: app);

      final docSnapshot = await firestore
          .collection(_collectionName)
          .doc(_documentName)
          .get()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('timeout'),
          );

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final baseUrl = data?[_fieldName] as String?;

        if (baseUrl != null && baseUrl.isNotEmpty) {
          ('Successfully fetched base URL from Firestore: $baseUrl');
          return baseUrl;
        }
      } else {
        ('Base URL document does not exist in Firestore');
      }
    } catch (e) {
      ('Error fetching base URL from Firestore: $e');
    }

    // Return null if fetching fails
    return null;
  }

  /// Get base URL with fallback logic:
  /// 1. Try to fetch from Firestore
  /// 2. If that fails, use cached value from local storage
  /// 3. If no cached value exists, use default fallback
  static Future<String> getBaseUrlWithFallback() async {
    const testUrl = String.fromEnvironment('TEST_BASE_URL');
    if (testUrl.isNotEmpty) {
      ApiConfig.baseUrl = testUrl;
      debugPrint('Using test base URL from environment: $testUrl');

      return testUrl;
    }
    debugPrint('Starting base URL retrieval process...');

    String? firestoreBaseUrl;
    try {
      firestoreBaseUrl = await fetchBaseUrl().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
    } catch (_) {}
    if (firestoreBaseUrl != null) {
      // Update local storage with the fetched value and the ApiConfig
      await ApiConfig.setBaseUrlWithFallback(firestoreBaseUrl);
      debugPrint('Using base URL from Firestore: $firestoreBaseUrl');
      return firestoreBaseUrl;
    }

    // If Firestore fetch failed, try to get from local storage
    try {
      final cachedBaseUrl = await ApiConfig.getBaseUrlFromStorage();
      if (cachedBaseUrl.isNotEmpty &&
          cachedBaseUrl != ApiConfig.defaultBaseUrl) {
        // Update the ApiConfig with the cached value
        ApiConfig.baseUrl = cachedBaseUrl;
        ('Using cached base URL from local storage: $cachedBaseUrl');
        return cachedBaseUrl;
      }
    } catch (e) {
      ('Error retrieving cached base URL: $e');
    }

    // If everything else fails, return the default fallback
    ('Using default fallback base URL: ${ApiConfig.defaultBaseUrl}');
    return ApiConfig.defaultBaseUrl;
  }

  /// Update the base URL in the ApiConfig and cache it
  static Future<void> updateBaseUrl(String newBaseUrl) async {
    await ApiConfig.setBaseUrlWithFallback(newBaseUrl);
  }
}
