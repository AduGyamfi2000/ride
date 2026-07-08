import 'package:flutter/material.dart';
import 'confirm_ride_screen.dart'; // Import the ConfirmRideScreen

class SelectTimeScreen extends StatefulWidget {
  final String selectedLocation;
  final String selectedVehicle;

  const SelectTimeScreen({
    super.key,
    required this.selectedLocation,
    required this.selectedVehicle,
  });

  @override
  SelectTimeScreenState createState() => SelectTimeScreenState();
}

class SelectTimeScreenState extends State<SelectTimeScreen> {
  TimeOfDay? selectedTime; // Holds the selected time

  // Method to pick the time using time picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null && pickedTime != selectedTime) {
      setState(() {
        selectedTime = pickedTime; // Update the selected time
      });
    }
  }

  // Method to select the current time ("Now")
  void _selectNow() {
    setState(() {
      selectedTime = TimeOfDay.now(); // Set current time as the selected time
    });
  }

  // Method to confirm time and navigate to ConfirmRideScreen
  void _confirmTime() {
    if (selectedTime != null) {
      final DateTime now = DateTime.now();
      final DateTime selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      // Navigate to the ConfirmRideScreen and pass the selected values
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmRideScreen(
            vehicleName: widget.selectedVehicle,
            location: widget.selectedLocation,
            rideTime: selectedDateTime, // Pass the selected time
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Time'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Selected Location: ${widget.selectedLocation}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _selectTime(context), // Open time picker
              child: const Text('Choose Time'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _selectNow, // Set the current time as "Now"
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Different color for "Now"
              ),
              child: const Text('Now'),
            ),
            const SizedBox(height: 20),
            if (selectedTime != null)
              Text(
                'Selected Time: ${selectedTime!.format(context)}',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed:
                  _confirmTime, // Confirm time and navigate to confirm ride screen
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Confirm Time'),
            ),
          ],
        ),
      ),
    );
  }
}
