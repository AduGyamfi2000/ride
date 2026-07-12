import 'package:flutter/material.dart';
import '../screens/otp_screen.dart';
import 'signup_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/textfield.dart';

class LoginScreen extends StatefulWidget {
  final String userRole;

  const LoginScreen({super.key, this.userRole = ''});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  // Define the admin phone number
  final String adminPhoneNumber =
      "+233123456789"; // Change this to your actual admin number

  void _sendOTP() {
    String phoneNumber = _phoneController.text.trim();

    // The admin number now goes through the same real Firebase phone-auth
    // OTP flow as everyone else — it just gets tagged with the 'Admin'
    // role. Previously this skipped Firebase Auth entirely, which meant
    // request.auth was null and the admin dashboard's own Firestore
    // security rules would reject every read.
    final isAdminNumber = phoneNumber == adminPhoneNumber;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneOTPVerification(
          phoneNumber: phoneNumber,
          userRole: isAdminNumber ? 'Admin' : (widget.userRole.isNotEmpty ? widget.userRole : ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome back', style: AppTextStyles.displayLarge),
            const SizedBox(height: 8),
            const Text(
              'Enter your phone number to continue',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'e.g. +233241234567',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Send OTP',
              icon: Icons.arrow_forward,
              onPressed: _sendOTP,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SignupScreen(initialRole: widget.userRole.isNotEmpty ? widget.userRole : null),
                    ),
                  );
                },
                child: const Text("Don't have an account? Sign up"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
