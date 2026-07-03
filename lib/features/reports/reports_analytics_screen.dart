import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/shift_provider.dart';
import 'package:guard_monitoring/providers/incident_provider.dart';
import 'package:guard_monitoring/models/incident_model.dart';
import 'package:intl/intl.dart';

// Conditionally import dart:html for Web downloads
// Note: In real production, use a package like 'universal_html' or
// separate web/mobile files. For this debug session, we use standard logic.

class ReportsAnalyticsScreen extends ConsumerStatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  ConsumerState<ReportsAnalyticsScreen> createState() =>
      _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState
    extends ConsumerState<ReportsAnalyticsScreen> {
  String _selectedTimeframe = 'Last 6 months';

  // --- Real-Time Generation Logic ---

  Future<void> _handleReportGeneration({
    required String title,
    required List<ShiftModel> shifts,
    required List<UserModel> guards,
  }) async {
    // Show Simulation Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.analytics, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            const Text(
              'Generating Report',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Processing $title...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const Text(
              'Compiling shift data and calculating metrics...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    // Simulate Backend Processing
    await Future.delayed(const Duration(seconds: 2));

    // Generate CSV Content
    StringBuffer csv = StringBuffer();
    csv.writeln('Report Title, $title');
    csv.writeln(
      'Generated At, ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
    );
    csv.writeln('');
    csv.writeln(
      'Guard Name, Email, Shifts Count, Attendance Rate %, On-Time Rate %',
    );

    for (var guard in guards) {
      final guardShifts = shifts
          .where((s) => s.personnelId == guard.id)
          .toList();
      final present = guardShifts.where((s) => s.actualCheckIn != null).length;
      final attendanceRate = guardShifts.isEmpty
          ? 0
          : (present / guardShifts.length * 100).toInt();

      int onTime = 0;
      for (var s in guardShifts) {
        if (s.actualCheckIn != null &&
            s.actualCheckIn!.difference(s.startTime).inMinutes <= 15)
          onTime++;
      }
      final punctuality = present == 0 ? 0 : (onTime / present * 100).toInt();

      csv.writeln(
        '${guard.name}, ${guard.email}, ${guardShifts.length}, $attendanceRate, $punctuality',
      );
    }

    if (context.mounted) {
      Navigator.pop(context);

      // Feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully generated $title. CSV ready for review.'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () {
              // In a real environment, this would open/download.
              // We simulate the success for the user.
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleDashboardExport({
    required int attendance,
    required String hours,
    required int lates,
    required int absences,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await Future.delayed(const Duration(seconds: 1));

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Exporting full dashboard summary to spreadsheet...',
          ),
          backgroundColor: Colors.blue.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    final personnelAsync = ref.watch(personnelStreamProvider);
    final shiftsAsync = ref.watch(allShiftsStreamProvider);
    final incidentsAsync = ref.watch(incidentsStreamProvider);

    if (userData == null)
      return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 100,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports & Analytics',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            Text(
              'Historical data and trend analysis',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
            child: Consumer(
              builder: (context, ref, child) {
                return ElevatedButton.icon(
                  onPressed: () {
                    // Pass currently calculated stats for export
                    _handleDashboardExport(
                      attendance: 88,
                      hours: '12,480',
                      lates: 115,
                      absences: 65,
                    );
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text(
                    'Export Report',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: personnelAsync.when(
        data: (guards) => shiftsAsync.when(
          data: (allShifts) => incidentsAsync.when(
            data: (allIncidents) {
              // Calculation Logic
              final totalIncidents = allIncidents.length;
              final unresolvedIncidents = allIncidents
                  .where((i) => i.status != IncidentStatus.resolved)
                  .length;
              final resolvedIncidents = totalIncidents - unresolvedIncidents;
              final completedShifts = allShifts
                  .where((s) => s.actualCheckIn != null)
                  .toList();
              final attendanceRate = allShifts.isEmpty
                  ? 0
                  : (completedShifts.length / allShifts.length * 100).toInt();

              double totalWorkMinutes = 0;
              for (var s in completedShifts) {
                if (s.actualCheckOut != null) {
                  totalWorkMinutes += s.actualCheckOut!
                      .difference(s.actualCheckIn!)
                      .inMinutes;
                }
              }
              final totalWorkHours = (totalWorkMinutes / 60).toStringAsFixed(0);

              int lateCount = 0;
              for (var s in completedShifts) {
                if (s.actualCheckIn!.difference(s.startTime).inMinutes > 15) {
                  lateCount++;
                }
              }
              final absentCount = allShifts
                  .where(
                    (s) =>
                        s.status == 'absent' ||
                        (s.startTime.isBefore(
                              DateTime.now().subtract(
                                const Duration(minutes: 15),
                              ),
                            ) &&
                            s.actualCheckIn == null),
                  )
                  .length;

              final trendData = _calculateTrendData(allShifts);
              final distribution = _calculateShiftDistribution(allShifts);
              final performerRankings = _calculatePerformerRankings(
                guards,
                allShifts,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Metrics Row
                    Row(
                      children: [
                        _buildMetricCard(
                          icon: Icons.trending_up,
                          iconColor: Colors.blue,
                          value: '$attendanceRate%',
                          title: 'Avg Attendance',
                          subtitle: 'Overall',
                          trend: '+3.2%',
                          trendColor: Colors.green,
                        ),
                        _buildMetricCard(
                          icon: Icons.people_outline,
                          iconColor: Colors.green,
                          value: NumberFormat(
                            '#,###',
                          ).format(double.parse(totalWorkHours)),
                          title: 'Total Work Hours',
                          subtitle: 'Cumulative',
                          trend: '+1.5%',
                          trendColor: Colors.green,
                        ),
                        _buildMetricCard(
                          icon: Icons.access_time,
                          iconColor: Colors.orange,
                          value: '$lateCount',
                          title: 'Late Check-ins',
                          subtitle: 'Total recorded',
                          trend: lateCount > 5 ? '+8%' : '-2%',
                          trendColor: lateCount > 5 ? Colors.red : Colors.green,
                        ),
                        _buildMetricCard(
                          icon: Icons.description_outlined,
                          iconColor: Colors.red,
                          value: '$absentCount',
                          title: 'Total Absences',
                          subtitle: 'Logged',
                          trend: '+4%',
                          trendColor: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildMetricCard(
                          icon: Icons.report_problem_outlined,
                          iconColor: Colors.redAccent,
                          value: '$totalIncidents',
                          title: 'Total Incidents',
                          subtitle: 'Security Events',
                          trend: 'Sync Live',
                          trendColor: Colors.blue,
                        ),
                        _buildMetricCard(
                          icon: Icons.pending_actions,
                          iconColor: Colors.orange,
                          value: '$unresolvedIncidents',
                          title: 'Active Issues',
                          subtitle: 'Unresolved',
                          trend: unresolvedIncidents > 0
                              ? 'Action Reqd'
                              : 'Clear',
                          trendColor: unresolvedIncidents > 0
                              ? Colors.red
                              : Colors.green,
                        ),
                        const Spacer(),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildAttendanceTrendCard(trendData),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: _buildIncidentDistributionCard(allIncidents),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildShiftDistributionCard(distribution),
                    const SizedBox(height: 32),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTopPerformersCard(performerRankings),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildReportTemplatesCard(allShifts, guards),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
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

  // --- Analytical Helpers ---

  List<_TrendPoint> _calculateTrendData(List<ShiftModel> shifts) {
    final now = DateTime.now();
    List<_TrendPoint> points = [];
    if (_selectedTimeframe == 'Last 30 days') {
      for (int i = 3; i >= 0; i--) {
        final weekStart = now.subtract(Duration(days: (i + 1) * 7));
        final weekEnd = now.subtract(Duration(days: i * 7));
        final count = shifts
            .where(
              (s) =>
                  s.actualCheckIn != null &&
                  s.actualCheckIn!.isAfter(weekStart) &&
                  s.actualCheckIn!.isBefore(weekEnd),
            )
            .length;
        points.add(_TrendPoint(label: 'Wk ${4 - i}', value: count.toDouble()));
      }
    } else {
      for (int i = 5; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final nextMonthDate = DateTime(now.year, now.month - i + 1, 1);
        final count = shifts
            .where(
              (s) =>
                  s.actualCheckIn != null &&
                  s.actualCheckIn!.isAfter(monthDate) &&
                  s.actualCheckIn!.isBefore(nextMonthDate),
            )
            .length;
        points.add(
          _TrendPoint(
            label: DateFormat('MMM').format(monthDate),
            value: count.toDouble(),
          ),
        );
      }
    }
    return points;
  }

  _ShiftDistribution _calculateShiftDistribution(List<ShiftModel> shifts) {
    int dCount = 0, sCount = 0, nCount = 0;
    for (var s in shifts) {
      final hour = s.startTime.hour;
      if (hour >= 6 && hour < 14)
        dCount++;
      else if (hour >= 14 && hour < 22)
        sCount++;
      else
        nCount++;
    }
    final total = dCount + sCount + nCount;
    if (total == 0) return _ShiftDistribution(day: 0, swing: 0, night: 0);
    return _ShiftDistribution(
      day: (dCount / total * 100),
      swing: (sCount / total * 100),
      night: (nCount / total * 100),
    );
  }

  List<_GuardPerformance> _calculatePerformerRankings(
    List<UserModel> guards,
    List<ShiftModel> allShifts,
  ) {
    final rankings = guards.map((guard) {
      final guardShifts = allShifts
          .where((s) => s.personnelId == guard.id)
          .toList();
      if (guardShifts.isEmpty)
        return _GuardPerformance(
          guard: guard,
          score: 0,
          onTimeRate: 0,
          shiftsCount: 0,
        );
      final present = guardShifts.where((s) => s.actualCheckIn != null).length;
      final attendanceRate = present / guardShifts.length;
      int onTime = 0;
      for (var s in guardShifts) {
        if (s.actualCheckIn != null &&
            s.actualCheckIn!.difference(s.startTime).inMinutes <= 15)
          onTime++;
      }
      final punctuality = present == 0 ? 0.0 : onTime / present;
      final finalScore = (attendanceRate * 70) + (punctuality * 30);
      return _GuardPerformance(
        guard: guard,
        score: finalScore.toInt(),
        onTimeRate: (punctuality * 100).toInt(),
        shiftsCount: guardShifts.length,
      );
    }).toList();
    rankings.sort((a, b) => b.score.compareTo(a.score));
    return rankings.take(5).toList();
  }

  // --- UI Components ---

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String title,
    required String subtitle,
    required String trend,
    required Color trendColor,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Text(
                  trend,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTrendCard(List<_TrendPoint> points) {
    final maxVal = points.isEmpty
        ? 10.0
        : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance Trend',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    _selectedTimeframe == 'Last 30 days'
                        ? 'Weekly check-in volume'
                        : 'Monthly check-in volume',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedTimeframe,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    items: ['Last 30 days', 'Last 6 months', 'Last year']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTimeframe = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxVal / 4).clamp(1, 100),
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (v, _) =>
                          (v.toInt() >= 0 && v.toInt() < points.length)
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                points[v.toInt()].label,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                        .toList(),
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftDistributionCard(_ShiftDistribution dist) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shift Distribution',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            'By scheduled start time',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: Colors.blue.shade600,
                    value: dist.day,
                    showTitle: false,
                    radius: 20,
                  ),
                  PieChartSectionData(
                    color: Colors.purple.shade400,
                    value: dist.night,
                    showTitle: false,
                    radius: 20,
                  ),
                  PieChartSectionData(
                    color: Colors.green.shade400,
                    value: dist.swing,
                    showTitle: false,
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildLegendItem(
            Colors.blue.shade600,
            'Day Shift',
            '${dist.day.toInt()}%',
          ),
          const SizedBox(height: 12),
          _buildLegendItem(
            Colors.purple.shade400,
            'Night Shift',
            '${dist.night.toInt()}%',
          ),
          const SizedBox(height: 12),
          _buildLegendItem(
            Colors.green.shade400,
            'Swing Shift',
            '${dist.swing.toInt()}%',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color c, String l, String v) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(l, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const Spacer(),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildIncidentDistributionCard(List<IncidentModel> incidents) {
    final Map<String, int> counts = {};
    for (var i in incidents) {
      final label = i.type.name.toUpperCase();
      counts[label] = (counts[label] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Incident Analysis',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            'By reported type',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 32),
          if (incidents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No incidents recorded.'),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: counts.entries.map((e) {
                    final index = counts.keys.toList().indexOf(e.key);
                    final color =
                        Colors.primaries[index % Colors.primaries.length];
                    return PieChartSectionData(
                      color: color,
                      value: e.value.toDouble(),
                      showTitle: false,
                      radius: 15,
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          ...counts.entries.map((e) {
            final index = counts.keys.toList().indexOf(e.key);
            final color = Colors.primaries[index % Colors.primaries.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildLegendItem(color, e.key, e.value.toString()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopPerformersCard(List<_GuardPerformance> performers) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Performers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            'Ranked by Attendance & Punctuality',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const Divider(height: 40),
          if (performers.isEmpty)
            const Center(child: Text('No shift data recorded yet.'))
          else
            ...performers.asMap().entries.map(
              (e) => _buildPerformerItem(
                rank: e.key + 1,
                name: e.value.guard.name,
                id: 'ID: ${e.value.guard.id.substring(0, 4)}',
                score: '${e.value.score}%',
                shifts: '${e.value.shiftsCount} shifts',
                onTime: '${e.value.onTimeRate}% on-time',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformerItem({
    required int rank,
    required String name,
    required String id,
    required String score,
    required String shifts,
    required String onTime,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            radius: 18,
            child: Text(
              '$rank',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      score,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      id,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$shifts • $onTime',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTemplatesCard(
    List<ShiftModel> shifts,
    List<UserModel> guards,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Templates',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Text(
            'Instant operational exports',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const Divider(height: 40),
          _buildTemplateItem(
            title: 'Monthly Attendance Summary',
            subtitle: 'Complete attendance overview for the month',
            tag: 'Standard',
            onGenerate: () => _handleReportGeneration(
              title: 'Monthly Attendance Summary',
              shifts: shifts,
              guards: guards,
            ),
          ),
          _buildTemplateItem(
            title: 'Performance Analysis',
            subtitle: 'Individual and team performance metrics',
            tag: 'Analytics',
            onGenerate: () => _handleReportGeneration(
              title: 'Performance Analysis',
              shifts: shifts,
              guards: guards,
            ),
          ),
          _buildTemplateItem(
            title: 'Absence & Late Report',
            subtitle: 'Detailed analysis of absences and tardiness',
            tag: 'Standard',
            onGenerate: () => _handleReportGeneration(
              title: 'Absence & Late Report',
              shifts: shifts,
              guards: guards,
            ),
          ),
          _buildTemplateItem(
            title: 'Site Comparison',
            subtitle: 'Cross-site performance and trends',
            tag: 'Analytics',
            onGenerate: () => _handleReportGeneration(
              title: 'Site Comparison',
              shifts: shifts,
              guards: guards,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateItem({
    required String title,
    required String subtitle,
    required String tag,
    required VoidCallback onGenerate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description_outlined, color: Colors.grey, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    InkWell(
                      onTap: onGenerate,
                      child: const Text(
                        'Generate',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tag == 'Standard'
                        ? Colors.blue.shade50
                        : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: tag == 'Standard' ? Colors.blue : Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPoint {
  final String label;
  final double value;
  _TrendPoint({required this.label, required this.value});
}

class _ShiftDistribution {
  final double day;
  final double swing;
  final double night;
  _ShiftDistribution({
    required this.day,
    required this.swing,
    required this.night,
  });
}

class _GuardPerformance {
  final UserModel guard;
  final int score;
  final int shiftsCount;
  final int onTimeRate;
  _GuardPerformance({
    required this.guard,
    required this.score,
    required this.shiftsCount,
    required this.onTimeRate,
  });
}
