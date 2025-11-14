import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Location state model
class LocationState {
  final Position? currentPosition;
  final bool isLoading;
  final String? errorMessage;

  LocationState({
    this.currentPosition,
    this.isLoading = false,
    this.errorMessage,
  });

  LocationState copyWith({
    Position? currentPosition,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Location service
class LocationService {
  static Future<Position?> getCurrentPosition() async {
    try {
      print('DEBUG: Starting location request...');

      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('DEBUG: Service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        print('DEBUG: Location services are disabled');
        throw Exception(
            'Location services are disabled. Please enable location from device settings.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('DEBUG: Current permission: $permission');

      if (permission == LocationPermission.denied) {
        print('DEBUG: Requesting location permission...');
        permission = await Geolocator.requestPermission();
        print('DEBUG: Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permission permanently denied. Please enable location from app settings.');
      }

      print('DEBUG: Getting position with high accuracy...');

      // First get a quick position, then get a more accurate one
      Position position;
      try {
        print('DEBUG: Attempting getCurrentPosition with low accuracy...');
        // First get a quick position with low accuracy
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
        print(
            'DEBUG: SUCCESS - Got low accuracy position: ${position.latitude}, ${position.longitude}');

        // Then try again with high accuracy
        try {
          print('DEBUG: Attempting getCurrentPosition with high accuracy...');
          final highAccuracyPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
          print(
              'DEBUG: SUCCESS - Got high accuracy position: ${highAccuracyPosition.latitude}, ${highAccuracyPosition.longitude}');
          return highAccuracyPosition;
        } catch (e) {
          print(
              'DEBUG: High accuracy failed with error: $e, using low accuracy position');
          return position;
        }
      } catch (e) {
        print('DEBUG: Regular position failed with error: $e');
        print('DEBUG: Error type: ${e.runtimeType}');
        print('DEBUG: Trying last known position...');

        // Try last known position
        try {
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            print(
                'DEBUG: SUCCESS - Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
            return lastPosition;
          } else {
            print('DEBUG: No last known position available');
          }
        } catch (lastKnownError) {
          print('DEBUG: Last known position also failed: $lastKnownError');
        }

        print('DEBUG: All location methods failed, returning null');
        return null;
      }
    } catch (e) {
      print('ERROR getting location: $e');
      print('ERROR type: ${e.runtimeType}');
      return null;
    }
  }

  static double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}

// Location provider
class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(LocationState());

  Future<void> getCurrentLocation() async {
    print('DEBUG: LocationNotifier - Starting getCurrentLocation');
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        print(
            'DEBUG: LocationNotifier - Position received: ${position.latitude}, ${position.longitude}');
        state = state.copyWith(
          currentPosition: position,
          isLoading: false,
        );
      } else {
        print('DEBUG: LocationNotifier - No position received');
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Location could not be obtained. Please check your internet connection and location settings.',
        );
      }
    } catch (e) {
      print('DEBUG: LocationNotifier - Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// Provider
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);
