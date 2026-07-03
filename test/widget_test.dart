import 'package:flutter_test/flutter_test.dart';
import 'package:guard_monitoring/models/user_model.dart';

void main() {
  group('UserRole & UserModel Tests', () {
    test('UserRoleExtension returns correct display names', () {
      expect(UserRole.superAdmin.displayName, 'System Admin');
      expect(UserRole.admin.displayName, 'Supervisor');
      expect(UserRole.guard.displayName, 'Guard');
    });

    test('UserModel.fromMap correctly parses roles from strings', () {
      final user1 = UserModel.fromMap({
        'id': '1',
        'email': 'admin@system.com',
        'name': 'SysAdmin',
        'role': 'superAdmin',
      });
      expect(user1.role, UserRole.superAdmin);

      final user2 = UserModel.fromMap({
        'id': '2',
        'email': 'super@org.com',
        'name': 'Supervisor',
        'role': 'admin',
      });
      expect(user2.role, UserRole.admin);

      final user3 = UserModel.fromMap({
        'id': '3',
        'email': 'guard@org.com',
        'name': 'Guard',
        'role': 'guard',
      });
      expect(user3.role, UserRole.guard);
    });

    test('UserModel.fromMap handles legacy integer roles', () {
      final userLegacy1 = UserModel.fromMap({
        'id': '1',
        'email': 'admin@system.com',
        'name': 'SysAdmin',
        'role': 2,
      });
      expect(userLegacy1.role, UserRole.superAdmin);

      final userLegacy2 = UserModel.fromMap({
        'id': '2',
        'email': 'super@org.com',
        'name': 'Supervisor',
        'role': 0,
      });
      expect(userLegacy2.role, UserRole.admin);

      final userLegacy3 = UserModel.fromMap({
        'id': '3',
        'email': 'guard@org.com',
        'name': 'Guard',
        'role': 1,
      });
      expect(userLegacy3.role, UserRole.guard);
    });
  });
}
