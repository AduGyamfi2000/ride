import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride/screens/auth_gate_screen.dart';
import 'package:ride/screens/onboarding_screen.dart';

void main() {
  testWidgets('AuthGateScreen shows onboarding on first launch',
      (WidgetTester tester) async {
    // No 'hasSeenOnboarding' flag set yet -> first-launch experience.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: AuthGateScreen()),
    );

    // Let the async SharedPreferences lookup inside AuthGateScreen resolve.
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
