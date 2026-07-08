class SettingsModel {
  String language;
  bool voiceEnabled;
  double textSize;

  SettingsModel({
    this.language = 'English',
    this.voiceEnabled = true,
    this.textSize = 16.0,
  });
}
