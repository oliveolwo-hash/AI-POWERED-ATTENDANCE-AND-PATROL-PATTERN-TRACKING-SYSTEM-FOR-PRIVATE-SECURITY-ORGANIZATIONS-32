import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/core/constants.dart';
import 'package:guard_monitoring/features/auth/login_screen.dart';

import 'package:guard_monitoring/features/auth/account_deactivated_screen.dart';
import 'package:guard_monitoring/features/dashboard/organization_dashboard.dart';
import 'package:guard_monitoring/features/dashboard/personnel_dashboard.dart';
import 'package:guard_monitoring/features/dashboard/super_admin_dashboard.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'firebase_options.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/components/dashboard_background.dart';
import 'package:guard_monitoring/providers/settings_provider.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();



  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardTrack',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authStateProvider);

    return authStateAsync.when(
      data: (user) {
        if (user == null) return const LoginScreen();

        // If logged in, watch user data
        final userDataAsync = ref.watch(userDataProvider);
        return userDataAsync.when(
          data: (userModel) {
            if (userModel == null) {
              // This can happen if auth is OK but document is deleted/not yet created
              return const LoadingScreen(message: 'Profile not found...');
            }

            // Check if user is active
            if (!userModel.isActive) {
              return const AccountDeactivatedScreen();
            }

            if (userModel.role == UserRole.guard && !userModel.isApproved) {
              return const WaitingForApprovalScreen();
            }

            Widget dashboardWidget;

            if (userModel.role == UserRole.superAdmin) {
              dashboardWidget = const SuperAdminDashboard();
            } else if (userModel.role == UserRole.admin) {
              dashboardWidget = const AdminDashboard();
            } else {
              dashboardWidget = const GuardDashboard();
            }

            return ref.watch(globalSettingsProvider).when(
              data: (settings) {
                final isLockdown = settings.lockdownActive ?? false;
                final isSuperAdmin = userModel.role == UserRole.superAdmin;

                if (isLockdown && !isSuperAdmin) {
                  return Theme(
                    data: AppTheme.lightTheme,
                    child: Scaffold(
                      backgroundColor: Colors.red.shade900,
                      body: Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                            ],
                          ),
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.gpp_bad, size: 80, color: Colors.red),
                              const SizedBox(height: 24),
                              const Text(
                                'SYSTEM LOCKDOWN ACTIVE',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red, letterSpacing: 1.2),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                settings.lockdownMessage ?? 'The system has been locked down by the administrator. Please await further instructions.',
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                                icon: const Icon(Icons.logout),
                                label: const Text('Sign Out'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Theme(
                  data: AppTheme.lightTheme,
                  child: dashboardWidget,
                );
              },
              loading: () => const LoadingScreen(message: 'Checking system status...'),
              error: (e, stack) => const LoadingScreen(message: 'Loading system status...'),
            );
          },
          loading: () =>
              const LoadingScreen(message: 'Connecting to Database...'),
          error: (e, stack) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
                  const SizedBox(height: 24),
                  const Text(
                    'Database Sync Issue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('We can verify your login, but not your profile.'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('Return to Login'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const LoadingScreen(message: 'Verifying Security...'),
      error: (e, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Authentication Service Error'),
              Text(e.toString()),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.invalidate(authStateProvider),
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends ConsumerStatefulWidget {
  final String message;
  const LoadingScreen({
    super.key,
    this.message = 'Initializing Secure Session...',
  });

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  bool _showCancel = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _showCancel = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: AppTheme.secondaryColor),
            const SizedBox(height: 24),
            Text(
              'GuardTrack',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
            Text(widget.message),
            if (_showCancel) ...[
              const SizedBox(height: 32),
              const Text(
                'This is taking longer than expected.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Cancel & Return to Login'),
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WaitingForApprovalScreen extends ConsumerWidget {
  const WaitingForApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                'Account Pending',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account has been created successfully. Your organization needs to approve your account before you can start monitoring.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
