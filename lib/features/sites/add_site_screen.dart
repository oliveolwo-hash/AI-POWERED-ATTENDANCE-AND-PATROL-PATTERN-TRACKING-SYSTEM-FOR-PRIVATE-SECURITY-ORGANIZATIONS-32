import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/components/shared_map_component.dart';
import 'package:guard_monitoring/core/constants.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

class AddSiteScreen extends ConsumerStatefulWidget {
  final SiteModel? existingSite;

  const AddSiteScreen({super.key, this.existingSite});

  @override
  ConsumerState<AddSiteScreen> createState() => _AddSiteScreenState();
}

class _AddSiteScreenState extends ConsumerState<AddSiteScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _buildingController;
  late final TextEditingController _streetController;
  late final TextEditingController _villageController;
  late final TextEditingController _customTypeController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final fm.MapController _flutterMapController = fm.MapController();

  List<Map<String, dynamic>> _suggestions = [];
  bool _isShowingSuggestions = false;

  // Use Point for map coordinates
  LatLng _selectedLocation = const LatLng(0.3476, 32.5825); // Default to Kampala, Uganda (lat, lng)
  double _radius = 100.0;
  String _siteType = 'Commercial';
  bool _isActive = true;
  bool _isGeofenceEnabled = true;
  bool _isLoading = false;
  String? _selectedSupervisorId;
  Timer? _debounce;
  bool _isProgrammaticAddressUpdate = false;

  final List<String> _siteTypes = [
    'Commercial',
    'Residential',
    'Industrial',
    'Government',
    'Retail',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingSite?.name ?? '',
    );
    _addressController = TextEditingController(
      text: widget.existingSite?.address ?? '',
    );
    _buildingController = TextEditingController(
      text: widget.existingSite?.building ?? '',
    );
    _streetController = TextEditingController(
      text: widget.existingSite?.street ?? '',
    );
    _villageController = TextEditingController(
      text: widget.existingSite?.village ?? '',
    );
    _addressController.addListener(_onAddressChanged);
    _customTypeController = TextEditingController();

    if (widget.existingSite != null) {
        _selectedLocation = LatLng(
          widget.existingSite!.latitude,
          widget.existingSite!.longitude,
        );
      _radius = widget.existingSite!.radius;
      _siteType = widget.existingSite!.type;
      if (!_siteTypes.contains(_siteType)) _siteTypes.add(_siteType);
      _isActive = widget.existingSite!.isActive;
      _isGeofenceEnabled = widget.existingSite!.isGeofenceEnabled;
      _selectedSupervisorId = widget.existingSite!.orgId;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.removeListener(_onAddressChanged);
    _nameController.dispose();

    _addressController.dispose();
    _buildingController.dispose();
    _streetController.dispose();
    _villageController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    if (_isProgrammaticAddressUpdate) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      if (_addressController.text.trim().isNotEmpty) {
        _geocodeAddressSilent(_addressController.text);
      }
    });
  }

  void _onMapTap(LatLng location) {
    setState(() => _selectedLocation = location);
    _reverseGeocode(location.latitude, location.longitude);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final nominatimUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1');
      final response = await http.get(nominatimUrl, headers: {'User-Agent': 'GuardMonitoringApp/1.0'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        final addressData = data['address'] as Map<String, dynamic>?;

        if (displayName != null) {
          final parts = displayName.split(',');
          final shortName = parts.isNotEmpty ? parts.first.trim() : displayName;
          
          final building = addressData?['building'] ?? addressData?['amenity'] ?? addressData?['shop'] ?? '';
          final street = addressData?['road'] ?? addressData?['pedestrian'] ?? addressData?['path'] ?? '';
          final village = addressData?['village'] ?? addressData?['suburb'] ?? addressData?['neighbourhood'] ?? addressData?['city_district'] ?? '';
          
          _isProgrammaticAddressUpdate = true;
          if (mounted) {
            setState(() {
              _nameController.text = shortName;
              _addressController.text = displayName;
              _buildingController.text = building;
              _streetController.text = street;
              _villageController.text = village;
            });
          }
          Future.microtask(() => _isProgrammaticAddressUpdate = false);
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
  }



  Future<void> _geocodeAddressSilent(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final mapboxUrl = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$MAPBOX_ACCESS_TOKEN&country=ug&limit=1');
      var response = await http.get(mapboxUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final center = data['features'][0]['center'];
          final lng = (center[0] as num).toDouble();
          final lat = (center[1] as num).toDouble();
          
          final newLoc = LatLng(lat, lng);
          _onMapTap(newLoc);
          _flutterMapController.move(newLoc, 16.0);
        }
      }
    } catch (e) {
      debugPrint('Silent geocode error: $e');
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isShowingSuggestions = false;
        });
      }
      return;
    }
    setState(() {
      _isSearching = true;
      _isShowingSuggestions = true;
    });

    try {
      final List<Map<String, dynamic>> combinedSuggestions = [];

      final mapboxUrl = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$MAPBOX_ACCESS_TOKEN&country=ug&proximity=32.5825,0.3476&limit=3&fuzzyMatch=false');
      
      final nomUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&countrycodes=ug&limit=3&addressdetails=1');

      final responses = await Future.wait([
        http.get(mapboxUrl),
        http.get(nomUrl, headers: {'User-Agent': 'GuardMonitoringApp/1.0'}),
      ]);

      if (responses[0].statusCode == 200) {
        final data = json.decode(responses[0].body);
        if (data['features'] != null) {
          for (var feature in data['features']) {
            combinedSuggestions.add({
              'text': feature['text'],
              'place_name': feature['place_name'],
              'center': feature['center'],
            });
          }
        }
      }

      if (responses[1].statusCode == 200) {
        final data = json.decode(responses[1].body) as List;
        for (var place in data) {
          final lat = double.tryParse(place['lat'].toString()) ?? 0.0;
          final lon = double.tryParse(place['lon'].toString()) ?? 0.0;
          final name = place['name'] ?? place['display_name']?.split(',').first ?? 'Unknown';
          
          bool isDuplicate = false;
          for (var exist in combinedSuggestions) {
            final existLng = (exist['center'][0] as num).toDouble();
            final existLat = (exist['center'][1] as num).toDouble();
            if ((existLat - lat).abs() < 0.01 && 
                (existLng - lon).abs() < 0.01 && 
                exist['text'].toString().toLowerCase() == name.toString().toLowerCase()) {
              isDuplicate = true;
              break;
            }
          }

          if (!isDuplicate) {
            if (name.toString().toLowerCase() == query.toLowerCase().trim()) {
               combinedSuggestions.insert(0, {
                'text': name,
                'place_name': place['display_name'],
                'center': [lon, lat],
              });
            } else {
               combinedSuggestions.add({
                'text': name,
                'place_name': place['display_name'],
                'center': [lon, lat],
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _suggestions = combinedSuggestions;
        });
      }
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSuggestionSelected(Map<String, dynamic> feature) {
    FocusScope.of(context).unfocus(); // dismiss keyboard
    final center = feature['center'];
    final lng = (center[0] as num).toDouble();
    final lat = (center[1] as num).toDouble();
    final placeName = feature['place_name'] as String;

    final parts = placeName.split(',');
    final shortName = parts.isNotEmpty ? parts.first.trim() : placeName;

    final newLoc = LatLng(lat, lng);
    
    // Smooth move
    _flutterMapController.move(newLoc, 16.0);
    
    // Update marker
    _onMapTap(newLoc);

    _isProgrammaticAddressUpdate = true;
    setState(() {
      _searchController.text = placeName;
      _nameController.text = shortName;
      _addressController.text = placeName;
      _suggestions = [];
      _isShowingSuggestions = false;
    });
    Future.microtask(() => _isProgrammaticAddressUpdate = false);
  }

  Future<void> _saveSite() async {
    final loggedInUser = ref.read(userDataProvider).value;
    if (loggedInUser == null) return;

    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Address are required.')),
      );
      return;
    }


    if (_siteType == 'Other' && _customTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify the custom site type.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
        final site = SiteModel(
          id: widget.existingSite?.id ?? const Uuid().v4(),
          orgId: _selectedSupervisorId ?? widget.existingSite?.orgId ?? loggedInUser.id,

          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          building: _buildingController.text.trim(),
          street: _streetController.text.trim(),
          village: _villageController.text.trim(),
          type: _siteType == 'Other'
              ? _customTypeController.text.trim()
              : _siteType,
          latitude: _selectedLocation.latitude,
          longitude: _selectedLocation.longitude,
          radius: _radius,
          isGeofenceEnabled: _isGeofenceEnabled,
          isActive: _isActive,
        );

      if (widget.existingSite != null) {
        await ref.read(siteRepositoryProvider).updateSite(site);
      } else {
        await ref.read(siteRepositoryProvider).addSite(site);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save site: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: isDesktop ? const EdgeInsets.all(32) : const EdgeInsets.all(16),
      child: Container(
        width: isDesktop ? 1200 : 600,
        height: isDesktop ? 800 : MediaQuery.of(context).size.height * 0.9,
        color: Colors.white,
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildMapSection(),
                  ),
                  Container(width: 1, color: Colors.grey.shade300),
                  Expanded(
                    flex: 4,
                    child: _buildFormSection(),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 4, child: _buildMapSection()),
                  Container(height: 1, color: Colors.grey.shade300),
                  Expanded(flex: 6, child: _buildFormSection()),
                ],
              ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Stack(
      children: [
        SharedMapComponent(
          mapController: _flutterMapController,
          initialCenter: _selectedLocation,
          initialZoom: 16,
          onTap: _onMapTap,
          markers: [
            MapMarkerData(
              id: 'selected',
              position: _selectedLocation,
              icon: Icons.location_on,
              color: Colors.red,
              size: 40,
              label: _nameController.text.isNotEmpty ? _nameController.text : 'Selected Location',
            )
          ],
          circles: [
            if (_isGeofenceEnabled)
              MapCircleData(
                id: 'geofence',
                center: _selectedLocation,
                radiusInMeters: _radius,
              )
          ],
        ),
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 500), () {
                            _fetchSuggestions(val);
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search place (e.g. Lugogo)...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          suffixIcon: _searchController.text.isNotEmpty 
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _suggestions.clear();
                                      _isShowingSuggestions = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Icon(Icons.search, color: AppTheme.primaryColor),
                      ),
                  ],
                ),
              ),
              if (_isShowingSuggestions)
                Card(
                  elevation: 8,
                  margin: const EdgeInsets.only(top: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: _suggestions.isEmpty && !_isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No results found'),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final feature = _suggestions[index];
                              final text = feature['text'] ?? '';
                              final placeName = feature['place_name'] ?? '';
                              return ListTile(
                                leading: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                                title: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(placeName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () => _onSuggestionSelected(feature),
                              );
                            },
                          ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.existingSite != null ? 'Edit Managed Site' : 'Add New Site',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [

                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Site Name',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Full Address',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buildingController,
                        decoration: const InputDecoration(
                          labelText: 'Building/Amenity',
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _streetController,
                        decoration: const InputDecoration(
                          labelText: 'Street/Road',
                          prefixIcon: Icon(Icons.add_road),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _villageController,
                  decoration: const InputDecoration(
                    labelText: 'Village/Neighborhood',
                    prefixIcon: Icon(Icons.holiday_village),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: _selectedLocation.latitude.toStringAsFixed(6)),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          filled: true,
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: _selectedLocation.longitude.toStringAsFixed(6)),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          filled: true,
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _siteType,
                        decoration: const InputDecoration(
                          labelText: 'Site Type',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _siteTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _siteType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Geofence',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isGeofenceEnabled,
                          activeColor: Colors.blue,
                          onChanged: (val) {
                              setState(() => _isGeofenceEnabled = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (_siteType == 'Other') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Specify Custom Site Type',
                      prefixIcon: Icon(Icons.edit),
                    ),
                  ),
                ],
                if (_isGeofenceEnabled) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Boundary Radius: ${_radius.toInt()}m',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: '${_radius.toInt()}m',
                    onChanged: (value) {
                      setState(() => _radius = value);
                    },
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSite,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.existingSite != null
                                    ? 'Update Site'
                                    : 'Save Site',
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
