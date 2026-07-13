/// Simple distance-based fare estimator.
///
/// NOTE: these are illustrative flat rates for a demo/capstone project,
/// not live/dynamic pricing — there's no surge, traffic, or time-of-day
/// factor. A production app would source rates from a backend config (so
/// they can be updated without an app release) rather than hardcoding
/// them here.
class FareService {
  FareService._();

  static const double _minFareGhs = 5.0;

  static const Map<String, _Rate> _rates = {
    'Motorcycle': _Rate(baseGhs: 3, perKmGhs: 1.5),
    'Tricycle': _Rate(baseGhs: 4, perKmGhs: 1.8),
    'Bus': _Rate(baseGhs: 2, perKmGhs: 1.0),
    'Taxi': _Rate(baseGhs: 8, perKmGhs: 3.0),
  };
  static const _Rate _defaultRate = _Rate(baseGhs: 5, perKmGhs: 2.0);

  /// Returns a fare estimate in GHS for [vehicleName] over [distanceKm],
  /// floored at a minimum fare. Returns null if [distanceKm] is null
  /// (e.g. no drop-off was set).
  static double? estimate({required String vehicleName, required double? distanceKm}) {
    if (distanceKm == null) return null;
    final rate = _rates[vehicleName] ?? _defaultRate;
    final fare = rate.baseGhs + rate.perKmGhs * distanceKm;
    return fare < _minFareGhs ? _minFareGhs : fare;
  }

  static String formatGhs(double amount) => 'GH₵ ${amount.toStringAsFixed(2)}';
}

class _Rate {
  final double baseGhs;
  final double perKmGhs;
  const _Rate({required this.baseGhs, required this.perKmGhs});
}
