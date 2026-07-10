import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride/auth/login_screen.dart';
import 'package:ride/main.dart';
import 'package:ride/screens/auth_gate_screen.dart';

void main() {
  testWidgets('shows the onboarding experience', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(hasSeenOnboarding: false));

    expect(find.text('Smart Rural Ride'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('login screen asks for role and phone number', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Select your role'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });

  testWidgets('auth gate offers sign up and login options', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthGateScreen()));

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
