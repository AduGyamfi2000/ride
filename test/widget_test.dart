import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride/screens/auth_gate_screen.dart';
import 'package:ride/screens/language_selection_screen.dart';
import 'package:ride/screens/onboarding_screen.dart';

void main() {
  testWidgets('AuthGateScreen shows language selection on true first launch',
      (WidgetTester tester) async {
    // No flags set at all -> true first-launch experience, before
    // onboarding even.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: AuthGateScreen()),
    );

    // Let the async SharedPreferences lookup inside AuthGateScreen resolve.
    await tester.pumpAndSettle();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
  });

  testWidgets('AuthGateScreen shows onboarding once a language is chosen',
      (WidgetTester tester) async {
    // Language chosen, but onboarding not yet seen.
    SharedPreferences.setMockInitialValues({'hasSelectedLanguage': true});

    await tester.pumpWidget(
      const MaterialApp(home: AuthGateScreen()),
    );

    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
