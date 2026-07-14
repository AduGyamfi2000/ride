import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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

  // Widget for each vehicle option, framed as a proper card matching the
  // rest of the app's card styling (previously a bare transparent
  // container with no border/shadow, which read as unfinished/inconsistent
  // next to every other screen's Card-based layout).
  Widget _vehicleOption(String vehicleName, String imagePath) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _speak("You have selected $vehicleName");
          _navigateToLocationPage(vehicleName); // Navigate to location page
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(imagePath, height: 76),
              const SizedBox(height: 12),
              Text(
                vehicleName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
