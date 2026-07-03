import 'package:cloud_firestore/cloud_firestore.dart';

enum IncidentPriority { low, medium, high, critical }

enum IncidentStatus { pending, investigating, resolved }

enum IncidentType {
  securityBreach,
  suspiciousActivity,
  equipmentMalfunction,
  medicalEmergency,
  fireSafety,
  vandalism,
  unauthorizedAccess,
  other,
}

class IncidentModel {
  final String id;
  final String guardId;
  final String orgId;
  final String description;
  final DateTime timestamp;
  final String location;
  final String? photoUrl; // Added for photo evidence

  final IncidentPriority priority;
  final IncidentStatus status;
  final IncidentType type;

  // Resolution Tracking
  final String? recommendedAction;
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  IncidentModel({
    required this.id,
    required this.guardId,
    required this.orgId,
    required this.description,
    required this.timestamp,
    required this.location,
    required this.priority,
    required this.status,
    required this.type,
    this.photoUrl,
    this.recommendedAction,
    this.resolutionNotes,
    this.resolvedAt,
    this.resolvedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guardId': guardId,
      'orgId': orgId,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location,
      'photoUrl': photoUrl,
      'priority': priority.name,
      'status': status.name,
      'type': type.name,
      'recommendedAction': recommendedAction,
      'resolutionNotes': resolutionNotes,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
    };
  }

  factory IncidentModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    // Legacy mapping
    IncidentPriority parsedPriority = IncidentPriority.medium;
    if (map['priority'] != null) {
      parsedPriority = IncidentPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => IncidentPriority.medium,
      );
    }

    IncidentStatus parsedStatus = IncidentStatus.pending;
    if (map['status'] != null) {
      parsedStatus = IncidentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => IncidentStatus.pending,
      );
    }

    IncidentType parsedType = IncidentType.other;
    if (map['type'] != null) {
      parsedType = IncidentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => IncidentType.other,
      );
    }

    return IncidentModel(
      id: doc.id,
      guardId: map['guardId'] ?? '',
      orgId: map['orgId'] ?? '',
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: map['location'] ?? '',
      photoUrl: map['photoUrl'],
      priority: parsedPriority,
      status: parsedStatus,
      type: parsedType,
      recommendedAction: map['recommendedAction'],
      resolutionNotes: map['resolutionNotes'],
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: map['resolvedBy'],
    );
  }
}
