import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offline_sync_service.dart';

class SyncService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _sub;

  void start() {
    _sub ??= _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _uploadPendingRides();
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _uploadPendingRides() async {
    final store = OfflineRideStore();
    final rides = await store.loadRides();
    if (rides.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final coll = FirebaseFirestore.instance.collection('rideRequests');
    for (var ride in rides) {
      // Reuse the id assigned when the ride was created offline so a
      // re-sync (or the app being killed mid-sync) can never create a
      // duplicate document.
      final doc = ride.id != null ? coll.doc(ride.id) : coll.doc();
      final data = ride.toJson();
      // Firestore needs a real Timestamp (not the millis int used for
      // Hive storage) so DriverHomeScreen's createdAt range query can
      // actually match synced rides.
      data['createdAt'] = Timestamp.fromDate(ride.createdAt);
      batch.set(doc, data, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      await store.clear();
    } catch (e) {
      // keep rides for next attempt
    }
  }
}

final syncService = SyncService();
