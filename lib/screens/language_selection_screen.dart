import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

/// The very first screen anyone sees — deliberately before onboarding,
/// so that once a language is picked, onboarding's own narration (and
/// everything after it) can actually be spoken in that language instead
/// of always starting in English.
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  static const _languages = [
    {'code': 'English', 'native': 'English'},
    {'code': 'Twi', 'native': 'Twi'},
    {'code': 'Ga', 'native': 'Ga'},
  ];

  Future<void> _choose(String language) async {
    await context.read<SettingsProvider>().updateSettings(language: language);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSelectedLanguage', true);

    // Speak a short confirmation in the language just chosen, then move
    // on — this is also a quick sanity check that voice output works
    // before the rest of the app leans on it.
    await VoiceGuideService().describePage(
      pageKey: 'language_selected',
      language: language,
      voiceEnabled: true,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.language, size: 48, color: AppColors.secondary),
              const SizedBox(height: 16),
              const Text('Choose your language', style: AppTextStyles.displayLarge),
              const SizedBox(height: 8),
              const Text('You can change this later in Settings.', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lang = _languages[index]['code']!;
                    return GestureDetector(
                      onTap: () => _choose(lang),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceVariant, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _languages[index]['native']!,
                                style: AppTextStyles.headlineMedium,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
