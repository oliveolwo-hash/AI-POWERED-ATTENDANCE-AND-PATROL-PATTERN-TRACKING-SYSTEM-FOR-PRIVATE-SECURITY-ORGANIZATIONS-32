import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guard_monitoring/core/constants.dart';

class MapMarkerData {
  final String id;
  final LatLng position;
  final IconData icon;
  final Color color;
  final double size;
  final String? label;
  final VoidCallback? onTap;

  MapMarkerData({
    required this.id,
    required this.position,
    this.icon = Icons.location_on,
    this.color = Colors.blue,
    this.size = 35,
    this.label,
    this.onTap,
  });
}

class MapCircleData {
  final String id;
  final LatLng center;
  final double radiusInMeters;
  final Color color;
  final Color borderColor;

  MapCircleData({
    required this.id,
    required this.center,
    required this.radiusInMeters,
    this.color = const Color(0x33F44336), // Colors.red.withOpacity(0.2)
    this.borderColor = const Color(0x66F44336), // Colors.red.withOpacity(0.4)
  });
}

class SharedMapComponent extends StatelessWidget {
  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<MapMarkerData> markers;
  final List<MapCircleData> circles;
  final void Function(LatLng position)? onTap;
  final LatLngBounds? cameraBounds;

  const SharedMapComponent({
    super.key,
    this.mapController,
    required this.initialCenter,
    this.initialZoom = 15,
    this.markers = const [],
    this.circles = const [],
    this.onTap,
    this.cameraBounds,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 5,
        maxZoom: 18,
        cameraConstraint: cameraBounds != null 
            ? CameraConstraint.contain(bounds: cameraBounds!) 
            : const CameraConstraint.unconstrained(),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        onTap: (tapPosition, point) {
          if (onTap != null) {
            onTap!(point);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: "https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$MAPBOX_ACCESS_TOKEN",
          userAgentPackageName: 'com.multiguard.app',
        ),
        if (circles.isNotEmpty)
          CircleLayer(
            circles: circles.map((circle) => CircleMarker(
              point: circle.center,
              radius: circle.radiusInMeters,
              useRadiusInMeter: true,
              color: circle.color,
              borderColor: circle.borderColor,
              borderStrokeWidth: 2,
            )).toList(),
          ),
        if (markers.isNotEmpty)
          MarkerLayer(
            markers: markers.map((markerData) => Marker(
              point: markerData.position,
              width: markerData.label != null ? 150 : markerData.size,
              height: markerData.size + (markerData.label != null ? 24 : 0),
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: markerData.onTap,
                child: MouseRegion(
                  cursor: markerData.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (markerData.label != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            markerData.label!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Icon(
                        markerData.icon,
                        color: markerData.color,
                        size: markerData.size,
                      ),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ),
      ],
    );
  }
}
