import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:capstone_mobile/screens/maintenance_request.dart';
import 'package:capstone_mobile/screens/resident_transaction.dart';
import 'package:capstone_mobile/screens/resident_profile.dart';
import 'package:intl/intl.dart'; // Add this for date formatting
import 'package:capstone_mobile/screens/login.dart';

class ResidentHomePage extends StatefulWidget {
  final List<String> properties;
  final String userid;

  const ResidentHomePage({super.key, required this.properties, required this.userid});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  List<dynamic> services = [];
  String? selectedProperty;
  String? selectedCategory;
  bool isLoading = true;
  Map<String, dynamic> userData = {};
  List<dynamic> fetchedUnits = [];
  List<dynamic> announcements = []; // Add this for announcements

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _fetchUserData(),
      _fetchServices(),
      _fetchAnnouncements(), // Add this to fetch announcements
    ]);
    setState(() => isLoading = false);
  }

  // Add this method to fetch announcements
  Future<void> _fetchAnnouncements() async {
    try {
      final propertiesParam = widget.properties.join(',');
      final response = await http.get(
        Uri.parse('http://pacific-condocare.com/public/get_announcements.php?properties=$propertiesParam'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            announcements = data['announcements'];
            
            // Sort by date (newest first)
            announcements.sort((a, b) {
              final dateA = DateTime.parse(a['createdAt']);
              final dateB = DateTime.parse(b['createdAt']);
              return dateB.compareTo(dateA);
            });
          });
        } else {
          print('Failed to load announcements: ${data['error']}');
        }
      } else {
        print('Failed to load announcements: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching announcements: $e');
    }
  }

  // Helper method to convert urgency to numeric value for sorting
  int _getUrgencyValue(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  // Helper method to get color based on urgency
  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(
        Uri.parse('http://pacific-condocare.com/public/get_units.php?userid=${widget.userid}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['status'] == 'success' && data['units'] is List) {
            List<dynamic> units = data['units'];

            setState(() {
              fetchedUnits = units;
              userData = {
                'properties': {
                  'L': units.map((unit) {
                    return {
                      'M': {
                        'name': {'S': unit['property']},
                        'units': {
                          'L': (unit['units'] as List).map((u) => {'S': u}).toList()
                        },
                      }
                    };
                  }).toList()
                }
              };
            });
          } else {
            print("Failed to get valid units data.");
          }
        } else {
          print("Response is not a valid Map<String, dynamic>");
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception fetching user data: $e");
    }
  }

 Future<void> _fetchServices() async {
  try {
    final propertiesParam = widget.properties.join(',');
    final response = await http.get(
      Uri.parse('http://pacific-condocare.com/public/get_services.php?property=$propertiesParam'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final loadedServices = data['services'];
        final initialCategory = loadedServices.isNotEmpty ? loadedServices.first['category'] : null;

        setState(() {
          services = loadedServices;
          selectedProperty = widget.properties.isNotEmpty ? widget.properties[0] : null;
          selectedCategory = initialCategory;
        });
      } else {
        print('Server error: ${data['error']}');
      }
    } else {
      print('Failed to load services: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching services: $e');
  }
}

  IconData _getIconForService(String name) {
    switch (name.toLowerCase()) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'plumbing & sanitary':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'pest control':
        return Icons.bug_report;
      case 'repairs':
        return Icons.build;
      case 'telco':
        return Icons.wifi;
      case 'leaks':
        return Icons.water_damage;
      case 'move in/move out process':
        return Icons.inventory;
      case 'structural concerns':
        return Icons.foundation_rounded; 
      default:
        return Icons.miscellaneous_services;
    }
  }

  // Build latest announcement card (compact version for the home screen)
  Widget _buildLatestAnnouncementCard(Map<String, dynamic> announcement) {
    final DateTime createdAt = DateTime.parse(announcement['createdAt']);
    final String formattedDate = DateFormat('MMM d, yyyy').format(createdAt);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getUrgencyColor(announcement['urgency']),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getUrgencyColor(announcement['urgency']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getUrgencyColor(announcement['urgency']),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${announcement['urgency']} Priority',
                    style: TextStyle(
                      color: _getUrgencyColor(announcement['urgency']),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            announcement['title'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 4),
          Text(
            announcement['message'],
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'From: ${announcement['property']}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Show all announcements dialog with proper constraints
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                          maxWidth: MediaQuery.of(context).size.width * 0.9,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'All Announcements',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: announcements
                                        .where((a) => selectedProperty == null ||
                                        a['property'] == selectedProperty)
                                        .map((a) => _buildAnnouncementCard(a))
                                        .toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: const Color(0xFFD2AB59),
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: Color(0xFFD2AB59),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build announcement card widget for the dialog showing all announcements
  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final DateTime createdAt = DateTime.parse(announcement['createdAt']);
    final String formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _getUrgencyColor(announcement['urgency']),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(announcement['urgency']).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getUrgencyColor(announcement['urgency']),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${announcement['urgency']} Priority',
                        style: TextStyle(
                          color: _getUrgencyColor(announcement['urgency']),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                announcement['title'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 5),
              Text(
                announcement['message'],
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'From: ${announcement['property']}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Show full announcement in dialog with proper constraints
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            announcement['title'],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          content: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.6,
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getUrgencyColor(announcement['urgency']).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getUrgencyColor(announcement['urgency']),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${announcement['urgency']} Priority',
                                      style: TextStyle(
                                        color: _getUrgencyColor(announcement['urgency']),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'From: ${announcement['property']}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  SelectableText(
                                    announcement['message'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Read More',
                      style: TextStyle(
                        color: Color(0xFFD2AB59),
                      ),
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

Widget _buildServiceTile(Map<String, dynamic> service) {
  final name = service['name'] ?? 'No Name';
  // Added: Extract subcategories from the service
  final List<String> subcategories = (service['subcategory'] as List<dynamic>?)
      ?.map((e) => e.toString())
      .toList() ?? [];

  return Card(
    color: Colors.white, 
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 8, 
    shadowColor: Colors.black26, 
    child: InkWell(
      onTap: () {
        if (selectedProperty != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MaintenanceRequestPage(
                userid: widget.userid,
                property: selectedProperty!,
                service: name,
                serviceId: service['id'],
                serviceCategory: service['category'],
                // Added: Pass the subcategories to the MaintenanceRequestPage
                serviceSubcategory: subcategories,
                userProperties: (userData['properties']?['L'] as List?)
                    ?.map<Map<String, dynamic>>((item) {
                  final propertyMap = item['M'] as Map<String, dynamic>;
                  final propertyName = propertyMap['name']['S'] as String;
                  final unitList = (propertyMap['units']['L'] as List)
                      .map<String>((unit) => unit['S'] as String)
                      .toList();
                  return {
                    'name': propertyName,
                    'units': unitList,
                  };
                }).toList() ?? [],
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForService(name),
              color: const Color(0xFFD2AB59),
              size: 36, // Slightly smaller icon
            ),
            const SizedBox(height: 10), // Reduced spacing
            Text(
              name,
              style: const TextStyle(
                color: Colors.black87, 
                fontWeight: FontWeight.w600,
                fontSize: 14, // Smaller font
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  List<dynamic> filteredServices = selectedProperty == null
      ? []
      : services.where((s) {
          final matchesProperty = s['property'] == selectedProperty;
          final matchesCategory = selectedCategory == null || s['category'] == selectedCategory;
          return matchesProperty && matchesCategory;
        }).toList();

  Set<String> categories = services.map<String>((s) => s['category'] ?? 'Uncategorized').toSet();

  // Filter announcements by selected property
  List<dynamic> filteredAnnouncements = selectedProperty == null
      ? announcements
      : announcements.where((a) => a['property'] == selectedProperty).toList();

  return Scaffold(
    backgroundColor: Colors.grey[100],
    appBar: AppBar(
      backgroundColor: const Color(0xFF2F2E2E),
      elevation: 4,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Image.asset('assets/images/pacific2.png', height: 32),
          const SizedBox(width: 10),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: Colors.white),
          onSelected: (value) {
            if (value == 'about') {
              // Handle about action
            } else if (value == 'logout') {
              // Navigate to login screen and remove all previous routes
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginPage(), // Make sure to import LoginPage
                ),
                (route) => false, // This removes all previous routes
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
        ),
      ],
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(  // Use ListView instead of SingleChildScrollView
            padding: const EdgeInsets.all(16), // Slightly reduced padding
            children: [
              // Announcements Section - Made more compact
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12), // Reduced padding
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Announcements',
                          style: TextStyle(
                            fontSize: 16, // Smaller font
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F2E2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8), // Reduced spacing
                    filteredAnnouncements.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10), // Reduced padding
                            child: Center(
                              child: Text(
                                'No announcements available',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12, // Smaller font
                                ),
                              ),
                            ),
                          )
                        : InkWell(
                            onTap: () {
                              // Show all announcements in dialog
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    width: double.maxFinite,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'All Announcements',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Flexible(
                                          child: SingleChildScrollView(
                                            child: Column(
                                              children: filteredAnnouncements
                                                  .map((a) => _buildAnnouncementCard(a))
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Close'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: filteredAnnouncements.isNotEmpty
                                ? _buildLatestAnnouncementCard(filteredAnnouncements.first)
                                : const SizedBox(),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16), // Reduced spacing

              // Property Selector
              if (widget.properties.isNotEmpty)
                DropdownButton<String>(
                  value: selectedProperty,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                  underline: Container(height: 2, color: const Color(0xFFD2AB59)),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedProperty = newValue;
                    });
                  },
                  items: widget.properties.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 12),
              // Category Selector
              if (services.isNotEmpty)
                DropdownButton<String>(
                  value: selectedCategory,
                  hint: const Text('Filter by Category', style: TextStyle(color: Colors.black)),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87),
                  underline: Container(height: 2, color: const Color(0xFFD2AB59)),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedCategory = newValue;
                    });
                  },
                  items: [
                    ...categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                  ],
                ),

              const SizedBox(height: 16), // Reduced spacing

              const Text(
                'Available Services',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16, // Smaller font
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Using GridView builder without fixed height
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(), // Disable internal scrolling
                shrinkWrap: true, // Allow GridView to take only needed space
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12, // Slightly reduced spacing
                  mainAxisSpacing: 12, // Slightly reduced spacing
                  childAspectRatio: 1.1, // Adjust this to make tiles slightly shorter
                ),
                itemCount: filteredServices.length,
                itemBuilder: (context, index) => _buildServiceTile(filteredServices[index]),
              ),
            ],
          ),
    bottomNavigationBar: BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFFD2AB59),
      unselectedItemColor: Colors.black54,
      currentIndex: 0,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResidentHomePage(properties: widget.properties, userid: widget.userid),
            ),
          );
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResidentTransactionPage(
                properties: widget.properties,
                userid: widget.userid,
              ),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResidentProfilePage(
                properties: widget.properties,
                userid: widget.userid,
              ),
            ),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Transactions'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    ),
  );
}
}
