import 'dart:io';

/// Everything collected on the signup form, carried through OTP
/// verification so the user's profile can be created (with uploaded
/// documents, for drivers) once the code checks out.
class PendingSignup {
  final String role; // Passenger or Driver
  final String firstName; // compulsory
  final String? lastName;
  final String? email;
  // Optional — if set, this account gets a real (non-anonymous) Firebase
  // Auth identity via email/password linking, and can skip OTP on future
  // logins. See lib/auth/synthetic_email.dart.
  final String? password;

  // Driver-only.
  final String? licenseNumber;
  final String? carMake;
  final String? carModel;
  final String? carPlateNumber;
  final String? carColor;
  final File? licenseImageFile;
  final File? carImageFile;

  PendingSignup({
    required this.role,
    required this.firstName,
    this.lastName,
    this.email,
    this.password,
    this.licenseNumber,
    this.carMake,
    this.carModel,
    this.carPlateNumber,
    this.carColor,
    this.licenseImageFile,
    this.carImageFile,
  });
}
