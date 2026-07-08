import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/admin_screen.dart';
import '../screens/otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final String userRole;

  const LoginScreen({super.key, this.userRole = ''});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define the admin phone number
  final String adminPhoneNumber =
      "+233123456789"; // Change this to your actual admin number

  void _sendOTP() {
    String phoneNumber = _phoneController.text.trim();

    // Check if the entered phone number is the admin's
    if (phoneNumber == adminPhoneNumber) {
      // Navigate directly to the Admin Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminScreen()),
      );
      return;
    }

    // Proceed with OTP verification for regular users
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneOTPVerification(
          phoneNumber: phoneNumber,
          userRole: widget.userRole.isNotEmpty ? widget.userRole : '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendOTP,
              child: const Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
