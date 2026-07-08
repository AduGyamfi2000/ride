import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../auth/auth_service.dart';

import '../services/user_service.dart';
import 'driver_home_screen.dart';
import 'home_screen.dart'; // Import for interacting with web-specific APIs

class PhoneOTPVerification extends StatefulWidget {
  final String phoneNumber;
  final String userRole; // Add user role as a parameter
  final String? name;
  final String? email;

  const PhoneOTPVerification(
      {super.key, required this.phoneNumber, required this.userRole, this.name, this.email});

  @override
  State<PhoneOTPVerification> createState() => _PhoneOTPVerificationState();
}

class _PhoneOTPVerificationState extends State<PhoneOTPVerification> {
  TextEditingController otp = TextEditingController();
  bool visible = true; // Make OTP input visible initially
  late ConfirmationResult temp; // Store the confirmation result for web

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // For native platforms, trigger sending OTP via AuthService
    if (!kIsWeb) {
      AuthService().sendOTP(widget.phoneNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firebase Phone OTP Authentication"),
      ),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            inputTextField("OTP", otp, context),
            const SizedBox(height: 20),
            submitOTPButton("Submit"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                _sendOTP(); // Resend the OTP
              },
              child: const Text("Resend OTP"),
            ),
          ],
        ),
      ),
    );
  }

  Widget submitOTPButton(String text) => ElevatedButton(
        onPressed: () async {
          try {
            if (kIsWeb) {
              // Confirm OTP for web
              UserCredential userCredential = await temp.confirm(otp.text);
              final user = userCredential.user;
              if (user == null) throw Exception('Sign-in failed');
            } else {
              // Native flow: verify using AuthService
              final ok = await AuthService().verifyOTP(otp.text);
              if (!ok) throw Exception('Invalid OTP');
            }

            final current = FirebaseAuth.instance.currentUser;
            if (current == null) throw Exception('Sign-in failed');

            await UserService.createOrUpdateUser(
              uid: current.uid,
              phoneNumber: widget.phoneNumber,
              role: widget.userRole.isNotEmpty ? widget.userRole : 'Passenger',
              name: widget.name ?? 'User',
              email: widget.email,
            );

            if (widget.userRole == 'Driver') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DriverHomeScreen(),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
            }
          } catch (e) {
            showMessage("OTP sign-in failed: $e");
          }
        },
        child: Text(text),
      );

  Widget inputTextField(String labelText,
          TextEditingController textEditingController, BuildContext context) =>
      Padding(
        padding: const EdgeInsets.all(10.00),
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 1.5,
          child: TextFormField(
            controller: textEditingController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: labelText,
              hintStyle: const TextStyle(color: Colors.blue),
              filled: true,
              fillColor: Colors.blue[100],
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(5.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(5.5),
              ),
            ),
          ),
        ),
      );

  /// Function to send OTP (for web)
  void _sendOTP() async {
    try {
      // Initialize the reCAPTCHA for web
      js.context.callMethod('eval', [
        """
        window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier('submit-button', {
          'size': 'invisible',
          'callback': function(response) {
            console.log('Recaptcha resolved, sending OTP...');
          }
        });
      """
      ]);

      // Send the OTP for web
      temp = await FirebaseAuth.instance.signInWithPhoneNumber(
        widget.phoneNumber,
        js.context['recaptchaVerifier'],
      );

      showMessage("OTP sent to ${widget.phoneNumber}");
    } catch (e) {
      showMessage("Failed to send OTP: $e");
    }
  }

  void showMessage(String msg) {
    final snackBar = SnackBar(content: Text(msg));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
