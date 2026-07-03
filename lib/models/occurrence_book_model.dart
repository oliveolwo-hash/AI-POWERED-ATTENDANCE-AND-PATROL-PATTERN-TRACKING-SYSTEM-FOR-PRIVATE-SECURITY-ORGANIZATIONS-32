import 'package:cloud_firestore/cloud_firestore.dart';

class OccurrenceBookModel {
  final String id;
  final String guardId;
  final String guardName;
  final String orgId; // Supervisor ID
  final DateTime timestamp;
  final String category; // 'Visitor', 'Vehicle', 'Security Check', 'General Log', 'Emergency'
  final String title;
  final String description;
  final String? visitorName;
  final String? visitorCompany;
  final String? vehicleNumber;
  final String? badgeNumber;

  OccurrenceBookModel({
    required this.id,
    required this.guardId,
    required this.guardName,
    required this.orgId,
    required this.timestamp,
    required this.category,
    required this.title,
    required this.description,
    this.visitorName,
    this.visitorCompany,
    this.vehicleNumber,
    this.badgeNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guardId': guardId,
      'guardName': guardName,
      'orgId': orgId,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'title': title,
      'description': description,
      'visitorName': visitorName,
      'visitorCompany': visitorCompany,
      'vehicleNumber': vehicleNumber,
      'badgeNumber': badgeNumber,
    };
  }

  factory OccurrenceBookModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedTimestamp;
    final tsVal = map['timestamp'];
    if (tsVal is String) {
      parsedTimestamp = DateTime.parse(tsVal);
    } else if (tsVal is Timestamp) {
      parsedTimestamp = tsVal.toDate();
    } else {
      parsedTimestamp = DateTime.now();
    }

    return OccurrenceBookModel(
      id: map['id'] ?? '',
      guardId: map['guardId'] ?? '',
      guardName: map['guardName'] ?? '',
      orgId: map['orgId'] ?? '',
      timestamp: parsedTimestamp,
      category: map['category'] ?? 'General Log',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      visitorName: map['visitorName'],
      visitorCompany: map['visitorCompany'],
      vehicleNumber: map['vehicleNumber'],
      badgeNumber: map['badgeNumber'],
    );
  }

  factory OccurrenceBookModel.fromFirestore(DocumentSnapshot doc) {
    return OccurrenceBookModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
