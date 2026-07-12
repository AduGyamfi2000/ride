import 'package:flutter/material.dart';
import '../models/ride_model.dart';

class RideProvider extends ChangeNotifier {
  Ride? _ongoingRide; // Store ongoing ride
  final List<Ride> _rideHistory = []; // Store history of rides

  Ride? get ongoingRide => _ongoingRide;
  List<Ride> get rideHistory => _rideHistory;

  List<Ride> ongoingRides = [];

  // Set the ongoing ride from a fully-built Ride (keeps id/uid/status intact)
  void setOngoingRide(Ride ride) {
    _ongoingRide = ride;
    notifyListeners();
  }

  // Method to move a completed ride to history
  void completeOngoingRide() {
    if (_ongoingRide != null) {
      _rideHistory.add(_ongoingRide!); // Move ride to history
      _ongoingRide = null; // Reset ongoing ride
      notifyListeners();
    }
  }

  // Method to cancel the ongoing ride
  void cancelOngoingRide() {
    _ongoingRide = null; // Remove ongoing ride
    notifyListeners(); // Notify listeners to update the UI
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
