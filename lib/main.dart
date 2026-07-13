import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ride/screens/home_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/ride_provider.dart';
import 'screens/auth_gate_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';
import 'services/offline_sync_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await OfflineRideStore.init();
  // Start background sync service
  syncService.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: MaterialApp(
        title: 'Smart Rural Ride',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        // AuthGateScreen owns the onboarding -> login -> home routing
        // decision, and reacts live to auth state changes.
        // home: const AuthGateScreen(),
        home: const HomeScreen(),
      ),
    );
  }
}
