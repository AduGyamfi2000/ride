import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/ride_status_badge.dart';
import '../widgets/section_header.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  // Only announce rides created after this screen opened, so re-opening
  // the screen (or any unrelated Firestore change) doesn't replay every
  // historical ride request through TTS.
  final DateTime _listenerStartTime = DateTime.now();

  String? _myPhone;
  String _myName = 'Driver';

  StreamSubscription<QuerySnapshot>? _rideOrdersSub;
  StreamSubscription<QuerySnapshot>? _acceptedRidesSub;
  StreamSubscription<Position>? _positionSub;
  List<String> _acceptedRideIds = [];

  @override
  void initState() {
    super.initState();
    _loadMyProfile().then((_) => _watchAcceptedRides());
    _listenForRideOrders();
  }

  @override
  void dispose() {
    _rideOrdersSub?.cancel();
    _acceptedRidesSub?.cancel();
    _positionSub?.cancel();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone');
    if (phone == null) return;
    _myPhone = phone; // set even if the profile fetch below fails, so
    // _watchAcceptedRides() (which only needs the phone, not the name)
    // still works.
    try {
      final profile = await UserService.fetchByPhone(phone);
      if (!mounted) return;
      setState(() => _myName = profile?.fullName ?? 'Driver');
    } catch (e) {
      // Non-critical for accepting/completing rides — just keep the
      // 'Driver' fallback name rather than surfacing an error for this.
    }
  }

  /// Watches this driver's currently-accepted rides and starts/stops
  /// broadcasting live location accordingly — only while at least one
  /// accepted ride is in progress, so we're not burning battery/writes
  /// for a driver who isn't actively on a trip.
  void _watchAcceptedRides() {
    if (_myPhone == null) return;
    _acceptedRidesSub = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('driverPhone', isEqualTo: _myPhone)
        .where('status', isEqualTo: 'Accepted')
        .snapshots()
        .listen((snapshot) {
      _acceptedRideIds = snapshot.docs.map((d) => d.id).toList();
      if (_acceptedRideIds.isNotEmpty && _positionSub == null) {
        _startBroadcastingLocation();
      } else if (_acceptedRideIds.isEmpty) {
        _stopBroadcastingLocation();
      }
    }, onError: (e) {
      // This query needs a composite index (driverPhone + status) —
      // see firestore.indexes.json. Without it deployed, this fails
      // silently with no onError handler; logging it here at least makes
      // the failure visible in the console instead of "nothing happens".
      log('Accepted-rides listener failed (check firestore.indexes.json is deployed): $e');
    });
  }

  void _startBroadcastingLocation() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Only emit (and write to Firestore) once the driver has moved
        // ~25m, instead of on every GPS tick — keeps writes and battery
        // use reasonable.
        distanceFilter: 25,
      ),
    ).listen((position) {
      for (final rideId in _acceptedRideIds) {
        FirebaseFirestore.instance.collection('rideRequests').doc(rideId).update({
          'driverLat': position.latitude,
          'driverLng': position.longitude,
          'driverLocationUpdatedAt': Timestamp.now(),
        });
      }
    });
  }

  void _stopBroadcastingLocation() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  // Stop any ongoing speech
  void _stopSpeaking() async {
    if (_isSpeaking) {
      await flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  // Listen for ride requests from Firestore
  void _listenForRideOrders() {
    _rideOrdersSub = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(_listenerStartTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // Only announce documents that were just added — otherwise every
        // unrelated Firestore change re-reads and re-speaks the whole
        // result set.
        if (change.type == DocumentChangeType.added) {
          var rideData = change.doc.data();
          if (rideData != null) {
            _notifyDriver(rideData); // Notify driver with TTS
          }
        }
      }
    }, onError: (e) {
      log('Ride-orders listener failed: $e');
    });
  }

  // Notify the driver of a new ride order
  void _notifyDriver(Map<String, dynamic> rideData) async {
    final passengerName = rideData['passengerName'] ?? 'a passenger';
    final location = rideData['location'] ?? 'your selected location';
    String message = "New ride request from $passengerName at $location";
    _stopSpeaking(); // Stop any ongoing speech
    await flutterTts.speak(message); // Speak the ride request
    setState(() {
      _isSpeaking = true;
    });
  }

  /// Accepts a ride inside a transaction so two drivers tapping "Accept"
  /// at the same moment can't both end up assigned to the same ride —
  /// whichever transaction commits first wins; the second sees the
  /// updated status and is told the ride was already taken.
  Future<void> _acceptRide(String rideId) async {
    if (_myPhone == null) return;
    final docRef = FirebaseFirestore.instance.collection('rideRequests').doc(rideId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data();
        if (data == null) return;
        final currentStatus = data['status'] as String?;
        if (currentStatus != 'Searching' && currentStatus != 'Scheduled') {
          throw Exception('already-taken');
        }
        tx.update(docRef, {
          'status': 'Accepted',
          'driverPhone': _myPhone,
          'driverName': _myName,
        });
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride accepted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This ride was just taken by another driver.')),
      );
    }
  }

  Future<void> _completeRide(String rideId) async {
    await FirebaseFirestore.instance.collection('rideRequests').doc(rideId).update({
      'status': 'Completed',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride marked as completed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return GestureDetector(
      onTap: _stopSpeaking,
      child: Scaffold(
        appBar: AppBar(title: const Text('Driver Home')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $_myName',
                style: TextStyle(fontSize: settingsProvider.settings.textSize, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'New requests and rides you have accepted appear below.',
                style: TextStyle(fontSize: settingsProvider.settings.textSize - 2, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('rideRequests').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "Couldn't load ride requests: ${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allRides = snapshot.data!.docs;

                    final newRequests = allRides.where((d) {
                      final status = (d.data() as Map<String, dynamic>)['status'];
                      return status == 'Searching' || status == 'Scheduled';
                    }).toList();

                    final myRides = allRides.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['status'] == 'Accepted' && data['driverPhone'] == _myPhone;
                    }).toList();

                    if (newRequests.isEmpty && myRides.isEmpty) {
                      return const Center(child: Text('No ride requests yet.'));
                    }

                    return ListView(
                      children: [
                        if (myRides.isNotEmpty) ...[
                          const SectionHeader(title: 'My Accepted Rides'),
                          const SizedBox(height: 8),
                          ...myRides.map((d) => _RideCard(
                                data: d.data() as Map<String, dynamic>,
                                textSize: settingsProvider.settings.textSize,
                                trailing: AppButton(
                                  label: 'Complete',
                                  isLarge: false,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () => _completeRide(d.id),
                                ),
                              )),
                          const SizedBox(height: 20),
                        ],
                        SectionHeader(title: 'New Requests (${newRequests.length})'),
                        const SizedBox(height: 8),
                        if (newRequests.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('No open requests right now.', style: AppTextStyles.bodyMedium),
                          )
                        else
                          ...newRequests.map((d) => _RideCard(
                                data: d.data() as Map<String, dynamic>,
                                textSize: settingsProvider.settings.textSize,
                                trailing: AppButton(
                                  label: 'Accept',
                                  isLarge: false,
                                  onPressed: () => _acceptRide(d.id),
                                ),
                              )),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final double textSize;
  final Widget trailing;

  const _RideCard({required this.data, required this.textSize, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "${data['passengerName'] ?? 'Passenger'}",
                        style: TextStyle(fontSize: textSize, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      RideStatusBadge(status: data['status'] as String? ?? 'Searching'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${data['vehicleName'] ?? ''} • ${data['location'] ?? 'Unknown'}",
                    style: TextStyle(fontSize: textSize - 2, color: AppColors.textSecondary),
                  ),
                  Text(
                    "Time: ${data['time'] ?? data['rideTime'] ?? 'Now'}",
                    style: TextStyle(fontSize: textSize - 2, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
