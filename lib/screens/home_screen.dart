import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride_model.dart';
import '../providers/ride_provider.dart';
import '../providers/settings_provider.dart';
import '../services/offline_sync_service.dart';
import '../services/fare_service.dart';
import '../services/rating_service.dart';
import '../services/user_service.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/ride_status_badge.dart';
import '../widgets/section_header.dart';
import 'setting_screen.dart';
import 'track_ride_screen.dart';
import 'vehicle_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isOngoingExpanded = false;
  bool _isHistoryExpanded = false;
  bool _isOffline = false;
  int _pendingRideCount = 0;
  String? _myFirstName;

  @override
  void initState() {
    super.initState();
    _introduceTabs(); // Automatically play the introduction on Home tab load
    _checkConnectivity();
    _loadMyName();
  }

  Future<void> _loadMyName() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone');
    if (phone == null) return;
    try {
      final profile = await UserService.fetchByPhone(phone);
      if (!mounted || profile == null) return;
      setState(() => _myFirstName = profile.firstName);
    } catch (e) {
      // Non-critical — the generic "Welcome to Smart Rural Ride" greeting
      // is a fine fallback, so just skip showing a name rather than
      // surfacing an error for something this minor.
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final pending = await OfflineRideStore().pendingCount();
    if (!mounted) return;
    setState(() {
      _isOffline = result == ConnectivityResult.none;
      _pendingRideCount = pending;
    });
  }

  // Stop speaking if TTS is ongoing
  void _stopSpeaking() async {
    if (_isSpeaking) {
      await VoiceGuideService().stop();
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  // Introduce the Home page on load
  void _introduceTabs() async {
    _stopSpeaking(); // Stop any ongoing TTS
    final settings = context.read<SettingsProvider>().settings;
    await VoiceGuideService().describePage(
      pageKey: 'home',
      language: settings.language,
      voiceEnabled: settings.voiceEnabled,
    );
    setState(() {
      _isSpeaking = true;
    });
  }

  // Speak the name of the selected tab
  void _speakTab(String tabName) async {
    _stopSpeaking(); // Stop any ongoing TTS
    final settings = context.read<SettingsProvider>().settings;
    if (!settings.voiceEnabled) return;
    await flutterTts.speak("You're now in the $tabName.");
    setState(() {
      _isSpeaking = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return GestureDetector(
      onTap: _stopSpeaking,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Smart Rural Ride'),
        ),
        body: Column(
          children: [
            if (_isOffline) OfflineBanner(pendingCount: _pendingRideCount),
            Expanded(
              child: _currentIndex == 0
                  ? _buildHomeTab(rideProvider, settingsProvider)
                  : _buildSettingsTab(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.car_rental),
              label: 'Order Ride',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VehicleSelectionScreen()),
                ).then((_) => _checkConnectivity());
              } else {
                _currentIndex = index;
                if (index == 0) {
                  _introduceTabs();
                  _checkConnectivity();
                } else if (index == 2) {
                  _speakTab('Settings');
                }
              }
            });
          },
        ),
      ),
    );
  }

  // Build the Home tab content
  Widget _buildHomeTab(
      RideProvider rideProvider, SettingsProvider settingsProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _myFirstName != null ? 'Welcome, $_myFirstName 👋' : 'Welcome to Smart Rural Ride',
                    style: TextStyle(
                      fontSize: settingsProvider.settings.textSize + 2,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book a ride quickly, track it live, and keep your journey simple with voice help.',
                    style: TextStyle(
                        fontSize: settingsProvider.settings.textSize,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Selected Language: ${settingsProvider.settings.language}',
            style: TextStyle(fontSize: settingsProvider.settings.textSize),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Ongoing Rides'),
          SwitchListTile(
            activeThumbColor: AppColors.primary,
            title: Text(
              "View Ongoing Rides",
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: settingsProvider.settings.textSize),
            ),
            subtitle: Text(
              "Tap to view rides that are in progress.",
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: settingsProvider.settings.textSize),
            ),
            value: _isOngoingExpanded,
            onChanged: (value) {
              setState(() {
                _isOngoingExpanded = value;
              });
            },
          ),
          if (_isOngoingExpanded && rideProvider.ongoingRides.isNotEmpty) ...[
            ...rideProvider.ongoingRides.map(
              (ride) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildOngoingRideTile(ride, rideProvider, settingsProvider),
              ),
            ),
          ] else if (_isOngoingExpanded) ...[
            const Center(
              child: Text("No ongoing rides.", style: TextStyle(color: AppColors.textHint)),
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'Ride History'),
          SwitchListTile(
            activeThumbColor: AppColors.info,
            title: Text(
              "View Ride History",
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: settingsProvider.settings.textSize),
            ),
            subtitle: Text(
              "Tap to view your past rides.",
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: settingsProvider.settings.textSize),
            ),
            value: _isHistoryExpanded,
            onChanged: (value) {
              setState(() {
                _isHistoryExpanded = value;
              });
            },
          ),
          if (_isHistoryExpanded && rideProvider.rideHistory.isNotEmpty) ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rideProvider.rideHistory.length,
              itemBuilder: (context, index) {
                final ride = rideProvider.rideHistory[index];
                return Dismissible(
                  key: Key(ride.id ?? '${ride.vehicleName}-$index'),
                  background: Container(color: AppColors.error),
                  onDismissed: (direction) {
                    rideProvider.deleteRideFromHistory(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ride deleted.')),
                    );
                  },
                  child: ListTile(
                    title: Text("${ride.vehicleName} - ${ride.location}",
                        style: TextStyle(fontSize: settingsProvider.settings.textSize)),
                    subtitle: Text(
                        "Time: ${ride.rideTime?.toString() ?? 'Now'}",
                        style: TextStyle(fontSize: settingsProvider.settings.textSize)),
                    leading: RideStatusBadge(status: ride.status),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => rideProvider.deleteRideFromHistory(index),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Reset Ride History',
              onPressed: () => _confirmResetHistory(rideProvider),
              variant: AppButtonVariant.danger,
              isLarge: false,
            ),
          ] else if (_isHistoryExpanded) ...[
            const Center(
              child: Text("No ride history available."),
            ),
          ],
        ],
      ),
    );
  }

  // Shows one ongoing ride's live status/driver info, streamed straight
  // from Firestore when we have a ride id (created while online, or
  // already synced from the offline queue). Falls back to the static
  // locally-held ride if there's no id yet (e.g. just booked offline).
  Widget _buildOngoingRideTile(Ride localRide, RideProvider rideProvider, SettingsProvider settingsProvider) {
    if (localRide.id == null) {
      return ListTile(
        title: Text("${localRide.vehicleName} - ${localRide.location}",
            style: TextStyle(fontSize: settingsProvider.settings.textSize)),
        subtitle: Text("Time: ${localRide.rideTime ?? 'Now'} (syncing...)",
            style: TextStyle(fontSize: settingsProvider.settings.textSize)),
        leading: RideStatusBadge(status: localRide.status),
        trailing: IconButton(
          icon: const Icon(Icons.cancel, color: AppColors.error),
          onPressed: () => _showCancelConfirmationDialog(localRide, rideProvider),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rideRequests').doc(localRide.id).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final status = data?['status'] as String? ?? localRide.status;
        final driverName = data?['driverName'] as String?;
        final driverPhone = data?['driverPhone'] as String?;
        final hasBeenRated = data?['driverRating'] != null;

        // Once a ride is completed, it belongs in history, not the
        // ongoing list — move it over (once) and prompt for a rating if
        // there was a driver and it hasn't been rated yet.
        if (status == 'Completed' && rideProvider.ongoingRides.any((r) => r.id == localRide.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            rideProvider.completeRide(localRide);
            if (driverPhone != null && !hasBeenRated) {
              _showRatingDialog(localRide, driverPhone, driverName ?? 'your driver');
            }
          });
        }

        // Trackable for the whole in-progress lifecycle now that drivers
        // actually move through on_the_way/arrived, not just Accepted.
        final isTrackable = ['Accepted', 'on_the_way', 'arrived'].contains(status);

        return ListTile(
          onTap: isTrackable
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TrackRideScreen(rideId: localRide.id!)),
                  )
              : null,
          title: Text("${localRide.vehicleName} - ${localRide.location}",
              style: TextStyle(fontSize: settingsProvider.settings.textSize)),
          subtitle: Text(
            [
              "Time: ${localRide.rideTime ?? 'Now'}",
              if (localRide.estimatedFareGhs != null) FareService.formatGhs(localRide.estimatedFareGhs!),
              if (driverName != null) "Driver: $driverName",
              if (isTrackable) 'Tap to track',
            ].join(' • '),
            style: TextStyle(fontSize: settingsProvider.settings.textSize),
          ),
          leading: RideStatusBadge(status: status),
          trailing: (status == 'Completed' || status == 'Cancelled')
              ? null
              : IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.error),
                  onPressed: () => _showCancelConfirmationDialog(localRide, rideProvider),
                ),
        );
      },
    );
  }

  void _confirmResetHistory(RideProvider rideProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Ride History'),
        content: const Text('This will permanently delete all of your past ride records. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              rideProvider.resetHistory();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmationDialog(Ride ride, RideProvider rideProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Ride'),
          content:
              const Text('Are you sure you want to cancel this ride?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Close the dialog without canceling
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                final rideId = ride.id;
                if (rideId != null) {
                  // Best-effort: also reflect the cancellation in
                  // Firestore so the driver's list and admin dashboard
                  // see it. If this fails (e.g. offline), the ride still
                  // gets cleared locally below.
                  try {
                    await FirebaseFirestore.instance
                        .collection('rideRequests')
                        .doc(rideId)
                        .update({'status': 'Cancelled'});
                  } catch (_) {
                    // Ignore — local cancellation still proceeds.
                  }
                }
                rideProvider.cancelRide(ride); // Confirm cancellation
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close the dialog
                }
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  // Prompts the passenger to rate their driver once a ride completes.
  // Purely optional — dismissing without picking a star just skips it,
  // there's no way to force a rating and no retry nagging.
  void _showRatingDialog(Ride ride, String driverPhone, String driverName) {
    int selectedStars = 5;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Rate $driverName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was your ride?'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starIndex = i + 1;
                      return IconButton(
                        icon: Icon(
                          starIndex <= selectedStars ? Icons.star : Icons.star_border,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        onPressed: () => setDialogState(() => selectedStars = starIndex),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await RatingService.submitRating(
                      rideId: ride.id!,
                      driverPhone: driverPhone,
                      stars: selectedStars,
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Build the Settings tab content
  Widget _buildSettingsTab() {
    return const SettingsScreen(); // Return the settings screen
  }
}
