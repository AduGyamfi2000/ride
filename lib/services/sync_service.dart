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
        uploadPendingRides();
      }
    });

    _connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        uploadPendingRides();
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> uploadPendingRides() async {
    final store = OfflineRideStore();
    final rides = await store.loadRides();
    if (rides.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final coll = FirebaseFirestore.instance.collection('rideRequests');
    for (var ride in rides) {
      final doc = coll.doc();
      batch.set(doc, ride.toJson());
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
