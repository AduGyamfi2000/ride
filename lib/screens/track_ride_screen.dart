import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../services/user_service.dart';
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
  String? _cachedDriverPhone;
  double? _driverRating;
  double? _lastDriverLat;
  double? _lastDriverLng;

  Future<void> _maybeLoadDriverRating(String? driverPhone) async {
    if (driverPhone == null || driverPhone == _cachedDriverPhone) return;
    _cachedDriverPhone = driverPhone;
    try {
      final profile = await UserService.fetchByPhone(driverPhone);
      if (!mounted) return;
      setState(() => _driverRating = profile?.averageRating);
    } catch (_) {
      // Non-critical — just skip showing a rating.
    }
  }

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

  // Ghana's general emergency number. Change this if deploying elsewhere,
  // or make it configurable per-user later.
  static const String _emergencyNumber = '112';

  Future<void> _callEmergencyServices() async {
    final uri = Uri(scheme: 'tel', path: _emergencyNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer on this device.')),
      );
    }
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer on this device.')),
      );
    }
  }

  Future<void> _shareLocationViaSms() async {
    final lat = _lastDriverLat;
    final lng = _lastDriverLng;
    final body = lat != null && lng != null
        ? 'I need help. My driver\'s last known location: https://maps.google.com/?q=$lat,$lng'
        : "I need help during my ride, but the driver's live location isn't available yet.";
    final uri = Uri(scheme: 'sms', queryParameters: {'body': body});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open messaging on this device.')),
      );
    }
  }

  void _showSosSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_police, color: AppColors.error),
              title: const Text('Call Emergency Services ($_emergencyNumber)'),
              onTap: () {
                Navigator.pop(context);
                _callEmergencyServices();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_location, color: AppColors.error),
              title: const Text('Share My Location'),
              subtitle: const Text('Opens a text message with a map link, for you to send to anyone you choose.'),
              onTap: () {
                Navigator.pop(context);
                _shareLocationViaSms();
              },
            ),
          ],
        ),
      ),
    );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSosSheet,
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.sos, color: Colors.white),
        label: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
          final driverPhone = data['driverPhone'] as String?;
          final driverLat = (data['driverLat'] as num?)?.toDouble();
          final driverLng = (data['driverLng'] as num?)?.toDouble();
          final pickupLat = (data['pickupLat'] as num?)?.toDouble();
          final pickupLng = (data['pickupLng'] as num?)?.toDouble();
          final lastUpdated = data['driverLocationUpdatedAt'] as Timestamp?;

          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadDriverRating(driverPhone));
          if (driverLat != null && driverLng != null) {
            _lastDriverLat = driverLat;
            _lastDriverLng = driverLng;
          }

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
                        if (_driverRating != null) ...[
                          const Icon(Icons.star, color: AppColors.primary, size: 16),
                          const SizedBox(width: 2),
                          Text(_driverRating!.toStringAsFixed(1), style: AppTextStyles.bodyMedium),
                        ],
                        if (driverPhone != null && status != 'Completed' && status != 'Cancelled') ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.call, color: AppColors.success),
                            tooltip: 'Call driver',
                            onPressed: () => _callNumber(driverPhone),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (status == 'Completed')
                      const Text('This ride has been completed.', style: AppTextStyles.bodyMedium)
                    else if (status == 'Cancelled')
                      const Text('This ride was cancelled.', style: AppTextStyles.bodyMedium)
                    else if (status == 'arrived')
                      const Text(
                        'Your driver has arrived at the pickup point!',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
                      )
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
