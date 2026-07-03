import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String details,
    required String userId,
    required String userEmail,
    required String userName,
    required String userRole,
  }) async {
    try {
      await _firestore.collection('activity_logs').add({
        'action': action,
        'details': details,
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'userRole': userRole,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Print locally for debugging, don't crash
      print('Activity log error: $e');
    }
  }
}
