import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride_model.dart';
import '../providers/ride_provider.dart';
import '../providers/settings_provider.dart';
import '../services/fare_service.dart';
import '../services/offline_sync_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

class ConfirmRideScreen extends StatefulWidget {
  final String vehicleName;
  final String location;
  final DateTime? rideTime;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffLocation;
  final double? dropoffLat;
  final double? dropoffLng;

  const ConfirmRideScreen({
    super.key,
    required this.vehicleName,
    required this.location,
    this.rideTime,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLocation,
    this.dropoffLat,
    this.dropoffLng,
  });

  @override
  ConfirmRideScreenState createState() => ConfirmRideScreenState();
}

class ConfirmRideScreenState extends State<ConfirmRideScreen> {
  FlutterTts flutterTts = FlutterTts();
  bool _isConfirming = false;

  bool get _hasBothPoints =>
      widget.pickupLat != null && widget.pickupLng != null && widget.dropoffLat != null && widget.dropoffLng != null;

  double? get _distanceKm {
    if (!_hasBothPoints) return null;
    final meters = Geolocator.distanceBetween(
      widget.pickupLat!,
      widget.pickupLng!,
      widget.dropoffLat!,
      widget.dropoffLng!,
    );
    return meters / 1000;
  }

  double? get _estimatedFare => FareService.estimate(vehicleName: widget.vehicleName, distanceKm: _distanceKm);

  @override
  void initState() {
    super.initState();
    _speakRideDetails();
  }

  // Function to read ride details using Text-to-Speech. This is already
  // more useful here than a generic page description would be — it's the
  // caller's dynamic destination/fare, not boilerplate — so it's kept as
  // is, just now respecting the voiceEnabled setting (previously ignored
  // it entirely).
  _speakRideDetails() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>().settings;
    if (!settings.voiceEnabled) return;
    String rideTime =
        widget.rideTime == null ? "now" : "on ${DateFormat('EEE, MMM d, h:mm a').format(widget.rideTime!)}";
    final fare = _estimatedFare;
    String fareText = fare != null ? " Estimated fare is ${FareService.formatGhs(fare)}." : "";
    String rideDetails =
        "You have selected a ${widget.vehicleName} from ${widget.location}, scheduled for $rideTime.$fareText";
    await flutterTts.speak(rideDetails);
  }

  // Function to confirm the ride: saves offline-first, then pushes to
  // Firestore immediately only if we're online. This avoids the ride being
  // written twice (once here, once again by SyncService when connectivity
  // returns).
  void _confirmRide() async {
    setState(() => _isConfirming = true);

    // If there's no active Firebase session at all (e.g. the app was
    // reopened after being signed out, or something skipped the login
    // flow), every Firestore write below will fail with a permission
    // error — catch that here with a clear message instead of letting it
    // surface as a confusing generic failure deep in the try/catch below.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isConfirming = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're not signed in — please log in again before booking a ride."),
        ),
      );
      return;
    }

    // Convert DateTime? to String
    String? rideTimeString =
        widget.rideTime == null ? null : DateFormat('EEE, MMM d • h:mm a').format(widget.rideTime!);

    // Anonymous Firebase users never have a displayName, so this used to
    // always write "Passenger" regardless of who actually booked — look
    // up their real first name from the phone-keyed profile instead.
    // Resolved once here (not just in the online branch) so offline-queued
    // rides carry the right name too once SyncService uploads them.
    // Guarded on its own: a failure here (e.g. rules not yet deployed)
    // shouldn't crash the whole booking flow before we even reach the
    // try/catch below — just fall back to a generic label.
    String passengerName = 'Passenger';
    String? myPhone;
    try {
      final prefs = await SharedPreferences.getInstance();
      myPhone = prefs.getString('userPhone');
      final myProfile = myPhone != null ? await UserService.fetchByPhone(myPhone) : null;
      if (myProfile?.firstName != null) passengerName = myProfile!.firstName;
    } catch (e) {
      log('Could not resolve passenger profile, using fallback name: $e');
    }

    // A ride booked more than a few minutes out is a scheduled/future
    // ride rather than an immediate one — surfaced as a distinct status
    // so drivers/admins (and RideStatusBadge in the UI) can tell them apart.
    final isScheduled = widget.rideTime != null &&
        widget.rideTime!.isAfter(DateTime.now().add(const Duration(minutes: 5)));
    // 'Searching' = awaiting a driver to accept; a driver accepting moves
    // it to 'Accepted' (see driver_home_screen.dart).
    final rideStatus = isScheduled ? 'Scheduled' : 'Searching';

    final distanceKm = _distanceKm;
    final estimatedFare = _estimatedFare;

    // A Firestore doc() call generates a unique id locally without writing
    // anything, so we can use it as our single source of truth for this
    // ride across Hive and Firestore.
    final rideId = FirebaseFirestore.instance.collection('rideRequests').doc().id;

    final ride = Ride(
      id: rideId,
      uid: uid,
      vehicleName: widget.vehicleName,
      location: widget.location,
      rideTime: rideTimeString,
      pickupAddress: widget.location,
      dropoffAddress: widget.dropoffLocation ?? widget.location,
      pickupLat: widget.pickupLat,
      pickupLng: widget.pickupLng,
      dropoffLat: widget.dropoffLat,
      dropoffLng: widget.dropoffLng,
      distanceKm: distanceKm,
      estimatedFareGhs: estimatedFare,
      status: rideStatus,
      passengerName: passengerName,
      passengerPhone: myPhone,
    );

    Provider.of<RideProvider>(context, listen: false).addOngoingRide(ride);

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (!isOnline) {
      // No connection: queue it for SyncService to upload later. Do NOT
      // also write to Firestore here.
      await OfflineRideStore().saveRide(ride);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're offline — the ride is saved and will sync automatically once you're back online."),
        ),
      );
      log('[ConfirmRide] booked offline, currentUser before navigating back: ${FirebaseAuth.instance.currentUser?.uid ?? "NULL"}');
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    // Online: write straight to Firestore using the same id (set is
    // idempotent, so even a retry can't create a duplicate document).
    try {
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(rideId)
          .set({
        'id': rideId,
        'uid': uid,
        'vehicleName': widget.vehicleName,
        'location': widget.location,
        'dropoffLocation': widget.dropoffLocation ?? widget.location,
        'rideTime': rideTimeString ?? 'Now',
        'passengerName': passengerName,
        'passengerPhone': myPhone,
        'pickupLat': widget.pickupLat,
        'pickupLng': widget.pickupLng,
        'dropoffLat': widget.dropoffLat,
        'dropoffLng': widget.dropoffLng,
        'distanceKm': distanceKm,
        'estimatedFareGhs': estimatedFare,
        'status': rideStatus,
        'createdAt': Timestamp.fromDate(ride.createdAt),
        'time': rideTimeString ?? 'Now',
      }).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride has been scheduled and saved.')),
      );

      log('[ConfirmRide] booked online, currentUser before navigating back: ${FirebaseAuth.instance.currentUser?.uid ?? "NULL"}');
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      // Log the real error to the console so it's actually diagnosable —
      // the SnackBar below is deliberately shorter/friendlier than this.
      log('Ride confirm failed: $e');

      // Firestore write failed even though we appeared online — fall back
      // to the offline queue so the ride isn't lost.
      await OfflineRideStore().saveRide(ride);
      if (!mounted) return;

      String message;
      if (e is FirebaseException && e.code == 'permission-denied') {
        // By far the most common cause in this project: firestore.rules
        // was edited locally but never redeployed to the Firebase
        // Console, or the session genuinely isn't signed in.
        message = "Couldn't save to the server (permission denied) — the ride is queued locally. "
            "Check that firestore.rules has been deployed and that you're logged in.";
      } else if (e is TimeoutException) {
        message = "Couldn't reach the server in time — the ride is saved locally and will sync automatically.";
      } else {
        message = 'Could not reach the server, ride saved for later sync: $e';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = _distanceKm;
    final fare = _estimatedFare;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Your Ride')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ride Details', style: AppTextStyles.displayLarge),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _rideDetailRow('Vehicle', widget.vehicleName),
                    const Divider(height: 24),
                    _rideDetailRow('Pickup', widget.location),
                    if (widget.dropoffLocation != null) ...[
                      const Divider(height: 24),
                      _rideDetailRow('Drop-off', widget.dropoffLocation!),
                    ],
                    const Divider(height: 24),
                    _rideDetailRow(
                      'Time',
                      widget.rideTime == null ? 'Now' : DateFormat('EEE, MMM d • h:mm a').format(widget.rideTime!),
                    ),
                    if (distanceKm != null) ...[
                      const Divider(height: 24),
                      _rideDetailRow('Distance', '${distanceKm.toStringAsFixed(1)} km'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (fare != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Fare', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      FareService.formatGhs(fare),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Estimate only — flat rate per distance, not live pricing.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "Fare estimate isn't available (missing pickup or drop-off location).",
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Go Back',
                    variant: AppButtonVariant.outlined,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Confirm',
                    isLoading: _isConfirming,
                    onPressed: _isConfirming ? null : _confirmRide,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to display ride details in rows
  Widget _rideDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
