import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/signup_screen.dart';
import '../providers/settings_provider.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';

/// Asks "are you a passenger or a driver?" using a consistent color code
/// (gold = Passenger, green = Driver) that carries through to the signup
/// screen and each role's home screen — see AppColors.passengerColor /
/// driverColor.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>().settings;
      VoiceGuideService().describePage(
        pageKey: 'role_selection',
        language: settings.language,
        voiceEnabled: settings.voiceEnabled,
      );
    });
  }

  Future<void> _chooseRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedRole', role);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SignupScreen(initialRole: role)),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                isTwi ? 'Woyɛ obiara?' : 'Are you a...',
                style: AppTextStyles.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                isTwi
                    ? 'Fa ɛtoɔ no gyina wo dwumadie so — sikakɔkɔɔ = Passenger, ahaban = Driver.'
                    : 'Each option has its own color — gold for Passenger, green for Driver. You\'ll see the same colors again on the next few pages.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        label: isTwi ? 'Passenger (Ɔsrafo)' : 'Passenger',
                        description: isTwi ? 'Mepɛ sɛ me nya taxi.' : "I want to book rides.",
                        icon: Icons.emoji_people,
                        color: AppColors.passengerColor,
                        onTap: () => _chooseRole('Passenger'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _RoleCard(
                        label: isTwi ? 'Driver' : 'Driver',
                        description: isTwi ? 'Mepɛ sɛ me ma nkurɔfoɔ taxi.' : 'I want to give rides.',
                        icon: Icons.drive_eta,
                        color: AppColors.driverColor,
                        onTap: () => _chooseRole('Driver'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
