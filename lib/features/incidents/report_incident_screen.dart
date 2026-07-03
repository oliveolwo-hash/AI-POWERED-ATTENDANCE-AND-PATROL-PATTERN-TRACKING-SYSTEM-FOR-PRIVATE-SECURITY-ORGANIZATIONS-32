import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guard_monitoring/models/incident_model.dart';
import 'package:guard_monitoring/providers/auth_provider.dart';
import 'package:guard_monitoring/providers/incident_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _customTypeController = TextEditingController();

  IncidentType? _selectedType;
  IncidentPriority _selectedPriority = IncidentPriority.medium;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  String _submitStatus = 'Submitting...';

  final Map<IncidentType, String> _typeLabels = {
    IncidentType.securityBreach: 'Security Breach',
    IncidentType.suspiciousActivity: 'Suspicious Activity',
    IncidentType.equipmentMalfunction: 'Equipment Malfunction',
    IncidentType.medicalEmergency: 'Medical Emergency',
    IncidentType.fireSafety: 'Fire/Safety Hazard',
    IncidentType.vandalism: 'Vandalism',
    IncidentType.unauthorizedAccess: 'Unauthorized Access',
    IncidentType.other: 'Other',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    }
  }

  Future<String?> _uploadImage(String incidentId) async {
    if (_imageFile == null) return null;

    try {
      setState(() => _submitStatus = 'Uploading Evidence...');
      final ref = FirebaseStorage.instance.ref().child(
        'incidents/$incidentId.jpg',
      );
      final bytes = await _imageFile!.readAsBytes();
      final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userData = ref.read(userDataProvider).value;
      if (userData == null) throw Exception('User not logged in');

      final incidentId = const Uuid().v4();

      // Upload image if exists
      final cloudPhotoUrl = await _uploadImage(incidentId);

      final incident = IncidentModel(
        id: incidentId,
        guardId: userData.id,
        orgId: userData.orgId ?? '',
        description: _selectedType == IncidentType.other
            ? '[Custom Type: ${_customTypeController.text.trim()}]\n\n${_descriptionController.text.trim()}'
            : _descriptionController.text.trim(),
        timestamp: DateTime.now(),
        location: _locationController.text.trim(),
        priority: _selectedPriority,
        status: IncidentStatus.pending,
        type: _selectedType!,
        photoUrl: cloudPhotoUrl,
      );

      await ref.read(incidentRepositoryProvider).submitIncident(incident);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident report submitted successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting report: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Incident',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Document and submit security incidents',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                title: 'Incident Type *',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _typeLabels.entries.map((entry) {
                    final isSelected = _selectedType == entry.key;
                    return InkWell(
                      onTap: () => setState(() => _selectedType = entry.key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: (MediaQuery.of(context).size.width - 64) / 2,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.blue : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_selectedType == IncidentType.other) ...[
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Specify Custom Incident Type *',
                  child: TextFormField(
                    controller: _customTypeController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Water Leak, Power Outage',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    validator: (value) =>
                        _selectedType == IncidentType.other &&
                            (value == null || value.isEmpty)
                        ? 'Please specify what happened'
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'Severity Level *',
                child: Row(
                  children: [
                    _buildPriorityOption(IncidentPriority.low, 'Low'),
                    const SizedBox(width: 8),
                    _buildPriorityOption(IncidentPriority.medium, 'Medium'),
                    const SizedBox(width: 8),
                    _buildPriorityOption(IncidentPriority.high, 'High'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'Location *',
                child: TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Building A - North Wing',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'Description *',
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Provide detailed information about the incident...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'Photos (Optional)',
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.none,
                      ),
                    ),
                    child: CustomPaint(
                      painter: DashedRectPainter(color: Colors.grey.shade300),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(
                                      _imageFile!.path,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                  : Image.file(
                                      File(_imageFile!.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.grey[400],
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Capture Photo',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send),
                  label: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Incident Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff17070),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPriorityOption(IncidentPriority priority, String label) {
    final isSelected = _selectedPriority == priority;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPriority = priority),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5;
    const dashSpace = 5;

    // Drawing top edge
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }

    // Drawing bottom edge
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(startX + dashWidth, size.height),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Drawing left edge
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }

    // Drawing right edge
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width, startY),
        Offset(size.width, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
