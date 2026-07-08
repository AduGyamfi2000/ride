import 'package:flutter/material.dart';
import '../models/settings_model.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsModel _settings = SettingsModel();

  SettingsModel get settings => _settings;

  void updateSettings({String? language, double? textSize, bool? voiceEnabled}) {
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
  }
}
