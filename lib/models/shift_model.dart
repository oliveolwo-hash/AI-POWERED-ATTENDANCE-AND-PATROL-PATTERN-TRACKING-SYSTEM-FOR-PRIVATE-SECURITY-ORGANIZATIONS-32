class ShiftModel {
  final String id;
  final String siteId;
  final String personnelId;
  final String orgId;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? actualCheckIn;
  final DateTime? actualCheckOut;
  final bool isOnSite;
  final String? status;
  final double? currentLat;
  final double? currentLng;
  final int? batteryLevel;
  final double? movementSpeed;
  final DateTime? lastLocationUpdate;

  ShiftModel({
    required this.id,
    required this.siteId,
    required this.personnelId,
    required this.orgId,
    required this.startTime,
    required this.endTime,
    this.actualCheckIn,
    this.actualCheckOut,
    this.isOnSite = false,
    this.status,
    this.currentLat,
    this.currentLng,
    this.batteryLevel,
    this.movementSpeed,
    this.lastLocationUpdate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteId': siteId,
      'personnelId': personnelId,
      'orgId': orgId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'actualCheckIn': actualCheckIn?.toIso8601String(),
      'actualCheckOut': actualCheckOut?.toIso8601String(),
      'isOnSite': isOnSite,
      'status': status,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'batteryLevel': batteryLevel,
      'movementSpeed': movementSpeed,
      'lastLocationUpdate': lastLocationUpdate?.toIso8601String(),
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] ?? '',
      siteId: map['siteId'] ?? '',
      personnelId: map['personnelId'] ?? '',
      orgId: map['orgId'] ?? '',
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      actualCheckIn: map['actualCheckIn'] != null
          ? DateTime.parse(map['actualCheckIn'])
          : null,
      actualCheckOut: map['actualCheckOut'] != null
          ? DateTime.parse(map['actualCheckOut'])
          : null,
      isOnSite: map['isOnSite'] ?? false,
      status: map['status'],
      currentLat: (map['currentLat'] as num?)?.toDouble(),
      currentLng: (map['currentLng'] as num?)?.toDouble(),
      batteryLevel: map['batteryLevel'] as int?,
      movementSpeed: (map['movementSpeed'] as num?)?.toDouble(),
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? DateTime.parse(map['lastLocationUpdate'])
          : null,
    );
  }
}
