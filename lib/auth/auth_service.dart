import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  // Send OTP to the phone number
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval or instant verification
          await _auth.signInWithCredential(credential);
          log("Phone number automatically verified.");
        },
        verificationFailed: (FirebaseAuthException e) {
          log('Verification Failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          // Save verificationId for later use
          _verificationId = verificationId;
          log('OTP sent to $phoneNumber');
          log('Verification ID: $verificationId');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          log('Code auto-retrieval timeout. Verification ID: $verificationId');
        },
      );
      return true;
    } catch (e) {
      log('Error sending OTP: $e');
      return false;
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String otp) async {
    try {
      if (_verificationId == null) {
        log('Verification ID is null, unable to verify OTP.');
        return false;
      }

      // Create phone auth credential using the verificationId and OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Sign in with the credential
      await _auth.signInWithCredential(credential);
      log('OTP verified successfully.');
      return true;
    } catch (e) {
      log('Error verifying OTP: $e');
      return false;
    }
  }
}
