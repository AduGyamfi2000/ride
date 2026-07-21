import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsModel _settings = SettingsModel();
  bool _loaded = false;

  SettingsModel get settings => _settings;
  bool get isLoaded => _loaded;

  /// Loads previously-saved settings from SharedPreferences. Call once at
  /// startup (see main.dart) — before this, `settings` just holds
  /// SettingsModel's hardcoded defaults.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings.language = prefs.getString('language') ?? _settings.language;
    _settings.textSize = prefs.getDouble('textSize') ?? _settings.textSize;
    _settings.voiceEnabled = prefs.getBool('voiceEnabled') ?? _settings.voiceEnabled;
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateSettings({String? language, double? textSize, bool? voiceEnabled}) async {
    if (language != null) {
      _settings.language = language;
    }
    if (textSize != null) {
      _settings.textSize = textSize;
    }
    if (voiceEnabled != null) {
      _settings.voiceEnabled = voiceEnabled;
    }
    notifyListeners();

    // Previously these were never saved anywhere — every setting reset to
    // SettingsModel's defaults (English, 16.0, true) on every fresh app
    // launch, silently discarding whatever the user had chosen.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _settings.language);
    await prefs.setDouble('textSize', _settings.textSize);
    await prefs.setBool('voiceEnabled', _settings.voiceEnabled);
  }
}
