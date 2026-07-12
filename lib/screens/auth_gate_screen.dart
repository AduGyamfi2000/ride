import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'admin_screen.dart';
import 'driver_home_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Decides the first real screen a user should land on:
/// - Onboarding, if they've never seen it.
/// - LoginScreen, if onboarding is done but there's no active Firebase
///   Auth session.
/// - The role-appropriate home screen, if they're signed in.
///
/// This used to be a private method inline in MyApp (in main.dart), which
/// meant the startup logic couldn't be tested or reused on its own. Pulling
/// it into its own widget also lets it react live to auth state changes
/// (e.g. a token expiring) via authStateChanges(), instead of only checking
/// FirebaseAuth.currentUser once at launch.
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  late final Future<_StartupPrefs> _startupPrefs;

  @override
  void initState() {
    super.initState();
    _startupPrefs = _loadStartupPrefs();
  }

  Future<_StartupPrefs> _loadStartupPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return _StartupPrefs(
      hasSeenOnboarding: prefs.getBool('hasSeenOnboarding') ?? false,
      selectedRole: prefs.getString('selectedRole'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupPrefs>(
      future: _startupPrefs,
      builder: (context, prefsSnapshot) {
        if (!prefsSnapshot.hasData) {
          return const _LoadingScreen();
        }

        final startupPrefs = prefsSnapshot.data!;
        if (!startupPrefs.hasSeenOnboarding) {
          return const OnboardingScreen();
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final user = authSnapshot.data;
            if (user == null) {
              return const LoginScreen();
            }

            switch (startupPrefs.selectedRole) {
              case 'Admin':
                return const AdminScreen();
              case 'Driver':
                return const DriverHomeScreen();
              default:
                return const HomeScreen();
            }
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StartupPrefs {
  final bool hasSeenOnboarding;
  final String? selectedRole;

  _StartupPrefs({required this.hasSeenOnboarding, this.selectedRole});
}
