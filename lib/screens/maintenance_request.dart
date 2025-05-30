import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MaintenanceRequestPage extends StatefulWidget {
  final String userid;
  final String property;
  final String service;
  final String serviceId;
  final String serviceCategory;
  final List<String> serviceSubcategory;
  final List<Map<String, dynamic>> userProperties;

  const MaintenanceRequestPage({
    super.key,
    required this.userid,
    required this.property,
    required this.service,
    required this.userProperties,
    required this.serviceCategory,
    required this.serviceSubcategory,
    required this.serviceId,
  });

  @override
  State<MaintenanceRequestPage> createState() => _MaintenanceRequestPageState();
}

class _MaintenanceRequestPageState extends State<MaintenanceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  List<String> _unitOptions = [];
  String? _selectedUnit;
  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;

  List<String> _issueTypes = [];
  String? _selectedIssueType;

  bool get isCommonArea => widget.serviceCategory.toLowerCase() == 'common areas';

  @override
  void initState() {
    super.initState();
    _extractUnits();
    _extractIssueTypes();
  }

  void _extractUnits() {
    for (var property in widget.userProperties) {
      if (property['name'] == widget.property) {
        var units = property['units'] as List? ?? [];
        _unitOptions = List<String>.from(units);
        if (_unitOptions.isNotEmpty) {
          _selectedUnit = _unitOptions[0];
        }
        break;
      }
    }
  }

  void _extractIssueTypes() {
    _issueTypes = widget.serviceSubcategory.map((e) => e.trim()).toList();
    if (_issueTypes.isNotEmpty) {
      _selectedIssueType = _issueTypes[0];
    }
  }

  Future<String?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  String _generateTaskId(String property) {
    final prefix = property.toLowerCase().contains('skyloft') ? 'sl' : 'eg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$prefix$timestamp';
  }

  // Helper method to format time in 12-hour format
  String _formatTime12Hour(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preferredDate != null && _preferredTime != null) {
      final available = await _isTimeAvailable(_preferredDate!, _preferredTime!);
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The selected time slot is already booked. Please choose a different time.')),
        );
        return;
      }
    }
    setState(() => _isSubmitting = true);

    final uri = Uri.parse('http://pacific-condocare.com/public/submit_request.php');
    final token = await getJwtToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authorization token is missing')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final body = {
      'taskid': _generateTaskId(widget.property),
      'age': 0,
      'area': widget.service,
      'assignedTo': '',
      'comments': _commentController.text,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'property': widget.property,
      'room': isCommonArea ? '' : _selectedUnit,
      'status': 'Open',
      'submittedBy': widget.userid,
      'type': widget.service,
      'updatedAt': '',
      'preferredDate': _preferredDate != null
          ? '${_preferredDate!.year.toString().padLeft(4, '0')}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}'
          : null,
      'preferredTime': _preferredTime != null
          ? '${_preferredTime!.hour.toString().padLeft(2, '0')}:${_preferredTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'serviceId': widget.serviceId,
      'serviceCategory': widget.serviceCategory,
      'subcategory': _selectedIssueType,


    };

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode(body),
    );

    final data = json.decode(response.body);
    setState(() => _isSubmitting = false);

    if (data['success']) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Request Submitted',
              style: TextStyle(color: Color(0xFFD2AB59))),
          content: const Text(
            'Your maintenance request has been successfully submitted.',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text('OK', style: TextStyle(color: Color(0xFFD2AB59))),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${data['error']}')),
      );
    }
  }

  Future<bool> _isTimeAvailable(DateTime date, TimeOfDay time) async {
    final token = await getJwtToken();
    final uri = Uri.parse('http://pacific-condocare.com/public/check_time_availability.php');

    final formattedDate = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'date': formattedDate,
        'time': formattedTime,
        'property': widget.property,
        'room': isCommonArea ? '' : _selectedUnit,
      }),
    );

    final data = json.decode(response.body);
    return data['available'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F2E2E),
        elevation: 2,
        iconTheme: const IconThemeData(color: Color(0xFFD2AB59)),
        title: const Text(
          'Maintenance Request',
          style: TextStyle(color: Color(0xFFD2AB59), fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.service,
                style: const TextStyle(
                  color: Color(0xFFD2AB59),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Property: ${widget.property}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),

              if (!isCommonArea)
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      dropdownColor: Colors.white,
                      items: _unitOptions.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit, style: TextStyle(color: Colors.black87)),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedUnit = value),
                      decoration: const InputDecoration(
                        labelText: 'Room / Unit Number',
                        labelStyle: TextStyle(color: Colors.black54),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      validator: (value) =>
                      value == null ? 'Please select a unit' : null,
                    ),
                  ),
                ),

              if (_issueTypes.isNotEmpty)
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      value: _selectedIssueType,
                      dropdownColor: Colors.white,
                      items: _issueTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type, style: TextStyle(color: Colors.black87)),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedIssueType = value),
                      decoration: const InputDecoration(
                        labelText: 'Issue Type',
                        labelStyle: TextStyle(color: Colors.black54),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      validator: (value) => value == null ? 'Please select an issue type' : null,
                    ),
                  ),
                ),

              // Comment field
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextFormField(
                    controller: _commentController,
                    maxLines: 4,
                    style: TextStyle(color: Colors.black87),
                    decoration: const InputDecoration(
                      labelText: 'Describe the issue',
                      labelStyle: TextStyle(color: Colors.black54),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter details' : null,
                  ),
                ),
              ),

              if (!isCommonArea) ...[
                const Text(
                  'Preferred Date & Time',
                  style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Date picker
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFD2AB59),
                                      onPrimary: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setState(() => _preferredDate = picked);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFFD2AB59), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _preferredDate == null
                                      ? 'Select Date'
                                      : '${_preferredDate!.year}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Time picker with forced 12-hour format
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              // Force 12-hour format by wrapping in MediaQuery
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    alwaysUse24HourFormat: false,
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFFD2AB59),
                                        onPrimary: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                              },
                            );
                            if (picked != null) setState(() => _preferredTime = picked);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFFD2AB59), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _preferredTime == null
                                      ? 'Select Time'
                                      : _formatTime12Hour(_preferredTime!),
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD2AB59),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Submit Request',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
