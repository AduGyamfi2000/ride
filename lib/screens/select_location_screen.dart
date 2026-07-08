import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'select_time_screen.dart';

class SelectLocationScreen extends StatefulWidget {
  final String vehicleName;

  const SelectLocationScreen({super.key, required this.vehicleName});

  @override
  SelectLocationScreenState createState() => SelectLocationScreenState();
}

class SelectLocationScreenState extends State<SelectLocationScreen> {
  FlutterTts flutterTts = FlutterTts();
  String? selectedLocation;

  // Function to speak the selected location
  _speak(String text) async {
    await flutterTts.speak(text);
  }

  // Function to confirm location selection
  void _confirmLocationSelection() {
    // Navigate to the time selection screen with selected location and vehicle
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectTimeScreen(
          selectedLocation: selectedLocation!,
          selectedVehicle: widget.vehicleName, // Pass the vehicle name
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _locationOption("Market Junction"),
          _locationOption("Airport"),
          _locationOption("City Center"),
          _locationOption("Train Station"),
        ],
      ),
    );
  }

  // Widget for each location option
  Widget _locationOption(String locationName) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLocation = locationName;
        });
        _speak("You have selected $locationName");
        _confirmLocationSelection(); // Confirm location selection and navigate
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          locationName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
