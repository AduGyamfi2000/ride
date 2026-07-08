import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../providers/ride_provider.dart';
import '../services/offline_sync_service.dart';

class ConfirmRideScreen extends StatefulWidget {
  final String vehicleName;
  final String location;
  final DateTime? rideTime;

  const ConfirmRideScreen({
    super.key,
    required this.vehicleName,
    required this.location,
    this.rideTime,
  });

  @override
  ConfirmRideScreenState createState() => ConfirmRideScreenState();
}

class ConfirmRideScreenState extends State<ConfirmRideScreen> {
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speakRideDetails();
  }

  // Function to read ride details using Text-to-Speech
  _speakRideDetails() async {
    String rideTime =
        widget.rideTime == null ? "now" : "on ${widget.rideTime?.toString()}";
    String rideDetails =
        "You have selected a ${widget.vehicleName} from ${widget.location}, scheduled for $rideTime.";
    await flutterTts.speak(rideDetails);
  }

  // Function to confirm the ride and save the details in both Firestore and the RideProvider
  void _confirmRide() async {
    // Convert DateTime? to String
    String? rideTimeString = widget.rideTime?.toString();

    final ride = Ride(
      vehicleName: widget.vehicleName,
      location: widget.location,
      rideTime: rideTimeString,
      pickupAddress: widget.location,
      dropoffAddress: widget.location,
    );

    Provider.of<RideProvider>(context, listen: false).addRide(
      widget.vehicleName,
      widget.location,
      rideTimeString,
    );

    await OfflineRideStore().saveRide(ride);

    // Save ride details to Firestore
    try {
      await FirebaseFirestore.instance.collection('rideRequests').add({
        'vehicleName': widget.vehicleName,
        'location': widget.location,
        'rideTime': rideTimeString ?? 'Now',
        'passengerName': 'Passenger',
        'status': 'Confirmed',
        'createdAt': Timestamp.now(),
        'time': rideTimeString ?? 'Now',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride has been scheduled and saved.')),
      );

      // Navigate back to the home screen
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      // Handle errors in saving to Firestore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving ride: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Your Ride'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Ride Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _rideDetailRow('Vehicle', widget.vehicleName),
            const SizedBox(height: 10),
            _rideDetailRow('Location', widget.location),
            const SizedBox(height: 10),
            _rideDetailRow(
              'Time',
              widget.rideTime == null ? 'Now' : widget.rideTime.toString(),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _confirmRide, // Confirm ride action
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Display Ongoing Rides section
            const Text(
              'Ongoing Rides',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<RideProvider>(
                builder: (context, rideProvider, child) {
                  return rideProvider.ongoingRides.isEmpty
                      ? const Center(
                          child: Text('No ongoing rides.'),
                        )
                      : ListView.builder(
                          itemCount: rideProvider.ongoingRides.length,
                          itemBuilder: (context, index) {
                            final ride = rideProvider.ongoingRides[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                    '${ride.vehicleName} from ${ride.location}'),
                                subtitle: Text(
                                  'Time: ${ride.rideTime ?? 'Now'}',
                                ),
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

  // Helper function to display ride details in rows
  Widget _rideDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
