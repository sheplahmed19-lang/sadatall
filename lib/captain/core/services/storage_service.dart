import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../errors/app_exceptions.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // first_unlock_this_device (not first_unlock) so the item is never marked
    // iCloud-syncable. The syncable variant needs a Keychain Sharing
    // entitlement that iOS enforces strictly; without it every read fails with
    // OSStatus -34018 and the captain app never leaves its loading spinner.
    // Vendor and user already use this value — keep all three aligned.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Secure storage for sensitive data
  Future<void> setSecureString(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      throw CacheException('Failed to store secure string: $e');
    }
  }

  /// Returns null rather than throwing when the platform keystore is
  /// unreadable. A failed read means "no credential available", which is the
  /// same as being logged out — throwing here instead propagated out of the
  /// startup auth check and left the app on a blank frame with no way to
  /// reach the login screen.
  Future<String?> getSecureString(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteSecureString(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      throw CacheException('Failed to delete secure string: $e');
    }
  }

  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw CacheException('Failed to clear secure storage: $e');
    }
  }

  // Regular storage for non-sensitive data
  Future<void> setString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      throw CacheException('Failed to store string: $e');
    }
  }

  Future<String?> getString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      throw CacheException('Failed to read string: $e');
    }
  }

  Future<void> setBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      throw CacheException('Failed to store boolean: $e');
    }
  }

  Future<bool?> getBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key);
    } catch (e) {
      throw CacheException('Failed to read boolean: $e');
    }
  }

  Future<void> setInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      throw CacheException('Failed to store integer: $e');
    }
  }

  Future<int?> getInt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key);
    } catch (e) {
      throw CacheException('Failed to read integer: $e');
    }
  }

  Future<void> setDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (e) {
      throw CacheException('Failed to store double: $e');
    }
  }

  Future<double?> getDouble(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(key);
    } catch (e) {
      throw CacheException('Failed to read double: $e');
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      await setString(key, jsonString);
    } catch (e) {
      throw CacheException('Failed to store JSON: $e');
    }
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    try {
      final jsonString = await getString(key);
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to read JSON: $e');
    }
  }

  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      throw CacheException('Failed to remove key: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw CacheException('Failed to clear storage: $e');
    }
  }

  // Storage keys constants
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyCaptainData = 'captain_data';
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyLastLocationUpdate = 'last_location_update';
  static const String keyFcmToken = 'fcm_token';
  static const String keyThemeMode = 'theme_mode';

  Future<void> saveThemeMode(String themeMode) async {
    await setString(keyThemeMode, themeMode);
  }

  Future<String?> getThemeMode() async {
    return await getString(keyThemeMode);
  }
}
