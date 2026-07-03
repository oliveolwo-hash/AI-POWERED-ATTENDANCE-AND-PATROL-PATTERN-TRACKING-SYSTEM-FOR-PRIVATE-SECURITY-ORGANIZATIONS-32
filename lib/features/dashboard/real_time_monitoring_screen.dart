import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:guard_monitoring/components/shared_map_component.dart';
import 'package:guard_monitoring/core/constants.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class RealTimeMonitoringScreen extends ConsumerStatefulWidget {
  const RealTimeMonitoringScreen({super.key});

  @override
  ConsumerState<RealTimeMonitoringScreen> createState() =>
      _RealTimeMonitoringScreenState();
}

class _RealTimeMonitoringScreenState
    extends ConsumerState<RealTimeMonitoringScreen> {
  final fm.MapController _flutterMapController = fm.MapController();
  String? _selectedGuardId;
  String? _selectedSiteId;
  String _activeTab = 'Guards';
  bool _autoRefresh = true;
  Set<String> _notifiedGuardsOutside = {};

  LatLng? _supervisorLocation;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _determineSupervisorLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determineSupervisorLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _supervisorLocation = LatLng(position.latitude, position.longitude);
        });
      }
      
      _positionSubscription = Geolocator.getPositionStream().listen((Position pos) {
        if (mounted) {
          setState(() {
            _supervisorLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (e) {
      debugPrint("Error determining supervisor location: $e");
    }
  }
  
  final double _defaultLat = 0.3476;
  final double _defaultLng = 32.5825;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  LatLng? _searchedLocation;

  void _focusCameraOn(double lat, double lng) {
    _flutterMapController.move(LatLng(lat, lng), 16.0);
  }

  Widget _buildMapSection(List<SiteModel> sites, List<ShiftModel> shifts) {
    return SharedMapComponent(
      mapController: _flutterMapController,
      initialCenter: _supervisorLocation ?? LatLng(_defaultLat, _defaultLng),
      markers: [
        ...sites.map((site) => MapMarkerData(
          id: site.id,
          position: LatLng(site.latitude, site.longitude),
          icon: Icons.location_on,
          color: Colors.blue,
          size: 40,
          label: site.name,
        )),
        ...shifts.where((s) => s.currentLat != null && s.currentLng != null).map((shift) => MapMarkerData(
          id: shift.id,
          position: LatLng(shift.currentLat!, shift.currentLng!),
          icon: Icons.person_pin_circle,
          color: Colors.green,
          size: 40,
          label: 'Guard',
        )),
        if (_searchedLocation != null)
          MapMarkerData(
            id: 'search',
            position: _searchedLocation!,
            icon: Icons.search,
            color: Colors.red,
            size: 40,
            label: 'Search Result',
          ),
      ],
      circles: sites.where((s) => s.isGeofenceEnabled).map((site) => MapCircleData(
        id: site.id,
        center: LatLng(site.latitude, site.longitude),
        radiusInMeters: site.radius,
      )).toList(),
    );
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final searchQuery = query.toLowerCase().contains('kampala') ? query : '$query Kampala, Uganda';
      
      double? lat;
      double? lng;

      // Nominatim Fallback
      final nomUrl = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&limit=1&countrycodes=ug&viewbox=32.45,0.45,32.70,0.20&bounded=1');
      var response = await http.get(nomUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          lat = double.parse(data[0]['lat'].toString());
          lng = double.parse(data[0]['lon'].toString());
        }
      }

      if (lat != null && lng != null) {
        final newLoc = LatLng(lat, lng);
        if (mounted) {
          setState(() {
            _searchedLocation = newLoc;
          });
          _focusCameraOn(lat, lng);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found in Uganda. Try another search.')));
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showGuardHistory(
    BuildContext context,
    UserModel personnel,
    ShiftModel shift,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.history, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${personnel.name} - Movement History',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),
              const Text(
                'Timeline of Recent Events',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Simulated history timeline
              _buildTimelineEvent(
                'Guard Checked In',
                shift.actualCheckIn ??
                    DateTime.now().subtract(const Duration(hours: 1)),
                Colors.green,
              ),
              _buildTimelineEvent(
                'Patrol Movement Detected',
                DateTime.now().subtract(const Duration(minutes: 45)),
                Colors.blue,
              ),
              if (shift.status == 'Alert')
                _buildTimelineEvent(
                  'Deviation Warning Triggered',
                  DateTime.now().subtract(const Duration(minutes: 10)),
                  Colors.red,
                ),
              if (shift.status == 'Alert')
                _buildTimelineEvent(
                  'Stationary Warning',
                  DateTime.now().subtract(const Duration(minutes: 2)),
                  Colors.orange,
                ),
              if (shift.status != 'Alert' &&
                  shift.movementSpeed != null &&
                  shift.movementSpeed! == 0.0)
                _buildTimelineEvent(
                  'Guard Idle',
                  DateTime.now().subtract(const Duration(minutes: 1)),
                  Colors.grey,
                ),
              _buildTimelineEvent(
                'Latest Telemetry Sync',
                shift.lastLocationUpdate ?? DateTime.now(),
                AppTheme.secondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(String title, DateTime time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text(
              DateFormat('HH:mm:ss').format(time),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    final sitesAsync = ref.watch(sitesStreamProvider);

    if (userData == null)
      return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // Only stream shifts if auto-refresh is active (in a real app, toggle suspends subscription updates)
        stream: userData.role == UserRole.superAdmin
            ? FirebaseFirestore.instance
                .collection('shifts')
                .where('actualCheckOut', isNull: true)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('shifts')
                .where('orgId', isEqualTo: userData.id)
                .where('actualCheckOut', isNull: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));

          final shifts = snapshot.hasData
              ? snapshot.data!.docs
                    .map(
                      (doc) => ShiftModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                      ),
                    )
                    .where((s) => s.actualCheckIn != null)
                    .toList()
              : <ShiftModel>[];

          return sitesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Map Error: $e')),
            data: (rawSites) {
                final isSuperAdmin = userData.role == UserRole.superAdmin;
                // Admins see all sites
                // Supervisors only see sites assigned to them.
                final sites = isSuperAdmin 
                    ? rawSites 
                    : rawSites.where((s) => s.orgId == userData.id).toList();
                    

                final distanceCalc = const Distance();

                // Guard Processing (statistics only)
                int activePatrols = 0;
                int stationary = 0;
                int alerts = 0;
                for (var shift in shifts) {
                  if (shift.status == 'Alert')
                    alerts++;
                  else if (shift.movementSpeed == null || shift.movementSpeed! == 0)
                    stationary++;
                  else
                    activePatrols++;
                    
                  // Inside/Outside Geofence check
                  if (shift.currentLat != null && shift.currentLng != null) {
                    final site = sites.where((s) => s.id == shift.siteId).firstOrNull;
                    if (site != null && site.isGeofenceEnabled) {
                      final dist = distanceCalc.as(LengthUnit.Meter, 
                          LatLng(shift.currentLat!, shift.currentLng!), 
                          LatLng(site.latitude, site.longitude));
                      if (dist > site.radius) {
                        if (!_notifiedGuardsOutside.contains(shift.id)) {
                          _notifiedGuardsOutside.add(shift.id);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Alert: A guard has left the geofence at ${site.name}'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          });
                        }
                      } else {
                        _notifiedGuardsOutside.remove(shift.id);
                      }
                    }
                  }
                }

              return Row(
                children: [
                  // MAP ENGINE TILE (70%)
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        // Top Stats Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          color: Colors.white,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatOverlay(
                                    Icons.security,
                                    'Total Tracked',
                                    '${shifts.length}',
                                    Colors.blueGrey,
                                  ),
                                  _buildStatOverlay(
                                    Icons.directions_run,
                                    'Active Patrols',
                                    '$activePatrols',
                                    Colors.green,
                                  ),
                                  _buildStatOverlay(
                                    Icons.boy,
                                    'Stationary',
                                    '$stationary',
                                    Colors.orange,
                                  ),
                                  _buildStatOverlay(
                                    Icons.warning,
                                    'Active Alerts',
                                    '$alerts',
                                    Colors.red,
                                  ),
                                ],
                              ),
                              // Live Sync Control Inline
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _autoRefresh
                                        ? Icons.sync
                                        : Icons.sync_disabled,
                                    color: _autoRefresh
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _autoRefresh ? 'Live Sync' : 'Paused',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Switch(
                                    value: _autoRefresh,
                                    activeColor: Colors.green,
                                    onChanged: (val) =>
                                        setState(() => _autoRefresh = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // The Map
                        Expanded(
                          child: Stack(
                            children: [
                              _buildMapSection(sites, shifts),
                              Positioned(
                                top: 10,
                                left: 10,
                                right: 10,
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: const InputDecoration(
                                            hintText: 'Search place (e.g. Entebbe)...',
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          ),
                                          onSubmitted: _searchPlace,
                                        ),
                                      ),
                                      if (_isSearching)
                                        const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.search, color: AppTheme.primaryColor),
                                          onPressed: () => _searchPlace(_searchController.text),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                right: 20,
                                child: FloatingActionButton(
                                  mini: true,
                                  backgroundColor: Colors.white,
                                  onPressed: () {
                                    if (_supervisorLocation != null) {
                                      _focusCameraOn(_supervisorLocation!.latitude, _supervisorLocation!.longitude);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Locating supervisor...')),
                                      );
                                      _determineSupervisorLocation().then((_) {
                                        if (_supervisorLocation != null) {
                                          _focusCameraOn(_supervisorLocation!.latitude, _supervisorLocation!.longitude);
                                        }
                                      });
                                    }
                                  },
                                  child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // GUARD TRACKING PANEL (30%)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(-2, 0),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            color: AppTheme.primaryColor,
                            child: Row(
                              children: [
                                const Icon(Icons.radar, color: Colors.white),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Live Monitoring',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _activeTab == 'Guards'
                                            ? 'Displaying ${shifts.length} active pipelines'
                                            : 'Displaying ${sites.length} managed sites',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Flat Tab Selector Under Header
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _activeTab = 'Guards'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _activeTab == 'Guards'
                                                  ? AppTheme.primaryColor
                                                  : Colors.transparent,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Guards (${shifts.length})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _activeTab == 'Guards'
                                                  ? AppTheme.primaryColor
                                                  : Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _activeTab = 'Sites'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _activeTab == 'Sites'
                                                  ? AppTheme.primaryColor
                                                  : Colors.transparent,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Sites (${sites.length})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _activeTab == 'Sites'
                                                  ? AppTheme.primaryColor
                                                  : Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _activeTab == 'Guards'
                                ? (shifts.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No active guards on site.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: shifts.length,
                                        itemBuilder: (context, index) {
                                          final shift = shifts[index];
                                          final isSelected =
                                              _selectedGuardId == shift.id;

                                          return FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(shift.personnelId)
                                                .get(),
                                            builder: (ctx, tSnap) {
                                              if (!tSnap.hasData)
                                                return const SizedBox.shrink();
                                              final user = UserModel.fromMap(
                                                tSnap.data!.data()
                                                    as Map<String, dynamic>,
                                              );
                                              final isAlert =
                                                  shift.status == 'Alert';

                                              return InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedGuardId = shift.id;
                                                    _selectedSiteId = null;
                                                  });
                                                  if (shift.currentLat != null &&
                                                      shift.currentLng != null) {
                                                    _focusCameraOn(
                                                      shift.currentLat!,
                                                      shift.currentLng!,
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.blue.withOpacity(
                                                            0.05,
                                                          )
                                                        : (isAlert
                                                              ? Colors.red
                                                                    .withOpacity(
                                                                      0.05,
                                                                    )
                                                              : Colors.white),
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: isSelected
                                                            ? Colors.blue
                                                            : (isAlert
                                                                  ? Colors.red
                                                                  : Colors
                                                                        .transparent),
                                                        width: 4,
                                                      ),
                                                      bottom: BorderSide(
                                                        color: Colors.grey.shade200,
                                                      ),
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets.all(16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            user.name,
                                                            style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isAlert
                                                                  ? Colors.red
                                                                  : Colors.green,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              isAlert
                                                                  ? 'ALERT V-2'
                                                                  : 'SECURE',
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize: 10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            shift.currentLat != null
                                                                ? Icons.gps_fixed
                                                                : Icons.gps_off,
                                                            size: 14,
                                                            color: Colors.grey,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            shift.currentLat != null
                                                                ? '${shift.currentLat!.toStringAsFixed(4)}, ${shift.currentLng!.toStringAsFixed(4)}'
                                                                : 'No GPS Fix',
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 16),
                                                      // Telemetry Row
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          _buildTelemetryBar(
                                                            Icons
                                                                .battery_charging_full,
                                                            '${shift.batteryLevel ?? 0}%',
                                                            (shift.batteryLevel ??
                                                                    0) /
                                                                100,
                                                            (shift.batteryLevel ??
                                                                        0) <
                                                                    20
                                                                ? Colors.red
                                                                : Colors.green,
                                                          ),
                                                          _buildTelemetryBar(
                                                            Icons.speed,
                                                            '${shift.movementSpeed ?? 0} km/h',
                                                            ((shift.movementSpeed ??
                                                                        0) /
                                                                    10)
                                                                .clamp(0.0, 1.0),
                                                            Colors.blue,
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              const Text(
                                                                'Last Sync',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color:
                                                                      Colors.grey,
                                                                ),
                                                              ),
                                                              Text(
                                                                shift.lastLocationUpdate !=
                                                                        null
                                                                    ? DateFormat(
                                                                        'HH:mm:ss',
                                                                      ).format(
                                                                        shift
                                                                            .lastLocationUpdate!,
                                                                      )
                                                                    : 'N/A',
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize: 12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      if (isSelected) ...[
                                                        const SizedBox(height: 16),
                                                        SizedBox(
                                                          width: double.infinity,
                                                          child: OutlinedButton.icon(
                                                            onPressed: () =>
                                                                _showGuardHistory(
                                                                  context,
                                                                  user,
                                                                  shift,
                                                                ),
                                                            icon: const Icon(
                                                              Icons.history,
                                                              size: 16,
                                                            ),
                                                            label: const Text(
                                                              'View Movement History',
                                                            ),
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
                                      ))
                                : (sites.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No sites added yet.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: sites.length,
                                        itemBuilder: (context, index) {
                                          final site = sites[index];
                                          final isSelected = _selectedSiteId == site.id;

                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                _selectedSiteId = site.id;
                                                _selectedGuardId = null;
                                              });
                                              _focusCameraOn(site.latitude, site.longitude);
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.blue.withOpacity(0.05)
                                                    : Colors.white,
                                                border: Border(
                                                  left: BorderSide(
                                                    color: isSelected
                                                        ? Colors.blue
                                                        : Colors.transparent,
                                                    width: 4,
                                                  ),
                                                  bottom: BorderSide(
                                                    color: Colors.grey.shade200,
                                                  ),
                                                ),
                                              ),
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          site.name,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: site.isActive ? Colors.green : Colors.grey,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          site.isActive ? 'ACTIVE' : 'INACTIVE',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    site.address,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.category, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        site.type,
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      const Icon(Icons.radar, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Geofence: ${site.isGeofenceEnabled ? "On" : "Off"}',
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ))),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatOverlay(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryBar(
    IconData icon,
    String label,
    double progress,
    Color color,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }
}
