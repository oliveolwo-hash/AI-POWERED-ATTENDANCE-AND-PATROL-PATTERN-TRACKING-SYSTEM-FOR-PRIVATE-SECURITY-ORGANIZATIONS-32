import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';

class GlobalSettings {
  final bool alertsEnabled;
  final bool reportsEnabled;
  final bool analyticsEnabled;
  final bool lockdownActive;
  final String lockdownMessage;

  GlobalSettings({
    required this.alertsEnabled,
    required this.reportsEnabled,
    required this.analyticsEnabled,
    required this.lockdownActive,
    required this.lockdownMessage,
  });

  factory GlobalSettings.fromMap(Map<String, dynamic> map) {
    return GlobalSettings(
      alertsEnabled: map['alertsEnabled'] ?? true,
      reportsEnabled: map['reportsEnabled'] ?? true,
      analyticsEnabled: map['analyticsEnabled'] ?? true,
      lockdownActive: map['lockdownActive'] ?? false,
      lockdownMessage: map['lockdownMessage'] ?? 'SYSTEM LOCKDOWN ACTIVE: Please proceed to safety!',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertsEnabled': alertsEnabled,
      'reportsEnabled': reportsEnabled,
      'analyticsEnabled': analyticsEnabled,
      'lockdownActive': lockdownActive,
      'lockdownMessage': lockdownMessage,
    };
  }
}

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(FirebaseFirestore.instance),
);

final globalSettingsProvider = StreamProvider<GlobalSettings>((ref) {
  // Watch auth state so this stream tears down and rebuilds perfectly on login/logout
  // preventing the stream from getting stuck in a dead/permission denied state.
  ref.watch(authStateProvider);
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

class SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepository(this._firestore);

  Stream<GlobalSettings> watchSettings() {
    return _firestore
        .collection('settings')
        .doc('global')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return GlobalSettings.fromMap(snapshot.data()!);
      }
      return GlobalSettings(
        alertsEnabled: true,
        reportsEnabled: true,
        analyticsEnabled: true,
        lockdownActive: false,
        lockdownMessage: 'SYSTEM LOCKDOWN ACTIVE: Please proceed to safety!',
      );
    });
  }

  Future<void> updateSettings(GlobalSettings settings) async {
    await _firestore.collection('settings').doc('global').set(settings.toMap());
  }

  Future<void> toggleLockdown({required bool active, String? message}) async {
    await _firestore.collection('settings').doc('global').set({
      'lockdownActive': active,
      'lockdownMessage': message ?? 'SYSTEM LOCKDOWN ACTIVE: Please proceed to safety!',
    }, SetOptions(merge: true));
  }

  Future<void> toggleModule({required String moduleKey, required bool enabled}) async {
    await _firestore.collection('settings').doc('global').set({
      moduleKey: enabled,
    }, SetOptions(merge: true));
  }
}
