import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_mobile/screens/login.dart';
import 'resident_home.dart';
import 'resident_transaction.dart'; 

class ResidentProfilePage extends StatefulWidget {
  final List<String> properties;
  final String userid;

  const ResidentProfilePage({
    Key? key,
    required this.properties,
    required this.userid,
  }) : super(key: key);

  @override
  State<ResidentProfilePage> createState() => _ResidentProfilePageState();
}

class _ResidentProfilePageState extends State<ResidentProfilePage> {
  bool isLoading = true;
  Map<String, dynamic> userData = {};
  int _currentIndex = 2; 
  
  // Controllers for editing fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // Track editing state
  bool _isEditingEmail = false;
  bool _isEditingContact = false;
  bool _isEditingPassword = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Function to validate Philippine phone numbers
  bool isValidPhilippinePhoneNumber(String contact) {
    // Pattern for mobile number: starts with 09 followed by 9 digits
    final mobilePattern = RegExp(r'^09\d{9}$');
    
    // Pattern for landline: 7-8 digits
    final landlinePattern = RegExp(r'^\d{7,8}$');
    
    return mobilePattern.hasMatch(contact) || landlinePattern.hasMatch(contact);
  }
  
  // Function to validate Gmail addresses
  bool isValidGmailAddress(String email) {
    // Case insensitive regex pattern to match Gmail addresses
    final gmailPattern = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$', caseSensitive: false);
    return gmailPattern.hasMatch(email);
  }

  Future<void> fetchUserProfile() async {
    try {
      final token = await getJwtToken();
      if (token == null) throw Exception('Token missing');

      final response = await http.get(
        Uri.parse('http://pacific-condocare.com/public/profile.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            userData = data['user'];
            _emailController.text = userData['email'] ?? '';
            _contactController.text = userData['contact'] ?? '';
            isLoading = false;
          });
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        throw Exception('HTTP error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> updateAccountInfo({String? newEmail, String? newContact, String? newPassword}) async {
    setState(() {
      _isUpdating = true;
    });
    
    try {
      final token = await getJwtToken();
      if (token == null) throw Exception('Token missing');

      final response = await http.post(
        Uri.parse('http://pacific-condocare.com/public/edit_accInfo.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userid': widget.userid,
          'email': newEmail,
          'contact': newContact,
          'password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Update local user data if fields were changed
          if (newEmail != null) {
            setState(() {
              userData['email'] = newEmail;
              _isEditingEmail = false;
            });
          }
          
          if (newContact != null) {
            setState(() {
              userData['contact'] = newContact;
              _isEditingContact = false;
            });
          }
          
          // Clear password fields
          if (newPassword != null) {
            setState(() {
              _passwordController.clear();
              _confirmPasswordController.clear();
              _isEditingPassword = false;
            });
          }
          
          // Show success popup
          showUpdatePopup(data['message'] ?? 'Account information updated successfully');
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        throw Exception('HTTP error ${response.statusCode}');
      }
    } catch (e) {
      // Show error popup
      showUpdatePopup('Error: $e', isError: true);
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void showUpdatePopup(String message, {bool isError = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isError ? 'Error' : 'Success'),
          content: Text(message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isError ? Colors.red[50] : Colors.green[50],
          titleTextStyle: TextStyle(
            color: isError ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          contentTextStyle: TextStyle(
            color: isError ? Colors.red[900] : Colors.green[900],
            fontSize: 16,
          ),
          actions: [
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(
                  color: isError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Profile', style: TextStyle(color: Color(0xFFD2AB59))),
        automaticallyImplyLeading: false,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileHeader(),
                  const SizedBox(height: 24),
                  sectionTitle('Account Info'),
                  profileInfoTile('User ID', userData['userid'] ?? ''),
                  nameTile(),
                  emailTile(),
                  contactTile(),
                  passwordTile(),
                  const SizedBox(height: 24),
                  sectionTitle('My Properties'),
                  ..._buildPropertiesWithUnits(),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor:  Colors.white,
        selectedItemColor: const Color(0xFFFFC740),
        unselectedItemColor:const Color(0xFF2F2E2E),
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;

          setState(() {
            _currentIndex = index;
          });

          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ResidentHomePage(
                  properties: widget.properties,
                  userid: widget.userid,
                ),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ResidentTransactionPage(
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
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget profileHeader() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            userData['name'] ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            userData['email'] ?? '',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget profileInfoTile(String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
  
  Widget nameTile() {
    // Modified to display name as non-editable field
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        title: const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(userData['name'] ?? ''),
      ),
    );
  }
  
  Widget emailTile() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        title: const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: _isEditingEmail 
          ? TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: 'Enter new email',
                helperText: 'Only Gmail addresses are accepted',
              ),
              keyboardType: TextInputType.emailAddress,
            )
          : Text(userData['email'] ?? ''),
        trailing: _isEditingEmail
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: _isUpdating 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, color: Colors.green),
                  onPressed: _isUpdating
                    ? null
                    : () {
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          if (isValidGmailAddress(email)) {
                            updateAccountInfo(newEmail: email);
                          } else {
                            showUpdatePopup(
                              'Please enter a valid Gmail address',
                              isError: true
                            );
                          }
                        } else {
                          showUpdatePopup('Email cannot be empty', isError: true);
                        }
                      },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _emailController.text = userData['email'] ?? '';
                      _isEditingEmail = false;
                    });
                  },
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditingEmail = true;
                });
              },
            ),
      ),
    );
  }
  
  Widget contactTile() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        title: const Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: _isEditingContact 
          ? TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                hintText: 'Enter contact number',
                helperText: 'Mobile or Landline',
              ),
              keyboardType: TextInputType.phone,
            )
          : Text(userData['contact'] ?? ''),
        trailing: _isEditingContact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: _isUpdating 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, color: Colors.green),
                  onPressed: _isUpdating
                    ? null
                    : () {
                        final contactNumber = _contactController.text.trim();
                        if (contactNumber.isNotEmpty) {
                          if (isValidPhilippinePhoneNumber(contactNumber)) {
                            updateAccountInfo(newContact: contactNumber);
                          } else {
                            showUpdatePopup(
                              'Please enter a valid Philippine mobile number (09XXXXXXXXX) or landline (7-8 digits)',
                              isError: true
                            );
                          }
                        } else {
                          showUpdatePopup('Contact number cannot be empty', isError: true);
                        }
                      },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _contactController.text = userData['contact'] ?? '';
                      _isEditingContact = false;
                    });
                  },
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditingContact = true;
                });
              },
            ),
      ),
    );
  }
  
  Widget passwordTile() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        title: const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Change your password'),
        trailing: _isEditingPassword
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: _isUpdating 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, color: Colors.green),
                  onPressed: _isUpdating
                    ? null
                    : () {
                        if (_passwordController.text.trim().isNotEmpty && 
                            _passwordController.text == _confirmPasswordController.text) {
                          updateAccountInfo(newPassword: _passwordController.text.trim());
                        } else if (_passwordController.text != _confirmPasswordController.text) {
                          showUpdatePopup('Passwords do not match', isError: true);
                        }
                      },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                      _isEditingPassword = false;
                    });
                  },
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditingPassword = true;
                });
              },
            ),
        children: _isEditingPassword ? [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ),
          const SizedBox(height: 16),
        ] : [],
      ),
    );
  }

  List<Widget> _buildPropertiesWithUnits() {
    final units = userData['units'] ?? {};
    List<Widget> propertyWidgets = [];

    (userData['properties'] as List<dynamic>? ?? []).forEach((property) {
      List<Widget> unitListWidgets = [];

      if (units.containsKey(property)) {
        final unitList = units[property] ?? [];
        for (var unit in unitList) {
          unitListWidgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4),
              child: Text('• $unit', style: const TextStyle(fontSize: 14)),
            ),
          );
        }
      }
      
      propertyWidgets.add(
        SizedBox(
          width: double.infinity,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Property: $property',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (unitListWidgets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Units:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    ...unitListWidgets,
                  ]
                ],
              ),
            ),
          ),
        ),
      );
    });

    return propertyWidgets;
  }
}
