# Fixes applied — RuralRide

## Critical

1. **Auth flow reconnected, via a new `AuthGateScreen`.** `OnboardingScreen`
   now navigates into `LoginScreen` instead of straight to
   `HomeScreen`/`DriverHomeScreen`. Startup routing (onboarding vs. login vs.
   home) used to be a private method inline in `MyApp`; it's now its own
   widget, `lib/screens/auth_gate_screen.dart`, which `main.dart` uses as
   `MaterialApp.home`. It reacts live to `FirebaseAuth.authStateChanges()`
   instead of only checking `currentUser` once at launch, and is unit-testable
   on its own (see `test/widget_test.dart`).
   `role_selection_screen.txt` (never compiled, unreferenced) was removed since
   onboarding now does its job.

2. **`otp_screen.dart` no longer imports `dart:js`.** That import is web-only
   and could break compilation on Android/iOS. Both platforms now go through
   `AuthService` (which wraps `FirebaseAuth.verifyPhoneNumber`, already
   cross-platform). OTP is now also sent automatically on web when the screen
   opens, instead of only on native.

3. **Duplicate ride writes fixed.** `ConfirmRideScreen` now checks connectivity
   first: online → single Firestore write; offline → queued in Hive only.
   Every ride gets one client-generated id (`FirebaseFirestore...doc().id`)
   used consistently in Firestore and Hive, and `SyncService` now uploads with
   `.doc(ride.id).set(..., merge: true)` so even a retry can't create a
   duplicate document.

4. **Driver TTS spam fixed.** `DriverHomeScreen` now filters `docChanges` to
   `DocumentChangeType.added` and only listens for rides created after the
   screen opened, instead of re-announcing every ride in the collection on
   every snapshot.

## Security

5. **Admin login now goes through real Firebase phone auth** instead of a
   client-side string comparison that bypassed `FirebaseAuth` entirely (which
   also meant `firestore.rules`' `isAdmin()` check would have failed, since it
   depends on `request.auth.token.phone_number`).

6. **`firestore.rules`:** `rideRequests` update/delete is now scoped to the
   ride's owner (`resource.data.uid == request.auth.uid`) or an admin, instead
   of any signed-in user. `create` now requires the doc's `uid` to match the
   authenticated user.

## Missing configuration

7. Added `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` to
   `AndroidManifest.xml`.
8. Added `NSLocationWhenInUseUsageDescription` /
   `NSLocationAlwaysAndWhenInUseUsageDescription` to `ios/Runner/Info.plist`.
9. Added the Google Maps JS `<script>` tag to `web/index.html` (reusing the
   existing API key — double check its referrer restrictions in Google Cloud
   Console for your deployed domain).

## Cleanup / smaller fixes

10. `Ride` model now has a real `id`, `uid`, and `createdAt`; `home_screen.dart`
    uses `ride.id` as the `Dismissible` key instead of `ride.vehicleName`
    (which collided whenever two rides used the same vehicle type).
11. `select_location_screen.dart` removed (dead code, superseded by
    `MapLocationPickerScreen`).
12. `CustomButton` and `CustomTextField` (`lib/widgets/`) had `color` and
    `keyboardType` params that were declared but never actually used — fixed
    so they take effect if/when these widgets are adopted.
13. `LoginScreen` now has a "Sign up" link to `SignupScreen`, and
    `SignupScreen` accepts an `initialRole` so the role chosen during
    onboarding carries through instead of being re-selected.

## UI merge (from a separate Clean-Architecture/BLoC prototype)

A second, much larger codebase (`local-ride-app-main`) was reviewed for
possible merging. It uses BLoC + Clean Architecture + GetIt DI, and expects
a custom REST backend (`Dio`/`ApiClient` pointed at `localhost:8080/api/v1`
and `https://api.ruralride.com/v1`) — no such server exists anywhere in that
codebase, so wiring it in as-is would break every network action. Its
Firebase-free, BLoC-based approach was **not** adopted for that reason.

What *was* adopted: its color palette, typography, and a handful of
reusable, backend-agnostic widgets — genuinely nicer than the previous bare
`ColorScheme.fromSeed` theme, and zero risk since they don't touch data
flow at all.

- `lib/theme/app_theme.dart` — new: `AppColors`, `AppTextStyles`,
  `AppSpacing`, `AppRadius`, and `AppTheme.lightTheme`, wired into
  `main.dart`.
- `lib/widgets/app_button.dart` — new: `AppButton` (variants: primary,
  secondary, outlined, ghost, danger; supports `isLoading`) and
  `BigIconButton`. Ported with one fix: the source had a stray, unused
  `required String text` constructor param alongside `label` — dropped.
- `lib/widgets/offline_banner.dart`, `ride_status_badge.dart`,
  `section_header.dart` — new, split out of a single combined source file
  from the prototype into proper standalone files.
- `lib/widgets/textfield.dart` (`CustomTextField`) — restyled to match the
  new theme; same constructor shape as before so no call sites broke.
- `home_screen.dart` restyled: `OfflineBanner` now shows when the device is
  offline (with a live pending-ride count via `OfflineRideStore.pendingCount()`,
  new), `SectionHeader`/`RideStatusBadge` replace plain bold `Text`, hardcoded
  `Colors.green/red/blue/orange` replaced with theme colors, and the
  "Reset Ride History" button is now an `AppButton`.
- `onboarding_screen.dart` and `login_screen.dart` restyled with `AppButton`/
  `CustomTextField`/theme colors. Onboarding's exact button text
  ("Start Journey") was preserved so the existing widget test still passes.

## New: custom signup/login, richer profiles, driver documents

Replaced Firebase's phone-auth SMS flow with a fully custom OTP system, and
expanded signup to collect proper passenger/driver profiles.

- `lib/auth/otp_generator.dart` (**new**) — `OtpService` generates a 6-digit
  code, stores it in Firestore (`otp_codes/{phone}`, 5 min expiry, 5 attempt
  cap), and verifies it. **Read the doc comment at the top of this file** —
  it explains exactly why this is not real phone verification (no SMS
  gateway is wired in, and the code is technically readable by any signed-in
  session), and what to change before this goes to real users.
- `lib/auth/auth_service.dart` (**removed**) — fully superseded by
  `OtpService`; nothing else referenced it.
- Signup now branches by role (`lib/auth/signup_screen.dart`, rewritten):
  - **Passenger**: phone (required), first name (required), last name +
    email (optional).
  - **Driver**: all of the above, plus license number, car make/model/plate
    (required), car color (optional), and a photo of their license and a
    photo of their car (both required — picked via `image_picker`,
    uploaded to Firebase Storage under `driver_documents/{phone}/`).
- `lib/models/user_profile_model.dart`, `lib/models/pending_signup.dart`
  (**new**) — the full profile shape, and a holder that carries signup-time
  data (including picked image `File`s) through to OTP verification.
- `lib/services/user_service.dart` (rewritten) — profiles are now keyed by
  **phone number**, not Firebase Auth uid (see below for why), plus a
  `uploadDriverDocument()` helper for Storage.
- `lib/screens/otp_screen.dart` (rewritten) — uses `OtpService` instead of
  Firebase phone auth. On success: signs in anonymously (see below), then
  either creates the profile (signup, uploading driver docs first) or looks
  up the existing one by phone (login). New drivers start with
  `verificationStatus: 'Pending'` until an admin reviews their documents.
- `lib/screens/profile_screen.dart` (rewritten) — matches the new phone-keyed
  profile shape, and adds a **Sign Out** button (there wasn't one before),
  which matters more now since a shared/rural device switching between
  users is a realistic scenario.
- `lib/screens/admin_screen.dart` — fixed to read `firstName`/`lastName`
  instead of the old `name` field.
- `storage.rules` (**new**) + `firebase.json` updated to register it.

### The one trade-off you should understand before your defence

Going OTP-without-a-backend means the app can no longer use Firebase's real
phone-number auth at all — successful OTP entry now just signs the user in
**anonymously** (`FirebaseAuth.instance.signInAnonymously()`). Consequences,
all documented in `otp_generator.dart` and `firestore.rules`:

- Profiles are keyed by **phone number**, not by Firebase Auth uid, so they
  survive reinstalls/relogins on the same phone number.
- There is no cryptographic proof that a signed-in session actually owns
  the phone number it claims — Firestore rules can check "is this session
  signed in", not "does this session own this phone number". `users` and
  `otp_codes` are consequently open to any signed-in (anonymous) session at
  the database level; the app's own UI is what limits a normal user to
  their own profile, not the rules.
- The previous admin check (`request.auth.token.phone_number == '...'`)
  no longer works at all with anonymous auth — there's no phone claim to
  check — so it's been removed from the rules rather than left silently
  broken.
- `rideRequests` ownership is still meaningfully enforced (scoped to the
  session's own uid, which can't be forged), so that part didn't regress.

None of this blocks you from demoing the app — it works exactly as
requested. But if this goes further than a capstone project, the fix is a
backend (e.g. a Cloud Function) that verifies the OTP server-side and mints
a Firebase **custom token** carrying the verified phone number/role as
claims, instead of anonymous auth.

### Also needed

- Added `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist`
  (required by `image_picker`).
- New dependencies in `pubspec.yaml`: `image_picker: ^1.1.2`,
  `firebase_storage: ^11.7.7`. Run `flutter pub get`; if there's a version
  conflict with your installed Firebase BoM, paste the error here and I'll
  adjust the pins.
- **Deploy the updated `firestore.rules` and the new `storage.rules`** to
  Firebase Console (or `firebase deploy`) — same as before, editing the
  local files does nothing until published.

## Known limitations still worth addressing later

- Drivers currently can't "accept" a ride (no status transition/assignment
  flow) — every driver sees every open request. Firestore rules were written
  to match this current behaviour; you'll need to revisit both the rules and
  the UI once an accept/assign flow is added.
- The admin phone number is still a hardcoded string in `login_screen.dart`,
  and (per above) admin status now can't be verified at the database level
  at all without a backend minting custom tokens — treat the current admin
  gate as a UI convenience, not a security boundary.
