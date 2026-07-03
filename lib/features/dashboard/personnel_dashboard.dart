import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/location_service.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/occurrence_book_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/shift_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'package:guard_monitoring/providers/alert_provider.dart';
import 'package:guard_monitoring/providers/incident_provider.dart';
import 'package:guard_monitoring/providers/settings_provider.dart';
import 'package:guard_monitoring/models/alert_model.dart';
import 'package:guard_monitoring/models/incident_model.dart';
import 'package:guard_monitoring/features/incidents/report_incident_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GuardDashboard extends ConsumerStatefulWidget {
  const GuardDashboard({super.key});

  @override
  ConsumerState<GuardDashboard> createState() => _GuardDashboardState();
}

class _GuardDashboardState extends ConsumerState<GuardDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    final globalSettings = ref.watch(globalSettingsProvider).value;

    final lockdownActive = globalSettings?.lockdownActive ?? false;
    final lockdownBanner = lockdownActive
        ? Container(
            color: Colors.red.shade900,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    globalSettings?.lockdownMessage ?? 'SYSTEM LOCKDOWN ACTIVE: Please proceed to safety!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LOCKDOWN ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                userData != null
                    ? userData.name.substring(0, 2).toUpperCase()
                    : '??',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userData?.name ?? 'Loading...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (userData != null)
                  Text(
                    'Guard',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final alertsAsync = ref.watch(alertsStreamProvider);
              return alertsAsync.when(
                data: (alerts) {
                  final unreadCount = alerts
                      .where(
                        (a) =>
                            !a.isRead &&
                            (a.targetId == 'all' || a.targetId == userData?.id),
                      )
                      .length;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        onPressed: () => setState(
                          () => _selectedIndex = 3,
                        ), // Navigate to Alerts tab
                        icon: const Icon(
                          Icons.notifications_none_outlined,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.dangerColor,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const IconButton(
                  onPressed: null,
                  icon: Icon(
                    Icons.notifications_none_outlined,
                    color: Colors.grey,
                  ),
                ),
                error: (_, __) => const Icon(Icons.error_outline),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout, color: Colors.grey),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (lockdownBanner != null) lockdownBanner,
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _ActiveShiftTab(),
                _GuardScheduleTab(),
                _AttendanceHistoryTab(),
                _GuardAlertsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Active',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// ACTIVE SHIFT TAB
// ------------------------------------------------------------------
class _ActiveShiftTab extends ConsumerStatefulWidget {
  const _ActiveShiftTab();

  @override
  ConsumerState<_ActiveShiftTab> createState() => _ActiveShiftTabState();
}

class _ActiveShiftTabState extends ConsumerState<_ActiveShiftTab>
    with SingleTickerProviderStateMixin {
  final _locationService = LocationService();
  late Timer _timer;
  late AnimationController _pulseController;
  DateTime _currentTime = DateTime.now();
  bool? _lastOnSiteStatus; // To detect transitions
  bool _isAutoCheckingOut = false; // Prevent checkout race conditions

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _locationService.stopTracking();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  double _getShiftProgress(ShiftModel shift) {
    if (shift.actualCheckIn == null) return 0.0;

    final total = shift.endTime.difference(shift.startTime).inSeconds;
    if (total <= 0) return 0.0;

    final elapsed = _currentTime.difference(shift.actualCheckIn!).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Future<void> _handleCheckIn(ShiftModel shift, SiteModel site) async {
    if (_currentTime.isBefore(shift.startTime)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You cannot check in before your shift time has reached.',
            ),
          ),
        );
      return;
    }

    final hasPermission = await _locationService.handleLocationPermission();
    if (!hasPermission) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')),
        );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final distance = const Distance().as(
        LengthUnit.Meter,
        LatLng(position.latitude, position.longitude),
        LatLng(site.latitude, site.longitude),
      );

      final isOnSite = distance <= site.radius;

      if (!isOnSite) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.location_off, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Currently not on site', style: TextStyle(color: Colors.red)),
                ],
              ),
              content: const Text(
                'You must be physically within the geofence of your assigned site to check in.',
                style: TextStyle(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retrieve location: $e')),
        );
      }
      return;
    }

    if (shift.status == 'paused') {
      await ref.read(shiftRepositoryProvider).updateShiftStatus(shift.id, 'in_progress');
    } else {
      await ref.read(shiftRepositoryProvider).checkIn(shift.id, DateTime.now());
    }
    
    _locationService.startTracking(
      site: site,
      onStatusChange: (isOnSite) {
        // Only update Firestore if the status actually changes
        if (isOnSite != _lastOnSiteStatus) {
          _lastOnSiteStatus = isOnSite;
          ref
              .read(shiftRepositoryProvider)
              .updateOnSiteStatus(shift.id, isOnSite);
        }
      },
      onLocationUpdate: (position) {
        ref
            .read(shiftRepositoryProvider)
            .updateLocation(shift.id, position.latitude, position.longitude);
      },
    );
  }

  Future<void> _handleCheckOut(ShiftModel shift) async {
    if (_currentTime.isBefore(shift.endTime)) {
      // Pause shift instead of finishing it if checking out early
      await ref.read(shiftRepositoryProvider).updateShiftStatus(shift.id, 'paused');
    } else {
      // Permanent check out
      await ref.read(shiftRepositoryProvider).checkOut(shift.id, DateTime.now());
    }
    _lastOnSiteStatus = null;
    _locationService.stopTracking();
  }

  @override
  Widget build(BuildContext context) {
    final activeShiftAsync = ref.watch(activeShiftProvider);

    return activeShiftAsync.when(
      data: (shift) {
        if (shift == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No active shift currently assigned.'),
                const SizedBox(height: 8),
                Text(
                  'Check your schedule tab for upcoming shifts.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final siteAsync = ref.watch(siteDetailsProvider(shift.siteId));

        return siteAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => Center(child: Text('Error loading site: $e')),
          data: (siteData) {
            final site =
                siteData ??
                SiteModel(
                  id: 'unknown',
                  orgId: 'unknown',
                  name: 'Unknown Site',
                  address: 'Unknown Address',
                  latitude: 0,
                  longitude: 0,
              );
            final isCheckedIn = shift.actualCheckIn != null && shift.status != 'paused';

            // Auto-resume location tracking if already checked in upon app launch
            if (isCheckedIn && _lastOnSiteStatus == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _lastOnSiteStatus == null) {
                  _lastOnSiteStatus = true; // temporary initial state to prevent loop
                  _locationService.startTracking(
                    site: site,
                    onStatusChange: (isOnSite) {
                      if (isOnSite != _lastOnSiteStatus) {
                        _lastOnSiteStatus = isOnSite;
                        ref.read(shiftRepositoryProvider).updateOnSiteStatus(shift.id, isOnSite);
                      }
                    },
                    onLocationUpdate: (position) {
                      ref.read(shiftRepositoryProvider).updateLocation(shift.id, position.latitude, position.longitude);
                    },
                  );
                }
              });
            }

            // Auto-checkout if shift elapsed
            if (isCheckedIn &&
                shift.actualCheckOut == null &&
                _currentTime.isAfter(shift.endTime) &&
                !_isAutoCheckingOut) {
              _isAutoCheckingOut = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Shift has ended! You have been automatically checked out.',
                      ),
                    ),
                  );
                  _handleCheckOut(shift).whenComplete(() {
                    if (mounted) setState(() => _isAutoCheckingOut = false);
                  });
                }
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Blue Clock Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.secondaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Current Time',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('hh:mm a').format(_currentTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM dd').format(_currentTime),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FadeTransition(
                              opacity: _pulseController,
                              child: ScaleTransition(
                                scale: Tween(
                                  begin: 0.8,
                                  end: 1.2,
                                ).animate(_pulseController),
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isCheckedIn
                                        ? (_lastOnSiteStatus == true ? AppTheme.successColor : Colors.orange)
                                        : Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                                isCheckedIn
                                    ? (_lastOnSiteStatus == true ? 'On Duty' : 'Outside permitted area')
                                    : 'Absent',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isCheckedIn) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Shift Duration',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDuration(
                              _currentTime.difference(shift.actualCheckIn!),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: () => isCheckedIn
                          ? _handleCheckOut(shift)
                          : _handleCheckIn(shift, site),
                      icon: Icon(
                        isCheckedIn
                            ? Icons.access_time_filled
                            : Icons.check_circle_outline,
                        size: 24,
                      ),
                      label: Text(
                        isCheckedIn ? 'Check Out' : 'Check In to Shift',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckedIn
                            ? AppTheme.dangerColor
                            : AppTheme.successColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Assignment Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Assignment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildAssignmentInfo(
                          Icons.location_on_outlined,
                          'Location',
                          site.name,
                        ),
                        const SizedBox(height: 16),
                        _buildAssignmentInfo(
                          Icons.access_time,
                          'Shift Time',
                          '${DateFormat('hh:mm a').format(shift.startTime)} - ${DateFormat('hh:mm a').format(shift.endTime)}',
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Shift Progress',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${(_getShiftProgress(shift) * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _getShiftProgress(shift),
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.secondaryColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.report_gmailerrorred_outlined,
                          label: 'Report Incident',
                          color: AppTheme.dangerColor,
                          onTap: () {
                            if (!isCheckedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You must have checked in to perform this action.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReportIncidentScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error loading assignment: $e')),
    );
  }

  Widget _buildAssignmentInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// SCHEDULE TAB (Remains same as before but with minor styling)
// ------------------------------------------------------------------
final guardScheduleProvider = StreamProvider<List<ShiftModel>>((ref) {
  final user = ref.watch(userDataProvider).value;
  if (user == null || user.orgId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('shifts')
      .where('orgId', isEqualTo: user.orgId)
      .where('personnelId', isEqualTo: user.id)
      .where(
        'endTime',
        isGreaterThanOrEqualTo: DateTime.now().toIso8601String(),
      )
      .orderBy('endTime')
      .snapshots()
      .map((s) => s.docs.map((d) => ShiftModel.fromMap(d.data())).toList());
});

// ------------------------------------------------------------------
// GUARD SCHEDULE TAB
// ------------------------------------------------------------------
class _GuardScheduleTab extends ConsumerWidget {
  const _GuardScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(guardScheduleProvider);

    return scheduleAsync.when(
      data: (shifts) {
        if (shifts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No upcoming shifts assigned yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final totalHours = shifts.fold(
          0.0,
          (sum, s) => sum + s.endTime.difference(s.startTime).inMinutes / 60.0,
        );
        final offDays = 7 - shifts.map((s) => s.startTime.day).toSet().length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Schedule',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                'This week\'s assignments',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4364F7).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _buildSummaryItem(Icons.calendar_today, 'This Week'),
                      const VerticalDivider(color: Colors.white24, width: 32),
                      _buildSummaryMetric(
                        '${totalHours.toInt()}',
                        'Total Hours',
                      ),
                      const VerticalDivider(color: Colors.white24, width: 32),
                      _buildSummaryMetric('${shifts.length}', 'Shifts'),
                      const VerticalDivider(color: Colors.white24, width: 32),
                      _buildSummaryMetric('$offDays', 'Off Days'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ...shifts.map((shift) => _buildScheduleCard(context, shift, ref)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric(String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    ShiftModel shift,
    WidgetRef ref,
  ) {
    final siteAsync = ref.watch(siteDetailsProvider(shift.siteId));
    final durationHrs = shift.endTime.difference(shift.startTime).inHours;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE').format(shift.startTime),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${durationHrs}h',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Text(
            DateFormat('MMM dd, yyyy').format(shift.startTime),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 20),
          siteAsync.when(
            data: (site) => _buildDetailItem(
              Icons.location_on_outlined,
              site?.name ?? 'Unknown Site',
              site?.address ?? 'No Address',
            ),
            loading: () => _buildDetailItem(
              Icons.location_on_outlined,
              'Loading...',
              '...',
            ),
            error: (_, __) =>
                _buildDetailItem(Icons.location_on_outlined, 'Error', 'Error'),
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            Icons.access_time_outlined,
            '${DateFormat('hh:mm A').format(shift.startTime)} - ${DateFormat('hh:mm A').format(shift.endTime)}',
            'Estimated duration: $durationHrs hours',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// ATTENDANCE HISTORY TAB
// ------------------------------------------------------------------
class _AttendanceHistoryTab extends ConsumerWidget {
  const _AttendanceHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allShiftsAsync = ref.watch(allShiftsStreamProvider);
    final user = ref.read(userDataProvider).value;

    return allShiftsAsync.when(
      data: (shifts) {
        // Filter: Only my completed shifts, sorted by date descending
        final history = shifts
            .where((s) => s.personnelId == user?.id && s.actualCheckOut != null)
            .toList();
        history.sort((a, b) => b.startTime.compareTo(a.startTime));

        final last7 = history.take(7).toList();

        // Calculate Stats
        final totalHours = history.fold(0.0, (sum, s) {
          if (s.actualCheckIn != null && s.actualCheckOut != null) {
            return sum +
                s.actualCheckOut!.difference(s.actualCheckIn!).inMinutes / 60.0;
          }
          return sum;
        });

        final totalShifts = history.length;
        final onTimeShifts = history.where((s) {
          // 15-minute grace period
          if (s.actualCheckIn == null) return false;
          return s.actualCheckIn!.isBefore(
            s.startTime.add(const Duration(minutes: 15)),
          );
        }).length;

        final attendanceRate = totalShifts == 0
            ? 0
            : (onTimeShifts / totalShifts * 100).toInt();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance Statistics',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Stats Grid
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    'Total Hours',
                    '${totalHours.toStringAsFixed(1)}h',
                    Icons.alarm,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Total Shifts',
                    '$totalShifts',
                    Icons.fact_check_outlined,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    'Attendance',
                    '$attendanceRate%',
                    Icons.trending_up,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Completed',
                    '${last7.length}',
                    Icons.check_circle_outline,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Recent Records (Last 7)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (last7.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No historical records found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...last7.map((shift) => _buildHistoryItem(context, shift, ref)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    ShiftModel shift,
    WidgetRef ref,
  ) {
    final siteAsync = ref.watch(siteDetailsProvider(shift.siteId));

    // Status Logic
    String status = 'On Time';
    Color statusColor = Colors.green;
    if (shift.actualCheckIn == null) {
      status = 'Absent';
      statusColor = Colors.red;
    } else if (shift.actualCheckIn!.isAfter(
      shift.startTime.add(const Duration(minutes: 15)),
    )) {
      status = 'Late';
      statusColor = Colors.orange;
    }

    final duration = shift.actualCheckIn != null && shift.actualCheckOut != null
        ? shift.actualCheckOut!.difference(shift.actualCheckIn!).inMinutes /
              60.0
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(shift.startTime).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd').format(shift.startTime),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                siteAsync.when(
                  data: (site) => Text(
                    site?.name ?? 'Unknown Site',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  loading: () => const Text(
                    'Loading site...',
                    style: TextStyle(fontSize: 15),
                  ),
                  error: (_, __) => const Text(
                    'Unknown Site',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('hh:mm a').format(shift.actualCheckIn ?? shift.startTime)} - ${DateFormat('hh:mm a').format(shift.actualCheckOut ?? shift.endTime)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${duration.toStringAsFixed(1)} hrs',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// ALERTS TAB (Remains same)
// ------------------------------------------------------------------
class _GuardAlertsTab extends ConsumerWidget {
  const _GuardAlertsTab();

  Color _getPriorityColor(AlertPriority p) {
    switch (p) {
      case AlertPriority.urgent:
        return Colors.red;
      case AlertPriority.warning:
        return Colors.orange;
      case AlertPriority.announcement:
        return Colors.blue;
      case AlertPriority.info:
        return Colors.grey.shade600;
    }
  }

  IconData _getPriorityIcon(AlertPriority p) {
    switch (p) {
      case AlertPriority.urgent:
        return Icons.report_problem;
      case AlertPriority.warning:
        return Icons.warning_amber_rounded;
      case AlertPriority.announcement:
        return Icons.campaign_outlined;
      case AlertPriority.info:
        return Icons.info_outline;
    }
  }

  void _showDeleteAlertConfirmation(
    BuildContext context,
    WidgetRef ref,
    String alertId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Alert'),
        content: const Text(
          'Are you sure you want to permanently delete this alert?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(alertRepositoryProvider).deleteAlert(alertId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsStreamProvider);
    final user = ref.read(userDataProvider).value;

    return alertsAsync.when(
      data: (alerts) {
        // Filter alerts for the current guard (broadcast or targeted)
        final myAlerts = alerts
            .where((a) => a.targetId == 'all' || a.targetId == user?.id)
            .toList();

        final unreadCount = myAlerts.where((a) => !a.isRead).length;
        final needsActionCount = myAlerts
            .where((a) => a.needsAcknowledgment && !a.isAcknowledged)
            .length;

        if (myAlerts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No mission alerts at this time.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Security Alerts & Messages',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$unreadCount unread, $needsActionCount need action',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Unread',
                        unreadCount,
                        Icons.notifications_none,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildSummaryCard(
                        'Action Required',
                        needsActionCount,
                        Icons.warning_amber_rounded,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: myAlerts.length,
                itemBuilder: (context, index) {
                  final alert = myAlerts[index];
                  final color = _getPriorityColor(alert.priority);
                  final isActionable =
                      alert.needsAcknowledgment && !alert.isAcknowledged;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alert Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getPriorityIcon(alert.priority),
                                color: color,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  alert.priority == AlertPriority.urgent
                                      ? 'Critical Update'
                                      : alert.priority.name.toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('hh:mm a').format(alert.timestamp),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                              if (!alert.isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showDeleteAlertConfirmation(
                                  context,
                                  ref,
                                  alert.id,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Alert Content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.message,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'From: ${alert.senderName} (${alert.senderRole})',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (alert.isAcknowledged)
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.green,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Acknowledged',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        if (!alert.isRead || isActionable)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Row(
                              children: [
                                if (alert.needsAcknowledgment &&
                                    !alert.isAcknowledged)
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => ref
                                          .read(alertRepositoryProvider)
                                          .acknowledgeAlert(alert.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Acknowledge'),
                                    ),
                                  ),
                                if (alert.needsAcknowledgment &&
                                    !alert.isAcknowledged)
                                  const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => ref
                                        .read(alertRepositoryProvider)
                                        .markAlertAsRead(alert.id),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Mark as Read',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSummaryCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// OCCURRENCE BOOK LOGS PROVIDER & TAB
// ------------------------------------------------------------------

final guardOccurrenceLogsProvider = StreamProvider<List<OccurrenceBookModel>>((ref) {
  final user = ref.watch(userDataProvider).value;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('occurrence_book')
      .where('guardId', isEqualTo: user.id)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => OccurrenceBookModel.fromFirestore(doc))
          .toList());
});

class _OccurrenceBookTab extends ConsumerStatefulWidget {
  const _OccurrenceBookTab();

  @override
  ConsumerState<_OccurrenceBookTab> createState() => _OccurrenceBookTabState();
}

class _OccurrenceBookTabState extends ConsumerState<_OccurrenceBookTab> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Visitor Check-In',
    'Vehicle Check-In',
    'General Occurrence',
    'Security Check',
    'Emergency Log'
  ];

  void _showAddLogDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final visitorNameController = TextEditingController();
    final visitorCompanyController = TextEditingController();
    final vehicleNumberController = TextEditingController();
    final badgeNumberController = TextEditingController();
    String category = 'General Occurrence';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.menu_book, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('New OB Log Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Log Category'),
                  items: _categories
                      .where((c) => c != 'All')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => category = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Entry Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Detailed Description',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                if (category == 'Visitor Check-In') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: visitorNameController,
                    decoration: const InputDecoration(
                      labelText: 'Visitor Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: visitorCompanyController,
                    decoration: const InputDecoration(
                      labelText: 'Visitor Company / Purpose',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: badgeNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Badge #',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ],
                if (category == 'Vehicle Check-In') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: vehicleNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number Plate',
                      prefixIcon: Icon(Icons.directions_car_filled_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: visitorNameController,
                    decoration: const InputDecoration(
                      labelText: 'Driver / Visitor Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: visitorCompanyController,
                    decoration: const InputDecoration(
                      labelText: 'Company / Purpose',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          descriptionController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in title and description.')),
                        );
                        return;
                      }

                      setModalState(() => isLoading = true);
                      try {
                        final guard = ref.read(userDataProvider).value;
                        if (guard == null) throw Exception('Guard not logged in');

                        final entry = OccurrenceBookModel(
                          id: const Uuid().v4(),
                          guardId: guard.id,
                          guardName: guard.name,
                          orgId: guard.orgId ?? '',
                          timestamp: DateTime.now(),
                          category: category,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          visitorName: visitorNameController.text.trim().isEmpty
                              ? null
                              : visitorNameController.text.trim(),
                          visitorCompany: visitorCompanyController.text.trim().isEmpty
                              ? null
                              : visitorCompanyController.text.trim(),
                          vehicleNumber: vehicleNumberController.text.trim().isEmpty
                              ? null
                              : vehicleNumberController.text.trim(),
                          badgeNumber: badgeNumberController.text.trim().isEmpty
                              ? null
                              : badgeNumberController.text.trim(),
                        );

                        await FirebaseFirestore.instance
                            .collection('occurrence_book')
                            .doc(entry.id)
                            .set(entry.toMap());

                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving entry: $e')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setModalState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obLogsAsync = ref.watch(guardOccurrenceLogsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Occurrence Book (OB Logs)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: AppTheme.primaryColor),
            onPressed: _showAddLogDialog,
            tooltip: 'Add Entry',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search logs...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: obLogsAsync.when(
              data: (logs) {
                final filtered = logs.where((log) {
                  final matchQuery = log.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      log.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (log.visitorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                      (log.vehicleNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                  
                  final matchCategory = _selectedCategory == 'All' || log.category == _selectedCategory;
                  return matchQuery && matchCategory;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No occurrence entries found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    final isVisitor = log.category == 'Visitor Check-In';
                    final isVehicle = log.category == 'Vehicle Check-In';
                    final isEmergency = log.category == 'Emergency Log';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isEmergency
                                        ? Colors.red.shade50
                                        : (isVisitor || isVehicle ? Colors.blue.shade50 : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    log.category.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isEmergency
                                          ? Colors.red
                                          : (isVisitor || isVehicle ? Colors.blue : Colors.black87),
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat('HH:mm - dd MMM').format(log.timestamp),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              log.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              log.description,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                            if (isVisitor) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_pin, color: Colors.blue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Visitor: ${log.visitorName ?? "Unknown"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text('Company: ${log.visitorCompany ?? "N/A"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          if (log.badgeNumber != null)
                                            Text('Badge Assigned: ${log.badgeNumber}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (isVehicle) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_car, color: Colors.blue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Plate Number: ${log.vehicleNumber ?? "Unknown"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text('Driver: ${log.visitorName ?? "Unknown"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text('Company/Purpose: ${log.visitorCompany ?? "N/A"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLogDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
