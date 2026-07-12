import 'dart:developer';
import 'dart:math' hide log;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Generates and verifies one-time passcodes without going through
/// Firebase's phone-auth SMS flow.
///
/// ⚠️ READ BEFORE SHIPPING THIS TO REAL USERS ⚠️
/// This works by writing the generated code straight into Firestore
/// (`otp_codes/{phone}`) so the client itself can check what the user
/// typed against it — there is no backend server in this project to keep
/// the code secret or to actually text it to anyone. That means:
///
///   1. "Delivery" right now just shows the code in the app / debug
///      console (see `generateAndStore`'s return value) — there is no
///      real SMS being sent. To send a real SMS, plug a gateway used in
///      Ghana (Arkesel, mNotify, Hubtel) or elsewhere (Twilio) into
///      `generateAndStore` — call the gateway's API with the code
///      instead of (or as well as) returning it directly.
///   2. Because the code is readable by anyone who can read the
///      `otp_codes` collection, and Firebase Anonymous Auth requires no
///      verification at all to obtain, this OTP step is a UX check
///      ("did you type the code we showed you"), not a real proof that
///      the person owns that phone number. A production app should move
///      generation/verification into a backend (e.g. a Cloud Function)
///      that never exposes the code to the client, and should mint a
///      Firebase custom auth token bound to the verified phone number.
///
/// This is a reasonable, clearly-flagged simplification for a student/demo
/// project — just don't mistake it for real phone verification.
class OtpService {
  static const int codeLength = 6;
  static const Duration validity = Duration(minutes: 5);
  static const int maxAttempts = 5;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _docIdFor(String phoneNumber) =>
      phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

  String _generateCode() {
    final rand = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < codeLength; i++) {
      buffer.write(rand.nextInt(10));
    }
    return buffer.toString();
  }

  /// Generates a fresh code, stores it (overwriting any previous code for
  /// this number), and returns it so the caller can show/log it.
  Future<String> generateAndStore(String phoneNumber) async {
    final code = _generateCode();
    await _firestore.collection('otp_codes').doc(_docIdFor(phoneNumber)).set({
      'code': code,
      'phone': phoneNumber,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(validity)),
      'attempts': 0,
      'createdAt': Timestamp.now(),
    });

    // Stand-in for real SMS delivery — see the class doc comment above.
    log('🔑 OTP for $phoneNumber: $code (expires in ${validity.inMinutes} min)');
    return code;
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> verify(String phoneNumber, String enteredCode) async {
    final docRef = _firestore.collection('otp_codes').doc(_docIdFor(phoneNumber));
    final snap = await docRef.get();

    if (!snap.exists) {
      return 'No code was requested for this number. Please request a new code.';
    }

    final data = snap.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    final attempts = (data['attempts'] as num?)?.toInt() ?? 0;

    if (DateTime.now().isAfter(expiresAt)) {
      await docRef.delete();
      return 'This code has expired. Please request a new one.';
    }

    if (attempts >= maxAttempts) {
      await docRef.delete();
      return 'Too many incorrect attempts. Please request a new code.';
    }

    if (data['code'] != enteredCode.trim()) {
      await docRef.update({'attempts': attempts + 1});
      final remaining = maxAttempts - (attempts + 1);
      return 'Incorrect code. $remaining attempt(s) left.';
    }

    await docRef.delete();
    return null; // success
  }
}
