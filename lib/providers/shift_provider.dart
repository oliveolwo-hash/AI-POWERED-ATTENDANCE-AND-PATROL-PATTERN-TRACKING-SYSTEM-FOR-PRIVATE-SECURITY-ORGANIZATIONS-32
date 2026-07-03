import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';

final shiftRepositoryProvider = Provider(
  (ref) => ShiftRepository(FirebaseFirestore.instance),
);

final activeShiftProvider = StreamProvider<ShiftModel?>((ref) {
  final userData = ref.watch(userDataProvider).value;
  if (userData == null || userData.orgId == null) return Stream.value(null);

  return ref
      .watch(shiftRepositoryProvider)
      .getActiveShift(userData.id, userData.orgId!);
});

class ShiftRepository {
  final FirebaseFirestore _firestore;

  ShiftRepository(this._firestore);

  Stream<ShiftModel?> getActiveShift(String personnelId, String orgId) {
    return _firestore
        .collection('shifts')
        .where('orgId', isEqualTo: orgId) // Required for security rules
        .where('personnelId', isEqualTo: personnelId)
        .where('actualCheckOut', isNull: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return ShiftModel.fromMap(snapshot.docs.first.data());
          }
          return null;
        });
  }

  Future<void> checkIn(String shiftId, DateTime time) async {
    await _firestore.collection('shifts').doc(shiftId).update({
      'actualCheckIn': time.toIso8601String(),
    });
  }

  Future<void> checkOut(String shiftId, DateTime time) async {
    await _firestore.collection('shifts').doc(shiftId).update({
      'actualCheckOut': time.toIso8601String(),
    });
  }

  Future<void> updateOnSiteStatus(String shiftId, bool isOnSite) async {
    await _firestore.collection('shifts').doc(shiftId).update({
      'isOnSite': isOnSite,
    });
  }

  Future<void> updateLocation(String shiftId, double lat, double lng) async {
    await _firestore.collection('shifts').doc(shiftId).update({
      'currentLat': lat,
      'currentLng': lng,
    });
  }

  Future<void> updateShiftStatus(String shiftId, String status) async {
    await _firestore.collection('shifts').doc(shiftId).update({
      'status': status,
    });
  }

  Future<void> deleteShift(String shiftId) async {
    await _firestore.collection('shifts').doc(shiftId).delete();
  }

  Stream<List<ShiftModel>> getAllShifts(String orgId, {String? personnelId}) {
    var query = _firestore
        .collection('shifts')
        .where('orgId', isEqualTo: orgId);

    if (personnelId != null) {
      query = query.where('personnelId', isEqualTo: personnelId);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ShiftModel.fromMap(doc.data())).toList(),
    );
  }

  Stream<List<ShiftModel>> getSystemShifts() {
    return _firestore.collection('shifts').snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ShiftModel.fromMap(doc.data())).toList(),
    );
  }
}

final allShiftsStreamProvider = StreamProvider<List<ShiftModel>>((ref) {
  final userData = ref.watch(userDataProvider).value;
  if (userData == null) return const Stream.empty();

  if (userData.role == UserRole.superAdmin) {
    return ref.watch(shiftRepositoryProvider).getSystemShifts();
  }

  final orgId = userData.role == UserRole.admin ? userData.id : userData.orgId;
  if (orgId == null) return const Stream.empty();

  // If guard, only get their own historical shifts.
  final personnelId = userData.role == UserRole.guard ? userData.id : null;

  return ref
      .watch(shiftRepositoryProvider)
      .getAllShifts(orgId, personnelId: personnelId);
});
