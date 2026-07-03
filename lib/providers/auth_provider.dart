import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/activity_log_service.dart';
import 'package:guard_monitoring/models/user_model.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final userModelProvider = StateProvider<UserModel?>((ref) => null);

final userDataProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return Stream.value(null);

  // Return the stream from repository
  return ref.watch(authRepositoryProvider).watchUserData(authState.uid);
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Stream<UserModel?> watchUserData(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? UserModel.fromMap(snapshot.data()!) : null,
        );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? orgId,
    String? orgName,
  }) async {
    final userCredential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 15));

    if (role == UserRole.superAdmin) {
      final snapshot = await _firestore.collection('users').where('role', isEqualTo: UserRole.superAdmin.name).get();
      if (snapshot.docs.length >= 3) {
        await userCredential.user?.delete();
        throw Exception('System maximum limit of 3 Super Admins has been reached.');
      }
    }

    final userModel = UserModel(
      id: userCredential.user!.uid,
      email: email,
      name: name,
      role: role,
      orgId: orgId,
      orgName: orgName,
      isApproved: role == UserRole.admin || role == UserRole.superAdmin ? true : false,
      isActive: true,
      permissions: role == UserRole.admin
          ? {
              'manageSites': true,
              'manageGuards': true,
              'resolveIncidents': true,
              'sendAlerts': true,
              'viewReports': true,
            }
          : null,
    );

    // Save to users collection
    await _firestore
        .collection('users')
        .doc(userModel.id)
        .set(userModel.toMap());

    // If it's an organization, also add to organizations collection for discovery
    if (role == UserRole.admin) {
      await _firestore.collection('organizations').doc(userModel.id).set({
        'id': userModel.id,
        'name': userModel.name,
      });
    }

    // Log action
    await ActivityLogService.log(
      action: 'SIGNUP',
      details: 'User self-registered: ${userModel.name} as ${userModel.role.name}',
      userId: userModel.id,
      userEmail: userModel.email,
      userName: userModel.name,
      userRole: userModel.role.name,
    );
  }

  Future<void> createSupervisorAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryAuthApp_Sup_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final userCredential = await FirebaseAuth.instanceFor(
        app: secondaryApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      final userModel = UserModel(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        role: UserRole.admin,
        isApproved: true,
        isActive: true,
        permissions: {
          'manageSites': true,
          'manageGuards': true,
          'resolveIncidents': true,
          'sendAlerts': true,
          'viewReports': true,
        },
      );

      // Save to users collection
      await _firestore
          .collection('users')
          .doc(userModel.id)
          .set(userModel.toMap());

      // Add to organizations collection
      await _firestore.collection('organizations').doc(userModel.id).set({
        'id': userModel.id,
        'name': userModel.name,
      });

      // Log action
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final currentAdmin = await getUserData(currentUser.uid);
        if (currentAdmin != null) {
          await ActivityLogService.log(
            action: 'CREATE_SUPERVISOR',
            details: 'Created supervisor account: ${userModel.name} (${userModel.email})',
            userId: currentAdmin.id,
            userEmail: currentAdmin.email,
            userName: currentAdmin.name,
            userRole: currentAdmin.role.name,
          );
        }
      }
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> createGuardAccount({
    required String email,
    required String password,
    required String name,
    required String orgId,
    required String orgName,
  }) async {
    // Use a secondary app instance so the currently logged-in Admin is not signed out
    final secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryAuthApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final userCredential = await FirebaseAuth.instanceFor(
        app: secondaryApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      final userModel = UserModel(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        role: UserRole.guard,
        orgId: orgId,
        orgName: orgName,
        isApproved: true, // Auto-approved since created by Admin/Supervisor
        isActive: true,
      );

      // Write to firestore using the primary default instance
      await _firestore
          .collection('users')
          .doc(userModel.id)
          .set(userModel.toMap());

      // Log action
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final currentAdmin = await getUserData(currentUser.uid);
        if (currentAdmin != null) {
          await ActivityLogService.log(
            action: 'CREATE_GUARD',
            details: 'Created guard account: ${userModel.name} (${userModel.email}) assigned to organization ${orgName}',
            userId: currentAdmin.id,
            userEmail: currentAdmin.email,
            userName: currentAdmin.name,
            userRole: currentAdmin.role.name,
          );
        }
      }
    } finally {
      // Clean up the secondary instance to prevent memory leaks / errors
      await secondaryApp.delete();
    }
  }

  Stream<List<Map<String, String>>> watchOrganizations() {
    return _firestore
        .collection('organizations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': (data['name'] as String?) ?? 'Unknown Organization',
            };
          }).toList(),
        );
  }

  Future<void> approvePersonnel(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isApproved': true,
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final currentAdmin = await getUserData(currentUser.uid);
      final targetUser = await getUserData(userId);
      if (currentAdmin != null && targetUser != null) {
        await ActivityLogService.log(
          action: 'APPROVE_PERSONNEL',
          details: 'Approved personnel registration: ${targetUser.name}',
          userId: currentAdmin.id,
          userEmail: currentAdmin.email,
          userName: currentAdmin.name,
          userRole: currentAdmin.role.name,
        );
      }
    }
  }

  Future<void> deleteGuard(String userId) async {
    final targetUser = await getUserData(userId);
    await _firestore.collection('users').doc(userId).delete();

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final currentAdmin = await getUserData(currentUser.uid);
      if (currentAdmin != null && targetUser != null) {
        await ActivityLogService.log(
          action: 'DELETE_GUARD',
          details: 'Deleted guard account: ${targetUser.name} (${targetUser.email})',
          userId: currentAdmin.id,
          userEmail: currentAdmin.email,
          userName: currentAdmin.name,
          userRole: currentAdmin.role.name,
        );
      }
    }
  }

  Future<void> deleteSuperAdmin(String userId) async {
    final targetUser = await getUserData(userId);
    await _firestore.collection('users').doc(userId).delete();

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final currentAdmin = await getUserData(currentUser.uid);
      if (currentAdmin != null && targetUser != null) {
        await ActivityLogService.log(
          action: 'DELETE_SUPERADMIN',
          details: 'Deleted system administrator account: ${targetUser.name} (${targetUser.email})',
          userId: currentAdmin.id,
          userEmail: currentAdmin.email,
          userName: currentAdmin.name,
          userRole: currentAdmin.role.name,
        );
      }
      if (currentUser.uid == userId) {
        // If they deleted themselves, sign out
        await signOut();
      }
    }
  }

  Future<void> toggleUserActiveStatus(String userId, bool active) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': active,
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final currentAdmin = await getUserData(currentUser.uid);
      final targetUser = await getUserData(userId);
      if (currentAdmin != null && targetUser != null) {
        await ActivityLogService.log(
          action: active ? 'ACTIVATE_USER' : 'DEACTIVATE_USER',
          details: '${active ? "Activated" : "Deactivated"} user: ${targetUser.name} (${targetUser.email})',
          userId: currentAdmin.id,
          userEmail: currentAdmin.email,
          userName: currentAdmin.name,
          userRole: currentAdmin.role.name,
        );
      }
    }
  }

  Future<void> updateSupervisorPermissions(String userId, Map<String, bool> permissions) async {
    await _firestore.collection('users').doc(userId).update({
      'permissions': permissions,
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final currentAdmin = await getUserData(currentUser.uid);
      final targetUser = await getUserData(userId);
      if (currentAdmin != null && targetUser != null) {
        await ActivityLogService.log(
          action: 'UPDATE_PERMISSIONS',
          details: 'Updated permissions for supervisor: ${targetUser.name} to $permissions',
          userId: currentAdmin.id,
          userEmail: currentAdmin.email,
          userName: currentAdmin.name,
          userRole: currentAdmin.role.name,
        );
      }
    }
  }

  Future<void> editSupervisor({
    required String userId,
    required String name,
    required String email,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'name': name,
      'email': email,
    });
    await _firestore.collection('organizations').doc(userId).update({
      'name': name,
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final currentAdmin = await getUserData(currentUser.uid);
      if (currentAdmin != null) {
        await ActivityLogService.log(
          action: 'EDIT_SUPERVISOR',
          details: 'Edited supervisor profile: $name ($email)',
          userId: currentAdmin.id,
          userEmail: currentAdmin.email,
          userName: currentAdmin.name,
          userRole: currentAdmin.role.name,
        );
      }
    }
  }

  Future<void> deleteSupervisor(String userId) async {
    final targetUser = await getUserData(userId);
    await _firestore.collection('users').doc(userId).delete();
    await _firestore.collection('organizations').doc(userId).delete();

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final currentAdmin = await getUserData(currentUser.uid);
      if (currentAdmin != null && targetUser != null) {
        await ActivityLogService.log(
          action: 'DELETE_SUPERVISOR',
          details: 'Deleted supervisor account: ${targetUser.name} (${targetUser.email})',
          userId: currentAdmin.id,
          userEmail: currentAdmin.email,
          userName: currentAdmin.name,
          userRole: currentAdmin.role.name,
        );
      }
    }
  }

  Stream<List<UserModel>> getAllSupervisors() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.admin.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<UserModel>> getAllGuards() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.guard.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<UserModel>> getPendingPersonnel(String orgId) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.guard.name)
        .where('orgId', isEqualTo: orgId)
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> signIn(String email, String password) async {
    final userCredential = await _auth
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 15));

    final userModel = await getUserData(userCredential.user!.uid);
    if (userModel != null) {
      await ActivityLogService.log(
        action: 'LOGIN',
        details: 'User logged in: ${userModel.name}',
        userId: userModel.id,
        userEmail: userModel.email,
        userName: userModel.name,
        userRole: userModel.role.name,
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final userModel = await getUserData(currentUser.uid);
      if (userModel != null) {
        await ActivityLogService.log(
          action: 'LOGOUT',
          details: 'User logged out: ${userModel.name}',
          userId: userModel.id,
          userEmail: userModel.email,
          userName: userModel.name,
          userRole: userModel.role.name,
        );
      }
    }
    await _auth.signOut();
  }

  Stream<List<UserModel>> getPersonnel(String orgId) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.guard.name)
        .where('orgId', isEqualTo: orgId)
        .where('isApproved', isEqualTo: true) // Only approved personnel
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList(),
        );
  }
}

final personnelStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(userDataProvider).value;
  if (user == null) return const Stream.empty();
  
  if (user.role == UserRole.superAdmin) {
    return ref.watch(authRepositoryProvider).getAllGuards();
  }
  return ref.watch(authRepositoryProvider).getPersonnel(user.id);
});

final pendingPersonnelStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(userDataProvider).value;
  if (user == null) return const Stream.empty();
  
  if (user.role == UserRole.superAdmin) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: UserRole.guard.name)
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList());
  }
  return ref.watch(authRepositoryProvider).getPendingPersonnel(user.id);
});

final organizationsStreamProvider = StreamProvider<List<Map<String, String>>>((
  ref,
) {
  return ref.watch(authRepositoryProvider).watchOrganizations();
});

final allSupervisorsStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).getAllSupervisors();
});

final allGuardsStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).getAllGuards();
});

final allUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).getAllUsers();
});

