import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../services/voice_guide_service.dart';
import 'role_selection_screen.dart';
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

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;

    // Role choice (Passenger vs Driver) now lives on its own dedicated,
    // color-coded page rather than being two buttons on this welcome
    // screen.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final isTwi = settings.language == 'Twi';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const Spacer(),
              // Taxi avatar — a large, unmistakable circular badge (not
              // just a plain image) so it reads clearly as the app's
              // identity mark, the very first thing anyone sees.
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.primary, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Image.asset('assets/images/taxi.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 28),
              Text(
                isTwi ? 'Akwaaba' : 'Welcome',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLarge.copyWith(color: AppColors.secondary),
              ),
              const SizedBox(height: 6),
              Text(
                isTwi ? 'Smart Rural Ride' : 'to Smart Rural Ride',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                isTwi
                    ? 'Yɛ boa wo ma woatumi ahwe kwan no yie wɔ akuraase.'
                    : 'Book a ride in your community, in a few simple taps.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              _featureRow(Icons.touch_app, isTwi ? 'Kɔtɔ a ɛyɛ mmerɛw' : 'Large, easy-to-tap buttons'),
              const SizedBox(height: 10),
              _featureRow(Icons.volume_up, isTwi ? 'Nne kwankyerɛ' : 'Every page explains itself by voice'),
              const SizedBox(height: 10),
              _featureRow(Icons.location_on, isTwi ? 'Kwan a ɛyɛ mmerɛw' : 'Simple ride booking in a few taps'),
              const Spacer(),
              AppButton(
                label: isTwi ? 'Hyɛ Aseɛ' : 'Get Started',
                icon: Icons.arrow_forward,
                onPressed: _continue,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.secondary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}
