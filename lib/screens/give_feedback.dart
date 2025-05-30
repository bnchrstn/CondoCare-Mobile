import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GiveFeedbackPage extends StatefulWidget {
  final String taskId;
  final String property;

  const GiveFeedbackPage({Key? key, required this.taskId, required this.property}) : super(key: key);

  @override
  _GiveFeedbackPageState createState() => _GiveFeedbackPageState();
}

class _GiveFeedbackPageState extends State<GiveFeedbackPage> {
  double _rating = 0.0;
  String _feedback = '';
  bool _isSubmitting = false;

  Future<String?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> submitFeedback() async {
    setState(() => _isSubmitting = true);
    
    final token = await getJwtToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final url = Uri.parse('http://pacific-condocare.com/public/give_feedback.php');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'taskid': widget.taskId,
      'property': widget.property,
      'rating': _rating,
      'feedback': _feedback,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      setState(() => _isSubmitting = false);

      if (data['success']) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Feedback Submitted', 
                style: TextStyle(color: Color(0xFFD2AB59))),
            content: const Text(
              'Your feedback has been successfully submitted.',
              style: TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                child: const Text('OK', style: TextStyle(color: Color(0xFFD2AB59))),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to previous screen
                },
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to submit feedback')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Give Feedback', 
            style: TextStyle(color: Color(0xFFD2AB59), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2F2E2E),
        elevation: 2,
        iconTheme: const IconThemeData(color: Color(0xFFD2AB59)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How was your experience?',
              style: TextStyle(
                color: Color(0xFFD2AB59),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            
            // Rating Slider
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rating',
                      style: TextStyle(
                        color: Colors.black87, 
                        fontSize: 16, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) => Text(
                        '$index',
                        style: TextStyle(color: Colors.black54),
                      )),
                    ),
                    Slider(
                      value: _rating,
                      min: 0.0,
                      max: 5.0,
                      divisions: 5,
                      label: _rating.toStringAsFixed(1),
                      activeColor: const Color(0xFFD2AB59),
                      onChanged: (value) {
                        setState(() => _rating = value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Comment Field
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextFormField(
                  onChanged: (value) => _feedback = value,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'Share your thoughts',
                    labelStyle: TextStyle(color: Colors.black54),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : submitFeedback,
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
                      'Submit Feedback',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
