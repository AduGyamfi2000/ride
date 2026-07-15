# ga voice recordings

Drop pre-recorded .mp3 files here, named exactly after the page keys used
in `lib/services/voice_guide_service.dart`'s `pageDescriptions` map, e.g.:

- onboarding.mp3
- login.mp3
- signup.mp3
- home.mp3
- vehicle_selection.mp3
- map_picker_pickup.mp3
- map_picker_dropoff.mp3
- select_time.mp3
- confirm_ride.mp3
- track_ride.mp3
- driver_home.mp3
- profile.mp3
- settings.mp3

VoiceGuideService automatically prefers a recording here over synthesized
speech whenever one exists for the current page + selected language — no
code changes needed, just add the file. If a recording is missing (like
right now — this folder is empty), it silently falls back to
text-to-speech using the description text already defined in
voice_guide_service.dart, so nothing breaks in the meantime.
