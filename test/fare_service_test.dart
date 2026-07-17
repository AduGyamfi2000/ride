import 'package:flutter_test/flutter_test.dart';
import 'package:ride/services/fare_service.dart';

void main() {
  group('FareService.estimate', () {
    test('returns null when distance is null (no drop-off set)', () {
      expect(FareService.estimate(vehicleName: 'Taxi', distanceKm: null), isNull);
    });

    test('applies the minimum fare for a very short trip', () {
      // Motorcycle: base 3 + 1.5/km. At 0.1km that's 3.15, below the
      // GH₵5 minimum, so the minimum should win.
      final fare = FareService.estimate(vehicleName: 'Motorcycle', distanceKm: 0.1);
      expect(fare, 5.0);
    });

    test('computes base + per-km rate once above the minimum', () {
      // Taxi: base 8 + 3.0/km. At 10km: 8 + 30 = 38.
      final fare = FareService.estimate(vehicleName: 'Taxi', distanceKm: 10);
      expect(fare, 38.0);
    });

    test('falls back to the default rate for an unrecognized vehicle name', () {
      // Default: base 5 + 2.0/km. At 10km: 5 + 20 = 25.
      final fare = FareService.estimate(vehicleName: 'Helicopter', distanceKm: 10);
      expect(fare, 25.0);
    });

    test('different vehicle types produce different fares for the same distance', () {
      final bus = FareService.estimate(vehicleName: 'Bus', distanceKm: 10)!;
      final taxi = FareService.estimate(vehicleName: 'Taxi', distanceKm: 10)!;
      expect(taxi, greaterThan(bus));
    });
  });

  group('FareService.formatGhs', () {
    test('formats with the currency symbol and two decimal places', () {
      expect(FareService.formatGhs(12.5), 'GH₵ 12.50');
    });

    test('rounds to two decimal places', () {
      expect(FareService.formatGhs(9.999), 'GH₵ 10.00');
    });
  });
}
