# ride

A new Flutter project.

## Setup notes

1. Google Maps API Key
	- Add your API key to `android/app/src/main/AndroidManifest.xml` under the `<application>` tag as `com.google.android.geo.API_KEY` (done for the provided key). For iOS add `GMSApiKey` to `ios/Runner/Info.plist` (done).
	- Restrict the key in Google Cloud Console (Android package name, iOS bundle id).

2. Firebase
	- Configure Firebase for Android and iOS with `google-services.json` and `GoogleService-Info.plist`.
	- Enable Phone Authentication in the Firebase Console.

3. Hive and offline
	- Hive is used to store rides when offline. Hive is initialized in `main.dart` via `OfflineRideStore.init()`.
	- `SyncService` uploads stored rides to Firestore when connectivity is restored.

4. Running
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

5. Notes
	- For production, don't commit API keys to source control; use secure env variables or secrets management.
	- The OTP flow supports both web and native paths. For Android automatic verification, consider handling `verificationCompleted` in `AuthService` to auto-sign-in.


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
