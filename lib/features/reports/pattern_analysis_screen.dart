import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/providers/pattern_analysis_provider.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class PatternAnalysisScreen extends ConsumerWidget {
  const PatternAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(patternAnalysisProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  'AI Pattern Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            Text(
              'Machine learning insights and predictive analytics',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        toolbarHeight: 90,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final user = ref.read(userDataProvider).value;
                  if (user?.orgId != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Seeding historical shift data...'),
                      ),
                    );
                    await SeedDataService().seedHistoricalData(user!.orgId!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Seeding complete! Refreshing AI Engine...',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.science, size: 16),
                label: const Text('Seed AI Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: analysisAsync.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Predictions Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.predictions
                    .map(
                      (p) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: _buildPredictionCard(p),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),

              // 2. Charts Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildAbsenceTrendChart(
                      data.absencesByMonth,
                      data.absenceTrendText,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildWeekdayPatternsChart(
                      data.absencesByWeekday,
                      data.latesByWeekday,
                      data.weekdayPatternText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 3. Performance & Anomalies Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildSitePerformance(data.siteScores),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: _buildAnomaliesList(data.anomalies)),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildPredictionCard(PredictionModel p) {
    Color badgeColor;
    IconData icon;
    if (p.type == 'shortage') {
      badgeColor = Colors.red.shade50;
      icon = Icons.warning_amber_rounded;
    } else if (p.type == 'spike') {
      badgeColor = Colors.orange.shade50;
      icon = Icons.warning_amber_rounded;
    } else {
      badgeColor = Colors.blue.shade50;
      icon = Icons.info_outline;
    }

    Color textColor = p.type == 'shortage'
        ? Colors.red
        : (p.type == 'spike' ? Colors.orange.shade800 : Colors.blue.shade700);

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${p.confidence}% confidence',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            p.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            p.description,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Recommendation',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            p.recommendation,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceTrendChart(Map<int, int> data, String alertText) {
    final maxVal = data.values.isEmpty
        ? 10.0
        : data.values.reduce((a, b) => a > b ? a : b).toDouble();

    // Convert current map to past 7 months sorted
    final now = DateTime.now();
    List<FlSpot> spots = [];
    List<String> labels = [];
    int x = 0;
    for (int i = 6; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final val = data[month.month]?.toDouble() ?? 0.0;
      spots.add(FlSpot(x.toDouble(), val));
      labels.add(DateFormat('MMM').format(month));
      x++;
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Absence Trend',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.show_chart, color: Colors.red),
            ],
          ),
          Text(
            '7-month pattern analysis',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxVal / 4).clamp(1, 100),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxVal / 4).clamp(1, 100),
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (v, _) =>
                          (v.toInt() >= 0 && v.toInt() < labels.length)
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[v.toInt()],
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
                    spots: spots,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text(
                  'Alert: ',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    alertText,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayPatternsChart(
    Map<int, int> absData,
    Map<int, int> lateData,
    String patternText,
  ) {
    List<BarChartGroupData> groups = [];
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    double maxVal = 0;
    for (int i = 1; i <= 7; i++) {
      final abs = absData[i]?.toDouble() ?? 0.0;
      final lat = lateData[i]?.toDouble() ?? 0.0;
      if (abs > maxVal) maxVal = abs;
      if (lat > maxVal) maxVal = lat;

      groups.add(
        BarChartGroupData(
          x: i - 1,
          barRods: [
            BarChartRodData(
              toY: abs,
              color: Colors.red,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: lat,
              color: Colors.orange,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekday Patterns',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.calendar_month, color: Colors.blue),
            ],
          ),
          Text(
            'Absences (Red) and lates (Orange) by day',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxVal / 4).clamp(1, 100),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxVal / 4).clamp(1, 100),
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (v, _) =>
                          (v.toInt() >= 0 && v.toInt() < days.length)
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                days[v.toInt()],
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
                barGroups: groups,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  'Pattern: ',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    patternText,
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSitePerformance(List<SiteScoreModel> scores) {
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
            'Site Performance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Comparative analysis across locations',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ...scores.map((s) => _buildSiteItem(s)),
        ],
      ),
    );
  }

  Widget _buildSiteItem(SiteScoreModel score) {
    Color color = Colors.green;
    if (score.score < 75)
      color = Colors.red;
    else if (score.score < 90)
      color = Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    score.site.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                '${score.score}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Absences: ${score.absences}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Text(
                'Late: ${score.lates}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Text(
                'Incidents: ${score.incidents}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: score.score / 100,
            backgroundColor: Colors.grey.shade100,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesList(List<AnomalyModel> anomalies) {
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
            'Detected Anomalies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'AI-identified irregular patterns requiring attention',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ...anomalies.map((a) => _buildAnomalyItem(a)),
        ],
      ),
    );
  }

  Widget _buildAnomalyItem(AnomalyModel a) {
    Color tagColor = Colors.blue;
    if (a.severity == 'high')
      tagColor = Colors.red;
    else if (a.severity == 'medium')
      tagColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: tagColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        a.severity,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  a.description,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    Text(
                      'Guard: ${a.guardName}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Frequency: ${a.frequencyText}',
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
          TextButton(
            onPressed: () {},
            child: const Text(
              'Investigate',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
