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

## New: nearby places (market/hospital/school/bank) and ride scheduling

- `lib/services/places_service.dart` (**new**) — calls the Google Places
  "Nearby Search" API for four categories (Market → `supermarket`,
  Hospital, School, Bank), returns results merged and sorted by distance.
  Fails soft (returns `[]`) on any error so one bad category/API hiccup
  doesn't break the screen.
- `lib/core/api_keys.dart` (**new**) — centralizes the existing Google Maps
  key so `PlacesService` doesn't need its own copy.
  **Places API must be enabled for this key in Google Cloud Console** —
  it's a separate API/billing SKU from "Maps SDK for Android/iOS" and
  "Maps JavaScript API", which are the only ones enabled so far.
- `lib/screens/map_location_picker_screen.dart` (rewritten) — the map is
  unchanged and still the main view. Underneath it, when GPS is on, a
  category-filter chip row (All/Market/Hospital/School/Bank) sits above a
  horizontal scrollable strip of nearby place cards (name + distance);
  tapping one sets it as the pickup point, same as tapping the map. Nearby
  places also show as markers on the map itself. If GPS is off/denied, the
  strip is replaced with a one-line hint instead of silently showing
  nothing.
- `lib/screens/select_time_screen.dart` (rewritten) — now offers **"Ride
  Now"** or **"Schedule for Later"**. Scheduling opens a date picker
  (today up to 30 days out) and a time picker, with a preview line showing
  the exact scheduled moment before confirming.
- `lib/screens/confirm_ride_screen.dart` — rides booked more than 5 minutes
  out are now saved with `status: 'Scheduled'` instead of `'Confirmed'`,
  in both the Firestore write and the offline (Hive) queue path.
- `lib/widgets/ride_status_badge.dart` — added a `'Scheduled'` case (🗓️,
  a distinct color) so it reads clearly wherever `RideStatusBadge` is used
  (currently `HomeScreen`'s ongoing-ride and history lists).
- New dependency in `pubspec.yaml`: `http: ^1.2.2`. Run `flutter pub get`.

## New: driver accept/complete flow (ride lifecycle)

Drivers previously could only see every ride request with no way to claim
one. Now:

- `lib/models/ride_model.dart` — added `driverPhone`/`driverName` fields,
  and the default status for a newly booked ride changed from
  `'Confirmed'` to `'Searching'` (awaiting a driver) — `'Confirmed'` now
  reads ambiguously once "a driver accepted" is also a status in the same
  lifecycle.
- `lib/screens/confirm_ride_screen.dart` — immediate rides now start as
  `'Searching'` instead of `'Confirmed'` (scheduled rides still start as
  `'Scheduled'`, unchanged).
- `lib/screens/driver_home_screen.dart` (rewritten) — now shows two
  sections: **New Requests** (unassigned rides, with an **Accept**
  button) and **My Accepted Rides** (rides this driver accepted, with a
  **Complete** button). Accepting runs inside a Firestore transaction that
  checks the ride is still unassigned before claiming it — if two drivers
  tap Accept at nearly the same moment, only the first transaction commits
  and the second is told the ride was already taken, instead of silently
  double-assigning it.
- `lib/screens/home_screen.dart` — the passenger's ongoing-ride tile is now
  a `StreamBuilder` on the ride's own Firestore document instead of only
  showing the static state from when it was booked, so the passenger
  actually sees the status flip to "Accepted" (and the driver's name) in
  real time. The Cancel button now also writes `status: 'Cancelled'` to
  Firestore (previously it only cleared local state — the Firestore
  document was left stuck at its original status forever).
- `firestore.rules` — `rideRequests` update is now open to any signed-in
  session rather than owner-only, because a driver accepting a ride is a
  *different* anonymous session than the passenger who created it. Same
  documented trade-off as `users`/`otp_codes`: the app's UI is what stops
  a passenger session from editing someone else's ride, not the database
  itself. `delete` stays owner-only. **Redeploy this file.**

## New: live ride tracking

Passengers can now watch their driver approach on a live map instead of
just seeing a static status label.

- `lib/models/ride_model.dart` — added `pickupLat`/`pickupLng` (the actual
  coordinates from the map picker, not just the address string) and
  `passengerName`.
- Pickup coordinates now flow end-to-end: `MapLocationPickerScreen` →
  `SelectTimeScreen` → `ConfirmRideScreen` → the Firestore `rideRequests`
  document (`pickupLat`/`pickupLng` fields). Previously only a free-text
  address was stored, which wasn't precise enough to measure a driver's
  distance to pickup.
- **Fixed while in there:** `passengerName` was being set from
  `FirebaseAuth.instance.currentUser?.displayName`, which anonymous
  Firebase users never have — every ride was silently labeled "Passenger"
  regardless of who booked it. It now resolves the real first name from
  the phone-keyed profile instead, for both the online and offline
  booking paths.
- `lib/screens/driver_home_screen.dart` — while a driver has at least one
  ride in `Accepted` status, it now streams their live position
  (`Geolocator.getPositionStream`, 25m distance filter to limit
  writes/battery use) and writes `driverLat`/`driverLng`/
  `driverLocationUpdatedAt` onto that ride's Firestore document.
  Broadcasting starts/stops automatically as accepted rides come and go —
  a driver with no accepted ride isn't burning battery on GPS. Also fixed
  a pre-existing leak: the ride-orders listener's `StreamSubscription` was
  never stored/cancelled; it and the two new subscriptions are now
  properly cancelled in `dispose()`.
- `lib/screens/track_ride_screen.dart` (**new**) — a map showing the
  pickup point and the driver's live position (auto-fits both in view),
  plus distance-to-pickup and a "last updated Ns ago" freshness indicator.
  Handles the no-location-yet, completed, and cancelled states explicitly
  rather than just showing an empty map.
- `lib/screens/home_screen.dart` — the ongoing-ride tile is now tappable
  once a driver has accepted, opening `TrackRideScreen`.

## New: admin driver-verification review UI

Drivers have uploaded license/car photos and started life as
`verificationStatus: 'Pending'` since the signup rework, but nothing let an
admin actually look at them until now.

- `lib/screens/admin_screen.dart` (rewritten) — restructured into three
  tabs (**Users**, **Rides**, **Drivers**) instead of one long scrolling
  page with two independently-scrolling lists crammed into it. A stat card
  row sits above the tabs, with a 4th "Pending Drivers" card that
  highlights (amber) when there's a backlog.
  - **Drivers tab (new):** queries `users` for `role == 'Driver' &&
    verificationStatus == 'Pending'`, and shows each one's name, phone,
    license number, car make/model/plate/color, and both uploaded photos
    (`Image.network` with a loading spinner and a broken-image fallback,
    since Storage URLs can fail to load). **Approve**/**Reject** buttons
    flip `verificationStatus` to `'Verified'`/`'Rejected'`.
  - Rides tab's status filter dropdown updated to match the real status
    values used elsewhere (`Searching`/`Scheduled`/`Accepted`/etc. instead
    of the old `Ongoing`, which no ride ever actually had), and now shows
    the assigned driver's name once a ride has one, via the existing
    `RideStatusBadge`.
  - "Active Rides" stat now correctly counts `Searching`/`Accepted`
    rides — it was previously counting `status == 'Ongoing'`, a value
    nothing in the app has written since before the ride-lifecycle
    rework in item #2.
- No `firestore.rules` changes needed — `users` was already
  `allow read, write: if isSignedIn()` from the OTP rework, which covers
  the approve/reject update.

## New: fare estimation (and a real drop-off step, which didn't exist before)

Fare estimation needs a trip distance, and the app never actually asked
for a destination — `dropoffAddress` was silently set equal to
`pickupAddress` everywhere. Fixed as part of this, since the fare feature
is meaningless without it.

- `lib/screens/map_location_picker_screen.dart` — now a two-step flow:
  choose pickup (as before, map + nearby-places strip), then the same
  screen switches to "Choose Drop-off Location" (with a back arrow to
  pickup) before continuing. Both markers show on the map together once
  set.
- `lib/screens/select_time_screen.dart`, `confirm_ride_screen.dart` —
  thread `dropoffLocation`/`dropoffLat`/`dropoffLng` through alongside the
  existing pickup coordinates.
- `lib/services/fare_service.dart` (**new**) — flat per-vehicle rates
  (`Motorcycle`/`Tricycle`/`Bus`/`Taxi`, matching the exact names used in
  `VehicleSelectionScreen`) times straight-line distance, with a GHS 5
  minimum fare. **This is an illustrative estimate, not live pricing** —
  no traffic/time-of-day/surge factor, and straight-line distance will
  under-count actual road distance. Said plainly in the UI text too, not
  just in code comments.
- `lib/models/ride_model.dart` — added `dropoffLat`/`dropoffLng`/
  `distanceKm`/`estimatedFareGhs`, persisted the same way as the other
  ride fields (Firestore + Hive offline queue both covered — no
  `firestore.rules` change needed since these are just additional fields
  on the same `create`).
- `lib/screens/confirm_ride_screen.dart` — shows the fare estimate
  prominently before confirming, and now also speaks it via TTS
  ("Estimated fare is GH₵12.50"). Also restyled with the app theme
  (it hadn't been touched since the original review), and removed a dead
  "Ongoing Rides" section that displayed a `RideProvider.ongoingRides`
  list nothing in the app ever populated — always showed "No ongoing
  rides." regardless of reality. That empty list field was removed from
  `RideProvider` too.
- `lib/screens/home_screen.dart`'s ongoing-ride tile and
  `lib/screens/admin_screen.dart`'s Rides tab both now show the fare
  estimate alongside the existing status/driver info.

## Fixes: color consistency, vehicle selection card frame, Confirm Ride errors

- **Color mismatch (green vs orange):** `setting_screen.dart` and
  `vehicle_selection_screen.dart` both had a hardcoded
  `backgroundColor: Colors.green` on their `AppBar`, left over from before
  `AppTheme` existed — every other screen was already using the theme's
  gold/orange primary color via `AppBarTheme`, so these two stood out.
  Removed both overrides; all AppBars are now uniformly styled from the
  theme. Also swapped a stray `Colors.black` label in
  `vehicle_selection_screen.dart` for `AppColors.textPrimary`.
- **Vehicle selection now has a proper card frame:** each vehicle option
  was a bare `Container` with `color: Colors.transparent` — no border, no
  shadow, nothing to visually mark it as tappable. Each option is now a
  themed `Card` with an `InkWell` tap ripple, matching every other card in
  the app.
- **Confirm Ride "could not reach server":** this message was a catch-all
  for *any* exception, including ones that had nothing to do with actual
  network reachability. Specifically fixed:
  - The passenger-profile lookup ran *before* the try/catch, so a failure
    there (e.g. rules not deployed) would crash the whole booking flow
    unhandled instead of being caught anywhere. It's now wrapped in its
    own try/catch with a fallback name.
  - Added an explicit check: if there's no active Firebase session at all
    (`FirebaseAuth.instance.currentUser` is null), the screen now says so
    directly ("You're not signed in — please log in again") instead of
    letting it fail deep inside a Firestore permission error.
  - The Firestore write now has a 15-second timeout, and the error message
    branches by cause: a `permission-denied` `FirebaseException` gets a
    message pointing at the two most common real causes in this project
    (rules not redeployed, or not actually signed in); a genuine timeout
    gets its own message; everything else still falls back to the
    original generic message. The raw error is also now logged to the
    console (`log(...)`) for actual debugging, separate from the
    friendlier SnackBar text.
  - **If you're still seeing this after pulling these changes,** the
    updated SnackBar text should now tell you which of the two it is —
    paste it here and I can pin down the exact cause.

## Fixes: "backend not working" — welcome name, profile save, and two real bugs

- **Home screen now greets you by first name** ("Welcome, Ama 👋"),
  looked up from the phone-keyed profile. Falls back to the generic
  greeting if the profile hasn't loaded yet (or can't be reached), rather
  than showing nothing.

- **Two silent-failure bugs found and fixed** — these are the most likely
  actual cause of "the backend doesn't seem to be working":

  1. **Missing composite Firestore indexes.** Two queries in this app
     filter on two fields at once (`rideRequests` by `driverPhone` +
     `status` in `driver_home_screen.dart`; `users` by `role` +
     `verificationStatus` in `admin_screen.dart`'s Drivers tab). Firestore
     requires an explicit composite index for that — without one, the
     query fails outright. `firestore.indexes.json` was sitting empty this
     whole time, so both queries have been silently failing. **Both
     indexes are now defined in `firestore.indexes.json` — deploy it
     (`firebase deploy --only firestore:indexes`, or create them manually
     in Firebase Console → Firestore → Indexes) alongside your rules.**
     Console will also give you a direct "create this index" link the
     first time each query runs, if you'd rather do it that way.
  2. **No error handling on any Firestore stream in the app.** Every
     `StreamBuilder`/`.listen()` on a Firestore query only checked
     `snapshot.hasData`, never `snapshot.hasError` (or `onError` for raw
     listeners). A failed query — like the two above — just showed an
     infinite loading spinner forever, with nothing in the UI indicating
     anything was wrong. Added proper error states to every Firestore
     stream in `driver_home_screen.dart`, `admin_screen.dart`, and
     `track_ride_screen.dart`, so a failure now shows an actual message
     instead of a spinner that never resolves.

- **`ProfileScreen` had the same class of bug for editing/saving.**
  `_load()` and `_save()` had no try/catch at all — any Firestore error
  (undeployed rules, no connection, etc.) either left the screen stuck on
  a spinner forever (`_load()`) or threw unhandled with the Save button
  giving no feedback at all (`_save()`). Both are now guarded: loading
  shows a real error with a "Try Again" button, and saving shows a clear
  message on failure instead of silently doing nothing.

- Also guarded the equivalent profile lookups in `home_screen.dart` (for
  the new welcome name) and `driver_home_screen.dart` (for the driver's
  display name) — lower-stakes since they degrade to a fallback rather
  than blocking anything, but consistent with the above.

### If it's still not working after this

Given everything above, the most likely remaining causes are outside the
code itself:
1. **`firestore.rules` and `storage.rules` haven't been deployed** — editing
   these files locally does nothing until published via Firebase Console
   or `firebase deploy`. This has come up several times already.
2. **`firestore.indexes.json` hasn't been deployed** (see above — new as of
   this fix).
3. **Firestore/Storage might not actually be enabled** on the Firebase
   project yet — creating a Firebase project does not automatically
   provision a Firestore database or Storage bucket; both need to be
   explicitly created once in the Console (Firestore Database → Create
   database; Storage → Get started).

With the error-handling fixes above, any of these three should now show up
as a visible, readable error message in the app instead of a silent hang —
paste that message here and I can tell you exactly which of the three it is.

## Storage without Firebase Storage (Cloudinary swap)

Firebase now requires the paid Blaze plan just to *enable* Cloud Storage —
there's no free way to turn it on anymore. Since driver license/car photos
were the only thing using it, swapped that one piece out for
**Cloudinary**, which has a genuinely free tier (25GB storage/bandwidth,
no credit card) and needs no backend of its own — the app uploads directly
via a plain HTTP POST.

**Nothing else changed.** Firestore is untouched — `licenseImageUrl`/
`carImageUrl` still just store a URL string on the user's profile document,
exactly as before. Only *where that URL points* is different.

- `lib/services/user_service.dart` — `uploadDriverDocument()` now POSTs to
  Cloudinary's unsigned upload endpoint instead of `firebase_storage`.
- `lib/core/api_keys.dart` — added `cloudinaryCloudName` /
  `cloudinaryUploadPreset` placeholders (**you need to fill these in** —
  steps below).
- Removed the `firebase_storage` dependency from `pubspec.yaml`, and
  `storage.rules` + its entry in `firebase.json` (no longer used —
  Cloudinary has its own separate access controls, described below).

### Setup steps (free, ~5 minutes)

1. Go to [cloudinary.com](https://cloudinary.com) → **Sign up free** — no
   credit card required.
2. On your Cloudinary **Dashboard**, copy your **Cloud name** (shown near
   the top).
3. Go to **Settings → Upload** → scroll to **Upload presets** → **Add
   upload preset**.
4. Set **Signing Mode** to **Unsigned** (this is what lets the app upload
   directly without a secret key baked into the app). Give it a name (e.g.
   `ruralride_driver_docs`) and save.
5. In `lib/core/api_keys.dart`, replace:
   - `cloudinaryCloudName` → your Cloud name from step 2
   - `cloudinaryUploadPreset` → the preset name from step 4
6. Run `flutter pub get` (the dependency list changed).

That's it — no rules file to deploy for this part. An unsigned preset can
optionally be restricted in the Cloudinary dashboard (e.g. max file size,
allowed formats, or requiring moderation) if you want tighter control
later; by default it accepts uploads from anyone who has the cloud
name + preset name, which — same caveat as everywhere else in this app's
auth model — is a reasonable trade-off for a project without a backend,
not a production-grade access control.

## New: onboarding branding, optional password login, and page-by-page voice narration

### Onboarding
`lib/screens/onboarding_screen.dart` now leads with a taxi logo (reusing
`assets/images/taxi.png` in a circular badge) plus a clear welcome message,
and the passenger button now reads **"Get Started"** instead of "Start
Journey".

### Optional password login (skip OTP next time)
Signup now has an optional password + confirm field. If set:

- `lib/auth/synthetic_email.dart` (**new**) derives a synthetic, never-shown
  "email" from the phone number (e.g. `p233241234567@ridehome.local`).
- On successful OTP verification during signup, `lib/screens/otp_screen.dart`
  links a real Firebase email/password credential to that synthetic email
  onto the just-created anonymous session (`linkWithCredential`) — this
  **upgrades the account off anonymous auth** for password users
  specifically, which is a real (if partial) improvement to the
  auth-security trade-off documented in `otp_generator.dart`/
  `firestore.rules`: a password account now has a persistent Firebase
  identity tied to real credentials, not just a device-local anonymous
  session.
- `UserProfile.hasPassword` (**new field**) records whether this succeeded.
  No password or hash is ever stored in Firestore — Firebase Auth's own
  infrastructure holds it securely, the same as any app using email/password
  sign-in.
- `lib/auth/login_screen.dart` (rewritten) — now two steps: enter phone
  number → if that account has `hasPassword == true`, ask for the password
  and sign in via `signInWithEmailAndPassword` (skipping OTP entirely); if
  not, falls through to the OTP flow exactly as before. A "Forgot password?
  Use a code instead" link is always available as a fallback.

**Required Firebase Console step, same as Anonymous Auth earlier:** go to
**Authentication → Sign-in method** and enable **Email/Password** — without
it, setting a password on signup will fail (silently falling back to
OTP-only for that account, since `_maybeSetPassword` doesn't block the rest
of signup if linking fails).

### Voice guidance on every page
`lib/services/voice_guide_service.dart` (**new**) — a single service that
narrates what each page/its key actions are for for, used consistently
across onboarding, login, signup, OTP, home, vehicle selection, the map
picker (separate narration for pickup vs. drop-off steps), select time,
track ride, driver home, profile, settings, and the admin dashboard.

- Respects the **Voice Guidance** toggle in Settings, which — worth
  flagging — previously did nothing at all; every TTS call in the app
  ignored it. All narration (new and pre-existing) now checks it.
- `confirm_ride_screen.dart` and `driver_home_screen.dart`'s existing
  dynamic announcements (ride details with live fare; "new ride request
  from X") were kept as-is rather than replaced with generic page text —
  they're more useful than boilerplate — just brought under the same
  voiceEnabled check.
- Fixed a real accuracy bug while in `home_screen.dart`: its old intro
  said "the blue tab" / "the red tab", colors that haven't matched the
  actual bottom nav since the app-wide color-consistency fix. Replaced
  with the new service.

**Built to be extended with real local-language recordings**, per your
request:
- `assets/audio/en/`, `assets/audio/twi/`, `assets/audio/ga/` (**new**,
  registered in `pubspec.yaml`) — each has a README listing the exact
  filenames expected (matching the `pageKey`s in `voice_guide_service.dart`,
  e.g. `home.mp3`, `confirm_ride.mp3`).
- `VoiceGuideService.describePage()` always tries a recording at
  `assets/audio/<lang>/<pageKey>.mp3` **first**, and only falls back to
  synthesized speech if none exists. **No code changes are needed to add a
  recording** — just drop the file in, matching filename, and it's used
  automatically.
- "Ga" is already selectable in Settings' language dropdown, ready for
  recordings even though no synthesized Ga translations are provided (see
  below).
- New dependency: `audioplayers: ^6.0.0`. Run `flutter pub get`.

**One honesty note:** I don't speak Twi or Ga, so I only filled in Twi
text where the app already had it (onboarding), and left every other
`pageDescriptions` entry Twi/Ga-less rather than machine-guess a
translation I can't verify — those currently fall back to the English text
automatically. A native speaker filling in accurate strings in
`voice_guide_service.dart` (or, better, just recording real audio per the
above) would complete this properly.

## Fixes: driver photo upload crashing on web, and a logout-on-navigate bug

- **"Unsupported operation: MultipartFile is only supported where dart:io
  is available"** — the driver signup flow used `dart:io`'s `File` to hold
  picked license/car photos, and `http.MultipartFile.fromPath()` to upload
  them. Neither works on Flutter Web at all — there's no real filesystem
  path behind a picked image on web (`dart:io` doesn't exist there), only
  a blob reference. Fixed by switching to image_picker's cross-platform
  `XFile` throughout (`lib/models/pending_signup.dart`,
  `lib/auth/signup_screen.dart`) and reading it as bytes instead of a path
  in `lib/services/user_service.dart`'s `uploadDriverDocument()`
  (`http.MultipartFile.fromBytes` instead of `.fromPath`) — this works
  identically on Android, iOS, and web.

- **Confirming a ride appeared to log the passenger out.** Root cause:
  `lib/screens/auth_gate_screen.dart` called
  `FirebaseAuth.instance.authStateChanges()` directly inside `build()`.
  Every call to `authStateChanges()` returns a *new* `Stream` instance —
  even though it logically represents the same ongoing auth state.
  `StreamBuilder` treats a new stream instance as something to
  re-subscribe to from scratch, resetting to "waiting" (and transiently
  `user == null`) until the new subscription's first event arrives. Any
  rebuild of this screen — and `ConfirmRideScreen`'s
  `Navigator.popUntil(context, (route) => route.isFirst)` after booking
  lands squarely back on it — could trigger exactly this, reading as "got
  logged out". Fixed by creating the stream once as a field instead of
  calling `authStateChanges()` fresh on every build.

## The "what else can make the app better" round (items #1-8)

### #1 — Real backend for security: recommendation only, not built
This needed a Cloud Function (verify OTP server-side, mint a custom
Firebase token) to properly close the anonymous-auth gap documented
throughout this project. Cloud Functions require Firebase's paid Blaze
plan to enable at all — same requirement that ruled out Firebase Storage
earlier. Rather than build code you can't deploy, this stays as a
documented recommendation: it's genuinely the strongest "future work" item
for a report, and now that password accounts exist (see below), it's a
natural next step to unify around.

### #2 — Multiple ongoing rides (real bug fix)
`RideProvider` held a single `Ride?` slot. Once scheduling existed, booking
a second ride (one now, one for later) silently overwrote the first in the
UI — Firestore still had both documents, but Home could only ever show
one. Rewritten to hold a `List<Ride>` (`lib/providers/ride_provider.dart`):
`addOngoingRide`, `completeRide(ride)`, `cancelRide(ride)` all operate on a
specific ride now rather than "the" ride. `home_screen.dart` renders a tile
per ongoing ride instead of one. Covered by `test/ride_provider_test.dart`,
including a test specifically guarding against the original bug.

### #3 — Driver ratings
- `UserProfile` gained `ratingSum`/`ratingCount` (a running total, not a
  stored list — one atomic increment per rating instead of read-modify-
  write) and an `averageRating` getter (null, not 0.0, when unrated).
- `lib/services/rating_service.dart` (**new**) — `submitRating()` records
  the score on the ride (so it's never asked for twice) and folds it into
  the driver's aggregate, both inside one Firestore transaction.
- `home_screen.dart` now detects when an ongoing ride's live status flips
  to `Completed`, moves it to history via the new `RideProvider.completeRide`,
  and — if there was a driver and no rating yet — shows a simple 5-star
  dialog. Skippable, no nagging/retry.
- The average now displays next to the driver's name on
  `driver_home_screen.dart` (their own) and `track_ride_screen.dart` (the
  passenger sees it while tracking).

### #4 — SOS / emergency button
`track_ride_screen.dart` has a persistent red SOS floating button. Tapping
it offers two `url_launcher`-backed actions: call Ghana's emergency number
(112, change the constant if deploying elsewhere) via the phone dialer, or
open a pre-filled SMS with a Google Maps link to the driver's last known
location, letting the passenger pick who to send it to. New dependency:
`url_launcher: ^6.3.0`.

### #5 — Password management in Profile
Signup could only *set* a password, never change or remove one.
`profile_screen.dart` now has a Password section:
- **Set** (if none): links a new email/password credential, same mechanism
  as signup.
- **Change** (if one exists): re-authenticates with the current password
  first (Firebase requires a recent sign-in to change a password — this
  avoids a `requires-recent-login` error on an older session), then updates.
- **Remove**: unlinks the email/password credential and flips `hasPassword`
  back to false, so `LoginScreen` falls back to OTP for that account again.

### #6 — Push notifications: receiving side built, sending side needs Blaze
Same billing wall as #1. `lib/services/push_notification_service.dart`
(**new**, `firebase_messaging: ^14.9.4`) requests permission, retrieves
this device's FCM token, and lets a screen listen for foreground messages
— all free, all built, wired into `driver_home_screen.dart` (token saved
to the driver's profile via `UserService.updateFcmToken`, foreground
messages shown as a SnackBar). **Actually triggering** a notification
automatically (the moment a matching ride appears) needs something
server-side watching Firestore and calling the FCM API — a Cloud Function,
requiring Blaze. Until that's in place, notifications can be sent manually
via Firebase Console → Cloud Messaging → "Send test message" using the
token saved on the driver's profile — enough to demonstrate the receiving
side genuinely works, just not automatically. Also added the Android 13+
`POST_NOTIFICATIONS` permission.

### #7 — Automated tests
Three new test files, all pure-logic (no Firebase mocking needed):
`test/ride_provider_test.dart`, `test/fare_service_test.dart`,
`test/user_profile_model_test.dart`. `OtpService` and the Firestore-backed
services weren't included — they'd need Firebase emulator or mocking
infrastructure this project doesn't have yet, which is a reasonable next
step if you want to extend coverage further.

### #8 — Polish
- `home_screen.dart`'s "Reset Ride History" now shows a confirmation dialog
  before wiping history, instead of firing immediately on tap.
- The raw `DateTime.toString()` display issue was already fixed at the
  source back in the fare-estimation round (`confirm_ride_screen.dart` uses
  `DateFormat('EEE, MMM d • h:mm a')` before ever storing the ride time as
  a string) — double-checked and confirmed still correct, nothing left to
  do here.
- Loading skeletons were considered but left out — the existing spinner
  states already have real content, and this seemed like a poor time
  trade-off versus everything else on the list.

## Second "make it better" round, item #1: using the ride-progress states that already existed

`RideStatusBadge` already had colors/labels defined for `on_the_way` and
`arrived`, but nothing in the app ever set those statuses — a ride jumped
straight from `Accepted` to `Completed`.

- `driver_home_screen.dart` — "My Accepted Rides" is now "My Rides In
  Progress", and shows the right action button per status: **Start Trip**
  (Accepted → on_the_way), **Mark Arrived** (on_the_way → arrived), then
  **Complete** (arrived → Completed). The accepted-rides query and location
  broadcast now cover all three in-progress statuses instead of stopping
  after "Accepted", so the passenger keeps seeing the driver move for the
  whole trip. The existing composite index (`driverPhone` + `status`)
  already covers the `whereIn` version of this query — no index changes
  needed.
- `track_ride_screen.dart` — shows a distinct "Your driver has arrived at
  the pickup point!" callout when status is `arrived`, instead of falling
  through to the generic distance text.
- `home_screen.dart` — the ongoing-ride tile is now tappable-to-track for
  the whole in-progress lifecycle (previously only while status was
  exactly `Accepted`).

## Third "make it better" round, item #2: call driver / call passenger

Previously only the driver's phone number was ever stored on a ride
document — there was no way for a driver to call the passenger, and no
"Call Driver" button existed for the passenger either.

- `lib/models/ride_model.dart` — added `passengerPhone`.
- `lib/screens/confirm_ride_screen.dart` — the passenger's phone (already
  being read from `SharedPreferences` to resolve their name) is now also
  stored on the ride, for both the online and offline booking paths.
- `lib/screens/track_ride_screen.dart` — a **Call Driver** button now sits
  next to the driver's name, next to their rating. Hidden once the ride is
  `Completed`/`Cancelled`.
- `lib/screens/driver_home_screen.dart` — a **Call Passenger** icon sits
  next to the passenger's name on "My Rides In Progress" cards, using the
  ride's stored `passengerPhone`. Deliberately **not** shown on "New
  Requests" — a driver shouldn't be calling someone whose ride they
  haven't accepted yet.
- Both reuse the same `tel:` URI approach already built for the SOS button
  (`url_launcher`, already a dependency — no new package needed).

## Onboarding redesign, restored Cloudinary keys, better signup diagnostics

- **Onboarding rewritten** with a genuinely distinct visual identity: a
  large circular taxi avatar (white badge, gold ring, soft shadow — not
  just a plain inline image), "Welcome / to Smart Rural Ride" as two
  weighted lines, and "Get Started" / "I am a Driver" as before.
- **`lib/core/api_keys.dart` had reverted to placeholder Cloudinary values**
  (`YOUR_CLOUD_NAME` / `YOUR_UNSIGNED_UPLOAD_PRESET`) in this working copy,
  restored to the real ones. If driver signup was failing after entering
  the OTP, this was very likely why — every license/car photo upload would
  have failed against a cloud name that doesn't exist. **If you're
  maintaining your own copy of this file separately from what I hand you,
  double check it has your real values, not placeholders.**
- `lib/screens/otp_screen.dart` — signup's error handling was one generic
  catch-all ("Something went wrong finishing sign-in: $e") for three very
  different possible failures (license photo upload, car photo upload,
  profile save). Each now throws its own specific, readable message, and
  the raw error is also logged to console (`log(...)`) for real debugging.
  **If driver signup fails again, the on-screen message should now say
  exactly which step failed** — paste it here and it'll be immediate to
  diagnose rather than guesswork.

### On "Passenger still gets logged out after confirming a ride"

I re-checked `lib/screens/auth_gate_screen.dart` and the fix from before
(hoisting the `authStateChanges()` stream to a field instead of recreating
it on every build) is still in place and correct — I couldn't find a
different cause on this pass. Given a couple of things reported as fixed
have come back (this, and onboarding not showing the taxi logo that was
already added), it's worth double-checking whether the environment you're
testing has actually picked up the latest files — particularly
`auth_gate_screen.dart` and `onboarding_screen.dart`. If it has and this is
still happening, the next most useful thing would be the exact moment it
happens (does it flash back to the Login screen, or the onboarding screen,
right after tapping Confirm — or only later?) so I can chase a different
cause.

## Diagnostic logging for the two still-unresolved bugs

Confirmed you're always testing my latest zip (with your own real
Cloudinary keys layered in) — so the Cloudinary-placeholder theory doesn't
explain the driver signup failure, and the auth-stream fix genuinely
hasn't fully resolved the logout-on-confirm issue. Rather than keep
guessing, added logging so the *next* occurrence of either is traceable
from the browser console (F12 → Console) instead of another blind attempt:

- `lib/screens/auth_gate_screen.dart` — a second listener on the (still
  correctly hoisted) auth stream logs every transition:
  `[AuthGateScreen] auth state changed: <uid or SIGNED OUT> at <time>`.
- `lib/screens/confirm_ride_screen.dart` — logs the current user's uid
  right before navigating back after a successful booking (both the
  online and offline paths), so it's possible to see whether the session
  was already gone *before* that navigation happens, or only after.
- `lib/screens/otp_screen.dart` — the signup path now logs each step as it
  happens (`[OTP submit] ...`): anonymous sign-in, license photo upload,
  car photo upload, profile save. If it fails, the last `[OTP submit]`
  line printed tells you exactly which step it got stuck on, even before
  reading the error message itself.

**Next step:** reproduce each bug once with the browser console open, and
paste the relevant `[AuthGateScreen]` / `[ConfirmRide]` / `[OTP submit]`
lines (plus whatever error follows) here — that trail should make both of
these conclusively diagnosable instead of another round of guessing.

## Role color-coding system, dedicated role-selection page, and Sign Out moved to Settings

A fairly large restructuring of the start-of-app flow, built around one
consistent idea: **gold = Passenger, green = Driver**, used the same way
on every screen that involves a role, so the color itself becomes a
learnable cue independent of reading the text.

- `lib/theme/app_theme.dart` — added `AppColors.passengerColor` (alias for
  `primary`/gold) and `AppColors.driverColor` (alias for `secondary`/
  green) as the one source of truth for this mapping.
- `lib/screens/onboarding_screen.dart` — simplified back to pure welcome
  content (taxi avatar, welcome message, one "Get Started" button). Role
  choice no longer happens here.
- `lib/screens/role_selection_screen.dart` (**new**) — the page after
  onboarding now asks "Are you a...", with two large color-coded cards
  (gold Passenger / green Driver). Voice narration explains the colors on
  load. Tapping one goes straight to that role's signup — not to Login —
  per your request.
- `lib/auth/signup_screen.dart` — the role toggle is now framed as color-
  coded tabs (gold/green, matching role selection exactly), the AppBar
  itself recolors to match whichever role is active, and there's now a
  colored banner below the form ("Meant to sign up as a Driver instead?
  Tap here.") in the *other* role's color, which switches the active tab
  when tapped. Both the tab switch and the page load are voice-narrated.
- `lib/screens/driver_home_screen.dart` — AppBar recolored to green
  (driver color), and the "Accept" button now uses the green button
  variant, so the whole driver experience reads consistently green.
- `lib/screens/home_screen.dart` — AppBar color made explicit as gold
  (`AppColors.passengerColor`) rather than implicitly matching the default
  theme, so it's clearly intentional rather than coincidental.
- **Sign Out moved from Profile to Settings.** `profile_screen.dart` no
  longer has a Sign Out button; `setting_screen.dart` now does, below a
  divider at the bottom of the page.

### A note on returning users

Because RoleSelectionScreen now goes straight to Signup rather than Login,
a **returning** user reaching this flow (e.g. reinstalled the app) lands on
Signup first and needs to tap "Already have an account? Login" at the
bottom to get to the login flow instead. This matches exactly what was
asked for, but is worth knowing about if it feels like an extra tap for
returning users during testing/demoing.

## Signup tabs removed, language selection added, settings now actually persist

### Signup screen simplified
Removed the tab bar from `signup_screen.dart` — the colored "switch to the
other role" banner below the form (already built) is now the *only* way
to switch roles, instead of two redundant mechanisms. A small colored bar
at the top still shows which role the form is currently for, without
being an interactive tab control.

### Language selection, before onboarding
- `lib/screens/language_selection_screen.dart` (**new**) — the very first
  screen on a truly fresh install, before onboarding. Picking a language
  speaks a short confirmation in that language, then continues to
  onboarding — meaning onboarding's own narration, and everything after
  it, can now actually be voiced in the chosen language from the start,
  instead of always beginning in English regardless of what gets picked
  later in Settings.
- `lib/screens/auth_gate_screen.dart` — gates on a new `hasSelectedLanguage`
  flag before the existing `hasSeenOnboarding` check.

### Found and fixed: settings were never actually saved
While wiring this up, found that `SettingsProvider` (language, text size,
voice toggle) never persisted anywhere — every setting silently reset to
`SettingsModel`'s hardcoded defaults (English, 16.0, voice on) on every
fresh app launch. This meant a language chosen once wouldn't have stuck
around anyway. `SettingsProvider` now loads from and saves to
`SharedPreferences`; `main.dart` loads it once before `runApp` so the
correct language/settings are ready before the first frame renders.

### Test updated
`test/widget_test.dart` now covers both the true first-launch case
(language selection) and the "language already chosen" case (onboarding),
since the very-first-screen changed.

## Car make/model as dependent dropdowns, with a free-text fallback

`lib/core/car_data.dart` (**new**) — a curated reference list of car makes
and their common models, weighted toward vehicles seen in Ghana (Toyota,
Hyundai, Kia, Nissan, Honda, Mercedes-Benz, and 12 more, ~17 makes total).
Not exhaustive by design — every make's model list, and the make list
itself, ends with an "Other (type your own)" option, so a driver whose
car genuinely isn't covered can still type it in freely rather than being
blocked.

`lib/auth/signup_screen.dart` — Car Make and Car Model are now dependent
dropdowns: picking a make populates the model dropdown with only that
make's models (plus Other); the model dropdown is disabled with a "Choose
a make first" hint until a make is picked, and resets if the make changes
(a previously-picked model may not apply to a new make). Picking "Other"
on either one reveals a free-text field right below it for typing the
actual value, which is what actually gets saved.

## Known limitations still worth addressing later

- The admin phone number is still a hardcoded string in `login_screen.dart`,
  and (per above) admin status now can't be verified at the database level
  at all without a backend minting custom tokens — treat the current admin
  gate as a UI convenience, not a security boundary.
- Fare estimates use straight-line distance, not road distance — see the
  note in `lib/services/fare_service.dart` for what a production version
  would need (a routing/directions API).
- No push notifications yet — a driver only hears the TTS alert for a new
  ride while `DriverHomeScreen` is actually open. Item #6 on the
  "make it better" list.
