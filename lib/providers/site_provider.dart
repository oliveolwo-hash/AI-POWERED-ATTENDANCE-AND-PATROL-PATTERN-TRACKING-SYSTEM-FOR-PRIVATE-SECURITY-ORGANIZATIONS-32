import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/models/user_model.dart';

final siteRepositoryProvider = Provider(
  (ref) => SiteRepository(FirebaseFirestore.instance),
);

final siteDetailsProvider = FutureProvider.family<SiteModel?, String>((
  ref,
  siteId,
) async {
  final doc = await FirebaseFirestore.instance
      .collection('sites')
      .doc(siteId)
      .get();
  if (!doc.exists) return null;
  return SiteModel.fromFirestore(doc);
});

final sitesStreamProvider = StreamProvider<List<SiteModel>>((ref) {
  final userData = ref.watch(userDataProvider).value;
  if (userData == null) return const Stream.empty();

  if (userData.role == UserRole.superAdmin) {
    return ref.watch(siteRepositoryProvider).getAllSites();
  }

  final orgId = userData.role == UserRole.admin ? userData.id : userData.orgId;
  if (orgId == null) return const Stream.empty();

  return ref.watch(siteRepositoryProvider).getSites(orgId);
});

class SiteRepository {
  final FirebaseFirestore _firestore;

  SiteRepository(this._firestore);

  Stream<List<SiteModel>> getSites(String orgId) {
    return _firestore
        .collection('sites')
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SiteModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<SiteModel>> getAllSites() {
    return _firestore
        .collection('sites')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => SiteModel.fromFirestore(doc)).toList(),
        );
  }

  Future<void> addSite(SiteModel site) async {
    await _firestore.collection('sites').doc(site.id).set(site.toMap());
  }

  Future<void> updateSite(SiteModel site) async {
    await _firestore.collection('sites').doc(site.id).update(site.toMap());
  }

  Future<void> deleteSite(String siteId) async {
    await _firestore.collection('sites').doc(siteId).delete();
  }
}
