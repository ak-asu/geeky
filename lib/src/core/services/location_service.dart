/// LocationService — coarse location detection and reverse geocoding.
///
/// Provides city/state-level location labels ("Phoenix, US") for geographic
/// content prioritization. Never stores or exposes precise coordinates.
/// All operations are consent-gated — only runs when user enables the feature.
library;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a location detection attempt.
sealed class LocationResult {
  const LocationResult();
}

/// Successfully resolved a human-readable region label.
final class LocationSuccess extends LocationResult {
  const LocationSuccess(this.region);

  /// City/state-level label, e.g. "Phoenix, US" or "Arizona, US".
  final String region;
}

/// User denied or revoked location permission.
final class LocationDenied extends LocationResult {
  const LocationDenied();
}

/// Location services are disabled on the device.
final class LocationDisabled extends LocationResult {
  const LocationDisabled();
}

/// An unexpected error occurred during detection.
final class LocationError extends LocationResult {
  const LocationError(this.message);
  final String message;
}

/// Service for obtaining coarse location (city/state) with consent checks.
///
/// Design principles:
/// - Coarse accuracy only — never requests fine/precise location.
/// - No caching of raw coordinates — discarded after label generation.
/// - Permissions are checked before any location access.
class LocationService {
  /// Check whether the app currently holds location permission.
  Future<bool> hasPermission() async {
    final status = await Geolocator.checkPermission();
    return status == LocationPermission.whileInUse ||
        status == LocationPermission.always;
  }

  /// Request coarse location permission from the user.
  ///
  /// Returns `true` if granted, `false` if denied or permanently denied.
  Future<bool> requestPermission() async {
    final existing = await Geolocator.checkPermission();
    if (existing == LocationPermission.deniedForever) return false;
    if (existing == LocationPermission.whileInUse ||
        existing == LocationPermission.always) {
      return true;
    }
    final result = await Geolocator.requestPermission();
    return result == LocationPermission.whileInUse ||
        result == LocationPermission.always;
  }

  /// Detect the user's current coarse region.
  ///
  /// Returns a [LocationResult] — callers should switch on the type.
  /// Raw coordinates are never persisted; only the human-readable label is used.
  Future<LocationResult> detectRegion() async {
    // Guard: location services enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationDisabled();

    // Guard: permission
    final granted = await requestPermission();
    if (!granted) return const LocationDenied();

    try {
      // Low accuracy → coarse location; saves battery and limits precision.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final label = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      return LocationSuccess(label);
    } on LocationServiceDisabledException {
      return const LocationDisabled();
    } on PermissionDeniedException {
      return const LocationDenied();
    } catch (e) {
      return LocationError(e.toString());
    }
  }

  /// Convert raw coordinates to a "City, CountryCode" label.
  ///
  /// Prefers administrativeArea (state/province) over locality (city) to keep
  /// the label at the region level the proposal specifies.
  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return _fallbackLabel(lat, lng);

      final p = placemarks.first;
      final area = p.administrativeArea?.trim();
      final city = p.locality?.trim();
      final country = p.isoCountryCode?.trim() ?? p.country?.trim();

      // Prefer state/province, fall back to city, then raw coords.
      final region = (area?.isNotEmpty == true) ? area! : city;
      if (region == null || region.isEmpty) return _fallbackLabel(lat, lng);

      return country != null && country.isNotEmpty
          ? '$region, $country'
          : region;
    } catch (_) {
      return _fallbackLabel(lat, lng);
    }
  }

  /// Fallback when geocoding fails — broad coordinate region.
  String _fallbackLabel(double lat, double lng) {
    // Quadrant-level label as a last resort (no city/state available).
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(0)}°$ns ${lng.abs().toStringAsFixed(0)}°$ew';
  }
}
