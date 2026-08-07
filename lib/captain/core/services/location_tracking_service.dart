import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import '../network/api_client.dart';
import '../config/api_config.dart';
import 'package:location/location.dart' as location;

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final Location _location = Location();
  final ApiClient _apiClient = ApiClient();

  StreamSubscription<LocationData>? _locationSubscription;
  LocationData? _lastKnownPosition;
  DateTime? _lastUpdateTime;
  bool _isTracking = false;

  static const Duration _minUpdateInterval = Duration(seconds: 3);
  static const double _minDistanceFilter = 5.0; // meters

  bool get isTracking => _isTracking;

  /// Initialize location settings
  Future<bool> _initializeLocation() async {
    // Check if location service is enabled
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        debugPrint("Location services are turned off on the device");
        return false;
      }
    }

    // Check permissions
    location.PermissionStatus permissionGranted = await _location
        .hasPermission();
    if (permissionGranted == location.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location.PermissionStatus.granted) {
        debugPrint("Location permission denied by user: $permissionGranted");
        return false;
      }
    }

    // Foreground tracking only — deliberately no locationAlways request here.
    // Requesting it hung startTracking() indefinitely, and it is not needed
    // while the app is in use.

    return true;
  }

  /// Configure location settings
  Future<void> _configureLocation() async {
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 3000, // 3 seconds
      distanceFilter: _minDistanceFilter,
    );

    // Foreground-only tracking: background mode needs ACCESS_BACKGROUND_LOCATION
    // (which we no longer request) and starts a foreground service, so leave it
    // off. Tracking stops when the app is backgrounded — that is intended.
  }

  /// Start tracking location
  Future<bool> startTracking() async {
    if (_isTracking) return true;
    // debugPrint("/////////////////////Starting location tracking...");

    try {
      // Initialize location
      if (!await _initializeLocation()) {
        debugPrint("Location initialization failed");
        return false;
      }

      // Configure location settings
      await _configureLocation();

      // Start listening to location updates
      _locationSubscription = _location.onLocationChanged.listen(
        _onLocationUpdate,
        onError: _onLocationError,
      );

      // onLocationChanged (with distanceFilter set) only fires once the
      // device has actually moved — on login/app-reentry the captain
      // hasn't moved yet, so without this the server never learns their
      // current position until their first ~5m of movement. Send one
      // immediate fix right away instead of waiting for that.
      try {
        // debugPrint("********************Getting initial location...");
        final current = await _location.getLocation();
        _onLocationUpdate(current);
      } catch (e) {
        debugPrint("Error getting initial location: $e");
      }

      _isTracking = true;
      debugPrint("Location tracking started");
      return true;
    } catch (e, st) {
      debugPrint("Error starting location tracking: $e\n$st");
      return false;
    }
  }

  /// Stop tracking location
  Future<void> stopTracking() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isTracking = false;
    _lastKnownPosition = null;
    _lastUpdateTime = null;

    debugPrint("Location tracking stopped");
  }

  /// Handle location updates
  void _onLocationUpdate(LocationData locationData) async {
    final now = DateTime.now();

    // Time-based throttling
    if (_lastUpdateTime != null &&
        now.difference(_lastUpdateTime!) < _minUpdateInterval) {
      return;
    }

    // Distance-based filtering
    if (_lastKnownPosition != null) {
      double distance = _calculateDistance(
        _lastKnownPosition!.latitude!,
        _lastKnownPosition!.longitude!,
        locationData.latitude!,
        locationData.longitude!,
      );
      if (distance < _minDistanceFilter) return;
    }

    _lastKnownPosition = locationData;
    _lastUpdateTime = now;

    ("Location update: ${locationData.latitude}, ${locationData.longitude}",);
    await _updateLocationOnServer(
      locationData.latitude!,
      locationData.longitude!,
    );
  }

  /// Handle location errors
  void _onLocationError(dynamic error) {
    ("Location tracking error: $error");
  }

  /// Calculate distance between two coordinates
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        (dLat / 2) * (dLat / 2) +
        _toRadians(lat1) * _toRadians(lat2) * (dLon / 2) * (dLon / 2);
    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  /// Update location on server
  Future<void> _updateLocationOnServer(
    double latitude,
    double longitude,
  ) async {
    try {
      await _apiClient.put(
        ApiConfig.captainsLocation,
        body: {"latitude": latitude, "longitude": longitude},
      );
      ("Location sent to server: $latitude, $longitude");
    } catch (e) {
      // Only log the error, don't throw it or trigger auth failures
      // Location updates should be silent background operations
      ("Error updating location on server: $e");
    }
  }

  /// Get current location
  Future<LocationData?> getCurrentLocation() async {
    try {
      if (!await _initializeLocation()) {
        return null;
      }
      return await _location.getLocation();
    } catch (e) {
      ("Error getting current location: $e");
      return null;
    }
  }
}

// PROVIDERS
final locationTrackingServiceProvider = Provider<LocationTrackingService>((
  ref,
) {
  return LocationTrackingService();
});

final locationTrackingProvider =
    StateNotifierProvider<LocationTrackingNotifier, LocationTrackingState>((
      ref,
    ) {
      return LocationTrackingNotifier(
        ref.watch(locationTrackingServiceProvider),
      );
    });

// STATE CLASSES
class LocationTrackingState {
  final bool isTracking;
  final LocationData? currentLocation;
  final String? error;

  const LocationTrackingState({
    this.isTracking = false,
    this.currentLocation,
    this.error,
  });

  LocationTrackingState copyWith({
    bool? isTracking,
    LocationData? currentLocation,
    String? error,
  }) {
    return LocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      currentLocation: currentLocation ?? this.currentLocation,
      error: error,
    );
  }
}

class LocationTrackingNotifier extends StateNotifier<LocationTrackingState> {
  final LocationTrackingService _locationService;

  LocationTrackingNotifier(this._locationService)
    : super(const LocationTrackingState());

  Future<void> startTracking() async {
    state = state.copyWith(error: null);
    try {
      final success = await _locationService.startTracking();
      if (success) {
        state = state.copyWith(isTracking: true);
      } else {
        state = state.copyWith(error: "Failed to start location tracking");
      }
    } catch (e) {
      state = state.copyWith(error: "Error: $e");
    }
  }

  Future<void> stopTracking() async {
    try {
      await _locationService.stopTracking();
      state = state.copyWith(isTracking: false, currentLocation: null);
    } catch (e) {
      state = state.copyWith(error: "Error stopping tracking: $e");
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        state = state.copyWith(currentLocation: location);
      }
    } catch (e) {
      state = state.copyWith(error: "Error getting location: $e");
    }
  }
}
