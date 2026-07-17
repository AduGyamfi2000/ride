import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles passenger-to-driver ratings after a completed ride.
class RatingService {
  static String _docIdFor(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Records [stars] (1-5) against the ride (so it's never prompted for
  /// twice) and folds it into the driver's running rating average.
  static Future<void> submitRating({
    required String rideId,
    required String driverPhone,
    required int stars,
  }) async {
    assert(stars >= 1 && stars <= 5);

    final firestore = FirebaseFirestore.instance;
    final rideRef = firestore.collection('rideRequests').doc(rideId);
    final driverRef = firestore.collection('users').doc(_docIdFor(driverPhone));

    // A transaction keeps the driver's ratingSum/ratingCount increment
    // atomic even if two ratings land at the same moment (unlikely for
    // one ride, but a driver could be mid-update on another ride's
    // rating at the same time).
    await firestore.runTransaction((tx) async {
      final driverSnap = await tx.get(driverRef);
      final currentSum = (driverSnap.data()?['ratingSum'] as num?)?.toInt() ?? 0;
      final currentCount = (driverSnap.data()?['ratingCount'] as num?)?.toInt() ?? 0;

      tx.update(rideRef, {'driverRating': stars});
      tx.set(
        driverRef,
        {'ratingSum': currentSum + stars, 'ratingCount': currentCount + 1},
        SetOptions(merge: true),
      );
    });
  }
}
