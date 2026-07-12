import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

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

  @override
  void initState() {
    super.initState();
    // Listen for new ride orders
    _listenForRideOrders();
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
    FirebaseFirestore.instance
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
    });
  }

  // Notify the driver of a new ride order
  void _notifyDriver(Map<String, dynamic> rideData) async {
    final passengerName = rideData['passengerName'] ?? 'a passenger';
    final location = rideData['location'] ?? 'your selected location';
    String message =
        "New ride request from $passengerName at $location";
    _stopSpeaking(); // Stop any ongoing speech
    await flutterTts.speak(message); // Speak the ride request
    setState(() {
      _isSpeaking = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Home'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Driver',
              style: TextStyle(fontSize: settingsProvider.settings.textSize),
            ),
            const SizedBox(height: 20),
            Text(
              'You will receive notifications about ride orders here.',
              style: TextStyle(fontSize: settingsProvider.settings.textSize),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('rideRequests')
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rides = snapshot.data!.docs;
                  if (rides.isEmpty) {
                    return const Center(
                      child: Text('No ride requests yet.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      var ride = rides[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(
                          "Ride from ${ride['passengerName']}",
                          style: TextStyle(
                              fontSize: settingsProvider.settings.textSize),
                        ),
                        subtitle: Text(
                          "Location: ${ride['location'] ?? 'Unknown'}, Time: ${ride['time'] ?? ride['rideTime'] ?? 'Now'}",
                          style: TextStyle(
                              fontSize: settingsProvider.settings.textSize),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
