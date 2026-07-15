import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ride_status_badge.dart';

class TrackRideScreen extends StatefulWidget {
  final String rideId;

  const TrackRideScreen({super.key, required this.rideId});

  @override
  State<TrackRideScreen> createState() => _TrackRideScreenState();
}

class _TrackRideScreenState extends State<TrackRideScreen> {
  GoogleMapController? _mapController;
  bool _hasFitBounds = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>().settings;
      VoiceGuideService().describePage(
        pageKey: 'track_ride',
        language: settings.language,
        voiceEnabled: settings.voiceEnabled,
      );
    });
  }

  String _distanceLabel(double meters) =>
      meters < 1000 ? '${meters.round()} m away' : '${(meters / 1000).toStringAsFixed(1)} km away';

  String _lastUpdatedLabel(Timestamp? ts) {
    if (ts == null) return '';
    final seconds = DateTime.now().difference(ts.toDate()).inSeconds;
    if (seconds < 60) return 'Updated ${seconds}s ago';
    return 'Updated ${(seconds / 60).floor()}m ago';
  }

  void _fitBounds(LatLng pickup, LatLng driver) {
    if (_mapController == null || _hasFitBounds) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        pickup.latitude < driver.latitude ? pickup.latitude : driver.latitude,
        pickup.longitude < driver.longitude ? pickup.longitude : driver.longitude,
      ),
      northeast: LatLng(
        pickup.latitude > driver.latitude ? pickup.latitude : driver.latitude,
        pickup.longitude > driver.longitude ? pickup.longitude : driver.longitude,
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    _hasFitBounds = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Your Ride')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rideRequests').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  "Couldn't load this ride: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'Searching';
          final driverName = data['driverName'] as String?;
          final driverLat = (data['driverLat'] as num?)?.toDouble();
          final driverLng = (data['driverLng'] as num?)?.toDouble();
          final pickupLat = (data['pickupLat'] as num?)?.toDouble();
          final pickupLng = (data['pickupLng'] as num?)?.toDouble();
          final lastUpdated = data['driverLocationUpdatedAt'] as Timestamp?;

          final hasDriverLocation = driverLat != null && driverLng != null;
          final hasPickup = pickupLat != null && pickupLng != null;

          double? distanceMeters;
          if (hasDriverLocation && hasPickup) {
            distanceMeters = Geolocator.distanceBetween(driverLat, driverLng, pickupLat, pickupLng);
          }

          final markers = <Marker>{
            if (hasPickup)
              Marker(
                markerId: const MarkerId('pickup'),
                position: LatLng(pickupLat, pickupLng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: 'Pickup point'),
              ),
            if (hasDriverLocation)
              Marker(
                markerId: const MarkerId('driver'),
                position: LatLng(driverLat, driverLng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: InfoWindow(title: driverName ?? 'Your driver'),
              ),
          };

          if (hasDriverLocation && hasPickup) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitBounds(LatLng(pickupLat, pickupLng), LatLng(driverLat, driverLng));
            });
          }

          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: hasPickup
                        ? LatLng(pickupLat, pickupLng)
                        : (hasDriverLocation ? LatLng(driverLat, driverLng) : const LatLng(5.6037, -0.1870)),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: markers,
                  myLocationButtonEnabled: false,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RideStatusBadge(status: status),
                        const SizedBox(width: 10),
                        if (driverName != null)
                          Expanded(
                            child: Text(
                              driverName,
                              style: AppTextStyles.headlineMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (status == 'Completed')
                      const Text('This ride has been completed.', style: AppTextStyles.bodyMedium)
                    else if (status == 'Cancelled')
                      const Text('This ride was cancelled.', style: AppTextStyles.bodyMedium)
                    else if (!hasDriverLocation)
                      const Text('Waiting for your driver to start sharing location…', style: AppTextStyles.bodyMedium)
                    else ...[
                      if (distanceMeters != null)
                        Text(
                          'Driver is ${_distanceLabel(distanceMeters)} from your pickup point',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.info),
                        ),
                      if (lastUpdated != null)
                        Text(_lastUpdatedLabel(lastUpdated), style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
