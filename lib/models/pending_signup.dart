import 'package:image_picker/image_picker.dart';

/// Everything collected on the signup form, carried through OTP
/// verification so the user's profile can be created (with uploaded
/// documents, for drivers) once the code checks out.
///
/// Uses image_picker's XFile rather than dart:io's File — File doesn't
/// work on Flutter Web at all (there's no real filesystem path to a blob
/// URL), whereas XFile works cross-platform via readAsBytes(). See
/// lib/services/user_service.dart's uploadDriverDocument() for the other
/// half of this fix.
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
  final XFile? licenseImageFile;
  final XFile? carImageFile;

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
