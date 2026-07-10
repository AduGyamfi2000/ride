import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  Future<String?> signInAndCreateSession() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user?.uid;
    } catch (e) {
      log('Unable to create Firebase auth session: $e');
      return null;
    }
  }

  Future<bool> sendOTP(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          log('Phone number automatically verified.');
        },
        verificationFailed: (FirebaseAuthException e) {
          log('Verification Failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
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

  Future<bool> verifyOTP(String otp) async {
    try {
      if (_verificationId == null) {
        log('Verification ID is null, unable to verify OTP.');
        return false;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);
      log('OTP verified successfully.');
      return true;
    } catch (e) {
      log('Error verifying OTP: $e');
      return false;
    }
  }
}
