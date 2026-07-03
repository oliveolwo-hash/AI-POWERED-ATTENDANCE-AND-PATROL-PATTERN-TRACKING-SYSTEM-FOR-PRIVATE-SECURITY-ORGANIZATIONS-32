import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/models/alert_model.dart';
import 'package:guard_monitoring/models/incident_model.dart';
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/occurrence_book_model.dart';
import 'package:guard_monitoring/providers/alert_provider.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/incident_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'package:guard_monitoring/providers/shift_provider.dart';
import 'package:guard_monitoring/providers/settings_provider.dart';
import 'package:guard_monitoring/providers/pattern_analysis_provider.dart';
import 'package:guard_monitoring/features/sites/add_site_screen.dart';
import 'package:guard_monitoring/features/shifts/shift_assignment_screen.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guard_monitoring/features/dashboard/real_time_monitoring_screen.dart' as guard_monitoring_real_time;
import 'dart:convert';

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _GlobalOverviewTab(),
      const _UserDirectoryTab(),
      const _GlobalMonitoringTab(),
      const _SitesManagementTab(),
      const _EmergencyCenterTab(),
      const _AuditLogsTab(),
      const _SystemSettingsTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Super Admin Portal'),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
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
                  const DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                    ),
                    child: Text(
                      'Super Admin Panel',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildDrawerItem(0, Icons.dashboard_outlined, 'Analytics Overview'),
                  _buildDrawerItem(1, Icons.people_outline, 'User Management'),
                  _buildDrawerItem(2, Icons.visibility_outlined, 'Live Monitoring'),
                  _buildDrawerItem(3, Icons.location_city_outlined, 'Sites Management'),
                  // Shift Schedules removed
                  _buildDrawerItem(4, Icons.emergency_share_outlined, 'Emergency Controls'),
                  _buildDrawerItem(5, Icons.history_edu_outlined, 'Audit Trail'),
                  _buildDrawerItem(6, Icons.settings_outlined, 'System Settings'),
                ],
              ),
            ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              backgroundColor: Colors.transparent,
              extended: MediaQuery.of(context).size.width >= 1000,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 48,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 8),
                    if (MediaQuery.of(context).size.width >= 1000)
                      const Text(
                        'SUPER ADMIN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.1,
                          color: Colors.white,
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
                      icon: const Icon(Icons.logout, color: Colors.indigo),
                      onPressed: () => ref.read(authRepositoryProvider).signOut(),
                      tooltip: 'Log Out',
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined, color: Colors.indigo),
                  selectedIcon: Icon(Icons.dashboard, color: Colors.indigo),
                  label: Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline, color: Colors.indigo),
                  selectedIcon: Icon(Icons.people, color: Colors.indigo),
                  label: Text('Users'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.visibility_outlined, color: Colors.indigo),
                  selectedIcon: Icon(Icons.visibility, color: Colors.indigo),
                  label: Text('Live Monitoring'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.location_city_outlined, color: Colors.indigo),
                  selectedIcon: Icon(Icons.location_city, color: Colors.indigo),
                  label: Text('Sites'),
                ),

                NavigationRailDestination(
                  icon: Icon(Icons.emergency_share_outlined, color: Colors.indigo),
                  selectedIcon: Icon(Icons.emergency, color: Colors.indigo),
                  label: Text('Emergency'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_edu_outlined, color: Colors.indigo),
                  selectedIcon: Icon(Icons.history_edu, color: Colors.indigo),
                  label: Text('Audit Trail'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined, color: Colors.indigo),
                  selectedIcon: Icon(Icons.settings, color: Colors.indigo),
                  label: Text('Settings'),
                ),
              ],
            ),
          if (isDesktop) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Container(
              color: Colors.transparent,
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(int index, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: _selectedIndex == index ? Colors.indigo : Colors.grey),
      title: Text(title, style: TextStyle(fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal)),
      selected: _selectedIndex == index,
      selectedColor: Colors.indigo,
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context); // Close drawer
      },
    );
  }
}

// -------------------------------------------------------------
// SITES MANAGEMENT TAB
// -------------------------------------------------------------
class _SitesManagementTab extends ConsumerStatefulWidget {
  const _SitesManagementTab();

  @override
  ConsumerState<_SitesManagementTab> createState() => _SitesManagementTabState();
}

class _SitesManagementTabState extends ConsumerState<_SitesManagementTab> {
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

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesStreamProvider);
    final supervisors = ref.watch(allSupervisorsStreamProvider).value ?? [];
    final allUsers = ref.watch(allUsersStreamProvider).value ?? [];
    final allGuards = allUsers.where((u) => u.role == UserRole.guard).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sites Management', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AddSiteScreen(),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Site', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width > 600 ? 300 : double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedType,
                      items: _types
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Show Inactive', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                final filteredSites = sites.where((s) {
                  final matchesType = _selectedType == 'All' || s.type == _selectedType;
                  final matchesActive = _showInactive || s.isActive;
                  return matchesType && matchesActive;
                }).toList();

                if (filteredSites.isEmpty) {
                  return const Center(child: Text('No sites found matching criteria.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: filteredSites.length,
                  itemBuilder: (context, index) {
                    final site = filteredSites[index];
                    final supervisor = supervisors.where((s) => s.id == site.orgId).firstOrNull;
                    final supervisorName = supervisor?.name ?? 'Unassigned';
                    final siteGuards = allGuards.where((g) => g.orgId == site.orgId).toList();

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: Icon(Icons.location_city, color: site.isActive ? Colors.indigo : Colors.grey),
                        ),
                        title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(site.address),
                            const SizedBox(height: 4),
                            Text(
                              'Type: ${site.type} | Supervisor: ${supervisorName}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            if (siteGuards.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: siteGuards.map((g) {
                                  return Chip(
                                    label: Text(g.name, style: const TextStyle(fontSize: 10)),
                                    backgroundColor: Colors.teal.shade50,
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.assignment_ind, color: Colors.orange),
                              tooltip: 'Assign Supervisor & Guards',
                              onPressed: () {
                                _showAssignSupervisorAndGuardsDialog(site, supervisors, allGuards);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.indigo),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AddSiteScreen(existingSite: site),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Site'),
                                    content: Text('Are you sure you want to permanently delete ${site.name}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(siteRepositoryProvider).deleteSite(site.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Site deleted successfully.')),
                                    );
                                  }
                                }
                              },
                            ),
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
    );
  }

  void _showAssignSupervisorAndGuardsDialog(
    SiteModel site,
    List<UserModel> allSupervisors,
    List<UserModel> allGuards,
  ) {
    UserModel? selectedSupervisor;
    final Set<String> selectedGuardIds = {};
    bool isFirstLoad = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isFirstLoad) {
            final currentSupervisorId = site.orgId;
            if (currentSupervisorId.isNotEmpty && currentSupervisorId != 'global') {
              try {
                selectedSupervisor = allSupervisors.firstWhere((s) => s.id == currentSupervisorId);
                for (final g in allGuards) {
                  if (g.orgId == selectedSupervisor?.id) {
                    selectedGuardIds.add(g.id);
                  }
                }
              } catch (_) {
                selectedSupervisor = null;
              }
            }
            isFirstLoad = false;
          }

          final availableGuards = selectedSupervisor == null
              ? <UserModel>[]
              : allGuards.where((g) =>
                  g.orgId == selectedSupervisor!.id ||
                  g.orgId == 'unassigned' ||
                  g.orgId == null ||
                  g.orgId == 'global' ||
                  g.orgId == '').toList();

          return AlertDialog(
            title: Text(
              'Assign Supervisor & Guards\n(${site.name})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SizedBox(
              width: 500,
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Supervisor',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserModel>(
                    value: selectedSupervisor,
                    hint: const Text('Choose a supervisor'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: allSupervisors
                        .map((s) => DropdownMenuItem<UserModel>(
                              value: s,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (newSup) {
                      setModalState(() {
                        selectedSupervisor = newSup;
                        selectedGuardIds.clear();
                        if (newSup != null) {
                          for (final g in allGuards) {
                            if (g.orgId == newSup.id) {
                              selectedGuardIds.add(g.id);
                            }
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Assign Guards to Supervisor',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: selectedSupervisor == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'Select a supervisor first to manage guards.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : (availableGuards.isEmpty
                            ? Center(
                                child: Text(
                                  'No unassigned guards available for this supervisor.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: availableGuards.length,
                                itemBuilder: (context, index) {
                                  final guard = availableGuards[index];
                                  final isSelected = selectedGuardIds.contains(guard.id);
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    child: CheckboxListTile(
                                      title: Text(guard.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(guard.email, style: const TextStyle(fontSize: 12)),
                                      value: isSelected,
                                      activeColor: Colors.indigo,
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            selectedGuardIds.add(guard.id);
                                          } else {
                                            selectedGuardIds.remove(guard.id);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              )),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedSupervisor == null
                    ? null
                    : () async {
                        // 1. Update Site
                        final updatedSite = SiteModel(
                          id: site.id,
                          orgId: selectedSupervisor!.id,

                          name: site.name,
                          address: site.address,
                          type: site.type,
                          latitude: site.latitude,
                          longitude: site.longitude,
                          radius: site.radius,
                          isGeofenceEnabled: site.isGeofenceEnabled,
                          isActive: site.isActive,
                        );
                        await ref.read(siteRepositoryProvider).updateSite(updatedSite);

                        // 2. Update Guards
                        for (final guard in availableGuards) {
                          final shouldBeAssigned = selectedGuardIds.contains(guard.id);
                          final isCurrentlyAssigned = guard.orgId == selectedSupervisor!.id;

                          if (shouldBeAssigned && !isCurrentlyAssigned) {
                            await FirebaseFirestore.instance.collection('users').doc(guard.id).update({
                              'orgId': selectedSupervisor!.id,
                              'orgName': selectedSupervisor!.name,
                            });
                          } else if (!shouldBeAssigned && isCurrentlyAssigned) {
                            await FirebaseFirestore.instance.collection('users').doc(guard.id).update({
                              'orgId': 'unassigned',
                              'orgName': 'Unassigned',
                            });
                          }
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Site supervisor and guards updated successfully.')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: const Text('Save Assignments', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// SHIFTS MANAGEMENT TAB
// -------------------------------------------------------------
class _ShiftsManagementTab extends ConsumerStatefulWidget {
  const _ShiftsManagementTab();

  @override
  ConsumerState<_ShiftsManagementTab> createState() => _ShiftsManagementTabState();
}

class _ShiftsManagementTabState extends ConsumerState<_ShiftsManagementTab> {
  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(allShiftsStreamProvider);
    final guardsAsync = ref.watch(allGuardsStreamProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Shifts & Schedule Management', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ShiftAssignmentScreen(),
              ),
              icon: const Icon(Icons.assignment_ind, color: Colors.white),
              label: const Text('Assign Shift', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: shiftsAsync.when(
        data: (shifts) => guardsAsync.when(
          data: (guards) => sitesAsync.when(
            data: (sites) {
              if (shifts.isEmpty) {
                return const Center(child: Text('No shifts scheduled in the system.'));
              }

              final sortedShifts = List<ShiftModel>.from(shifts);
              sortedShifts.sort((a, b) => b.startTime.compareTo(a.startTime));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                itemCount: sortedShifts.length,
                itemBuilder: (context, index) {
                  final shift = sortedShifts[index];
                  final guard = guards.firstWhere((g) => g.id == shift.personnelId, orElse: () => UserModel(id: shift.personnelId, name: 'Unknown Guard', email: '', role: UserRole.guard));
                  final site = sites.firstWhere((s) => s.id == shift.siteId, orElse: () => SiteModel(id: shift.siteId, orgId: '', name: 'Unknown Site', address: '', latitude: 0, longitude: 0));

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        child: const Icon(Icons.schedule, color: Colors.teal),
                      ),
                      title: Text('${guard.name} @ ${site.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Time: ${DateFormat("yy-MM-dd HH:mm").format(shift.startTime)} to ${DateFormat("HH:mm").format(shift.endTime)}'),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${(shift.status ?? 'unknown').toUpperCase()} | Check-in: ${shift.actualCheckIn != null ? DateFormat("HH:mm").format(shift.actualCheckIn!) : "--:--"}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Shift'),
                              content: const Text('Are you sure you want to permanently delete this scheduled shift?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(shiftRepositoryProvider).deleteShift(shift.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Shift cancelled and deleted.')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}


// -------------------------------------------------------------
// 1. GLOBAL OVERVIEW / ANALYTICS TAB
// -------------------------------------------------------------
class _GlobalOverviewTab extends ConsumerWidget {
  const _GlobalOverviewTab();

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supervisorsAsync = ref.watch(allSupervisorsStreamProvider);
    final guardsAsync = ref.watch(allGuardsStreamProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);
    final incidentsAsync = ref.watch(incidentsStreamProvider);
    final shiftsAsync = ref.watch(allShiftsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Analytics Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row of Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : (MediaQuery.of(context).size.width < 900 ? 2 : 4),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 1.5 : 1.3,
                  children: [
                    _buildStatCard(
                      label: 'Supervisors',
                      value: supervisorsAsync.when(
                        data: (list) => '${list.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      icon: Icons.business,
                      color: Colors.indigo,
                    ),
                    _buildStatCard(
                      label: 'Total Guards',
                      value: guardsAsync.when(
                        data: (list) => '${list.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      icon: Icons.security,
                      color: Colors.teal,
                    ),
                    _buildStatCard(
                      label: 'Monitored Sites',
                      value: sitesAsync.when(
                        data: (list) => '${list.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      icon: Icons.location_on,
                      color: Colors.orange,
                    ),
                    _buildStatCard(
                      label: 'Total Incidents',
                      value: incidentsAsync.when(
                        data: (list) => '${list.length}',
                        loading: () => '...',
                        error: (_, __) => '0',
                      ),
                      icon: Icons.dangerous,
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            // Charts & Feed Section
            incidentsAsync.when(
              data: (incidents) {
                if (incidents.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No incident data available to plot trends.')),
                    ),
                  );
                }

                // Group by type
                final typeCounts = <IncidentType, int>{};
                for (var incident in incidents) {
                  typeCounts[incident.type] = (typeCounts[incident.type] ?? 0) + 1;
                }

                // Render Chart
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Incidents by Category',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (typeCounts.values.isEmpty ? 5 : typeCounts.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < IncidentType.values.length) {
                                        final name = IncidentType.values[index].name;
                                        // Return a short version of the name
                                        return SideTitleWidget(
                                          meta: meta,
                                          child: Text(
                                            name.substring(0, name.length > 5 ? 5 : name.length).toUpperCase(),
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: IncidentType.values.asMap().entries.map((entry) {
                                final index = entry.key;
                                final type = entry.value;
                                final count = typeCounts[type] ?? 0;
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: count.toDouble(),
                                      color: Colors.indigo,
                                      width: 16,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading charts: $e')),
            ),
            const SizedBox(height: 24),
            // Today Active Shifts Status
            shiftsAsync.when(
              data: (shifts) {
                final activeNow = shifts.where((s) => s.actualCheckIn != null && s.actualCheckOut == null).length;
                final scheduledToday = shifts.length;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      radius: 28,
                      child: const Icon(Icons.run_circle_outlined, color: Colors.teal, size: 28),
                    ),
                    title: const Text(
                      'Live Field Deployments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text('$activeNow guards are currently active on shifts (out of $scheduledToday scheduled today).'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ACTIVE: $activeNow',
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. USER MANAGEMENT DIRECTORY
// -------------------------------------------------------------
class _UserDirectoryTab extends ConsumerStatefulWidget {
  const _UserDirectoryTab();

  @override
  ConsumerState<_UserDirectoryTab> createState() => _UserDirectoryTabState();
}

class _UserDirectoryTabState extends ConsumerState<_UserDirectoryTab> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'all'; // 'all', 'supervisors', 'guards'

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'supervisor'; // 'supervisor', 'guard'
    String? selectedOrgId;
    String? selectedOrgName;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final supervisorsAsync = ref.watch(allSupervisorsStreamProvider);

          return AlertDialog(
            title: const Text('Add User Account', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Role Selector
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'User Role'),
                    items: const [
                      DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                      DropdownMenuItem(value: 'guard', child: Text('Guard')),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedRole = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  // If guard, no longer assign supervisor here
                  if (selectedRole == 'guard') ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Guards are created as Unassigned. You can assign them to a Supervisor later using the Assign Sites & Guards button.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
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
                        if (emailController.text.trim().isEmpty ||
                            passwordController.text.trim().isEmpty ||
                            nameController.text.trim().isEmpty) {
                          return;
                        }
                        setModalState(() => isLoading = true);
                        try {
                          if (selectedRole == 'supervisor') {
                            await ref.read(authRepositoryProvider).createSupervisorAccount(
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                  name: nameController.text.trim(),
                                );
                          } else {
                            await ref.read(authRepositoryProvider).createGuardAccount(
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                  name: nameController.text.trim(),
                                  orgId: 'unassigned',
                                  orgName: 'Unassigned',
                                );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setModalState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPermissionsDialog(UserModel supervisor) {
    // Initial permission state
    final currentPermissions = Map<String, bool>.from(supervisor.permissions ?? {
      'manageSites': true,
      'manageGuards': true,
      'resolveIncidents': true,
      'sendAlerts': true,
      'viewReports': true,
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit Supervisor Permissions\n(${supervisor.name})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Manage Sites'),
                subtitle: const Text('Add, edit, or delete sites'),
                value: currentPermissions['manageSites'] ?? false,
                onChanged: (val) => setModalState(() => currentPermissions['manageSites'] = val ?? false),
              ),
              CheckboxListTile(
                title: const Text('Manage Guards'),
                subtitle: const Text('Approve or delete field personnel'),
                value: currentPermissions['manageGuards'] ?? false,
                onChanged: (val) => setModalState(() => currentPermissions['manageGuards'] = val ?? false),
              ),
              CheckboxListTile(
                title: const Text('Resolve Incidents'),
                subtitle: const Text('Investigate and close incident tickets'),
                value: currentPermissions['resolveIncidents'] ?? false,
                onChanged: (val) => setModalState(() => currentPermissions['resolveIncidents'] = val ?? false),
              ),
              CheckboxListTile(
                title: const Text('Send Alerts'),
                subtitle: const Text('Broadcast incident warnings to personnel'),
                value: currentPermissions['sendAlerts'] ?? false,
                onChanged: (val) => setModalState(() => currentPermissions['sendAlerts'] = val ?? false),
              ),
              CheckboxListTile(
                title: const Text('View Analytics & Reports'),
                subtitle: const Text('Access reporting and trend prediction tools'),
                value: currentPermissions['viewReports'] ?? false,
                onChanged: (val) => setModalState(() => currentPermissions['viewReports'] = val ?? false),
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
                await ref.read(authRepositoryProvider).updateSupervisorPermissions(
                      supervisor.id,
                      currentPermissions,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Apply Settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    String? selectedOrgId = user.orgId;
    String? selectedOrgName = user.orgName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final supervisorsAsync = ref.watch(allSupervisorsStreamProvider);

          return AlertDialog(
            title: const Text('Edit User Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                  ),
                  if (user.role == UserRole.guard) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'To change the assigned Supervisor for this guard, use the Assign Sites & Guards button on the dashboard.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty) return;
                  if (user.role == UserRole.admin) {
                    await ref.read(authRepositoryProvider).editSupervisor(
                          userId: user.id,
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                        );
                  } else {
                    // Guards
                    await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'orgId': selectedOrgId,
                      'orgName': selectedOrgName,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text('Are you sure you want to permanently delete ${user.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (user.role == UserRole.admin) {
                await ref.read(authRepositoryProvider).deleteSupervisor(user.id);
              } else if (user.role == UserRole.superAdmin) {
                await ref.read(authRepositoryProvider).deleteSuperAdmin(user.id);
              } else {
                await ref.read(authRepositoryProvider).deleteGuard(user.id);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAssignSitesAndGuardsDialog(UserModel supervisor, List<SiteModel> allSites, List<UserModel> allGuards) {
    final superAdminId = ref.read(userDataProvider).value?.id ?? 'global';
    
    // Sites logic
    final availableSites = allSites.where((s) => s.orgId == superAdminId || s.orgId == 'global' || s.orgId == supervisor.id).toList();
    final Set<String> selectedSiteIds = {};
    for (final site in availableSites) {
      if (site.orgId == supervisor.id) {
        selectedSiteIds.add(site.id);
      }
    }

    // Guards logic
    final availableGuards = allGuards.where((g) => g.orgId == 'unassigned' || g.orgId == null || g.orgId == superAdminId || g.orgId == 'global' || g.orgId == supervisor.id).toList();
    final Set<String> selectedGuardIds = {};
    for (final guard in availableGuards) {
      if (guard.orgId == supervisor.id) {
        selectedGuardIds.add(guard.id);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Assign to ${supervisor.name}'),
              content: SizedBox(
                width: 500,
                height: 500,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.indigo,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(text: 'Sites'),
                        Tab(text: 'Guards'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Sites Tab
                          availableSites.isEmpty
                              ? const Center(child: Text('No available sites to assign.'))
                              : ListView.builder(
                                  itemCount: availableSites.length,
                                  itemBuilder: (context, index) {
                                    final site = availableSites[index];
                                    final isSelected = selectedSiteIds.contains(site.id);
                                    return CheckboxListTile(
                                      title: Text(site.name),
                                      subtitle: Text(site.address),
                                      value: isSelected,
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            selectedSiteIds.add(site.id);
                                          } else {
                                            selectedSiteIds.remove(site.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                          // Guards Tab
                          availableGuards.isEmpty
                              ? const Center(child: Text('No unassigned guards available.'))
                              : ListView.builder(
                                  itemCount: availableGuards.length,
                                  itemBuilder: (context, index) {
                                    final guard = availableGuards[index];
                                    final isSelected = selectedGuardIds.contains(guard.id);
                                    return CheckboxListTile(
                                      title: Text(guard.name),
                                      subtitle: Text(guard.email),
                                      value: isSelected,
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            selectedGuardIds.add(guard.id);
                                          } else {
                                            selectedGuardIds.remove(guard.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Save Sites
                    for (final site in availableSites) {
                      final shouldBeAssigned = selectedSiteIds.contains(site.id);
                      final isCurrentlyAssigned = site.orgId == supervisor.id;

                      if (shouldBeAssigned && !isCurrentlyAssigned) {
                        final updatedSite = SiteModel(
                          id: site.id, orgId: supervisor.id, name: site.name, address: site.address, type: site.type, latitude: site.latitude, longitude: site.longitude, radius: site.radius, isGeofenceEnabled: site.isGeofenceEnabled, isActive: site.isActive,
                        );
                        await ref.read(siteRepositoryProvider).updateSite(updatedSite);
                      } else if (!shouldBeAssigned && isCurrentlyAssigned) {
                        final updatedSite = SiteModel(
                          id: site.id, orgId: superAdminId, name: site.name, address: site.address, type: site.type, latitude: site.latitude, longitude: site.longitude, radius: site.radius, isGeofenceEnabled: site.isGeofenceEnabled, isActive: site.isActive,
                        );
                        await ref.read(siteRepositoryProvider).updateSite(updatedSite);
                      }
                    }

                    // Save Guards
                    for (final guard in availableGuards) {
                      final shouldBeAssigned = selectedGuardIds.contains(guard.id);
                      final isCurrentlyAssigned = guard.orgId == supervisor.id;

                      if (shouldBeAssigned && !isCurrentlyAssigned) {
                        await FirebaseFirestore.instance.collection('users').doc(guard.id).update({
                          'orgId': supervisor.id,
                          'orgName': supervisor.name,
                        });
                      } else if (!shouldBeAssigned && isCurrentlyAssigned) {
                        await FirebaseFirestore.instance.collection('users').doc(guard.id).update({
                          'orgId': 'unassigned',
                          'orgName': 'Unassigned',
                        });
                      }
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignments updated successfully.')));
                  },
                  child: const Text('Save Assignments'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersStreamProvider);
    final currentUser = ref.watch(userDataProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add User', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRoleFilter,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Roles')),
                          DropdownMenuItem(value: 'superAdmins', child: Text('System Admins')),
                          DropdownMenuItem(value: 'supervisors', child: Text('Supervisors')),
                          DropdownMenuItem(value: 'guards', child: Text('Guards')),
                        ],
                        onChanged: (val) => setState(() => _selectedRoleFilter = val!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // User Grid/List
          Expanded(
            child: usersAsync.when(
              data: (users) {
                // Filter users
                final filtered = users.where((u) {
                  final matchesSearch = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      u.email.toLowerCase().contains(_searchQuery.toLowerCase());
                  if (!matchesSearch) return false;

                  if (u.id == currentUser?.id) return false;

                  if (_selectedRoleFilter == 'superAdmins') {
                    return u.role == UserRole.superAdmin;
                  } else if (_selectedRoleFilter == 'supervisors') {
                    return u.role == UserRole.admin;
                  } else if (_selectedRoleFilter == 'guards') {
                    return u.role == UserRole.guard;
                  }
                  
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No users match the search criteria.'));
                }

                final systemAdmins = filtered.where((u) => u.role == UserRole.superAdmin).toList();
                final supervisors = filtered.where((u) => u.role == UserRole.admin).toList();
                final guards = filtered.where((u) => u.role == UserRole.guard).toList();
                final unassignedGuards = guards.where((g) => g.orgId == null || !supervisors.any((s) => s.id == g.orgId)).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  children: [
                    if (systemAdmins.isNotEmpty) ...[
                      const Text('System Administrators', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 140,
                        ),
                        itemCount: systemAdmins.length,
                        itemBuilder: (ctx, i) => _buildUserCard(systemAdmins[i], context, ref),
                      ),
                      const SizedBox(height: 32),
                    ],

                    if (supervisors.isNotEmpty) ...[
                      const Text('Supervisors & Assigned Guards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 12),
                      ...supervisors.map((supervisor) {
                        final assignedGuards = guards.where((g) => g.orgId == supervisor.id).toList();
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 800;
                                final supervisorWidget = SizedBox(
                                  width: isWide ? 380 : double.infinity,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('SUPERVISOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      const SizedBox(height: 8),
                                      _buildUserCard(supervisor, context, ref),
                                    ],
                                  ),
                                );
                                
                                final guardsWidget = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('ASSIGNED GUARDS (${assignedGuards.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    if (assignedGuards.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                                        child: const Center(child: Text('No guards assigned to this supervisor.', style: TextStyle(color: Colors.grey))),
                                      )
                                    else
                                      ListView.separated(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        itemCount: assignedGuards.length,
                                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                                        itemBuilder: (ctx, i) {
                                          final g = assignedGuards[i];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.security, size: 16, color: Colors.teal),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      Text(g.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                );

                                if (isWide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      supervisorWidget,
                                      const SizedBox(width: 24),
                                      Expanded(child: guardsWidget),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      supervisorWidget,
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 16),
                                      guardsWidget,
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 32),
                    ],

                    if (unassignedGuards.isNotEmpty) ...[
                      const Text('Unassigned Guards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 140,
                        ),
                        itemCount: unassignedGuards.length,
                        itemBuilder: (ctx, i) => _buildUserCard(unassignedGuards[i], context, ref),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading directory: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user, BuildContext context, WidgetRef ref) {
    final isSupervisor = user.role == UserRole.admin;
    final isSystemAdmin = user.role == UserRole.superAdmin;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isSystemAdmin ? Colors.purple.shade50 : isSupervisor ? Colors.indigo.shade50 : Colors.teal.shade50,
          child: Icon(
            isSystemAdmin ? Icons.admin_panel_settings : isSupervisor ? Icons.business : Icons.security,
            color: isSystemAdmin ? Colors.purple : isSupervisor ? Colors.indigo : Colors.teal,
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              isSystemAdmin ? 'SYSTEM ADMIN' : isSupervisor ? 'SUPERVISOR' : 'GUARD (Org: ${user.orgName ?? "Unassigned"})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSystemAdmin ? Colors.purple : isSupervisor ? Colors.indigo : Colors.teal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (!isSupervisor && !user.isApproved) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PENDING APPROVAL',
                  style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        trailing: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSupervisor && !user.isApproved) ...[
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Approve',
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).approvePersonnel(user.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Approved ${user.name}')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: 'Reject',
                  onPressed: () => _showDeleteConfirmation(user),
                ),
              ],
              if (isSupervisor)
                IconButton(
                  icon: const Icon(Icons.lock_person, color: Colors.indigo),
                  tooltip: 'Permissions',
                  onPressed: () => _showPermissionsDialog(user),
                ),
              Tooltip(
                message: user.isActive ? 'Deactivate User' : 'Activate User',
                child: Switch(
                  value: user.isActive,
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  inactiveTrackColor: Colors.red.shade100,
                  onChanged: (active) async {
                    await ref.read(authRepositoryProvider).toggleUserActiveStatus(user.id, active);
                  },
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) async {
                  if (action == 'edit') {
                    _showEditUserDialog(user);
                  } else if (action == 'delete') {
                    _showDeleteConfirmation(user);
                  } else if (action == 'reset_password') {
                    try {
                      await ref.read(authRepositoryProvider).sendPasswordResetEmail(user.email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Password reset email sent to ${user.email}')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset_password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset, size: 20),
                        SizedBox(width: 8),
                        Text('Reset Password'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Account', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. GLOBAL MONITORING TAB
// -------------------------------------------------------------
class _GlobalMonitoringTab extends StatelessWidget {
  const _GlobalMonitoringTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Live Monitoring', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const guard_monitoring_real_time.RealTimeMonitoringScreen(),
    );
  }
}

// -------------------------------------------------------------
// INCIDENTS FEED MONITOR (Moved to Emergency)
// -------------------------------------------------------------

class _IncidentsFeedMonitor extends ConsumerWidget {
  const _IncidentsFeedMonitor();

  Color _getPriorityColor(IncidentPriority priority) {
    switch (priority) {
      case IncidentPriority.critical:
        return Colors.red.shade900;
      case IncidentPriority.high:
        return Colors.red;
      case IncidentPriority.medium:
        return Colors.orange;
      case IncidentPriority.low:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(incidentsStreamProvider);

    return incidentsAsync.when(
      data: (incidents) {
        if (incidents.isEmpty) {
          return const Center(child: Text('No incident logs reported yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: incidents.length,
          itemBuilder: (context, index) {
            final incident = incidents[index];
            final color = _getPriorityColor(incident.priority);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            incident.priority.name.toUpperCase(),
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(incident.timestamp),
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      incident.type.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(incident.description),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(incident.location, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status: ${incident.status.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Report Override'),
                                content: const Text('Are you sure you want to override and delete this incident report? This removes it globally.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete Override', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(incidentRepositoryProvider).deleteIncident(incident.id);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, elevation: 0),
                          child: const Text('Override Delete'),
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
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _AlertsFeedMonitor extends ConsumerWidget {
  const _AlertsFeedMonitor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsStreamProvider);

    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return const Center(child: Text('No alert broadcasts records found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            final isGlobal = alert.orgId == 'global';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isGlobal ? Colors.red.shade50 : Colors.blue.shade50,
                  child: Icon(
                    isGlobal ? Icons.campaign : Icons.warning_amber_outlined,
                    color: isGlobal ? Colors.red : Colors.blue,
                  ),
                ),
                title: Text(alert.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Target: ${alert.targetId} • Sender: ${alert.senderName}\nOrg: ${alert.orgId}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    await ref.read(alertRepositoryProvider).deleteAlert(alert.id);
                  },
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// -------------------------------------------------------------
// 4. EMERGENCY & GLOBAL CONTROL TAB
// -------------------------------------------------------------
class _EmergencyCenterTab extends ConsumerStatefulWidget {
  const _EmergencyCenterTab();

  @override
  ConsumerState<_EmergencyCenterTab> createState() => _EmergencyCenterTabState();
}

class _EmergencyCenterTabState extends ConsumerState<_EmergencyCenterTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Emergency & Global Control', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red.shade900,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red.shade900,
          tabs: const [
            Tab(icon: Icon(Icons.security), text: 'Controls'),
            Tab(icon: Icon(Icons.report_problem), text: 'Incidents Feed'),
            Tab(icon: Icon(Icons.campaign), text: 'Broadcasts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _EmergencyControlsView(),
          _IncidentsFeedMonitor(),
          _AlertsFeedMonitor(),
        ],
      ),
    );
  }
}

class _EmergencyControlsView extends ConsumerStatefulWidget {
  const _EmergencyControlsView();

  @override
  ConsumerState<_EmergencyControlsView> createState() => _EmergencyControlsViewState();
}

class _EmergencyControlsViewState extends ConsumerState<_EmergencyControlsView> {
  final _messageController = TextEditingController(text: 'SYSTEM LOCKDOWN ACTIVE: Please proceed to safety immediately!');
  final _broadcastController = TextEditingController();

  Future<void> _sendGlobalBroadcast() async {
    final message = _broadcastController.text.trim();
    if (message.isEmpty) return;

    final superAdminUser = ref.read(userDataProvider).value;
    if (superAdminUser == null) return;

    final alert = AlertModel(
      id: const Uuid().v4(),
      orgId: 'global',
      message: message,
      timestamp: DateTime.now(),
      personnelId: superAdminUser.id,
      senderName: 'Super Administrator',
      targetId: 'all',
      type: AlertType.adminMessage,
      priority: AlertPriority.urgent,
      siteId: '',
    );

    await ref.read(alertRepositoryProvider).sendAlert(alert);
    _broadcastController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Global alert broadcasted successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(globalSettingsProvider);
    return settingsAsync.when(
      data: (settings) {
        final bool isLockdown = settings.lockdownActive ?? false;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isLockdown ? Colors.red.shade50 : Colors.amber.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLockdown ? Icons.gpp_bad : Icons.lock_open,
                                color: isLockdown ? Colors.red : Colors.amber.shade800,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Global System Lockdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text(
                                    isLockdown ? 'Lockdown state is ACTIVE across all terminals.' : 'System is running in normal state.',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isLockdown,
                              activeColor: Colors.red,
                              onChanged: (val) async {
                                if (val) {
                                  await ref.read(settingsRepositoryProvider).toggleLockdown(active: true, message: _messageController.text.trim());
                                } else {
                                  await ref.read(settingsRepositoryProvider).toggleLockdown(active: false);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _messageController,
                          enabled: !isLockdown,
                          decoration: const InputDecoration(
                            labelText: 'Lockdown Warning Message',
                            border: OutlineInputBorder(),
                            helperText: 'This banner message will display immediately at the top of all user dashboards.',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.campaign, color: Colors.indigo, size: 28),
                            SizedBox(width: 12),
                            Text('System-wide Alert Broadcast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Send a critical system alert notification to all supervisors and guards instantly.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _broadcastController,
                          decoration: const InputDecoration(
                            labelText: 'Broadcast Message',
                            hintText: 'Enter emergency bulletin details...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _sendGlobalBroadcast,
                            icon: const Icon(Icons.send, color: Colors.white),
                            label: const Text('Send Global Broadcast Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// -------------------------------------------------------------
// 5. AUDIT LOGS VIEW
// -------------------------------------------------------------
class _AuditLogsTab extends ConsumerStatefulWidget {
  const _AuditLogsTab();

  @override
  ConsumerState<_AuditLogsTab> createState() => _AuditLogsTabState();
}

class _AuditLogsTabState extends ConsumerState<_AuditLogsTab> {
  String _filterAction = 'all';

  Color _getActionColor(String action) {
    if (action.contains('LOGIN')) return Colors.green;
    if (action.contains('LOGOUT')) return Colors.grey;
    if (action.contains('LOCKDOWN')) return Colors.red;
    if (action.contains('CREATE')) return Colors.blue;
    if (action.contains('DELETE')) return Colors.red;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Audit Trails & Logs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterAction,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Actions')),
                    DropdownMenuItem(value: 'LOGIN', child: Text('Logins')),
                    DropdownMenuItem(value: 'LOGOUT', child: Text('Logouts')),
                    DropdownMenuItem(value: 'CREATE', child: Text('Creations')),
                    DropdownMenuItem(value: 'LOCKDOWN', child: Text('Lockdowns')),
                  ],
                  onChanged: (val) => setState(() => _filterAction = val!),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activity_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final filtered = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final action = (data['action'] as String?) ?? '';
            if (_filterAction == 'all') return true;
            if (_filterAction == 'CREATE') return action.startsWith('CREATE');
            return action == _filterAction;
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No audit logs recorded matching filters.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final log = filtered[index].data() as Map<String, dynamic>;
              final action = (log['action'] as String?) ?? 'ACTION';
              final details = (log['details'] as String?) ?? '';
              final userName = (log['userName'] as String?) ?? 'System';
              final userRole = (log['userRole'] as String?) ?? 'SYSTEM';
              final timestamp = (log['timestamp'] as Timestamp?)?.toDate();
              final color = _getActionColor(action);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          action,
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(details, style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(
                              'By: $userName ($userRole)',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          DateFormat('HH:mm:ss\nyy-MM-dd').format(timestamp),
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// 6. SYSTEM MODULE CONFIGURATION SETTINGS
// -------------------------------------------------------------
class _SystemSettingsTab extends ConsumerWidget {
  const _SystemSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(globalSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('System Settings & Modules', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.emergency_share, color: Colors.red),
                        title: const Text('Security Alerts Module', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Enable or disable live alerts and SOS broadcasts globally.'),
                        trailing: Switch(
                          value: settings.alertsEnabled,
                          onChanged: (val) async {
                            await ref.read(settingsRepositoryProvider).toggleModule(moduleKey: 'alertsEnabled', enabled: val);
                          },
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.analytics_outlined, color: Colors.blue),
                        title: const Text('Reports & Analytics Module', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Allow supervisors to generate incident performance metrics.'),
                        trailing: Switch(
                          value: settings.reportsEnabled,
                          onChanged: (val) async {
                            await ref.read(settingsRepositoryProvider).toggleModule(moduleKey: 'reportsEnabled', enabled: val);
                          },
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.psychology, color: Colors.purple),
                        title: const Text('AI Pattern Analysis Module', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Allow supervisors to run temporal AI anomaly detection graphs.'),
                        trailing: Switch(
                          value: settings.analyticsEnabled,
                          onChanged: (val) async {
                            await ref.read(settingsRepositoryProvider).toggleModule(moduleKey: 'analyticsEnabled', enabled: val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System Administration & Seeding',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.psychology, color: Colors.purple),
                        title: const Text('Seed Mock Analytics Data', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Generates 150 historical shifts/incidents for predictive charts.'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final userData = ref.read(userDataProvider).value;
                            if (userData == null) return;
                            try {
                              await SeedDataService().seedHistoricalData(userData.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mock historical records seeded successfully.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to seed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Seed Data'),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.download, color: Colors.green),
                        title: const Text('Export JSON Database Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Backup user accounts, sites, and shifts data locally.'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            try {
                              final users = await FirebaseFirestore.instance.collection('users').get();
                              final sites = await FirebaseFirestore.instance.collection('sites').get();
                              final shifts = await FirebaseFirestore.instance.collection('shifts').get();

                              final backupMap = {
                                'users': users.docs.map((d) => d.data()).toList(),
                                'sites': sites.docs.map((d) => d.data()).toList(),
                                'shifts': shifts.docs.map((d) => d.data()).toList(),
                              };

                              final jsonString = jsonEncode(backupMap);
                              
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('JSON Backup Exported'),
                                    content: SingleChildScrollView(
                                      child: SelectableText(jsonString),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Backup failed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Export JSON'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
