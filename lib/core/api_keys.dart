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

  // Cloudinary — used for driver license/car photo uploads instead of
  // Firebase Storage (which now requires the paid Blaze plan just to
  // enable). Cloudinary's free tier (25GB storage/bandwidth) needs no
  // credit card. Replace both values below with your own after signing
  // up — see the setup steps in CHANGES.md under "Storage without
  // Firebase Storage".
  static const String cloudinaryCloudName = 'YOUR_CLOUD_NAME';
  static const String cloudinaryUploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET';
}
