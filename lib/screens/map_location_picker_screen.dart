import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'select_time_screen.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final String vehicleName;

  const MapLocationPickerScreen({super.key, required this.vehicleName});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(5.6037, -0.1870);
  LatLng? _selectedLocation;
  String _selectedAddress = 'Tap on the map to choose a pickup point';

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
    });
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_selectedLocation!));
    }
  }

  Future<void> _updateAddress(LatLng latLng) async {
    final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      setState(() {
        _selectedAddress = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'.trim();
      });
    }
  }

  void _onMapTapped(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
    });
    _updateAddress(latLng);
  }

  void _continueToTimeSelection() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a pickup location first.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectTimeScreen(
          selectedLocation: _selectedAddress,
          selectedVehicle: widget.vehicleName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Pickup Location'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: 14),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTapped,
              myLocationEnabled: true,
              markers: _selectedLocation == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: _selectedLocation!,
                      ),
                    },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected pickup', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_selectedAddress),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _continueToTimeSelection,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
