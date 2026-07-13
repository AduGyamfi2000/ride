import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
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

  // Two-step flow: pickup first, then drop-off — a real destination is
  // needed to compute trip distance/fare, which the app didn't capture
  // before (dropoff used to just silently equal pickup).
  bool _selectingDropoff = false;

  LatLng? _pickupLocation;
  String _pickupAddress = 'Tap on the map to choose a pickup point';
  LatLng? _dropoffLocation;
  String _dropoffAddress = 'Tap on the map to choose a drop-off point';

  final PlacesService _placesService = PlacesService();
  bool _gpsAvailable = false;
  bool _loadingPlaces = false;
  List<NearbyPlace> _nearbyPlaces = [];
  String _selectedCategory = 'All';

  static const Map<String, IconData> _categoryIcons = {
    'Market': Icons.storefront,
    'Hospital': Icons.local_hospital,
    'School': Icons.school,
    'Bank': Icons.account_balance,
  };

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
    if (!mounted) return;
    setState(() {
      _pickupLocation = LatLng(position.latitude, position.longitude);
      _gpsAvailable = true;
    });
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_pickupLocation!));
    }
    _loadNearbyPlaces(position.latitude, position.longitude);
  }

  Future<void> _loadNearbyPlaces(double lat, double lng) async {
    setState(() => _loadingPlaces = true);
    final places = await _placesService.searchAllCategories(latitude: lat, longitude: lng);
    if (!mounted) return;
    setState(() {
      _nearbyPlaces = places;
      _loadingPlaces = false;
    });
  }

  List<NearbyPlace> get _filteredPlaces => _selectedCategory == 'All'
      ? _nearbyPlaces
      : _nearbyPlaces.where((p) => p.category == _selectedCategory).toList();

  Future<void> _updateAddress(LatLng latLng) async {
    final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
    if (placemarks.isEmpty) return;
    final place = placemarks.first;
    final address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'.trim();
    setState(() {
      if (_selectingDropoff) {
        _dropoffAddress = address;
      } else {
        _pickupAddress = address;
      }
    });
  }

  void _onMapTapped(LatLng latLng) {
    setState(() {
      if (_selectingDropoff) {
        _dropoffLocation = latLng;
      } else {
        _pickupLocation = latLng;
      }
    });
    _updateAddress(latLng);
  }

  void _selectPlace(NearbyPlace place) {
    final latLng = LatLng(place.latitude, place.longitude);
    final label = place.address != null && place.address!.isNotEmpty
        ? '${place.name}, ${place.address}'
        : place.name;
    setState(() {
      if (_selectingDropoff) {
        _dropoffLocation = latLng;
        _dropoffAddress = label;
      } else {
        _pickupLocation = latLng;
        _pickupAddress = label;
      }
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
  }

  void _onContinuePressed() {
    if (!_selectingDropoff) {
      if (_pickupLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a pickup location first.')),
        );
        return;
      }
      setState(() => _selectingDropoff = true);
      return;
    }

    if (_dropoffLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a drop-off location.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectTimeScreen(
          selectedLocation: _pickupAddress,
          selectedVehicle: widget.vehicleName,
          pickupLat: _pickupLocation!.latitude,
          pickupLng: _pickupLocation!.longitude,
          dropoffLocation: _dropoffAddress,
          dropoffLat: _dropoffLocation!.latitude,
          dropoffLng: _dropoffLocation!.longitude,
        ),
      ),
    );
  }

  void _backToPickup() {
    setState(() => _selectingDropoff = false);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_pickupLocation != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (_dropoffLocation != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          infoWindow: const InfoWindow(title: 'Drop-off'),
        ),
      ..._nearbyPlaces.map(
        (p) => Marker(
          markerId: MarkerId('${p.category}-${p.name}-${p.latitude}'),
          position: LatLng(p.latitude, p.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: p.name, snippet: p.category),
          onTap: () => _selectPlace(p),
        ),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectingDropoff ? 'Choose Drop-off Location' : 'Choose Pickup Location'),
        leading: _selectingDropoff
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _backToPickup)
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: 14),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTapped,
              myLocationEnabled: true,
              markers: markers,
            ),
          ),
          _buildNearbyPlacesSection(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pickup', style: AppTextStyles.caption),
                Text(_pickupAddress, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (_selectingDropoff) ...[
                  const SizedBox(height: 8),
                  const Text('Drop-off', style: AppTextStyles.caption),
                  Text(_dropoffAddress, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                AppButton(
                  label: _selectingDropoff ? 'Continue' : 'Next: Choose Drop-off',
                  icon: Icons.arrow_forward,
                  onPressed: _onContinuePressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPlacesSection() {
    if (!_gpsAvailable) {
      return Container(
        width: double.infinity,
        color: AppColors.surfaceVariant,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: const Row(
          children: [
            Icon(Icons.location_off_outlined, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Turn on location to see nearby markets, hospitals, schools, and banks.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _categoryChip('All'),
                ..._categoryIcons.keys.map(_categoryChip),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: _loadingPlaces
                ? const Center(child: CircularProgressIndicator())
                : _filteredPlaces.isEmpty
                    ? const Center(
                        child: Text('No nearby places found.', style: AppTextStyles.bodyMedium),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filteredPlaces.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final place = _filteredPlaces[index];
                          return _NearbyPlaceCard(
                            place: place,
                            icon: _categoryIcons[place.category] ?? Icons.place,
                            onTap: () => _selectPlace(place),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String category) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(category),
        selected: selected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (_) => setState(() => _selectedCategory = category),
      ),
    );
  }
}

class _NearbyPlaceCard extends StatelessWidget {
  final NearbyPlace place;
  final IconData icon;
  final VoidCallback onTap;

  const _NearbyPlaceCard({required this.place, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text(place.category, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const Spacer(),
            Text(place.distanceLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
