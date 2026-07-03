import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/activity_log_service.dart';
import 'package:guard_monitoring/models/alert_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/models/user_model.dart';

final alertRepositoryProvider = Provider(
  (ref) => AlertRepository(FirebaseFirestore.instance),
);

final alertsStreamProvider = StreamProvider<List<AlertModel>>((ref) {
  final userData = ref.watch(userDataProvider).value;
  if (userData == null) return const Stream.empty();

  return ref.watch(alertRepositoryProvider).getAlerts(userData);
});

class AlertRepository {
  final FirebaseFirestore _firestore;

  AlertRepository(this._firestore);

  Stream<List<AlertModel>> getAlerts(UserModel user) {
    if (user.role == UserRole.superAdmin) {
      return _firestore
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => AlertModel.fromMap(doc.data()))
              .toList());
    }

    final orgId = user.role == UserRole.admin ? user.id : user.orgId;
    if (orgId == null) return const Stream.empty();

    // Query for user's organization alerts or global alerts
    return _firestore
        .collection('alerts')
        .where('orgId', whereIn: [orgId, 'global'])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final allAlerts = snapshot.docs
              .map((doc) => AlertModel.fromMap(doc.data()))
              .toList();

          if (user.role == UserRole.admin) {
            return allAlerts;
          }

          // For guards, filter to alerts they created, alerts targeted at them, or broadcasts
          return allAlerts
              .where(
                (a) =>
                    a.personnelId == user.id ||
                    a.targetId == user.id ||
                    a.targetId == 'all',
              )
              .toList();
        });
  }

  Future<void> sendAlert(AlertModel alert) async {
    await _firestore.collection('alerts').doc(alert.id).set(alert.toMap());

    // Log action
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final doc = await _firestore.collection('users').doc(currentUid).get();
      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!);
        await ActivityLogService.log(
          action: 'SEND_ALERT',
          details: 'Sent alert: "${alert.message}" to target "${alert.targetId}"',
          userId: user.id,
          userEmail: user.email,
          userName: user.name,
          userRole: user.role.name,
        );
      }
    }
  }

  Future<void> resolveAlert(
    String alertId,
    String resolutionNotes,
    String resolvedBy,
  ) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'isResolved': true,
      'resolutionNotes': resolutionNotes,
      'resolvedBy': resolvedBy,
      'resolvedAt': DateTime.now().toIso8601String(),
    });

    // Log action
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final doc = await _firestore.collection('users').doc(currentUid).get();
      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!);
        await ActivityLogService.log(
          action: 'RESOLVE_ALERT',
          details: 'Resolved alert ID: $alertId. Notes: $resolutionNotes',
          userId: user.id,
          userEmail: user.email,
          userName: user.name,
          userRole: user.role.name,
        );
      }
    }
  }

  Future<void> markAlertAsRead(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).update({'isRead': true});
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'isAcknowledged': true,
      'isRead': true,
    });
  }

  Future<void> deleteAlert(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).delete();

    // Log action
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final doc = await _firestore.collection('users').doc(currentUid).get();
      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!);
        await ActivityLogService.log(
          action: 'DELETE_ALERT',
          details: 'Deleted alert ID: $alertId',
          userId: user.id,
          userEmail: user.email,
          userName: user.name,
          userRole: user.role.name,
        );
      }
    }
  }
}

