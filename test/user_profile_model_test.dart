import 'package:flutter_test/flutter_test.dart';
import 'package:ride/models/user_profile_model.dart';

void main() {
  group('UserProfile.fullName', () {
    test('is just the first name when no last name is set', () {
      final profile = UserProfile(phone: '+233241234567', firstName: 'Ama', role: 'Passenger');
      expect(profile.fullName, 'Ama');
    });

    test('combines first and last name when both are set', () {
      final profile = UserProfile(
        phone: '+233241234567',
        firstName: 'Ama',
        lastName: 'Owusu',
        role: 'Passenger',
      );
      expect(profile.fullName, 'Ama Owusu');
    });

    test('treats a blank last name the same as no last name', () {
      final profile = UserProfile(
        phone: '+233241234567',
        firstName: 'Ama',
        lastName: '   ',
        role: 'Passenger',
      );
      expect(profile.fullName, 'Ama');
    });
  });

  group('UserProfile.isDriver', () {
    test('is true only for the Driver role', () {
      expect(UserProfile(phone: 'x', firstName: 'A', role: 'Driver').isDriver, isTrue);
      expect(UserProfile(phone: 'x', firstName: 'A', role: 'Passenger').isDriver, isFalse);
      expect(UserProfile(phone: 'x', firstName: 'A', role: 'Admin').isDriver, isFalse);
    });
  });

  group('UserProfile.averageRating', () {
    test('is null when there are no ratings yet (not 0.0)', () {
      // Deliberately not 0.0 — a driver with zero ratings should not
      // display as if they'd been rated "0 stars".
      final profile = UserProfile(phone: 'x', firstName: 'A', role: 'Driver');
      expect(profile.averageRating, isNull);
    });

    test('computes sum / count once ratings exist', () {
      final profile = UserProfile(
        phone: 'x',
        firstName: 'A',
        role: 'Driver',
        ratingSum: 9,
        ratingCount: 2,
      );
      expect(profile.averageRating, 4.5);
    });
  });

  group('UserProfile JSON round-trip', () {
    test('toJson -> fromJson preserves every field', () {
      final original = UserProfile(
        phone: '+233241234567',
        firstName: 'Kofi',
        lastName: 'Asante',
        email: 'kofi@example.com',
        role: 'Driver',
        licenseNumber: 'GHA-1234',
        carMake: 'Toyota',
        carModel: 'Corolla',
        carPlateNumber: 'GR 1234-24',
        carColor: 'Silver',
        licenseImageUrl: 'https://example.com/license.jpg',
        carImageUrl: 'https://example.com/car.jpg',
        verificationStatus: 'Verified',
        hasPassword: true,
        ratingSum: 27,
        ratingCount: 6,
      );

      final roundTripped = UserProfile.fromJson(original.toJson());

      expect(roundTripped.phone, original.phone);
      expect(roundTripped.firstName, original.firstName);
      expect(roundTripped.lastName, original.lastName);
      expect(roundTripped.email, original.email);
      expect(roundTripped.role, original.role);
      expect(roundTripped.licenseNumber, original.licenseNumber);
      expect(roundTripped.carMake, original.carMake);
      expect(roundTripped.carModel, original.carModel);
      expect(roundTripped.carPlateNumber, original.carPlateNumber);
      expect(roundTripped.carColor, original.carColor);
      expect(roundTripped.licenseImageUrl, original.licenseImageUrl);
      expect(roundTripped.carImageUrl, original.carImageUrl);
      expect(roundTripped.verificationStatus, original.verificationStatus);
      expect(roundTripped.hasPassword, original.hasPassword);
      expect(roundTripped.ratingSum, original.ratingSum);
      expect(roundTripped.ratingCount, original.ratingCount);
    });

    test('fromJson fills in sensible defaults for missing fields', () {
      final profile = UserProfile.fromJson({'phone': '+233241234567'});
      expect(profile.firstName, 'User');
      expect(profile.role, 'Passenger');
      expect(profile.verificationStatus, 'Pending');
      expect(profile.hasPassword, isFalse);
      expect(profile.ratingSum, 0);
      expect(profile.ratingCount, 0);
    });
  });
}
