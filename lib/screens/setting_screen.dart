import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  String? _selectedLanguage;
  double _textSize = 16.0;
  bool _voiceEnabled = true;

  @override
  void initState() {
    super.initState();
    final settingsProvider = context.read<SettingsProvider>();
    _selectedLanguage = settingsProvider.settings.language;
    _textSize = settingsProvider.settings.textSize;
    _voiceEnabled = settingsProvider.settings.voiceEnabled;
  }

  void _saveSettings() {
    context.read<SettingsProvider>().updateSettings(
      language: _selectedLanguage,
      textSize: _textSize,
      voiceEnabled: _voiceEnabled,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text('Language', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue;
                });
              },
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Twi', child: Text('Twi')),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Text Size', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Slider(
              value: _textSize,
              min: 14.0,
              max: 24.0,
              divisions: 10,
              label: _textSize.round().toString(),
              onChanged: (double newValue) {
                setState(() {
                  _textSize = newValue;
                });
              },
            ),
            Text('Current size: ${_textSize.round()}'),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Voice guidance'),
              subtitle: const Text('Use voice instructions and audio cues.'),
              value: _voiceEnabled,
              onChanged: (value) {
                setState(() {
                  _voiceEnabled = value;
                });
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              icon: const Icon(Icons.person),
              label: const Text('Edit Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
