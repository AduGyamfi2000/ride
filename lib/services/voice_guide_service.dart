import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Narrates what a page (and its key actions) are about, for low-literacy
/// users who rely on voice guidance rather than reading.
///
/// Voice output has two layers, tried in order:
///   1. A pre-recorded file at assets/audio/<lang>/<pageKey>.mp3, if one
///      exists — this is the extension point for real human recordings in
///      Twi, Ga, or any other local language (device TTS engines often
///      don't support these languages at all, or sound poor/robotic even
///      when they do).
///   2. Synthesized speech (flutter_tts) using the description text below,
///      as a fallback that always works even before any recordings exist.
///
/// To add real recordings later: drop an .mp3 named after the page key
/// into assets/<lang>/ (see the README in each folder) — no code changes
/// needed, this service picks it up automatically.
class VoiceGuideService {
  VoiceGuideService._internal();
  static final VoiceGuideService _instance = VoiceGuideService._internal();
  factory VoiceGuideService() => _instance;

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  // Maps the app's user-facing language setting to the folder name under
  // assets/audio/. Add a new entry here (and a matching assets/audio/<x>/
  // folder + pubspec.yaml entry) to support another local language.
  static const Map<String, String> _langFolders = {
    'English': 'en',
    'Twi': 'twi',
    'Ga': 'ga',
  };

  // Description spoken for each page/element. English is always filled
  // in; Twi/Ga entries are added where already available in the app and
  // otherwise intentionally left out rather than guessed — an entry
  // missing here just falls back to the English text below, which is
  // safer than a wrong machine-translated guess. A native speaker should
  // fill these in over time.
  static final Map<String, Map<String, String>> pageDescriptions = {
    'language_selected': {
      'English': 'Language selected.',
      'Twi': 'Wɔayi Twi.',
    },
    'onboarding': {
      'English':
          'Welcome to Smart Rural Ride. Tap Get Started to continue.',
      'Twi':
          'Meda wo akwaaba wɔ Smart Rural Ride. Fa wo nsa ka Get Started na yɛ toa so.',
    },
    'role_selection': {
      'English':
          'Are you a passenger or a driver? Tap the gold button for Passenger, if you want to book rides. Tap the green button for Driver, if you want to give rides. You will see these same colors again on the next pages.',
      'Twi':
          'Woyɛ Passenger anaa Driver? Fa wo nsa ka sikakɔkɔɔ button no sɛ Passenger, anaasɛ ahaban button no sɛ Driver.',
    },
    'login': {
      'English':
          'This is the login page. Enter your phone number and tap Continue. If your account has a password, you will be asked for it here instead of a code.',
    },
    'signup': {
      'English':
          'This is the sign up page. The colored bar at the top shows which role you are signing up for. Fill in your phone number and first name — these are required. Other fields are optional. Drivers must also add license, car details, and photos. If you meant to sign up as the other role, there is a colored button below the form — tap it to switch.',
    },
    'signup_passenger_selected': {
      'English': 'Passenger selected. This tab is gold.',
    },
    'signup_driver_selected': {
      'English': 'Driver selected. This tab is green. You will need to add your license, car details, and photos.',
    },
    'otp': {
      'English':
          'Enter the code shown on this screen to verify your phone number, then tap Verify.',
    },
    'home': {
      'English':
          'This is your home screen. At the top you can see your ongoing ride status. Below that is your ride history. Use the Order Ride button at the bottom to book a new trip.',
    },
    'vehicle_selection': {
      'English':
          'Choose the type of vehicle you want for your ride: tricycle, taxi, bus, or motorcycle. Tap one to continue.',
    },
    'map_picker_pickup': {
      'English':
          'Choose your pickup point. Tap anywhere on the map, or choose a nearby market, hospital, school, or bank from the list below if your location is on.',
    },
    'map_picker_dropoff': {
      'English': 'Now choose where you want to go. Tap the map or pick a nearby place, then tap Continue.',
    },
    'select_time': {
      'English':
          'Choose when you want your ride. Tap Ride Now to go immediately, or Schedule for Later to pick a future date and time.',
    },
    'confirm_ride': {
      'English':
          'Review your ride details and estimated fare, then tap Confirm to book it.',
    },
    'track_ride': {
      'English':
          'This screen shows your driver approaching on the map, with their distance from your pickup point.',
    },
    'driver_home': {
      'English':
          'This is your driver home screen. New ride requests appear here with an Accept button. Rides you have accepted appear above with a Complete button.',
    },
    'profile': {
      'English': 'This is your profile page. You can edit your name, last name, and email here, then tap Save.',
    },
    'settings': {
      'English': 'This is the settings page. You can change the app language, text size, and turn voice guidance on or off.',
    },
    'admin_dashboard': {
      'English':
          'This is the admin dashboard. Use the tabs to view users, rides, and drivers waiting for approval.',
    },
  };

  /// Speaks the description for [pageKey] in [language] ('English', 'Twi',
  /// 'Ga', ...). Does nothing if [voiceEnabled] is false. Tries a
  /// pre-recorded file first, falls back to text-to-speech.
  Future<void> describePage({
    required String pageKey,
    required String language,
    required bool voiceEnabled,
  }) async {
    if (!voiceEnabled) return;

    final folder = _langFolders[language] ?? 'en';
    final assetPath = 'audio/$folder/$pageKey.mp3';

    try {
      // AssetSource paths are relative to the assets/ declared in
      // pubspec.yaml, so this resolves to assets/audio/<folder>/<key>.mp3.
      await _player.play(AssetSource(assetPath));
      return;
    } catch (e) {
      // Expected until real recordings are added — fall through to TTS.
      if (kDebugMode) {
        debugPrint('No recording at assets/$assetPath, falling back to TTS: $e');
      }
    }

    final text = pageDescriptions[pageKey]?[language] ?? pageDescriptions[pageKey]?['English'];
    if (text == null) return;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    await _player.stop();
  }
}
