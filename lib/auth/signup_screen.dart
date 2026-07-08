import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../screens/otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  String? _selectedRole;
  String? errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            const Spacer(),
            const Text("Sign Up", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w500)),
            const SizedBox(height: 30),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Enter Phone Number",
                errorText: errorMessage,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              decoration: const InputDecoration(
                labelText: "Full name (optional)",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email (optional)",
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              hint: const Text('Select Role'),
              initialValue: _selectedRole,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue;
                });
              },
              items: <String>['Passenger', 'Driver']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                // Navigate to PhoneOTPVerification with phone number and role
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhoneOTPVerification(
                          phoneNumber: _phoneController.text,
                          userRole: _selectedRole ?? '',
                          name: _nameController.text.isNotEmpty ? _nameController.text : null,
                          email: _emailController.text.isNotEmpty ? _emailController.text : null,
                        ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Send OTP"),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Navigate back to login screen
              },
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text("Already have an account? Login"),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
