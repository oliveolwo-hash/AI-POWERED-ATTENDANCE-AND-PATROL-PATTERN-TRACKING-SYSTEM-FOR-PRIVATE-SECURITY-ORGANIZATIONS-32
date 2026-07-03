import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'package:guard_monitoring/providers/shift_provider.dart';
import 'package:guard_monitoring/providers/alert_provider.dart';
import 'package:guard_monitoring/models/alert_model.dart';
import 'package:guard_monitoring/features/shifts/shift_assignment_screen.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ManageGuardsScreen extends ConsumerStatefulWidget {
  const ManageGuardsScreen({super.key});

  @override
  ConsumerState<ManageGuardsScreen> createState() => _ManageGuardsScreenState();
}

class _ManageGuardsScreenState extends ConsumerState<ManageGuardsScreen> {
  String _searchQuery = '';
  String? _selectedSiteFilter;

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    final guardsAsync = ref.watch(personnelStreamProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);
    final shiftsAsync = ref.watch(allShiftsStreamProvider);

    if (userData == null)
      return const Center(child: CircularProgressIndicator());

    final bool isAdmin = userData.role == UserRole.superAdmin;

    return DefaultTabController(
      length: isAdmin ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personnel Command Center'),
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.shield), text: 'Active Guards'),
              if (isAdmin)
                const Tab(icon: Icon(Icons.pending_actions), text: 'Pending Approvals'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ShiftAssignmentScreen(),
                ),
                icon: const Icon(
                  Icons.assignment_ind,
                  size: 16,
                  color: Colors.blue,
                ),
                label: const Text(
                  'Assign Shift',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateGuardDialog(context, ref, userData),
                  icon: const Icon(
                    Icons.person_add,
                    size: 16,
                    color: AppTheme.secondaryColor,
                  ),
                  label: const Text(
                    'Add Guard',
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryColor),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            const SizedBox(width: 16),
          ],
        ),
        body: TabBarView(
          children: [
            _buildActiveGuardsTab(context, guardsAsync, shiftsAsync, sitesAsync, userData),
            if (isAdmin)
              _buildPendingApprovalsTab(context, ref, userData),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGuardsTab(
    BuildContext context,
    AsyncValue<List<UserModel>> guardsAsync,
    AsyncValue<List<ShiftModel>> shiftsAsync,
    AsyncValue<List<SiteModel>> sitesAsync,
    UserModel userData,
  ) {
    return guardsAsync.when(
        data: (guards) => shiftsAsync.when(
          data: (allShifts) {
            // 1. Filter Today's Shifts
            final now = DateTime.now();
            final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
            final endOfDay = DateTime(
              now.year,
              now.month,
              now.day,
              23,
              59,
              59,
            ).toUtc();

            final todayShifts = allShifts.where((s) {
              final start = s.startTime.toUtc();
              return start.isAfter(
                    startOfDay.subtract(const Duration(seconds: 1)),
                  ) &&
                  start.isBefore(endOfDay.add(const Duration(seconds: 1)));
            }).toList();

            // 2. Map Guard ID -> Shift
            final Map<String, ShiftModel> guardStatusMap = {
              for (var s in todayShifts) s.personnelId: s,
            };

            // 3. Filter Guards
            final filteredGuards = guards.where((g) {
              final nameMatch =
                  g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  g.email.toLowerCase().contains(_searchQuery.toLowerCase());

              if (!nameMatch) return false;

              if (_selectedSiteFilter != null) {
                final shift = guardStatusMap[g.id];
                return shift?.siteId == _selectedSiteFilter;
              }

              return true;
            }).toList();

            // 4. Calculate Stats
            int activeNow = 0;
            int lateToday = 0;
            int absentToday = 0;

            for (var s in todayShifts) {
              if (s.actualCheckOut != null) continue;
              if (s.actualCheckIn != null) {
                activeNow++;
                if (s.actualCheckIn!
                        .difference(s.startTime.toLocal())
                        .inMinutes >
                    15)
                  lateToday++;
              } else if (now.isAfter(
                s.startTime.toLocal().add(const Duration(minutes: 15)),
              )) {
                absentToday++;
              }
            }

            return Column(
              children: [
                // Top Metrics
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      _buildSummaryChip(
                        'Total Staff',
                        guards.length,
                        Colors.blueGrey,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryChip('Active Now', activeNow, Colors.green),
                      const SizedBox(width: 8),
                      _buildSummaryChip('Late Today', lateToday, Colors.orange),
                      const SizedBox(width: 8),
                      _buildSummaryChip(
                        'Absent/Missing',
                        absentToday,
                        Colors.red,
                      ),
                    ],
                  ),
                ),

                // Filters
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by name...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              hint: const Text(
                                'All Sites',
                                style: TextStyle(fontSize: 13),
                              ),
                              value: _selectedSiteFilter,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'All Sites',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (sitesAsync.value != null)
                                  ...sitesAsync.value!.map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedSiteFilter = v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // List
                Expanded(
                  child: filteredGuards.isEmpty
                      ? const Center(
                          child: Text(
                            'No personnel found for selected filters.',
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 220, // Approximate height of _PersonnelUnifiedCard
                          ),
                          itemCount: filteredGuards.length,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemBuilder: (context, index) {
                            final guard = filteredGuards[index];
                            final todayShift = guardStatusMap[guard.id];
                            final siteList = todayShift != null 
                                ? sitesAsync.value?.where((s) => s.id == todayShift.siteId).toList() ?? []
                                : [];
                            final site = siteList.isNotEmpty ? siteList.first : null;

                            return _PersonnelUnifiedCard(
                              guard: guard,
                              todayShift: todayShift,
                              siteName: site?.name,
                            );
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error loading shifts: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading guards: $e')),
      );
    }

  Widget _buildPendingApprovalsTab(BuildContext context, WidgetRef ref, UserModel supervisor) {
    final pendingAsync = ref.watch(pendingPersonnelStreamProvider);

    return pendingAsync.when(
      data: (guards) {
        if (guards.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No pending guard approvals.'),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 220,
          ),
          padding: const EdgeInsets.all(16),
          itemCount: guards.length,
          itemBuilder: (context, index) {
            final guard = guards[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade50,
                  child: const Icon(Icons.person, color: Colors.orange),
                ),
                title: Text(guard.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guard.email),
                    const SizedBox(height: 4),
                    Text('Org: ${guard.orgName ?? "N/A"}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      tooltip: 'Approve Guard',
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).approvePersonnel(guard.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Approved ${guard.name}')),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                      tooltip: 'Reject / Delete',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Reject Guard Registration'),
                            content: Text('Are you sure you want to reject and delete ${guard.name}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(authRepositoryProvider).deleteGuard(guard.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Rejected and deleted ${guard.name}')),
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
      error: (e, s) => Center(child: Text('Error loading pending guards: $e')),
    );
  }

  void _showCreateGuardDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel adminData,
  ) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Guard Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Secure Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            passwordController.text.isEmpty ||
                            nameController.text.isEmpty)
                          return;

                        setState(() => isLoading = true);
                        try {
                          await ref
                              .read(authRepositoryProvider)
                              .createGuardAccount(
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                                name: nameController.text.trim(),
                                orgId: adminData.id,
                                orgName: adminData.name ?? 'Organization',
                              );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        } finally {
                          if (context.mounted)
                            setState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGuardDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    UserModel guard,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GuardHistorySheet(guard: guard),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _PersonnelUnifiedCard extends ConsumerWidget {
  final UserModel guard;
  final ShiftModel? todayShift;
  final String? siteName;

  const _PersonnelUnifiedCard({
    required this.guard,
    this.todayShift,
    this.siteName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double mockRate = 85.0 + (guard.name.length % 15);
    final isSuperAdmin = ref.watch(userDataProvider).value?.role == UserRole.superAdmin;

    // Status Logic
    String statusText = 'Ready';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.person_outline;

    if (todayShift != null) {
      if (todayShift!.status == 'absent') {
        statusText = 'Absent';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
      } else if (todayShift!.actualCheckOut != null) {
        statusText = 'Finished';
        statusColor = Colors.blue;
        statusIcon = Icons.task_alt;
      } else if (todayShift!.actualCheckIn != null) {
        statusText = 'On Duty';
        statusColor = Colors.green;
        statusIcon = Icons.shield;
      } else {
        final now = DateTime.now();
        if (now.isAfter(
          todayShift!.startTime.toLocal().add(const Duration(minutes: 15)),
        )) {
          statusText = 'Late';
          statusColor = Colors.orange;
          statusIcon = Icons.warning;
        } else {
          statusText = 'Scheduled';
          statusColor = Colors.blueGrey;
          statusIcon = Icons.schedule;
        }
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blueGrey[100],
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.blueGrey,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guard.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        guard.email,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSuperAdmin) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Score: ${mockRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            if (todayShift != null) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Site', siteName ?? '---'),
                  _buildMiniStat(
                    'Scheduled',
                    '${DateFormat("HH:mm").format(todayShift!.startTime.toLocal())} - ${DateFormat("HH:mm").format(todayShift!.endTime.toLocal())}',
                  ),
                  if (isSuperAdmin)
                    _buildMiniStat(
                      'Actual',
                      todayShift!.actualCheckIn != null
                          ? DateFormat(
                              "HH:mm",
                            ).format(todayShift!.actualCheckIn!.toLocal())
                          : '--:--',
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ],

            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final state = context
                          .findAncestorStateOfType<_ManageGuardsScreenState>();
                      if (state != null) {
                        state._showGuardDetailsSheet(context, ref, guard);
                      }
                    },
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text(
                      'View History',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (isSuperAdmin) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove Guard'),
                          content: Text(
                            'Are you sure you want to completely remove ${guard.name}? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Remove Guard',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(authRepositoryProvider)
                            .deleteGuard(guard.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${guard.name} removed.')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      side: const BorderSide(color: Colors.red, width: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}

class _GuardHistorySheet extends ConsumerWidget {
  final UserModel guard;
  const _GuardHistorySheet({required this.guard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(allShiftsStreamProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle & Close
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Personnel Performance Vault',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Header Profile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    guard.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guard.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        guard.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Main Feed
          Expanded(
            child: shiftsAsync.when(
              data: (allShifts) {
                final history =
                    allShifts
                        .where(
                          (s) =>
                              s.personnelId == guard.id &&
                              s.actualCheckOut != null,
                        )
                        .toList()
                      ..sort((a, b) => b.startTime.compareTo(a.startTime));

                if (history.isEmpty) {
                  return const Center(
                    child: Text(
                      'No historical shifts found for this personnel.',
                    ),
                  );
                }

                // Calculate Stats
                int onTime = 0;
                double totalHours = 0;
                for (var s in history) {
                  if (s.actualCheckIn != null &&
                      s.actualCheckIn!
                              .difference(s.startTime.toLocal())
                              .inMinutes <=
                          15)
                    onTime++;
                  if (s.actualCheckOut != null && s.actualCheckIn != null) {
                    totalHours += s.actualCheckOut!
                        .difference(s.actualCheckIn!)
                        .inHours;
                  }
                }
                final punctuality = (onTime / history.length) * 100;

                return Column(
                  children: [
                    // Stats Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          _buildStatBox(
                            'Total Shifts',
                            history.length.toString(),
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildStatBox(
                            'On-Time Rate',
                            '${punctuality.toStringAsFixed(0)}%',
                            punctuality >= 90 ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _buildStatBox(
                            'Hours Logged',
                            '${totalHours.toStringAsFixed(1)}h',
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 48),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SHIFT HISTORY LOG',
                          style: TextStyle(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        itemCount: history.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final shift = history[index];
                          final siteList = sitesAsync.value?.where((s) => s.id == shift.siteId).toList() ?? [];
                          final site = siteList.isNotEmpty ? siteList.first : null;
                          final isLate =
                              shift.actualCheckIn != null &&
                              shift.actualCheckIn!
                                      .difference(shift.startTime.toLocal())
                                      .inMinutes >
                                  15;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(shift.startTime.toLocal()),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          site?.name ?? 'Unknown Site',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (isLate
                                                    ? Colors.orange
                                                    : Colors.green)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isLate ? 'LATE' : 'ON-TIME',
                                        style: TextStyle(
                                          color: isLate
                                              ? Colors.orange
                                              : Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildTimeInfo(
                                      'Check In',
                                      DateFormat(
                                        'HH:mm',
                                      ).format(shift.actualCheckIn!.toLocal()),
                                    ),
                                    _buildTimeInfo(
                                      'Check Out',
                                      DateFormat(
                                        'HH:mm',
                                      ).format(shift.actualCheckOut!.toLocal()),
                                    ),
                                    _buildTimeInfo(
                                      'Scheduled',
                                      '${DateFormat('HH:mm').format(shift.startTime.toLocal())}',
                                    ),
                                  ],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
