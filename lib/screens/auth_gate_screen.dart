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
  // IMPORTANT: this must be created once and reused, not called fresh
  // inside build(). StreamBuilder treats a new Stream *instance* as a
  // brand new stream to subscribe to — even though authStateChanges()
  // logically represents "the same" ongoing auth state, calling it again
  // returns a different Stream object each time. StreamBuilder then
  // resets to ConnectionState.waiting (showing _LoadingScreen, or worse,
  // a transient user == null before the new subscription's first event
  // arrives) on every rebuild of this widget — which is exactly what
  // "confirming a ride logs me out" looks like if any rebuild of this
  // screen happens to coincide with Navigator popping back to it.
  final Stream<User?> _authStateChanges = FirebaseAuth.instance.authStateChanges();

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
          stream: _authStateChanges,
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
