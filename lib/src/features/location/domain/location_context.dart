import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_context.freezed.dart';
part 'location_context.g.dart';

/// Reverse-geocoded location for the current device.
///
/// All fields are nullable — partial data is still useful.
/// GPS coordinates are intentionally not stored; only human-readable
/// city/state/country names are kept for privacy.
@freezed
abstract class LocationContext with _$LocationContext {
  const LocationContext._();

  const factory LocationContext({
    String? city,
    String? state,
    String? country,
  }) = _LocationContext;

  factory LocationContext.fromJson(Map<String, dynamic> json) =>
      _$LocationContextFromJson(json);

  /// Flat list of non-null location strings used for content token matching.
  ///
  /// Example: LocationContext(city: 'Tempe', state: 'Arizona', country: 'United States')
  ///   → ['Tempe', 'Arizona', 'United States']
  List<String> get tokens => [
        if (city != null && city!.isNotEmpty) city!,
        if (state != null && state!.isNotEmpty) state!,
        if (country != null && country!.isNotEmpty) country!,
      ];

  /// True when no location data is available.
  bool get isEmpty => city == null && state == null && country == null;
}
