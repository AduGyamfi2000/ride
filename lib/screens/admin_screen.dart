import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fare_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/ride_status_badge.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  AdminScreenState createState() => AdminScreenState();
}

class AdminScreenState extends State<AdminScreen> {
  String _rideStatusFilter = 'All'; // Default filter
  int _totalUsers = 0;
  int _totalRides = 0;
  int _activeRides = 0;
  int _pendingDrivers = 0;

  @override
  void initState() {
    super.initState();
    _calculateSummaryStats(); // Calculate the stats when the screen is loaded
  }

  // Fetch users from Firestore
  Stream<QuerySnapshot> _getUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  // Fetch ride requests from Firestore based on filter
  Stream<QuerySnapshot> _getRideRequestsStream() {
    if (_rideStatusFilter == 'All') {
      return FirebaseFirestore.instance.collection('rideRequests').snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('rideRequests')
          .where('status', isEqualTo: _rideStatusFilter)
          .snapshots();
    }
  }

  // Drivers awaiting document review.
  Stream<QuerySnapshot> _getPendingDriversStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Driver')
        .where('verificationStatus', isEqualTo: 'Pending')
        .snapshots();
  }

  // Function to calculate summary stats
  void _calculateSummaryStats() async {
    // Total users
    FirebaseFirestore.instance.collection('users').get().then((snapshot) {
      if (!mounted) return;
      setState(() {
        _totalUsers = snapshot.size;
        _pendingDrivers = snapshot.docs
            .where((doc) =>
                doc.data()['role'] == 'Driver' && doc.data()['verificationStatus'] == 'Pending')
            .length;
      });
    });

    // Total rides and active rides
    FirebaseFirestore.instance
        .collection('rideRequests')
        .get()
        .then((snapshot) {
      if (!mounted) return;
      setState(() {
        _totalRides = snapshot.size;
        _activeRides = snapshot.docs
            .where((doc) => doc.data()['status'] == 'Searching' || doc.data()['status'] == 'Accepted')
            .length;
      });
    });
  }

  // Function to remove a user
  void _removeUser(String userId) {
    FirebaseFirestore.instance.collection('users').doc(userId).delete().then(
      (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User removed successfully.')),
        );
      },
    );
  }

  // Function to edit a user (placeholder for now)
  void _editUser(String userId) {
    // Navigate to edit user screen or show a dialog (implementation not shown)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit user functionality coming soon.')),
    );
  }

  Future<void> _setDriverVerification(String userId, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'verificationStatus': status,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status == 'Verified' ? 'Driver approved.' : 'Driver rejected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Rides'),
              Tab(text: 'Drivers'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryStatCard('Users', _totalUsers),
                  _summaryStatCard('Rides', _totalRides),
                  _summaryStatCard('Active', _activeRides),
                  _summaryStatCard('Pending Drivers', _pendingDrivers, highlight: _pendingDrivers > 0),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUsersTab(),
                  _buildRidesTab(),
                  _buildDriversTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!.docs;
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            var user = users[index].data() as Map<String, dynamic>;
            final displayName = [user['firstName'], user['lastName']]
                .where((n) => n != null && (n as String).isNotEmpty)
                .join(' ');
            return ListTile(
              title: Text(displayName.isNotEmpty ? displayName : 'Unnamed User'),
              subtitle: Text('Phone: ${user['phone'] ?? 'N/A'} • ${user['role'] ?? 'Passenger'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.info),
                    onPressed: () => _editUser(users[index].id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: () => _removeUser(users[index].id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRidesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text('Filter:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _rideStatusFilter,
                onChanged: (String? newValue) {
                  setState(() {
                    _rideStatusFilter = newValue!;
                  });
                },
                items: <String>['All', 'Searching', 'Scheduled', 'Accepted', 'Completed', 'Cancelled']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getRideRequestsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rides = snapshot.data!.docs;
              if (rides.isEmpty) {
                return const Center(child: Text('No ride activities found.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rides.length,
                itemBuilder: (context, index) {
                  var ride = rides[index].data() as Map<String, dynamic>;
                  final fare = (ride['estimatedFareGhs'] as num?)?.toDouble();
                  final extraLines = [
                    if (ride['driverName'] != null) 'Driver: ${ride['driverName']}',
                    if (fare != null) 'Fare: ${FareService.formatGhs(fare)}',
                  ];
                  return Card(
                    child: ListTile(
                      title: Text('Ride by ${ride['passengerName'] ?? 'Passenger'}'),
                      subtitle: Text(
                        'Location: ${ride['location'] ?? 'Unknown'}, Time: ${ride['rideTime'] ?? ride['time'] ?? 'Now'}'
                        '${extraLines.isNotEmpty ? '\n${extraLines.join(' • ')}' : ''}',
                      ),
                      isThreeLine: extraLines.isNotEmpty,
                      trailing: RideStatusBadge(status: ride['status'] as String? ?? 'Searching'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDriversTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPendingDriversStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final drivers = snapshot.data!.docs;
        if (drivers.isEmpty) {
          return const Center(child: Text('No drivers waiting for review.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final doc = drivers[index];
            final data = doc.data() as Map<String, dynamic>;
            return _PendingDriverCard(
              data: data,
              onApprove: () => _setDriverVerification(doc.id, 'Verified'),
              onReject: () => _setDriverVerification(doc.id, 'Rejected'),
            );
          },
        );
      },
    );
  }

  // Helper function to build summary stat cards
  Widget _summaryStatCard(String label, int value, {bool highlight = false}) {
    return Card(
      color: highlight ? AppColors.warning.withValues(alpha: 0.12) : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: highlight ? AppColors.warning : AppColors.textPrimary,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PendingDriverCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingDriverCard({required this.data, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final name = [data['firstName'], data['lastName']]
        .where((n) => n != null && (n as String).isNotEmpty)
        .join(' ');
    final licenseUrl = data['licenseImageUrl'] as String?;
    final carUrl = data['carImageUrl'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name.isNotEmpty ? name : 'Unnamed Driver', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text('Phone: ${data['phone'] ?? 'N/A'}', style: AppTextStyles.bodyMedium),
            Text("License #: ${data['licenseNumber'] ?? 'N/A'}", style: AppTextStyles.bodyMedium),
            Text(
              "Car: ${data['carMake'] ?? ''} ${data['carModel'] ?? ''} • ${data['carPlateNumber'] ?? 'N/A'}"
              "${data['carColor'] != null ? ' • ${data['carColor']}' : ''}",
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DocumentPreview(label: "License Photo", url: licenseUrl)),
                const SizedBox(width: 10),
                Expanded(child: _DocumentPreview(label: "Car Photo", url: carUrl)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    variant: AppButtonVariant.outlined,
                    isLarge: false,
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    variant: AppButtonVariant.secondary,
                    isLarge: false,
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  final String label;
  final String? url;

  const _DocumentPreview({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 110,
            width: double.infinity,
            child: url == null
                ? Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textHint),
                  )
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.textHint),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
