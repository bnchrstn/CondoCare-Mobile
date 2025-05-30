import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:capstone_mobile/screens/give_feedback.dart';
import 'dart:convert';

import 'resident_transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaintenanceStatusPage extends StatefulWidget {
  final Transaction transaction;

  const MaintenanceStatusPage({super.key, required this.transaction});

  @override
  State<MaintenanceStatusPage> createState() => _MaintenanceStatusPageState();
}

class _MaintenanceStatusPageState extends State<MaintenanceStatusPage> {
  String? feedback;
  String? adminFeedback;
  int? rating;
  bool isLoading = true;

  // Updated colors to match maintenance_request.dart
  static const appBarColor = Color(0xFF2F2E2E);
  static const gold = Color(0xFFD2AB59);

  @override
  void initState() {
    super.initState();
    fetchFeedback();
  }

  Future<void> fetchFeedback() async {
    final token = await getJwtToken();
    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final url = Uri.parse('http://pacific-condocare.com/public/feedbacks.php');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'taskid': widget.transaction.taskid,
      'property': widget.transaction.property,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          feedback = data['feedback'];
          rating = int.tryParse(data['rating']?.toString() ?? '0');
          adminFeedback = data['adminFeedback'];  // Store admin feedback
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<bool> cancelRequest(BuildContext context, String taskid, String property, String room) async {
    final token = await getJwtToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    final url = Uri.parse('pacific-condocare.com/public/cancel_transaction.php');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({'taskid': taskid, 'property': property, 'room': room});

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      final success = data['success'] == true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Request cancelled successfully' : (data['error'] ?? 'Failed to cancel request.')),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );

      return success;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.redAccent),
      );
      return false;
    }
  }

  // Format date to show only the date part (no time)
  String formatDateOnly(String rawDate) {
    try {
      final dateTime = DateTime.parse(rawDate);
      return DateFormat('MMMM d, y').format(dateTime);
    } catch (_) {
      return 'Invalid date';
    }
  }

  // Format time to 12-hour format (e.g. "9:00 AM" instead of "09:00")
  String formatTimeIn12Hour(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return 'Not specified';
    }

    try {
      // Check if it's already in 12-hour format or contains AM/PM
      if (timeString.toUpperCase().contains('AM') || timeString.toUpperCase().contains('PM')) {
        return timeString; // Already in 12-hour format
      }

      // Try to parse it as a time in 24-hour format (like "14:30")
      final timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);

        if (hour != null && minute != null) {
          final now = DateTime.now();
          final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
          return DateFormat('h:mm a').format(dateTime); // "9:30 AM" format
        }
      }

      // If it's a complete DateTime string, try parsing it directly
      final dateTime = DateTime.tryParse(timeString);
      if (dateTime != null) {
        return DateFormat('h:mm a').format(dateTime);
      }

      // If we can't parse it, return as is
      return timeString;
    } catch (_) {
      return timeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;

    return Scaffold(
      // Updated background color to match maintenance_request.dart
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: appBarColor,
        title: const Text(
          'Request Details',
          style: TextStyle(
            color: gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: gold),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            // Updated to white background for card to match maintenance_request.dart
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Maintenance Request',
                style: TextStyle(
                  color: gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _detailItem('Status', transaction.status),
              _detailItem('Issue', transaction.serviceName),
              _detailItem('Booked Date', formatDateOnly(transaction.dateBooked)),
              // Updated preferred time field with 12-hour format
              _detailItem('Preferred Time', formatTimeIn12Hour(transaction.preferredTime)),
              _detailItem(
                'Completed Date',
                transaction.status.toLowerCase() == 'closed'
                    ? formatDateOnly(transaction.dateFinished)
                    : 'Not yet completed',
              ),
              _detailItem(
                'Assigned To',
                transaction.assignedTo != null && transaction.assignedTo!.isNotEmpty
                    ? transaction.assignedTo!
                    : 'Not assigned yet',
              ),
              if (transaction.status.toLowerCase() == 'closed') ...[
                const SizedBox(height: 20),
                // Updated divider color
                const Divider(color: Colors.grey),
                const Text(
                  'Your Feedback',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                if (feedback != null && feedback!.isNotEmpty) ...[
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < (rating ?? 0) ? Icons.star : Icons.star_border,
                        color: gold,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Updated text color
                  Text(
                    feedback!,
                    style: TextStyle(color: Colors.black87),
                  ),
                ] else ...[
                  // Updated text color
                  Text(
                    'No feedback yet.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(color: Colors.grey),
                const Text(
                  'Admin Feedback',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                if (adminFeedback != null && adminFeedback!.isNotEmpty) ...[
                  // Updated text color
                  Text(
                    adminFeedback!,
                    style: TextStyle(color: Colors.black87),
                  ),
                ] else ...[
                  // Updated text color
                  Text(
                    'No admin feedback yet.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ]
              ],
              const SizedBox(height: 30),
              // Button section with proper spacing
              const Divider(height: 30, color: Colors.grey),
              const SizedBox(height: 10),
              // Contact Admin button - always visible
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Contact admin
                  },
                  icon: const Icon(Icons.support_agent, color: Colors.black),
                  label: const Text(
                    'Contact Admin',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Cancel Request button - only for non-closed requests
              if (transaction.status.toLowerCase() != 'closed')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          // Updated dialog background color
                          backgroundColor: Colors.white,
                          title: const Text('Cancel Request', style: TextStyle(color: gold)),
                          content: const Text(
                            'Are you sure you want to cancel this request?',
                            // Updated text color
                            style: TextStyle(color: Colors.black87),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No', style: TextStyle(color: gold)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final result = await cancelRequest(
                          context,
                          transaction.taskid,
                          transaction.property,
                          transaction.room,
                        );
                        if (result) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    label: const Text(
                      'Cancel Request',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              // Add spacing after cancel button if it exists
              if (transaction.status.toLowerCase() != 'closed')
                const SizedBox(height: 14),
              // Give Feedback button - only for closed requests without feedback
              if (transaction.status.toLowerCase() == 'closed' && (feedback == null || feedback!.isEmpty))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GiveFeedbackPage(
                            taskId: transaction.taskid,
                            property: transaction.property,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.feedback, color: Colors.black),
                    label: const Text(
                      'Give Feedback',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ),
              // Add bottom padding to ensure content is never cut off
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              // Updated label text color
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              // Updated value text color
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
