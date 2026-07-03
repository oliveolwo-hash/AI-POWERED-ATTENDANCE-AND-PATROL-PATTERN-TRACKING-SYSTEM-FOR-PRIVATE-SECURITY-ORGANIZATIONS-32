import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/core/theme.dart';
import 'package:guard_monitoring/models/shift_model.dart';
import 'package:guard_monitoring/models/site_model.dart';
import 'package:guard_monitoring/models/user_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/site_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftAssignmentScreen extends ConsumerStatefulWidget {
  final VoidCallback? onAssigned;
  const ShiftAssignmentScreen({super.key, this.onAssigned});

  @override
  ConsumerState<ShiftAssignmentScreen> createState() =>
      _ShiftAssignmentScreenState();
}

class _ShiftAssignmentScreenState extends ConsumerState<ShiftAssignmentScreen> {
  SiteModel? _selectedSite;
  UserModel? _selectedPersonnel;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 8));
  bool _isLoading = false;

  Future<void> _assignShift() async {
    if (_selectedSite == null || _selectedPersonnel == null) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User not authenticated');

      final shift = ShiftModel(
        id: const Uuid().v4(),
        siteId: _selectedSite!.id,
        personnelId: _selectedPersonnel!.id,
        orgId: _selectedPersonnel!.orgId ?? user.uid,
        startTime: _startTime,
        endTime: _endTime,
      );

      await FirebaseFirestore.instance
          .collection('shifts')
          .doc(shift.id)
          .set(shift.toMap());
      if (mounted) {
        if (widget.onAssigned != null) {
          widget.onAssigned!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign shift: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesStreamProvider);
    final personnelAsync = ref.watch(personnelStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assign Shift',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Site',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              sitesAsync.when(
                data: (sites) => DropdownButtonFormField<SiteModel>(
                  value: _selectedSite,
                  items: sites
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSite = val),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Personnel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              personnelAsync.when(
                data: (personnel) => DropdownButtonFormField<UserModel>(
                  value: _selectedPersonnel,
                  items: personnel
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPersonnel = val),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Shift Timing',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_startTime.toString()),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_startTime),
                  );
                  if (time != null) {
                    setState(
                      () => _startTime = DateTime(
                        _startTime.year,
                        _startTime.month,
                        _startTime.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(_endTime.toString()),
                leading: const Icon(Icons.access_time_filled),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_endTime),
                  );
                  if (time != null) {
                    setState(
                      () => _endTime = DateTime(
                        _endTime.year,
                        _endTime.month,
                        _endTime.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 48),
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
                      onPressed: _isLoading ? null : _assignShift,
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
                          : const Text('Assign Shift'),
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
