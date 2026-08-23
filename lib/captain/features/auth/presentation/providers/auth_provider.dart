import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/app_utils.dart';
import '../../data/models/captain_model.dart';
import '../../data/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

class AuthState {
  final bool isAuthenticated;
  final bool isLocked;
  final bool isLoading;
  final CaptainModel? captain;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLocked = false,
    this.isLoading = false,
    this.captain,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLocked,
    bool? isLoading,
    CaptainModel? captain,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLocked: isLocked ?? this.isLocked,
      isLoading: isLoading ?? this.isLoading,
      captain: captain ?? this.captain,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final StorageService _storageService = StorageService();
  final ApiClient _apiClient = ApiClient();
  final LocationTrackingService _locationService = LocationTrackingService();
  final NotificationService _notificationService = NotificationService();

  AuthNotifier(this._authService) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);

    try {
      // Initialize tokens in API client from storage first
      await _apiClient.initializeTokensFromStorage();

      final token = await _storageService.getSecureString(
        StorageService.keyAuthToken,
      );
      final refreshToken = await _storageService.getSecureString(
        StorageService.keyRefreshToken,
      );
      final captainJson = await _storageService.getJson(
        StorageService.keyCaptainData,
      );

      if (token != null && captainJson != null) {
        final captain = CaptainModel.fromJson(captainJson);

        // Check if captain is locked
        if (captain.isLocked == true) {
          state = state.copyWith(
            isAuthenticated: false,
            isLocked: true,
            captain: captain,
            isLoading: false,
          );
          return;
        }

        // Ensure the tokens are set in API client (redundant but safe)
        _apiClient.setAuthToken(token);
        if (refreshToken != null) {
          _apiClient.setRefreshToken(refreshToken);
        }

        // Start location tracking for authenticated users.
        // Bounded: this awaits an iOS permission dialog, and if the user never
        // answers it (or the platform channel stalls) an unbounded await here
        // leaves isLoading true forever — a permanent loading spinner with no
        // screen behind it. Tracking is not required to render the app.
        try {
          await _locationService
              .startTracking()
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          ('Location tracking did not start during auth check: $e');
        }

        // Update FCM token on server for authenticated users
        try {
          final fcmToken = await _notificationService
              .getToken()
              .timeout(const Duration(seconds: 8));
          if (fcmToken != null) {
            await _notificationService
                .updateFCMTokenOnServer(fcmToken)
                .timeout(const Duration(seconds: 8));
          }
        } catch (e) {
          // FCM token update failure should not prevent login
          // Just log the error
          if (true) {
            // Always log for now
            ('Failed to update FCM token during auth check: $e');
          }
        }

        state = state.copyWith(
          isAuthenticated: true,
          captain: captain,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: AppUtils.getLocalizedErrorMessage(e),
      );
    } finally {
      // The auth wrapper renders nothing but a spinner while isLoading is
      // true, so it must be cleared on every path out of this method — an
      // early return or an unforeseen throw would otherwise strand the app on
      // a blank loading frame with no route behind it.
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.login(email: email, password: password);
      final captain = result['captain'] as CaptainModel;
      final token = result['token'] as String;
      final refreshToken = result['refreshToken'] as String;

      // Check if captain is locked
      if (captain.isLocked == true) {
        state = state.copyWith(
          isAuthenticated: false,
          isLocked: true,
          captain: captain,
          isLoading: false,
        );
        return true; // Return true to indicate successful login but locked status
      }

      // Store tokens and captain data
      await _storageService.setSecureString(StorageService.keyAuthToken, token);
      await _storageService.setSecureString(StorageService.keyRefreshToken, refreshToken);
      await _storageService.setJson(
        StorageService.keyCaptainData,
        captain.toJson(),
      );

      // Set the tokens in API client
      _apiClient.setAuthToken(token);
      _apiClient.setRefreshToken(refreshToken);

      // Start location tracking
      await _locationService.startTracking();

      // Update FCM token on server after login
      try {
        final fcmToken = await _notificationService.getToken();
        if (fcmToken != null) {
          await _notificationService.updateFCMTokenOnServer(fcmToken);
        }
      } catch (e) {
        // FCM token update failure should not prevent login
        // Just log the error
        if (true) {
          // Always log for now
          ('Failed to update FCM token during login: $e');
        }
      }

      state = state.copyWith(
        isAuthenticated: true,
        captain: captain,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppUtils.getLocalizedErrorMessage(e));
      return false;
    }
  }

  Future<bool> signup(
    String userName,
    String email,
    String phoneNumber,
    String password,
    String nationalId,
    File? photo,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.signup(
        userName: userName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        nationalId: nationalId,
        photo: photo,
      );
      final captain = result['captain'] as CaptainModel;
      final token = result['token'] as String;
      final refreshToken = result['refreshToken'] as String;

      // Check if captain is locked (new captains are locked by default)
      if (captain.isLocked == true) {
        // Store tokens and captain data even for locked captains
        await _storageService.setSecureString(StorageService.keyAuthToken, token);
        await _storageService.setSecureString(StorageService.keyRefreshToken, refreshToken);
        await _storageService.setJson(
          StorageService.keyCaptainData,
          captain.toJson(),
        );

        // Set tokens in API client for future requests
        _apiClient.setAuthToken(token);
        _apiClient.setRefreshToken(refreshToken);

        state = state.copyWith(
          isAuthenticated: false,
          isLocked: true,
          captain: captain,
          isLoading: false,
        );
        return true; // Return true to indicate successful signup but locked status
      }

      // Store tokens and captain data for unlocked captains
      await _storageService.setSecureString(StorageService.keyAuthToken, token);
      await _storageService.setSecureString(StorageService.keyRefreshToken, refreshToken);
      await _storageService.setJson(
        StorageService.keyCaptainData,
        captain.toJson(),
      );

      // Set the tokens in API client
      _apiClient.setAuthToken(token);
      _apiClient.setRefreshToken(refreshToken);

      // Start location tracking for unlocked captains only
      await _locationService.startTracking();

      // Update FCM token on server after signup
      try {
        final fcmToken = await _notificationService.getToken();
        if (fcmToken != null) {
          await _notificationService.updateFCMTokenOnServer(fcmToken);
        }
      } catch (e) {
        // FCM token update failure should not prevent signup
        // Just log the error
        if (true) {
          // Always log for now
          ('Failed to update FCM token during signup: $e');
        }
      }

      state = state.copyWith(
        isAuthenticated: true,
        captain: captain,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppUtils.getLocalizedErrorMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      // Send dummy FCM token to server before logout
      try {
        await _notificationService.sendDummyTokenToServer();
      } catch (e) {
        // Don't prevent logout if FCM token update fails
        ('Failed to send dummy FCM token during logout: $e');
      }

      // Stop location tracking
      _locationService.stopTracking();

      // Clear tokens from API client
      _apiClient.clearAuthToken();

      // Remove stored data
      await _storageService.deleteSecureString(StorageService.keyAuthToken);
      await _storageService.deleteSecureString(StorageService.keyRefreshToken);
      await _storageService.remove(StorageService.keyCaptainData);
      await _notificationService.cancelTokenListener();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppUtils.getLocalizedErrorMessage(e));
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true);

    try {
      _locationService.stopTracking();
      await _authService.deleteAccount();
      await _storageService.remove(StorageService.keyCaptainData);
      await _notificationService.cancelTokenListener();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppUtils.getLocalizedErrorMessage(e));
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
