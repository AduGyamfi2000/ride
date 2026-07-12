import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Function to calculate summary stats
  void _calculateSummaryStats() async {
    // Total users
    FirebaseFirestore.instance.collection('users').get().then((snapshot) {
      setState(() {
        _totalUsers = snapshot.size;
      });
    });

    // Total rides and active rides
    FirebaseFirestore.instance
        .collection('rideRequests')
        .get()
        .then((snapshot) {
      setState(() {
        _totalRides = snapshot.size;
        _activeRides = snapshot.docs
            .where((doc) => doc.data()['status'] == 'Ongoing')
            .length;
      });
    });
  }

  // Function to remove a user
  void _removeUser(String userId) {
    FirebaseFirestore.instance.collection('users').doc(userId).delete().then(
      (_) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Stats Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryStatCard('Total Users', _totalUsers),
                _summaryStatCard('Total Rides', _totalRides),
                _summaryStatCard('Active Rides', _activeRides),
              ],
            ),
            const SizedBox(height: 30),

            // Display Users Section
            const Text(
              'Registered Users',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getUsersStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data!.docs;
                  if (users.isEmpty) {
                    return const Center(
                      child: Text('No users found.'),
                    );
                  }
                  return ListView.builder(
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
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editUser(users[index].id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeUser(users[index].id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 30),

            // Ride Filtering Options
            DropdownButton<String>(
              value: _rideStatusFilter,
              onChanged: (String? newValue) {
                setState(() {
                  _rideStatusFilter = newValue!;
                });
              },
              items: <String>['All', 'Ongoing', 'Completed', 'Cancelled']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Display Ride Activities Section
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getRideRequestsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rides = snapshot.data!.docs;
                  if (rides.isEmpty) {
                    return const Center(
                      child: Text('No ride activities found.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      var ride = rides[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text('Ride by ${ride['passengerName'] ?? 'Passenger'}'),
                          subtitle: Text(
                              'Location: ${ride['location'] ?? 'Unknown'}, Time: ${ride['rideTime'] ?? ride['time'] ?? 'Now'}'),
                          trailing: Text('Status: ${ride['status']}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build summary stat cards
  Widget _summaryStatCard(String label, int value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
