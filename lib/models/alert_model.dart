enum AlertType { sos, geofenceEscape, lateArrival, adminMessage }

enum AlertPriority { urgent, warning, announcement, info }

class AlertModel {
  final String id;
  final String
  personnelId; // The ID of the guard who triggered it (if applicable)
  final String?
  targetId; // 'all' for broadcast, specific ID for a specific guard, null for admin alerts
  final String siteId; // Can be empty if it's a general broadcast
  final String orgId;
  final String message;
  final AlertType type;
  final AlertPriority priority;
  final DateTime timestamp;
  final bool isResolved;

  // New Management Fields
  final bool isRead;
  final bool needsAcknowledgment;
  final bool isAcknowledged;
  final String senderName;
  final String senderRole;

  // Resolution Tracking
  final String? recommendedAction;
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  AlertModel({
    required this.id,
    required this.personnelId,
    this.targetId,
    required this.siteId,
    required this.orgId,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.isResolved = false,
    this.isRead = false,
    this.needsAcknowledgment = false,
    this.isAcknowledged = false,
    this.senderName = 'System',
    this.senderRole = 'Security Desk',
    this.recommendedAction,
    this.resolutionNotes,
    this.resolvedAt,
    this.resolvedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personnelId': personnelId,
      'targetId': targetId,
      'siteId': siteId,
      'orgId': orgId,
      'message': message,
      'type': type.index,
      'priority': priority.name,
      'timestamp': timestamp.toIso8601String(),
      'isResolved': isResolved,
      'isRead': isRead,
      'needsAcknowledgment': needsAcknowledgment,
      'isAcknowledged': isAcknowledged,
      'senderName': senderName,
      'senderRole': senderRole,
      'recommendedAction': recommendedAction,
      'resolutionNotes': resolutionNotes,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    AlertPriority parsedPriority = AlertPriority.info;
    if (map['priority'] != null) {
      final pString = map['priority'].toString().toLowerCase();
      if (pString == 'urgent' || pString == 'critical')
        parsedPriority = AlertPriority.urgent;
      else if (pString == 'warning')
        parsedPriority = AlertPriority.warning;
      else if (pString == 'announcement')
        parsedPriority = AlertPriority.announcement;
    }

    return AlertModel(
      id: map['id'] ?? '',
      personnelId: map['personnelId'] ?? '',
      targetId: map['targetId'],
      siteId: map['siteId'] ?? '',
      orgId: map['orgId'] ?? '',
      message: map['message'] ?? '',
      type: AlertType.values[map['type'] ?? 0],
      priority: parsedPriority,
      timestamp: DateTime.parse(map['timestamp']),
      isResolved: map['isResolved'] ?? false,
      isRead: map['isRead'] ?? false,
      needsAcknowledgment: map['needsAcknowledgment'] ?? false,
      isAcknowledged: map['isAcknowledged'] ?? false,
      senderName: map['senderName'] ?? 'System',
      senderRole: map['senderRole'] ?? 'Operations',
      recommendedAction: map['recommendedAction'],
      resolutionNotes: map['resolutionNotes'],
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.parse(map['resolvedAt'])
          : null,
      resolvedBy: map['resolvedBy'],
    );
  }
}
