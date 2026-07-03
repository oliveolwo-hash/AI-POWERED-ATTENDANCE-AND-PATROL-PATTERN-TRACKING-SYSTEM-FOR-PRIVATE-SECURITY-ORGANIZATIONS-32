import 'package:cloud_firestore/cloud_firestore.dart';

class SiteModel {
  final String id;
  final String orgId;

  final String name;
  final String address;
  final String building;
  final String street;
  final String village;
  final String type;
  final double latitude;
  final double longitude;
  final double radius; // In meters for geofencing
  final bool isGeofenceEnabled;
  final bool isActive;

  SiteModel({
    required this.id,
    required this.orgId,

    required this.name,
    required this.address,
    this.building = '',
    this.street = '',
    this.village = '',
    this.type = 'Commercial',
    required this.latitude,
    required this.longitude,
    this.radius = 100.0,
    this.isGeofenceEnabled = true,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orgId': orgId,

      'name': name,
      'address': address,
      'building': building,
      'street': street,
      'village': village,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isGeofenceEnabled': isGeofenceEnabled,
      'isActive': isActive,
    };
  }

  factory SiteModel.fromMap(Map<String, dynamic> map) {
    return SiteModel(
      id: map['id'] ?? '',
      orgId: map['orgId'] ?? '',

      name: map['name'] ?? '',
      address: map['address'] ?? '',
      building: map['building'] ?? '',
      street: map['street'] ?? '',
      village: map['village'] ?? '',
      type: map['type'] ?? 'Commercial',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radius: (map['radius'] as num?)?.toDouble() ?? 100.0,
      isGeofenceEnabled: map['isGeofenceEnabled'] ?? true,
      isActive: map['isActive'] ?? true,
    );
  }

  factory SiteModel.fromFirestore(DocumentSnapshot doc) {
    return SiteModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
