import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location_context.dart';

/// Platform-level location service.
///
/// Wraps [Geolocator] and [geocoding] to produce a [LocationContext].
/// All error paths return null — callers never need to handle exceptions.
/// Only foreground, city-level accuracy is used to minimise battery impact.
abstract final class LocationService {
  static const _positionTimeout = Duration(seconds: 10);

  /// Requests foreground permission if needed, then returns the user's
  /// city / state / country. Returns null on any failure or denial.
  static Future<LocationContext?> getCurrentContext() async {
    try {
      // 1. Service enabled?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // 2. Permission check / request
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // 3. Get position — low accuracy is enough for city-level resolution
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _positionTimeout,
        ),
      );

      // 4. Reverse geocode — GPS coordinates are never persisted
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      return LocationContext(
        city: _nonEmpty(place.locality),
        state: _nonEmpty(place.administrativeArea),
        country: _nonEmpty(place.country),
      );
    } catch (_) {
      // Absorb all platform/network exceptions — location is optional
      return null;
    }
  }

  static String? _nonEmpty(String? value) =>
      (value != null && value.isNotEmpty) ? value : null;
}
