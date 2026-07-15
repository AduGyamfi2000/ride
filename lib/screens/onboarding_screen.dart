import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../services/voice_guide_service.dart';
import '../auth/login_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playGuide();
    });
  }

  Future<void> _playGuide() async {
    final settings = context.read<SettingsProvider>().settings;
    await VoiceGuideService().describePage(
      pageKey: 'onboarding',
      language: settings.language,
      voiceEnabled: settings.voiceEnabled,
    );
  }

  Future<void> _finishOnboarding(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    await prefs.setString('selectedRole', role);
    if (!mounted) {
      return;
    }

    // Previously this jumped straight to HomeScreen/DriverHomeScreen with
    // no authentication at all. Now the chosen role is carried into
    // LoginScreen so the user actually verifies their phone number before
    // reaching the app.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(userRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Taxi logo — reuses the existing vehicle artwork so the
              // very first thing a user sees ties directly to what the
              // app does, instead of a generic placeholder icon.
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/taxi.png', height: 90),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                settings.language == 'Twi' ? 'Akwaaba' : 'Welcome to Smart Rural Ride',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                settings.language == 'Twi'
                    ? 'Yɛ boa wo ma woatumi ahwe kwan no yie wɔ akuraase.'
                    : 'Book a ride in your community, in a few simple taps.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              _featureTile(Icons.touch_app, 'Large touch targets', 'Easy to tap even with limited reading experience.'),
              _featureTile(Icons.volume_up, 'Voice guidance', 'Every page tells you what it does and how to use it.'),
              _featureTile(Icons.location_on, 'Simple ride booking', 'Select vehicle, place, and time in a few taps.'),
              const Spacer(),
              AppButton(
                label: settings.language == 'Twi' ? 'Hyɛ Aseɛ' : 'Get Started',
                icon: Icons.arrow_forward,
                onPressed: () => _finishOnboarding('Passenger'),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: settings.language == 'Twi' ? 'Mɛyɛ Driver' : 'I am a Driver',
                icon: Icons.drive_eta,
                variant: AppButtonVariant.outlined,
                onPressed: () => _finishOnboarding('Driver'),
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
            backgroundColor: AppColors.secondaryLight.withValues(alpha: 0.2),
            child: Icon(icon, color: AppColors.secondary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(description),
        ),
      ),
    );
  }
}
