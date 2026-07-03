import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:guard_monitoring/models/site_model.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;

  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  void startTracking({
    required SiteModel site,
    required Function(bool isOnSite) onStatusChange,
    required Function(Position position) onLocationUpdate,
  }) {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          final distance = const Distance().as(
            LengthUnit.Meter,
            LatLng(position.latitude, position.longitude),
            LatLng(site.latitude, site.longitude),
          );

          final isOnSite = distance <= site.radius;
          onStatusChange(isOnSite);
          onLocationUpdate(position);

          // Log sparingly to avoid flooding the console
          if (distance < site.radius + 100) {
            debugPrint(
              'Tracking: ${distance.toStringAsFixed(1)}m from site. On site: $isOnSite',
            );
          }
        });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
