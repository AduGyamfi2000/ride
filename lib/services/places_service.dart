import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/api_keys.dart';

class NearbyPlace {
  final String name;
  final String category; // 'Market', 'Hospital', 'School', 'Bank'
  final double latitude;
  final double longitude;
  final String? address;
  final double distanceMeters;

  NearbyPlace({
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.distanceMeters,
  });

  String get distanceLabel =>
      distanceMeters < 1000 ? '${distanceMeters.round()} m away' : '${(distanceMeters / 1000).toStringAsFixed(1)} km away';
}

class PlacesService {
  // Maps our simple category labels to Google Places "type" values.
  // See: https://developers.google.com/maps/documentation/places/web-service/supported_types
  static const Map<String, String> _categoryTypes = {
    'Market': 'supermarket',
    'Hospital': 'hospital',
    'School': 'school',
    'Bank': 'bank',
  };

  static List<String> get categories => _categoryTypes.keys.toList();

  /// Fetches nearby places for one category around [latitude]/[longitude].
  /// Returns an empty list (rather than throwing) on any network/API
  /// error, so a single failed category doesn't break the whole screen.
  Future<List<NearbyPlace>> searchNearby({
    required String category,
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
    int limit = 5,
  }) async {
    final type = _categoryTypes[category];
    if (type == null) return [];

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
      'location': '$latitude,$longitude',
      'radius': '$radiusMeters',
      'type': type,
      'key': ApiKeys.googleMaps,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        // Common causes: Places API not enabled, billing not enabled, or
        // an invalid/restricted key — surfaced here as an empty list, but
        // worth checking Google Cloud Console if this always returns [].
        return [];
      }

      final results = (data['results'] as List<dynamic>?) ?? [];
      final places = results.take(limit).map((r) {
        final loc = r['geometry']['location'];
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        return NearbyPlace(
          name: r['name'] as String? ?? category,
          category: category,
          latitude: lat,
          longitude: lng,
          address: r['vicinity'] as String?,
          distanceMeters: Geolocator.distanceBetween(latitude, longitude, lat, lng),
        );
      }).toList();

      places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return places;
    } catch (_) {
      return [];
    }
  }

  /// Fetches nearby places across all categories (Market, Hospital,
  /// School, Bank) and returns them merged, sorted by distance.
  Future<List<NearbyPlace>> searchAllCategories({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
    int perCategoryLimit = 5,
  }) async {
    final results = await Future.wait(
      categories.map((c) => searchNearby(
            category: c,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            limit: perCategoryLimit,
          )),
    );
    final merged = results.expand((list) => list).toList();
    merged.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return merged;
  }
}
