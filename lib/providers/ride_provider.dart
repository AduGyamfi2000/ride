import 'package:flutter/material.dart';
import '../models/ride_model.dart';

class RideProvider extends ChangeNotifier {
  // Previously a single Ride?, which meant booking a second ride (now
  // possible thanks to scheduling) silently overwrote the first one in
  // the UI — Firestore still had both documents, but the Home screen
  // could only ever show one.
  final List<Ride> _ongoingRides = [];
  final List<Ride> _rideHistory = []; // Store history of rides

  List<Ride> get ongoingRides => List.unmodifiable(_ongoingRides);
  List<Ride> get rideHistory => List.unmodifiable(_rideHistory);

  // Adds a newly-booked ride to the ongoing list (keeps id/uid/status intact).
  void addOngoingRide(Ride ride) {
    _ongoingRides.add(ride);
    notifyListeners();
  }

  // Moves a specific ride (matched by id) from ongoing to history.
  void completeRide(Ride ride) {
    _ongoingRides.removeWhere((r) => r.id == ride.id);
    _rideHistory.add(ride);
    notifyListeners();
  }

  // Removes a specific ride (matched by id) from the ongoing list, without
  // adding it to history — used when the passenger cancels.
  void cancelRide(Ride ride) {
    _ongoingRides.removeWhere((r) => r.id == ride.id);
    notifyListeners();
  }

  // Method to delete a specific ride from the history
  void deleteRideFromHistory(int index) {
    _rideHistory.removeAt(index); // Remove ride at the specific index
    notifyListeners(); // Notify listeners to update the UI
  }

  // Method to reset all the history
  void resetHistory() {
    _rideHistory.clear(); // Clear the ride history list
    notifyListeners(); // Notify listeners to update the UI
  }
}
