import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../services/user_service.dart';
import 'driver_home_screen.dart';
import 'home_screen.dart'; // Import for interacting with web-specific APIs

class PhoneOTPVerification extends StatefulWidget {
  final String phoneNumber;
  final String userRole; // Add user role as a parameter
  final String? name;
  final String? email;
  final String? roleDetail;

  const PhoneOTPVerification(
      {super.key, required this.phoneNumber, required this.userRole, this.name, this.email, this.roleDetail});

  @override
  State<PhoneOTPVerification> createState() => _PhoneOTPVerificationState();
}

class _PhoneOTPVerificationState extends State<PhoneOTPVerification> {
  TextEditingController otp = TextEditingController();
  bool visible = true; // Make OTP input visible initially
  String? _generatedOtp;

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOTP();
    });
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
            final enteredOtp = otp.text.trim();
            if (_generatedOtp == null || enteredOtp != _generatedOtp) {
              throw Exception('Invalid OTP');
            }

            final authService = AuthService();
            final currentUid = FirebaseAuth.instance.currentUser?.uid ??
                await authService.signInAndCreateSession() ??
                'temp_${widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '')}';

            await UserService.createOrUpdateUser(
              uid: currentUid,
              phoneNumber: widget.phoneNumber,
              role: widget.userRole.isNotEmpty ? widget.userRole : 'Passenger',
              name: widget.name ?? 'User',
              email: widget.email,
              roleDetail: widget.roleDetail,
            );

            showMessage('Signed in successfully');

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

  /// Function to send OTP
  Future<void> _sendOTP() async {
    try {
      final random = Random();
      _generatedOtp = (1000 + random.nextInt(9000)).toString();
      print('Temporary OTP for ${widget.phoneNumber}: $_generatedOtp');
      if (!mounted) return;
      showMessage('OTP sent to terminal: $_generatedOtp');
    } catch (e) {
      if (!mounted) return;
      showMessage('Failed to send OTP: $e');
    }
  }

  void showMessage(String msg) {
    if (!mounted) return;
    final snackBar = SnackBar(content: Text(msg));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
