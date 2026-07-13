class Ride {
  final String? id;
  final String? uid;
  final String vehicleName;
  final String location;
  final String? rideTime;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? distanceKm;
  final double? estimatedFareGhs;
  final String status;
  final DateTime createdAt;
  final String? passengerName;
  // Set once a driver accepts the ride.
  final String? driverPhone;
  final String? driverName;

  Ride({
    this.id,
    this.uid,
    required this.vehicleName,
    required this.location,
    this.rideTime,
    this.pickupAddress,
    this.dropoffAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.distanceKm,
    this.estimatedFareGhs,
    this.status = 'Searching',
    DateTime? createdAt,
    this.passengerName,
    this.driverPhone,
    this.driverName,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'vehicleName': vehicleName,
        'location': location,
        'rideTime': rideTime,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'distanceKm': distanceKm,
        'estimatedFareGhs': estimatedFareGhs,
        'status': status,
        'createdAtMillis': createdAt.millisecondsSinceEpoch,
        'passengerName': passengerName,
        'driverPhone': driverPhone,
        'driverName': driverName,
      };

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String?,
        uid: json['uid'] as String?,
        vehicleName: json['vehicleName'] as String? ?? 'Ride',
        location: json['location'] as String? ?? 'Unknown',
        rideTime: json['rideTime'] as String?,
        pickupAddress: json['pickupAddress'] as String?,
        dropoffAddress: json['dropoffAddress'] as String?,
        pickupLat: (json['pickupLat'] as num?)?.toDouble(),
        pickupLng: (json['pickupLng'] as num?)?.toDouble(),
        dropoffLat: (json['dropoffLat'] as num?)?.toDouble(),
        dropoffLng: (json['dropoffLng'] as num?)?.toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        estimatedFareGhs: (json['estimatedFareGhs'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'Searching',
        createdAt: json['createdAtMillis'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['createdAtMillis'] as int)
            : DateTime.now(),
        passengerName: json['passengerName'] as String?,
        driverPhone: json['driverPhone'] as String?,
        driverName: json['driverName'] as String?,
      );
}
