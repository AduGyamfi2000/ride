/// Centralized API keys. This reuses the same Google Maps key already
/// configured in AndroidManifest.xml / Info.plist / web/index.html, so
/// there's one place to update it if it ever rotates.
///
/// NOTE: For the nearby-places feature (lib/services/places_service.dart)
/// to work, "Places API" must be enabled for this key in Google Cloud
/// Console (it's a separate API/billing SKU from "Maps SDK for
/// Android/iOS" and "Maps JavaScript API", which are the ones already in
/// use for the map itself).
class ApiKeys {
  ApiKeys._();
  static const String googleMaps = 'AIzaSyCb29QieeoHzxFuMnYfYHZXGb220Zto354';
}
