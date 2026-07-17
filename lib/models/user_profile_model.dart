class UserProfile {
  final String phone;
  final String firstName; // compulsory
  final String? lastName; // optional
  final String? email; // optional
  final String role; // Passenger, Driver, Admin

  // Driver-only fields — null/empty for passengers.
  final String? licenseNumber;
  final String? carMake;
  final String? carModel;
  final String? carPlateNumber;
  final String? carColor;
  final String? licenseImageUrl;
  final String? carImageUrl;
  // Pending until an admin reviews the license/car photos.
  final String verificationStatus;
  // True once the user has set an optional password (see
  // lib/auth/synthetic_email.dart). The password itself is never stored
  // here — Firebase Auth's email/password provider holds it securely;
  // this flag just tells LoginScreen whether to offer password entry
  // instead of OTP.
  final bool hasPassword;
  // Driver rating aggregate — kept as a running sum + count (rather than
  // storing every individual rating here) so the average can be updated
  // with a single atomic Firestore increment per new rating, no need to
  // read-modify-write the whole list. See lib/services/rating_service.dart.
  final int ratingSum;
  final int ratingCount;

  UserProfile({
    required this.phone,
    required this.firstName,
    this.lastName,
    this.email,
    required this.role,
    this.licenseNumber,
    this.carMake,
    this.carModel,
    this.carPlateNumber,
    this.carColor,
    this.licenseImageUrl,
    this.carImageUrl,
    this.verificationStatus = 'Pending',
    this.hasPassword = false,
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  String get fullName =>
      (lastName != null && lastName!.trim().isNotEmpty) ? '$firstName $lastName' : firstName;

  bool get isDriver => role == 'Driver';

  // Null when the driver has no ratings yet, rather than showing "0.0
  // stars" which would misleadingly look like a bad rating.
  double? get averageRating => ratingCount == 0 ? null : ratingSum / ratingCount;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'role': role,
        'licenseNumber': licenseNumber,
        'carMake': carMake,
        'carModel': carModel,
        'carPlateNumber': carPlateNumber,
        'carColor': carColor,
        'licenseImageUrl': licenseImageUrl,
        'carImageUrl': carImageUrl,
        'verificationStatus': verificationStatus,
        'hasPassword': hasPassword,
        'ratingSum': ratingSum,
        'ratingCount': ratingCount,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        phone: json['phone'] as String? ?? '',
        firstName: json['firstName'] as String? ?? 'User',
        lastName: json['lastName'] as String?,
        email: json['email'] as String?,
        role: json['role'] as String? ?? 'Passenger',
        licenseNumber: json['licenseNumber'] as String?,
        carMake: json['carMake'] as String?,
        carModel: json['carModel'] as String?,
        carPlateNumber: json['carPlateNumber'] as String?,
        carColor: json['carColor'] as String?,
        licenseImageUrl: json['licenseImageUrl'] as String?,
        carImageUrl: json['carImageUrl'] as String?,
        verificationStatus: json['verificationStatus'] as String? ?? 'Pending',
        hasPassword: json['hasPassword'] as bool? ?? false,
        ratingSum: (json['ratingSum'] as num?)?.toInt() ?? 0,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      );
}
