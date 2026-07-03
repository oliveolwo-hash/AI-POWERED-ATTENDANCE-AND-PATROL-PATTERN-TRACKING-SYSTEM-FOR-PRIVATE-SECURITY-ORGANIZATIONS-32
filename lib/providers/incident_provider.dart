import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/activity_log_service.dart';
import 'package:guard_monitoring/models/incident_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';

final incidentRepositoryProvider = Provider(
  (ref) => IncidentRepository(FirebaseFirestore.instance),
);

final incidentsStreamProvider = StreamProvider<List<IncidentModel>>((ref) {
  final userData = ref.watch(userDataProvider).value;
  if (userData == null) return const Stream.empty();

  if (userData.role == UserRole.superAdmin) {
    return ref.watch(incidentRepositoryProvider).getAllIncidents();
  }

  final orgId = userData.role == UserRole.admin ? userData.id : userData.orgId;
  if (orgId == null) return const Stream.empty();

  // If guard, only get their own incidents. If admin, get all for org.
  final guardId = userData.role == UserRole.guard ? userData.id : null;

  return ref
      .watch(incidentRepositoryProvider)
      .getIncidents(orgId, guardId: guardId);
});

class IncidentRepository {
  final FirebaseFirestore _firestore;

  IncidentRepository(this._firestore);

  Stream<List<IncidentModel>> getIncidents(String orgId, {String? guardId}) {
    var query = _firestore
        .collection('incidents')
        .where('orgId', isEqualTo: orgId);

    if (guardId != null) {
      query = query.where('guardId', isEqualTo: guardId);
    }

    return query
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncidentModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<IncidentModel>> getAllIncidents() {
    return _firestore
        .collection('incidents')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncidentModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> submitIncident(IncidentModel incident) async {
    await _firestore
        .collection('incidents')
        .doc(incident.id)
        .set(incident.toMap());

    // Log action
    final doc = await _firestore.collection('users').doc(incident.guardId).get();
    if (doc.exists) {
      final guardUser = UserModel.fromMap(doc.data()!);
      await ActivityLogService.log(
        action: 'SUBMIT_INCIDENT',
        details: 'Incident reported: ${incident.type.name} at ${incident.location} (Priority: ${incident.priority.name})',
        userId: guardUser.id,
        userEmail: guardUser.email,
        userName: guardUser.name,
        userRole: guardUser.role.name,
      );
    }
  }

  Future<void> resolveIncident({
    required String incidentId,
    required String resolutionNotes,
    required String resolvedBy,
    required IncidentStatus status,
  }) async {
    await _firestore.collection('incidents').doc(incidentId).update({
      'status': status.name,
      'resolutionNotes': resolutionNotes,
      'resolvedBy': resolvedBy,
      'resolvedAt': Timestamp.now(),
    });

    // Log action
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final doc = await _firestore.collection('users').doc(currentUid).get();
      if (doc.exists) {
        final adminUser = UserModel.fromMap(doc.data()!);
        await ActivityLogService.log(
          action: 'RESOLVE_INCIDENT',
          details: 'Updated incident status: $incidentId to ${status.name}. Notes: $resolutionNotes',
          userId: adminUser.id,
          userEmail: adminUser.email,
          userName: adminUser.name,
          userRole: adminUser.role.name,
        );
      }
    }
  }

  Future<void> deleteIncident(String id) async {
    await _firestore.collection('incidents').doc(id).delete();

    // Log action
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final doc = await _firestore.collection('users').doc(currentUid).get();
      if (doc.exists) {
        final adminUser = UserModel.fromMap(doc.data()!);
        await ActivityLogService.log(
          action: 'DELETE_INCIDENT',
          details: 'Deleted incident report ID: $id',
          userId: adminUser.id,
          userEmail: adminUser.email,
          userName: adminUser.name,
          userRole: adminUser.role.name,
        );
      }
    }
  }
}

