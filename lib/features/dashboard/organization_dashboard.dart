import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/features/dashboard/real_time_monitoring_screen.dart';
import 'package:guard_monitoring/features/personnel/manage_guards_screen.dart';
import 'package:guard_monitoring/features/reports/pattern_analysis_screen.dart';
import 'package:guard_monitoring/features/reports/reports_analytics_screen.dart';
import 'package:guard_monitoring/features/shifts/shift_assignment_screen.dart';
import 'package:guard_monitoring/features/sites/add_site_screen.dart';
import 'package:guard_monitoring/providers/alert_provider.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'package:guard_monitoring/providers/settings_provider.dart';
import 'package:guard_monitoring/models/alert_model.dart';
import 'package:guard_monitoring/models/incident_model.dart';
import 'package:guard_monitoring/providers/incident_provider.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/models/occurrence_book_model.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class _DashboardItem {
  final IconData icon;
  final String label;
  final Widget page;
  final String? permissionKey;

  const _DashboardItem({
    required this.icon,
    required this.label,
    required this.page,
    this.permissionKey,
  });
}

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    
    final userData = ref.watch(userDataProvider).value;
    final globalSettings = ref.watch(globalSettingsProvider).value;

    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Build the lists of tabs dynamically based on permissions
    final allDestinations = [
      _DashboardItem(
        icon: Icons.location_city,
        label: 'Sites',
        page: const _SitesList(),
        permissionKey: 'manageSites',
      ),
      _DashboardItem(
        icon: Icons.radar,
        label: 'Monitor',
        page: const RealTimeMonitoringScreen(),
      ),
      _DashboardItem(
        icon: Icons.admin_panel_settings,
        label: 'Guards',
        page: const ManageGuardsScreen(),
        permissionKey: 'manageGuards',
      ),
      _DashboardItem(
        icon: Icons.warning,
        label: 'Alerts & Incidents',
        page: const _AlertsAndIncidentsTab(),
        permissionKey: 'resolveIncidents',
      ),
      _DashboardItem(
        icon: Icons.analytics,
        label: 'Reports & Analytics',
        page: const ReportsAnalyticsScreen(),
        permissionKey: 'viewReports',
      ),
      _DashboardItem(
        icon: Icons.psychology,
        label: 'Pattern Analysis',
        page: const PatternAnalysisScreen(),
        permissionKey: 'viewReports',
      ),
    ];

    // Filter by supervisor permissions and global modules
    final allowedDestinations = allDestinations.where((item) {
      if (item.permissionKey != null) {
        final hasPerm = userData.permissions?[item.permissionKey] ?? true;
        if (!hasPerm) return false;
      }
      
      if (globalSettings != null) {
        if (item.label == 'Alerts & Incidents' && !globalSettings.alertsEnabled) {
          return false;
        }
        if (item.label == 'Reports & Analytics' && !globalSettings.reportsEnabled) {
          return false;
        }
        if (item.label == 'Pattern Analysis' && !globalSettings.analyticsEnabled) {
          return false;
        }
      }
      return true;
    }).toList();

    int selectedIndex = _selectedIndex;
    if (selectedIndex >= allowedDestinations.length) {
      selectedIndex = 0;
    }

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
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Supervisor Dashboard'),
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                    ),
                    child: const Text(
                      'Supervisor Controls',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  for (int i = 0; i < allowedDestinations.length; i++)
                    _buildDrawerItem(
                      i,
                      allowedDestinations[i].icon,
                      allowedDestinations[i].label,
                      selectedIndex,
                    ),
                ],
              ),
            ),
      body: Column(
        children: [
          if (lockdownBanner != null) lockdownBanner,
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  NavigationRail(
                    extended: MediaQuery.of(context).size.width >= 1000,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() => _selectedIndex = index);
                    },
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.security,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                          if (MediaQuery.of(context).size.width >= 1000)
                            const Text(
                              'Supervisor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () =>
                                ref.read(authRepositoryProvider).signOut(),
                            tooltip: 'Log Out',
                          ),
                        ),
                      ),
                    ),
                    destinations: allowedDestinations
                        .map((dest) => NavigationRailDestination(
                              icon: Icon(dest.icon),
                              label: Text(dest.label),
                            ))
                        .toList(),
                  ),
                if (isDesktop) const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: allowedDestinations.isEmpty
                      ? const Center(
                          child: Text('You do not have access to any modules.'),
                        )
                      : IndexedStack(
                          index: selectedIndex,
                          children: allowedDestinations
                              .map((dest) => dest.page)
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(
    int index,
    IconData icon,
    String title,
    int selectedIndex,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selectedIndex == index,
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context); // Close drawer
      },
    );
  }
}

class _AlertsAndIncidentsTab extends StatelessWidget {
  const _AlertsAndIncidentsTab();

  @override
  Widget build(BuildContext context) {
    return const _UnifiedManagementFeed();
  }
}

// -------------------------------------------------------------
// UNIFIED MANAGEMENT FEED
// -------------------------------------------------------------

class _UnifiedManagementFeed extends ConsumerStatefulWidget {
  const _UnifiedManagementFeed();

  @override
  ConsumerState<_UnifiedManagementFeed> createState() =>
      _UnifiedManagementFeedState();
}

class _UnifiedManagementFeedState
    extends ConsumerState<_UnifiedManagementFeed> {
  IncidentPriority? _priorityFilter;
  IncidentStatus? _statusFilter;

  Color _getPriorityColor(IncidentModel item) {
    switch (item.priority) {
      case IncidentPriority.critical:
        return AppTheme.dangerColor;
      case IncidentPriority.high:
        return AppTheme.warningColor;
      case IncidentPriority.medium:
        return AppTheme.warningColor; // Can tweak if needed
      case IncidentPriority.low:
        return AppTheme.secondaryColor;
    }
  }

  Color _getStatusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.resolved:
        return AppTheme.successColor;
      case IncidentStatus.investigating:
        return AppTheme.secondaryColor;
      case IncidentStatus.pending:
        return AppTheme.warningColor;
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showResolveDialog(IncidentModel incident) {
    final notesController = TextEditingController();
    IncidentStatus selectedStatus = IncidentStatus.resolved;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Resolve Incident'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<IncidentStatus>(
                value: selectedStatus,
                isExpanded: true,
                items: IncidentStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setModalState(() => selectedStatus = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  hintText: 'Add internal resolution notes...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = ref.read(userDataProvider).value;
                await ref
                    .read(incidentRepositoryProvider)
                    .resolveIncident(
                      incidentId: incident.id,
                      resolutionNotes: notesController.text.trim(),
                      resolvedBy: user?.name ?? 'Admin',
                      status: selectedStatus,
                    );
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteIncidentConfirmation(IncidentModel incident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Incident Report'),
        content: const Text(
          'Are you sure you want to permanently delete this incident? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(incidentRepositoryProvider)
                  .deleteIncident(incident.id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPhotoAttachment(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    padding: const EdgeInsets.all(100),
                    color: Colors.white,
                    child: const CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(100),
                  color: Colors.white,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.red,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Error loading evidence',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
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
          'Are you sure you want to permanently delete this alert? It will be removed for all users.',
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

  void _showAlertHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final alertsAsync = ref.watch(alertsStreamProvider);
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.history, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Broadcast History'),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: alertsAsync.when(
                data: (alerts) {
                  if (alerts.isEmpty)
                    return const Center(child: Text('No past broadcasts.'));
                  return ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (ctx, idx) => const Divider(),
                    itemBuilder: (ctx, idx) {
                      final alert = alerts[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: const Icon(
                            Icons.campaign,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          alert.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Sent ${_timeAgo(alert.timestamp)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BROADCAST',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () => _showDeleteAlertConfirmation(
                                context,
                                ref,
                                alert.id,
                              ),
                              tooltip: 'Delete Alert',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(
    IconData icon,
    Color color,
    String title,
    int count,
    String subtitle,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(incidentsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Monitoring',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            Text(
              'Incident Resolution & Dispatch Center',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.campaign, color: AppTheme.primaryColor),
            tooltip: 'Broadcast Center',
            onSelected: (val) {
              if (val == 'history') {
                _showAlertHistoryDialog(context);
              } else if (val == 'send') {
                _showSendAlertDialog(context, ref);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20),
                    SizedBox(width: 12),
                    Text('View Recent Alerts'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'send',
                child: Row(
                  children: [
                    Icon(
                      Icons.add_alert,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Send New Alert',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: incidentsAsync.when(
        data: (incidents) {
          // Metrics (Incident Only)
          final pendingCount = incidents
              .where((i) => i.status == IncidentStatus.pending)
              .length;
          final investigatingCount = incidents
              .where((i) => i.status == IncidentStatus.investigating)
              .length;
          final resolvedCount = incidents
              .where((i) => i.status == IncidentStatus.resolved)
              .length;
          final totalIncidents = incidents.length;

          // Filtered list
          final filtered = incidents.where((i) {
            final pMatch =
                _priorityFilter == null ||
                i.priority.name == _priorityFilter?.name;
            final sMatch = _statusFilter == null || i.status == _statusFilter;
            return pMatch && sMatch;
          }).toList();
          filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildMetricCard(
                      Icons.report_problem,
                      Colors.orange,
                      'Pending',
                      pendingCount,
                      'Needs Review',
                    ),
                    _buildMetricCard(
                      Icons.manage_search,
                      Colors.blue,
                      'Working',
                      investigatingCount,
                      'Investigations',
                    ),
                    _buildMetricCard(
                      Icons.check_circle,
                      Colors.green,
                      'Resolved',
                      resolvedCount,
                      'Closed Reports',
                    ),
                    _buildMetricCard(
                      Icons.assignment,
                      Colors.blueGrey,
                      'Total',
                      totalIncidents,
                      'Hist. Incidents',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Incident Management Feed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pendingCount PENDING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (incidents.any(
                      (i) =>
                          i.priority == IncidentPriority.high &&
                          i.status != IncidentStatus.resolved,
                    )) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'CRITICAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Status Filter
                    DropdownButtonHideUnderline(
                      child: DropdownButton<IncidentStatus?>(
                        value: _statusFilter,
                        hint: const Text(
                          'Status',
                          style: TextStyle(fontSize: 12),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Status'),
                          ),
                          ...IncidentStatus.values.map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s.name.toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => _statusFilter = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Priority Filter
                    DropdownButtonHideUnderline(
                      child: DropdownButton<IncidentPriority?>(
                        value: _priorityFilter,
                        hint: const Text(
                          'Priority',
                          style: TextStyle(fontSize: 12),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Priorities'),
                          ),
                          ...IncidentPriority.values.map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.name.toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _priorityFilter = val),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No incidents match your filters.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, idx) =>
                            const Divider(height: 32),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final color = _getPriorityColor(item);
                          final statusColor = _getStatusColor(item.status);

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.report,
                                  color: color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.type.name.toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.status.name.toUpperCase(),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _timeAgo(item.timestamp),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.location,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        const Icon(
                                          Icons.person_outline,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Reporter: Guard',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.photoUrl != null && item.photoUrl!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => Dialog(
                                              child: Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  Image.network(item.photoUrl!, fit: BoxFit.contain),
                                                  IconButton(
                                                    icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                                                    onPressed: () => Navigator.pop(ctx),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            item.photoUrl!,
                                            height: 100,
                                            width: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              height: 100,
                                              width: 100,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        if (item.status !=
                                            IncidentStatus.resolved)
                                          ElevatedButton(
                                            onPressed: () =>
                                                _showResolveDialog(item),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                              'Update Status / Resolve',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (item.photoUrl != null) ...[
                                          const SizedBox(width: 12),
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _showPhotoAttachment(
                                                  context,
                                                  item.photoUrl!,
                                                ),
                                            icon: const Icon(
                                              Icons.image_outlined,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'View Evidence',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () =>
                                              _showDeleteIncidentConfirmation(
                                                item,
                                              ),
                                          tooltip: 'Delete Report',
                                        ),
                                      ],
                                    ),
                                    if (item.status ==
                                            IncidentStatus.resolved &&
                                        item.resolutionNotes != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.all(10),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(
                                              0.1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Resolution Notes: ${item.resolutionNotes}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showSendAlertDialog(BuildContext context, WidgetRef ref) {
    final messageController = TextEditingController();
    final senderNameController = TextEditingController(
      text: ref.read(userDataProvider).value?.name ?? 'Admin',
    );
    final senderRoleController = TextEditingController(
      text: 'Operations Center',
    );
    AlertPriority selectedPriority = AlertPriority.info;
    bool needsAcknowledgment = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Broadcast Command Alert'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Priority Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                DropdownButton<AlertPriority>(
                  value: selectedPriority,
                  isExpanded: true,
                  items: AlertPriority.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => selectedPriority = val!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sender Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                TextField(
                  controller: senderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Sender Name',
                    hintText: 'e.g. Security Manager',
                  ),
                ),
                TextField(
                  controller: senderRoleController,
                  decoration: const InputDecoration(
                    labelText: 'Department/Role',
                    hintText: 'e.g. Operations',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    hintText: 'Enter broadcast details...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text(
                    'Require Acknowledgment',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: needsAcknowledgment,
                  onChanged: (val) =>
                      setModalState(() => needsAcknowledgment = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (messageController.text.trim().isEmpty) return;
                final userData = ref.read(userDataProvider).value;
                if (userData == null) return;

                final alert = AlertModel(
                  id: const Uuid().v4(),
                  personnelId: userData.id,
                  targetId: 'all',
                  siteId: '',
                  orgId: userData.id,
                  message: messageController.text.trim(),
                  type: AlertType.adminMessage,
                  priority: selectedPriority,
                  timestamp: DateTime.now(),
                  senderName: senderNameController.text.trim(),
                  senderRole: senderRoleController.text.trim(),
                  needsAcknowledgment: needsAcknowledgment,
                );

                await ref.read(alertRepositoryProvider).sendAlert(alert);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Broadcast Alert'),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// OLD REPLACED TABS (Now consolidated above)
// -------------------------------------------------------------

class _SitesList extends ConsumerStatefulWidget {
  const _SitesList();

  @override
  ConsumerState<_SitesList> createState() => _SitesListState();
}

class _SitesListState extends ConsumerState<_SitesList> {
  String _selectedType = 'All';
  bool _showInactive = false;
  final List<String> _types = [
    'All',
    'Commercial',
    'Residential',
    'Industrial',
    'Government',
    'Retail',
    'Other',
  ];

  void _deleteSiteWithConfirmation(String siteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Managed Site'),
        content: const Text(
          'Are you sure you want to completely delete this site? All associated guard assignments must be cancelled manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(siteRepositoryProvider).deleteSite(siteId);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site deleted successfully.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Managed Sites'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedType,
                      icon: const Icon(Icons.filter_list),
                      items: _types
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Text(
                      'Show Inactive',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Switch(
                      value: _showInactive,
                      onChanged: (val) => setState(() => _showInactive = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sitesAsync.when(
              data: (sites) {
                final currentUserId = ref.read(userDataProvider).value?.id;
                final supervisorSites = sites.where((s) => s.orgId == currentUserId).toList();

                final filteredSites = supervisorSites.where((s) {
                  final matchesType =
                      _selectedType == 'All' || s.type == _selectedType;
                  final matchesActive = _showInactive || s.isActive;
                  return matchesType && matchesActive;
                }).toList();

                if (filteredSites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('You have not been assigned any sites yet.'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filteredSites.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final site = filteredSites[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: site.isActive
                              ? Colors.transparent
                              : Colors.red.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        site.name,
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        site.type,
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (!site.isActive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'INACTIVE',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: site.isActive
                                      ? AppTheme.secondaryColor
                                      : Colors.grey,
                                  child: const Icon(
                                    Icons.location_city,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        site.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        site.address,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      site.isGeofenceEnabled
                                          ? Icons.gps_fixed
                                          : Icons.gps_off,
                                      size: 16,
                                      color: site.isGeofenceEnabled
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      site.isGeofenceEnabled
                                          ? '${site.radius.toInt()}m Boundary'
                                          : 'No Geofence',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) =>
                  Center(child: Text('Error loading sites: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// Consolidated into _UnifiedManagementFeed above.

class _SupervisorOBLogsTab extends ConsumerStatefulWidget {
  const _SupervisorOBLogsTab();

  @override
  ConsumerState<_SupervisorOBLogsTab> createState() => _SupervisorOBLogsTabState();
}

class _SupervisorOBLogsTabState extends ConsumerState<_SupervisorOBLogsTab> {
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

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    if (userData == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Occurrence Book (OB Logs)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black),
            ),
            Text(
              'Verify Visitor, Vehicle and Patrol occurrences',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('occurrence_book')
            .where('orgId', isEqualTo: userData.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final logs = docs.map((doc) => OccurrenceBookModel.fromFirestore(doc)).toList();
          logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          final filtered = logs.where((log) {
            final matchQuery = log.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                log.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                log.guardName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (log.visitorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                (log.vehicleNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

            final matchCategory = _selectedCategory == 'All' || log.category == _selectedCategory;
            return matchQuery && matchCategory;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search logs, guards, visitors...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          filled: true,
                          fillColor: Colors.grey.shade50,
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
                child: filtered.isEmpty
                    ? const Center(child: Text('No occurrence book entries recorded.'))
                    : ListView.builder(
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
                                        DateFormat('HH:mm - dd MMM yyyy').format(log.timestamp),
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
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.security, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Logged by: ${log.guardName}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                    ],
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
