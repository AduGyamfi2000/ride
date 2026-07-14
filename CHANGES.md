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
