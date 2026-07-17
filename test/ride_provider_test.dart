import 'package:flutter_test/flutter_test.dart';
import 'package:ride/models/ride_model.dart';
import 'package:ride/providers/ride_provider.dart';

Ride _ride(String id, {String status = 'Searching'}) => Ride(
      id: id,
      vehicleName: 'Taxi',
      location: 'Test Location',
      status: status,
    );

void main() {
  group('RideProvider', () {
    test('starts with no ongoing rides or history', () {
      final provider = RideProvider();
      expect(provider.ongoingRides, isEmpty);
      expect(provider.rideHistory, isEmpty);
    });

    test('addOngoingRide adds without overwriting a previous ride', () {
      // This is the specific bug being guarded against: the old
      // implementation held a single Ride? slot, so booking a second
      // ride (e.g. one now, one scheduled for later) silently replaced
      // the first one in the UI.
      final provider = RideProvider();
      provider.addOngoingRide(_ride('ride-1'));
      provider.addOngoingRide(_ride('ride-2'));

      expect(provider.ongoingRides.length, 2);
      expect(provider.ongoingRides.map((r) => r.id), containsAll(['ride-1', 'ride-2']));
    });

    test('completeRide moves the matching ride from ongoing to history', () {
      final provider = RideProvider();
      final ride = _ride('ride-1');
      provider.addOngoingRide(ride);
      provider.addOngoingRide(_ride('ride-2'));

      provider.completeRide(ride);

      expect(provider.ongoingRides.map((r) => r.id), ['ride-2']);
      expect(provider.rideHistory.map((r) => r.id), ['ride-1']);
    });

    test('cancelRide removes the matching ride without adding it to history', () {
      final provider = RideProvider();
      final ride = _ride('ride-1');
      provider.addOngoingRide(ride);

      provider.cancelRide(ride);

      expect(provider.ongoingRides, isEmpty);
      expect(provider.rideHistory, isEmpty);
    });

    test('deleteRideFromHistory removes only the ride at that index', () {
      final provider = RideProvider();
      provider.addOngoingRide(_ride('a'));
      provider.addOngoingRide(_ride('b'));
      provider.completeRide(provider.ongoingRides.first); // 'a' -> history
      provider.completeRide(provider.ongoingRides.first); // 'b' -> history

      provider.deleteRideFromHistory(0);

      expect(provider.rideHistory.length, 1);
    });

    test('resetHistory clears history but leaves ongoing rides untouched', () {
      final provider = RideProvider();
      final ongoing = _ride('still-ongoing');
      provider.addOngoingRide(ongoing);
      provider.addOngoingRide(_ride('to-complete'));
      provider.completeRide(provider.ongoingRides.last);

      provider.resetHistory();

      expect(provider.rideHistory, isEmpty);
      expect(provider.ongoingRides.map((r) => r.id), ['still-ongoing']);
    });

    test('ongoingRides is unmodifiable from the outside', () {
      final provider = RideProvider();
      provider.addOngoingRide(_ride('a'));
      expect(() => provider.ongoingRides.add(_ride('b')), throwsUnsupportedError);
    });
  });
}
