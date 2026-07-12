import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'map_location_picker_screen.dart';

class VehicleSelectionScreen extends StatefulWidget {
  const VehicleSelectionScreen({super.key});

  @override
  VehicleSelectionScreenState createState() => VehicleSelectionScreenState();
}

class VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  FlutterTts flutterTts = FlutterTts();

  // Function to play voice instruction
  _speak(String text) async {
    await flutterTts.speak(text);
  }

  // Function to navigate to the select location page
  void _navigateToLocationPage(String vehicleName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(vehicleName: vehicleName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Vehicle Type'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: <Widget>[
            _vehicleOption('Tricycle', 'assets/images/pragya.png'),
            _vehicleOption('Taxi', 'assets/images/taxi.png'),
            _vehicleOption('Bus', 'assets/images/aboboyaa.png'),
            _vehicleOption('Motorcycle', 'assets/images/motorcycle.png'),
          ],
        ),
      ),
    );
  }

  // Widget for each vehicle option
  Widget _vehicleOption(String vehicleName, String imagePath) {
    return GestureDetector(
      onTap: () {
        _speak("You have selected $vehicleName");
        _navigateToLocationPage(vehicleName); // Navigate to location page
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          // You can set a default color if needed, or leave it transparent
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 80),
            const SizedBox(height: 10),
            Text(
              vehicleName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Changed to black for visibility
              ),
            ),
          ],
        ),
      ),
    );
  }
}
