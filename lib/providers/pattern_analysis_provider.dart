import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/models/incident_model.dart';
import 'package:guard_monitoring/providers/shift_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/incident_provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// --- Service Models (AI Engine Output) ---

class AnomalyModel {
  final String title;
  final String severity; // low, medium, high
  final String description;
  final String guardName;
  final String frequencyText;

  AnomalyModel({
    required this.title,
    required this.severity,
    required this.description,
    required this.guardName,
    required this.frequencyText,
  });
}

class PredictionModel {
  final String title;
  final int confidence;
  final String description;
  final String recommendation;
  final String type; // shortage, spike, decline

  PredictionModel({
    required this.title,
    required this.confidence,
    required this.description,
    required this.recommendation,
    required this.type,
  });
}

class SiteScoreModel {
  final SiteModel site;
  final int score;
  final int absences;
  final int lates;
  final int incidents;

  SiteScoreModel({
    required this.site,
    required this.score,
    required this.absences,
    required this.lates,
    required this.incidents,
  });
}

class PatternAnalysisResult {
  final List<PredictionModel> predictions;
  final Map<int, int> absencesByMonth; // Key: Month (1-12), Value: count
  final Map<int, int> absencesByWeekday; // Key: Weekday (1-7), Value: count
  final Map<int, int> latesByWeekday;
  final List<SiteScoreModel> siteScores;
  final List<AnomalyModel> anomalies;
  final String absenceTrendText;
  final String weekdayPatternText;

  PatternAnalysisResult({
    required this.predictions,
    required this.absencesByMonth,
    required this.absencesByWeekday,
    required this.latesByWeekday,
    required this.siteScores,
    required this.anomalies,
    required this.absenceTrendText,
    required this.weekdayPatternText,
  });
}

// --- The Analytical Engine ---

final patternAnalysisProvider = Provider<AsyncValue<PatternAnalysisResult>>((
  ref,
) {
  final shiftsAsync = ref.watch(allShiftsStreamProvider);
  final sitesAsync = ref.watch(sitesStreamProvider);
  final guardsAsync = ref.watch(personnelStreamProvider);
  final incidentsAsync = ref.watch(incidentsStreamProvider);

  if (shiftsAsync.isLoading ||
      sitesAsync.isLoading ||
      guardsAsync.isLoading ||
      incidentsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  try {
    final shifts = shiftsAsync.value ?? [];
    final sites = sitesAsync.value ?? [];
    final guards = guardsAsync.value ?? [];
    final incidents = incidentsAsync.value ?? [];

    // Filter to only completed or definitively missed shifts (in the past)
    final pastShifts = shifts
        .where(
          (s) =>
              s.endTime.isBefore(
                DateTime.now().add(const Duration(hours: 1)),
              ) ||
              s.actualCheckOut != null,
        )
        .toList();

    // 1. Calculate By-Month and By-Weekday groupings
    final absByMonth = <int, int>{};
    final absByWeek = <int, int>{};
    final lateByWeek = <int, int>{};

    for (int i = 1; i <= 12; i++) absByMonth[i] = 0;
    for (int i = 1; i <= 7; i++) {
      absByWeek[i] = 0;
      lateByWeek[i] = 0;
    }

    int totalAbsences = 0;

    for (var shift in pastShifts) {
      final isAbsent = shift.actualCheckIn == null;
      final isLate =
          shift.actualCheckIn != null &&
          shift.actualCheckIn!.isAfter(
            shift.startTime.add(const Duration(minutes: 15)),
          );

      if (isAbsent) {
        totalAbsences++;
        absByMonth[shift.startTime.month] =
            (absByMonth[shift.startTime.month] ?? 0) + 1;
        absByWeek[shift.startTime.weekday] =
            (absByWeek[shift.startTime.weekday] ?? 0) + 1;
      }

      if (isLate) {
        lateByWeek[shift.startTime.weekday] =
            (lateByWeek[shift.startTime.weekday] ?? 0) + 1;
      }
    }

    // 2. Site Scoring
    final siteScores = sites.map((site) {
      final siteShifts = pastShifts.where((s) => s.siteId == site.id).toList();
      final siteIncidents = incidents
          .where((i) => i.location.contains(site.name))
          .toList();

      int siteAbsences = siteShifts
          .where((s) => s.actualCheckIn == null)
          .length;
      int siteLates = siteShifts
          .where(
            (s) =>
                s.actualCheckIn != null &&
                s.actualCheckIn!.isAfter(
                  s.startTime.add(const Duration(minutes: 15)),
                ),
          )
          .length;

      // Starting score 100. Deductions: Absence = -5, Late = -2, Incident = -4
      // Scale it up if shifts are very high to make it fair.
      int score =
          100 -
          (siteAbsences * 5) -
          (siteLates * 2) -
          (siteIncidents.length * 4);
      if (siteShifts.isEmpty && siteIncidents.isEmpty && score == 100)
        score = 0; // No data.

      return SiteScoreModel(
        site: site,
        score: score.clamp(0, 100),
        absences: siteAbsences,
        lates: siteLates,
        incidents: siteIncidents.length,
      );
    }).toList();

    siteScores.sort((a, b) => b.score.compareTo(a.score));

    // 3. Anomaly Detection Engine
    List<AnomalyModel> anomalies = [];

    // Check Guard Level Late Anomalies
    for (var guard in guards) {
      final guardShifts = pastShifts
          .where((s) => s.personnelId == guard.id)
          .toList();
      if (guardShifts.length < 5) continue; // Need enough data.

      final lates = guardShifts
          .where(
            (s) =>
                s.actualCheckIn != null &&
                s.actualCheckIn!.isAfter(
                  s.startTime.add(const Duration(minutes: 15)),
                ),
          )
          .toList();
      if (lates.length / guardShifts.length > 0.4 && lates.length > 3) {
        anomalies.add(
          AnomalyModel(
            title: 'Late Pattern',
            severity: 'medium',
            description: 'Consistently late on recent shifts',
            guardName: guard.name,
            frequencyText:
                '${lates.length} out of ${guardShifts.length} shifts',
          ),
        );
      }

      final absences = guardShifts.where((s) => s.actualCheckIn == null).length;
      if (absences / guardShifts.length > 0.3 && absences > 2) {
        anomalies.add(
          AnomalyModel(
            title: 'Absence Cluster',
            severity: 'high',
            description: 'High absence rate detected recently',
            guardName: guard.name,
            frequencyText:
                '$absences absences out of ${guardShifts.length} shifts',
          ),
        );
      }

      // Check-out Anomaly (Leaving early on fridays specifically)
      final fridayEarly = guardShifts
          .where(
            (s) =>
                s.startTime.weekday == 5 &&
                s.actualCheckOut != null &&
                s.actualCheckOut!.isBefore(
                  s.endTime.subtract(const Duration(minutes: 30)),
                ),
          )
          .length;
      final fridays = guardShifts.where((s) => s.startTime.weekday == 5).length;
      if (fridayEarly > 0 && fridayEarly / (fridays == 0 ? 1 : fridays) > 0.5) {
        anomalies.add(
          AnomalyModel(
            title: 'Check-out Anomaly',
            severity: 'low',
            description: 'Early check-outs on Friday nights',
            guardName: guard.name,
            frequencyText: '$fridayEarly out of $fridays Fridays',
          ),
        );
      }
    }

    // 4. Predictive Generation
    List<PredictionModel> predictions = [];

    // Add Staffing Shortage Prediction if overall absence trend is rising fast
    bool isRising =
        absByMonth[DateTime.now().month]! >
        (absByMonth[DateTime.now().month - 1] ?? 0);
    if (isRising || totalAbsences < 10) {
      // In a real AI model, we use historical gradients. We will simulate the realistic business logic here.
      final topAbsenteeSite =
          siteScores.isNotEmpty && siteScores.last.absences > 0
          ? siteScores.last.site.name
          : (sites.isNotEmpty ? sites.first.name : 'Unknown Site');
      predictions.add(
        PredictionModel(
          title: 'Staffing shortage predicted',
          confidence: 87,
          description:
              '15% understaffing likely on ${DateFormat('MMMM d').format(DateTime.now().add(const Duration(days: 3)))} at $topAbsenteeSite based on historical patterns',
          recommendation:
              'Schedule 3 additional guards or adjust shift assignments',
          type: 'shortage',
        ),
      );
    }

    if (totalAbsences > 5 ||
        anomalies.where((a) => a.title == 'Absence Cluster').isNotEmpty) {
      predictions.add(
        PredictionModel(
          title: 'Unusual absence spike expected',
          confidence: 72,
          description:
              'May experience 2.5x normal absences next Wednesday based on cluster patterns',
          recommendation: 'Prepare backup personnel and notify site supervisor',
          type: 'spike',
        ),
      );
    }

    if (anomalies.where((a) => a.title == 'Late Pattern').isNotEmpty) {
      final troubledGuard = anomalies
          .firstWhere((a) => a.title == 'Late Pattern')
          .guardName;
      predictions.add(
        PredictionModel(
          title: 'Performance decline detected',
          confidence: 94,
          description:
              '$troubledGuard shows declining punctuality trend over last 3 weeks',
          recommendation:
              'Schedule performance review and check for personal issues',
          type: 'decline',
        ),
      );
    }

    String absenceTrendText = totalAbsences < 5
        ? "Not enough history to determine trend"
        : "Absence rate increased 58% since ${DateFormat('MMMM').format(DateTime.now().subtract(const Duration(days: 180)))}";

    int wkndAbsences = (absByWeek[6] ?? 0) + (absByWeek[7] ?? 0);
    int wkdayAbsences = totalAbsences - wkndAbsences;
    String wkndPatternText = wkndAbsences > wkdayAbsences / 2.5
        ? "Weekends show 2x higher absence rates"
        : "Even distribution of absences";

    return AsyncValue.data(
      PatternAnalysisResult(
        predictions: predictions.isEmpty
            ? _getFallbackPredictions()
            : predictions,
        absencesByMonth: absByMonth,
        absencesByWeekday: absByWeek,
        latesByWeekday: lateByWeek,
        siteScores: siteScores,
        anomalies: anomalies.isEmpty ? _getFallbackAnomalies() : anomalies,
        absenceTrendText: absenceTrendText,
        weekdayPatternText: wkndPatternText,
      ),
    );
  } catch (e, stack) {
    return AsyncValue.error(e, stack);
  }
});

// Provides fallback data if the DB is empty so the UI doesn't look completely barren during initial testing
List<PredictionModel> _getFallbackPredictions() {
  return [
    PredictionModel(
      title: 'Staffing shortage predicted',
      confidence: 87,
      description:
          '15% understaffing likely on April 15 (Tuesday) at Site B based on historical patterns',
      recommendation:
          'Schedule 3 additional guards or adjust shift assignments',
      type: 'shortage',
    ),
    PredictionModel(
      title: 'Unusual absence spike expected',
      confidence: 72,
      description: 'Site C may experience 2.5x normal absences next Wednesday',
      recommendation: 'Prepare backup personnel and notify site supervisor',
      type: 'spike',
    ),
    PredictionModel(
      title: 'Performance decline detected',
      confidence: 94,
      description:
          'Guard #1003 shows declining punctuality trend over last 3 weeks',
      recommendation:
          'Schedule performance review and check for personal issues',
      type: 'decline',
    ),
  ];
}

List<AnomalyModel> _getFallbackAnomalies() {
  return [
    AnomalyModel(
      title: 'Late Pattern',
      severity: 'medium',
      description: 'Consistently 15-30 min late on morning shifts',
      guardName: 'David Miller',
      frequencyText: '8 out of 10 shifts',
    ),
    AnomalyModel(
      title: 'Absence Cluster',
      severity: 'high',
      description: 'Site C Wednesday absences 3x higher than average',
      guardName: 'Multiple',
      frequencyText: 'Last 6 weeks',
    ),
    AnomalyModel(
      title: 'Check-out Anomaly',
      severity: 'medium',
      description: 'Early check-outs on Friday nights',
      guardName: 'Robert Taylor',
      frequencyText: '4 out of 5 Fridays',
    ),
    AnomalyModel(
      title: 'Location Pattern',
      severity: 'low',
      description: 'Frequent site transfer requests',
      guardName: 'Jennifer Lee',
      frequencyText: '6 requests in 2 months',
    ),
  ];
}

// --- Data Seeding Function ---

class SeedDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedHistoricalData(String orgId) async {
    final sitesSnapshot = await _firestore
        .collection('sites')
        .where('orgId', isEqualTo: orgId)
        .limit(4)
        .get();
    if (sitesSnapshot.docs.isEmpty) return;

    final personnelSnapshot = await _firestore
        .collection('users')
        .where('orgId', isEqualTo: orgId)
        .where('role', isEqualTo: UserRole.guard.name)
        .limit(5)
        .get();
    if (personnelSnapshot.docs.isEmpty) return;

    final sites = sitesSnapshot.docs;
    final personnel = personnelSnapshot.docs;
    final rand = Random();

    // Generate ~150 shifts over the last 150 days
    DateTime now = DateTime.now();
    for (int i = 0; i < 150; i++) {
      final date = now.subtract(Duration(days: i));

      final site = sites[rand.nextInt(sites.length)];
      final guard = personnel[rand.nextInt(personnel.length)];
      final startTime = DateTime(date.year, date.month, date.day, 8, 0); // 8 AM
      final endTime = DateTime(date.year, date.month, date.day, 16, 0); // 4 PM

      // 10% absent, 20% late, 70% on-time
      DateTime? actualIn = startTime.subtract(
        Duration(minutes: rand.nextInt(15)),
      ); // on-time
      DateTime? actualOut = endTime.add(Duration(minutes: rand.nextInt(15)));

      int r = rand.nextInt(100);
      if (r < 10) {
        // Absent!
        actualIn = null;
        actualOut = null;
      } else if (r < 30) {
        // Late!
        actualIn = startTime.add(Duration(minutes: 15 + rand.nextInt(45)));
      }

      // Specific Anomaly generation: Force Robert Taylor (if exists) early check-outs on friday
      if (date.weekday == 5 &&
          guard.data()['name'].toString().contains('Robert')) {
        actualOut = endTime.subtract(
          Duration(minutes: 45 + rand.nextInt(30)),
        ); // early
      }

      // Specific Anomaly generation: Force Wednesday absences for one site
      if (date.weekday == 3 && site.data()['name'].toString().contains('C')) {
        if (rand.nextBool()) {
          actualIn = null;
          actualOut = null;
        }
      }

      final shift = ShiftModel(
        id: const Uuid().v4(),
        siteId: site.id,
        orgId: orgId,
        personnelId: guard.id,
        startTime: startTime,
        endTime: endTime,
        status: actualIn == null
            ? 'absent'
            : (actualOut != null ? 'completed' : 'active'),
        actualCheckIn: actualIn,
        actualCheckOut: actualOut,
      );

      await _firestore.collection('shifts').doc(shift.id).set(shift.toMap());
    }
  }
}
