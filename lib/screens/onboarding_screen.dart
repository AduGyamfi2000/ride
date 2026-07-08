import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import 'driver_home_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playGuide();
    });
  }

  Future<void> _playGuide() async {
    final settings = context.read<SettingsProvider>().settings;
    final text = settings.language == 'Twi'
        ? 'Meda wo akwaaba. Smart Rural Ride boa wo ma wotumi ahwe kwan a eye den a wobɛ fa ako.'
        : 'Welcome to Smart Rural Ride. Choose Passenger or Driver and begin your journey with simple taps and voice help.';
    await _flutterTts.speak(text);
  }

  Future<void> _finishOnboarding(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    await prefs.setString('selectedRole', role);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => role == 'Driver' ? const DriverHomeScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final title = settings.language == 'Twi' ? 'Smart Rural Ride' : 'Smart Rural Ride';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                settings.language == 'Twi'
                    ? 'Mogye di wo ho. Yɛ boa wo ma woatumi ahwe kwan no yie.'
                    : 'Easy ride booking for rural communities with large buttons, color cues, and voice guidance.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              _featureTile(Icons.touch_app, 'Large touch targets', 'Easy to tap even with limited reading experience.'),
              _featureTile(Icons.volume_up, 'Voice guidance', 'Every step speaks clearly in English or Twi.'),
              _featureTile(Icons.location_on, 'Simple ride booking', 'Select vehicle, place, and time in a few taps.'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _finishOnboarding('Passenger'),
                  icon: const Icon(Icons.emoji_people),
                  label: Text(settings.language == 'Twi' ? 'Fa yɛn nhwɛ' : 'Start Journey'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _finishOnboarding('Driver'),
                  icon: const Icon(Icons.drive_eta),
                  label: Text(settings.language == 'Twi' ? 'Mɛyɛ Driver' : 'I am a Driver'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureTile(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(icon, color: Colors.green.shade800),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(description),
        ),
      ),
    );
  }
}
