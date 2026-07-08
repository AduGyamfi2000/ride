import 'package:hive_flutter/hive_flutter.dart';
import '../models/ride_model.dart';

class OfflineRideStore {
  static const String _boxName = 'offline_rides';
  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveRide(Ride ride) async {
    final rides = await loadRides();
    rides.add(ride);
    await _box.put('rides', rides.map((item) => item.toJson()).toList());
  }

  Future<void> saveRides(List<Ride> rides) async {
    await _box.put('rides', rides.map((ride) => ride.toJson()).toList());
  }

  Future<List<Ride>> loadRides() async {
    final raw = _box.get('rides', defaultValue: <Map<String, dynamic>>[]);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Ride.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return <Ride>[];
  }

  Future<void> clear() async {
    await _box.delete('rides');
  }
}
