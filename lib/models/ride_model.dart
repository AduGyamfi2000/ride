class Ride {
  final String vehicleName;
  final String location;
  final String? rideTime;
  final String? pickupAddress;
  final String? dropoffAddress;

  Ride({
    required this.vehicleName,
    required this.location,
    this.rideTime,
    this.pickupAddress,
    this.dropoffAddress,
  });

  Map<String, dynamic> toJson() => {
        'vehicleName': vehicleName,
        'location': location,
        'rideTime': rideTime,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
      };

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        vehicleName: json['vehicleName'] as String? ?? 'Ride',
        location: json['location'] as String? ?? 'Unknown',
        rideTime: json['rideTime'] as String?,
        pickupAddress: json['pickupAddress'] as String?,
        dropoffAddress: json['dropoffAddress'] as String?,
      );
}
