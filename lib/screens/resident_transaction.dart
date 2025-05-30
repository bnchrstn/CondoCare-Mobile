import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'resident_home.dart';
import 'resident_profile.dart';
import 'maintenance_status.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_mobile/screens/login.dart';

class ResidentTransactionPage extends StatefulWidget {
  final List<String> properties;
  final String userid;

  const ResidentTransactionPage({
    Key? key,
    required this.properties,
    required this.userid,
  }) : super(key: key);

  @override
  State<ResidentTransactionPage> createState() => _ResidentTransactionPageState();
}

class _ResidentTransactionPageState extends State<ResidentTransactionPage> {
  late Future<List<Transaction>> _transactionFuture = Future.value([]);
  String? _statusFilter = 'All';
  String? _selectedProperty;
  String? _selectedRoom;
  List<String> _rooms = [];

  List<Transaction> _allScheduleChanges = [];
  
  // Set to store IDs of transactions that have been viewed
  Set<String> _viewedTransactionIds = {};
  
  // Map to store closed transactions we've seen before
  Map<String, bool> _knownClosedTransactions = {};
  
  // Map to store transactions with preferred time changes we've seen
  Map<String, String> _knownScheduleChanges = {};
  
  int _currentIndex = 1;
  bool _hasNewNotifications = false;
  bool _hasNewScheduleChanges = false;
  List<Transaction> _notificationTransactions = [];
  List<Transaction> _completedTransactions = [];
  List<Transaction> _scheduleChangeTransactions = [];

  @override
void initState() {
  super.initState();
  _selectedProperty = widget.properties.isNotEmpty ? widget.properties.first : null;

  // Load viewed transactions from SharedPreferences
  _loadViewedTransactions().then((_) {
    // Also load all schedule changes we already know about from local state
    _loadScheduleChangeHistory();
    
    fetchRooms().then((_) {
      setState(() {
        _selectedRoom = _rooms.isNotEmpty ? _rooms.first : null;
        _transactionFuture = (_selectedProperty != null && _selectedRoom != null)
            ? fetchTransactions()
            : Future.value([]);
      });
    });
  });
}

void _loadScheduleChangeHistory() async {
  try {
    // Load schedule changes history from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final allScheduleChangesString = prefs.getString('all_schedule_changes_${widget.userid}') ?? '[]';
    
    final List<dynamic> historyList = json.decode(allScheduleChangesString);
    List<Transaction> loadedHistory = [];
    
    for (var item in historyList) {
      loadedHistory.add(Transaction.fromJson(item));
    }
    
    setState(() {
      _allScheduleChanges = loadedHistory;
    });
    
    print('Loaded schedule change history: ${_allScheduleChanges.length} items');
  } catch (e) {
    print('Error loading schedule change history: $e');
    setState(() {
      _allScheduleChanges = [];
    });
  }
}

Future<void> _saveScheduleChangeHistory() async {
  try {
    // Convert the list of transactions to a JSON serializable format
    final List<Map<String, dynamic>> historyJson = _allScheduleChanges.map((tx) => {
      'taskid': tx.taskid,
      'Sname': tx.serviceName,
      'createdAt': tx.dateBooked,
      'status': tx.status,
      'updatedAt': tx.dateFinished,
      'property': tx.property,
      'room': tx.room,
      'assignedTo': tx.assignedTo,
      'preferredTime': tx.preferredTime,
    }).toList();
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_schedule_changes_${widget.userid}', json.encode(historyJson));
    
    print('Saved schedule change history: ${historyJson.length} items');
  } catch (e) {
    print('Error saving schedule change history: $e');
  }
}

  String _formatTimeTo12Hour(String timeStr) {
  // Handle common time formats
  if (timeStr.contains(':')) {
    try {
      // Try to parse the time if it's in 24-hour format (e.g., "16:30")
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        int hour = int.tryParse(parts[0]) ?? 0;
        final minute = parts[1];
        
        final period = hour >= 12 ? 'PM' : 'AM';
        hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        
        return '$hour:$minute $period';
      }
    } catch (e) {
      print('Error formatting time: $e');
    }
  }
  
  // Return the original string if we couldn't format it
  return timeStr;
}

  Future<void> _loadViewedTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load viewed transactions
    final viewedList = prefs.getStringList('viewed_txn_${widget.userid}') ?? [];
    setState(() {
      _viewedTransactionIds = Set<String>.from(viewedList);
    });
    
    // Load known closed transactions
    final knownClosedString = prefs.getString('known_closed_txn_${widget.userid}') ?? '{}';
    try {
      final Map<String, dynamic> knownClosed = json.decode(knownClosedString);
      _knownClosedTransactions = knownClosed.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      print('Error loading known closed transactions: $e');
      _knownClosedTransactions = {};
    }
    
    // Load known schedule changes
    final knownScheduleChangesString = prefs.getString('known_schedule_changes_${widget.userid}') ?? '{}';
    try {
      final Map<String, dynamic> knownChanges = json.decode(knownScheduleChangesString);
      _knownScheduleChanges = knownChanges.map((key, value) => MapEntry(key, value as String));
    } catch (e) {
      print('Error loading known schedule changes: $e');
      _knownScheduleChanges = {};
    }
    
    print('Loaded viewed transactions: $_viewedTransactionIds');
    print('Loaded known closed transactions: $_knownClosedTransactions');
    print('Loaded known schedule changes: $_knownScheduleChanges');
  }

  Future<void> _saveViewedTransaction(String taskId) async {
    // Add to local state
    setState(() {
      _viewedTransactionIds.add(taskId);
    });
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewed_txn_${widget.userid}', _viewedTransactionIds.toList());
  }

  Future<void> _saveKnownClosedTransaction(String taskId) async {
    // Add to local state
    setState(() {
      _knownClosedTransactions[taskId] = true;
    });
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('known_closed_txn_${widget.userid}', json.encode(_knownClosedTransactions));
  }

  Future<Transaction?> _findTransactionById(String taskId) async {
    try {
      // Fetch the current transactions if needed
      final transactions = await _transactionFuture;
      return transactions.firstWhere((tx) => tx.taskid == taskId);
    } catch (e) {
      print('Error finding transaction: $e');
      return null;
    }
  }

 Future<void> _saveKnownScheduleChange(String taskId, String newTime) async {
  // Find the transaction with this taskId
  final transaction = await _findTransactionById(taskId);
  
  // Add to schedule change history if it's a new change
  if (transaction != null && (_knownScheduleChanges.containsKey(taskId) && 
      _knownScheduleChanges[taskId] != newTime)) {
    setState(() {
      // Add to all schedule changes list if not already present with this specific time
      if (!_allScheduleChanges.any((tx) => 
          tx.taskid == taskId && tx.preferredTime == newTime)) {
        _allScheduleChanges.add(transaction);
        
        // Save the updated history to persistent storage
        _saveScheduleChangeHistory();
      }
    });
  }
  
  // Add to local state
  setState(() {
    _knownScheduleChanges[taskId] = newTime;
  });
  
  // Save to SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('known_schedule_changes_${widget.userid}', json.encode(_knownScheduleChanges));
}

 void _markScheduleChangeViewed(String taskId, String preferredTime) async {
  // Use both taskId and preferredTime to make a unique identifier
  final changeId = "schedule_change_${taskId}_${preferredTime}";
  
  setState(() {
    _viewedTransactionIds.add(changeId);
    _saveViewedTransaction(changeId);
    
    // Update the schedule change notification list
    _scheduleChangeTransactions = _scheduleChangeTransactions
        .where((tx) => tx.taskid != taskId)
        .toList();
    
    _hasNewScheduleChanges = _scheduleChangeTransactions.isNotEmpty;
    _updateNotificationStatus();
    
    // Note: We no longer remove from _allScheduleChanges as it's our history
  });
}

  void _updateNotificationStatus() {
    setState(() {
      _hasNewNotifications = _notificationTransactions.isNotEmpty || _hasNewScheduleChanges;
    });
  }

  Future<void> fetchRooms() async {
    final uri = Uri.http('pacific-condocare.com', '/public/get_unitTransactions.php', {
      'userid': widget.userid,
      'property': _selectedProperty ?? '',
    });

    final token = await getJwtToken();
    final response = await http.get(uri, headers: {
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        if (data.containsKey('units')) {
          setState(() {
            _rooms = List<String>.from(data['units']);
          });
        } else {
          print('Warning: No "units" key in response.');
        }
      } else {
        print('Error from backend: ${data['error']}');
      }
    } else {
      print('HTTP error while fetching rooms: ${response.statusCode}');
    }
  }

  Future<List<Transaction>> fetchTransactions() async {
    final uri = Uri.http('pacific-condocare.com', '/public/get_transactions.php', {
      'property': _selectedProperty ?? '',
      'room': _selectedRoom ?? '',
      if (_statusFilter != null && _statusFilter != 'All') 
        'status': _statusFilter!.toLowerCase(), 
    });

    final token = await getJwtToken();
    final response = await http.get(uri, headers: {
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        List<Transaction> transactions = (data['transactions'] as List)
            .map((json) => Transaction.fromJson(json))
            .toList();

        // Sort transactions in descending order
        transactions.sort((a, b) => DateTime.parse(b.dateBooked).compareTo(DateTime.parse(a.dateBooked)));
        
        // Reset notification flags
        bool hasNew = false;
        bool hasScheduleChanges = false;
        
        // Lists to track notifications
        List<Transaction> newlyClosedTransactions = [];
        List<Transaction> scheduleChangedTransactions = [];
        
        // Clear and rebuild completed transactions list
        List<Transaction> completedTransactions = [];
        
         for (var tx in transactions) {
      // Check for schedule changes
      if (tx.preferredTime != null) {
        final knownTime = _knownScheduleChanges[tx.taskid];
        if (knownTime != null && knownTime != tx.preferredTime) {
          // Preferred time has changed
          hasScheduleChanges = true;
          
          // Create a unique identifier for this specific change
          final changeId = "schedule_change_${tx.taskid}_${tx.preferredTime}";
          
          // If we haven't viewed this specific change yet, add to notification list
          if (!_viewedTransactionIds.contains(changeId)) {
            scheduleChangedTransactions.add(tx);
          }
          
          // Add to all schedule changes for history
          if (!_allScheduleChanges.any((histTx) => 
              histTx.taskid == tx.taskid && histTx.preferredTime == tx.preferredTime)) {
            _allScheduleChanges.add(tx);
          }
          
          // Update our knowledge of this transaction's schedule
          _saveKnownScheduleChange(tx.taskid, tx.preferredTime!);
        } else if (knownTime == null) {
          // First time seeing this transaction, save its schedule
          _saveKnownScheduleChange(tx.taskid, tx.preferredTime!);
        }
      }
          
          // Check for closed transactions
          if (tx.status.toLowerCase() == 'closed') {
            // Add to completed transactions list
            completedTransactions.add(tx);
            
            // Check if we know about this closed transaction already
            bool isKnown = _knownClosedTransactions.containsKey(tx.taskid);
            
            if (!isKnown) {
              // We found a closed transaction we didn't know about before
              hasNew = true;
              
              // Mark this transaction as known for future reference
              _saveKnownClosedTransaction(tx.taskid);
              
              // If we haven't viewed this transaction yet, add to notification list
              if (!_viewedTransactionIds.contains(tx.taskid)) {
                newlyClosedTransactions.add(tx);
              }
            } else if (!_viewedTransactionIds.contains(tx.taskid)) {
              // This is a known closed transaction that hasn't been viewed yet
              hasNew = true;
            }
          }
        }

        // Show notifications for newly closed transactions
        if (newlyClosedTransactions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Show notification for the most recent closed transaction
            if (mounted && newlyClosedTransactions.isNotEmpty) {
              _showClosedNotification(context, newlyClosedTransactions.first);
            }
          });
        }
        
        // Show notifications for schedule changes
        if (scheduleChangedTransactions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Show notification for the most recent schedule change
            if (mounted && scheduleChangedTransactions.isNotEmpty) {
              _showScheduleChangeNotification(context, scheduleChangedTransactions.first);
            }
          });
        }
        
        // Store transactions for notifications
        _notificationTransactions = transactions.where((tx) => 
          tx.status.toLowerCase() == 'closed' && !_viewedTransactionIds.contains(tx.taskid)
        ).toList();
        
         _scheduleChangeTransactions = transactions.where((tx) => 
      tx.preferredTime != null && 
      _knownScheduleChanges.containsKey(tx.taskid) && 
      _knownScheduleChanges[tx.taskid] != tx.preferredTime &&
      !_viewedTransactionIds.contains("schedule_change_${tx.taskid}_${tx.preferredTime}")
    ).toList();
        
        setState(() {
      _hasNewNotifications = hasNew;
      _hasNewScheduleChanges = hasScheduleChanges;
      _completedTransactions = completedTransactions;
      _updateNotificationStatus();
    });

        
        return transactions;
      } else {
        throw Exception('Backend error: ${data['error']}');
      }
    } else {
      throw Exception('HTTP error: ${response.statusCode}');
    }
  }

  void _showClosedNotification(BuildContext context, Transaction transaction) {
    // Show a notification dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Maintenance Complete',
                  style: TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your recent maintenance request has been completed:',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          transaction.serviceName,
                          style: TextStyle(fontSize: 14),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date Completed: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          _formatDateOnly(transaction.dateFinished),
                          style: TextStyle(fontSize: 14),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  if (transaction.assignedTo != null && transaction.assignedTo!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completed By: ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Expanded(
                            child: Text(
                              transaction.assignedTo!,
                              style: TextStyle(fontSize: 14),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('View Details'),
              onPressed: () {
                Navigator.of(context).pop();
                _markTransactionViewed(transaction.taskid);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaintenanceStatusPage(transaction: transaction),
                  ),
                );
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                _markTransactionViewed(transaction.taskid);
              },
            ),
          ],
        );
      },
    );
  }

  void _showScheduleChangeNotification(BuildContext context, Transaction transaction) {
    // Format the preferred time to 12-hour format
    String formattedTime = _formatTimeTo12Hour(transaction.preferredTime ?? 'Not specified');

    // Show a notification dialog for schedule changes
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Maintenance Schedule Updated',
                  style: TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your maintenance request schedule has been updated:',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          transaction.serviceName,
                          style: TextStyle(fontSize: 14),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Time: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          formattedTime,
                          style: TextStyle(fontSize: 14),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'If you are not available at this new time, please contact the admin to reschedule.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('View Details'),
              onPressed: () {
                Navigator.of(context).pop();
                _markScheduleChangeViewed(transaction.taskid, transaction.preferredTime ?? "");
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaintenanceStatusPage(transaction: transaction),
                  ),
                );
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                _markScheduleChangeViewed(transaction.taskid, transaction.preferredTime ?? "");
              },
            ),
          ],
        );
      },
    );
  }

  void _showCompletedMaintenanceHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // This allows the bottom sheet to be full height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7, // 70% of screen height
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Completed Maintenance History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD2AB59),
                  ),
                ),
              ),
              const Divider(),
              _completedTransactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text('No completed maintenance found'),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _completedTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = _completedTransactions[index];
                          
                          // Check if this is a new transaction to show the notification badge
                          bool isNew = !_viewedTransactionIds.contains(tx.taskid);
                          
                          return ListTile(
                            leading: Stack(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                if (isNew)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(tx.serviceName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Completed Date: ${_formatDateOnly(tx.dateFinished)}'),
                                if (tx.assignedTo != null && tx.assignedTo!.isNotEmpty)
                                  Text('Completed By: ${tx.assignedTo}'),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.pop(context);
                              if (!_viewedTransactionIds.contains(tx.taskid)) {
                                _markTransactionViewed(tx.taskid);
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MaintenanceStatusPage(transaction: tx),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showScheduleChangeHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Schedule Change History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD2AB59),
                  ),
                ),
              ),
              const Divider(),
              _allScheduleChanges.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text('No schedule changes to show'),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allScheduleChanges.length,
                        itemBuilder: (context, index) {
                          final tx = _allScheduleChanges[index];
                          
                          // Format the time for display
                          String formattedTime = _formatTimeTo12Hour(tx.preferredTime ?? 'Not specified');
                          
                          // Check if this is an unviewed change to show notification dot
                          final changeId = "schedule_change_${tx.taskid}_${tx.preferredTime}";
          bool hasUnviewedChange = tx.preferredTime != null &&
                                 _knownScheduleChanges.containsKey(tx.taskid) &&
                                 _knownScheduleChanges[tx.taskid] != tx.preferredTime &&
                                 !_viewedTransactionIds.contains(changeId);
          
          // Mark schedule change as viewed if applicable
          if (hasUnviewedChange) {
            _markScheduleChangeViewed(tx.taskid, tx.preferredTime ?? "");
          }
                          
                          return ListTile(
                            leading: Stack(
                              children: [
                                const Icon(Icons.schedule, color: Colors.orange),
                                if (hasUnviewedChange)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(tx.serviceName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Schedule Changed To: $formattedTime'),
                                Text('Service Date: ${_formatDateOnly(tx.dateBooked)}'),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.pop(context);
                              if (hasUnviewedChange) {
            _markScheduleChangeViewed(tx.taskid, tx.preferredTime ?? "");
          }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MaintenanceStatusPage(transaction: tx),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dateTime = DateTime.parse(dateStr);
      final formatter = DateFormat('MMM dd, yyyy - hh:mm a');
      return formatter.format(dateTime);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateOnly(String dateStr) {
    try {
      final dateTime = DateTime.parse(dateStr);
      final formatter = DateFormat('MMM dd, yyyy');
      return formatter.format(dateTime);
    } catch (e) {
      return dateStr;
    }
  }

  Future<String?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  void _markTransactionViewed(String taskId) {
    setState(() {
      _viewedTransactionIds.add(taskId);
      _saveViewedTransaction(taskId);
      
      // Update the notification list
      _notificationTransactions = _notificationTransactions
          .where((tx) => tx.taskid != taskId)
          .toList();
      
      _hasNewNotifications = _notificationTransactions.isNotEmpty || _hasNewScheduleChanges;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF333333),
        elevation: 4,
        title: const Text(
          'Transaction History',
          style: TextStyle(
            color: Color(0xFFD2AB59),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // History icon for completed maintenance
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                onPressed: () {
                  _showCompletedMaintenanceHistory(context);
                },
                tooltip: 'Completed Maintenance History',
              ),
              if (_notificationTransactions.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // Hamburger menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: (value) {
              if (value == 'about') {
                // Handle about action
              } else if (value == 'logout') {
                // Navigate to login screen and remove all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: Colors.white,
                        value: _selectedProperty,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                        style: const TextStyle(color: Colors.black),
                        onChanged: (newValue) async {
                          setState(() {
                            _selectedProperty = newValue;
                            _selectedRoom = null;
                            _rooms = [];
                          });
                          await fetchRooms();
                          setState(() {
                            _selectedRoom = _rooms.isNotEmpty ? _rooms.first : null;
                            _transactionFuture = fetchTransactions();
                          });
                        },
                        items: widget.properties.map((property) {
                          return DropdownMenuItem<String>(
                            value: property,
                            child: Text(property),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: Colors.white,
                        value: _selectedRoom,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                        style: const TextStyle(color: Colors.black),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedRoom = newValue;
                            _transactionFuture = fetchTransactions();
                          });
                        },
                        items: _rooms.map((room) {
                          return DropdownMenuItem<String>(
                            value: room,
                            child: Text(room),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status Filter Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: Colors.white,
                  value: _statusFilter,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  style: const TextStyle(color: Colors.black),
                  onChanged: (newValue) {
                    setState(() {
                      _statusFilter = newValue;
                      _transactionFuture = fetchTransactions();
                    });
                  },
                  items: ['All', 'Open', 'Closed'].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Transaction List
            Expanded(
              child: FutureBuilder<List<Transaction>>(
                future: _transactionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No transactions available'),
                    );
                  }

                  final transactions = snapshot.data!;
                  return ListView.builder(
              itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
        
        // Check if this transaction has a schedule change notification
        bool hasScheduleChange = _knownScheduleChanges.containsKey(tx.taskid) && 
                               tx.preferredTime != null && 
                               _knownScheduleChanges[tx.taskid] != tx.preferredTime &&
                               !_viewedTransactionIds.contains("schedule_change_${tx.taskid}_${tx.preferredTime}");
                      
                      return TransactionCard(
        number: (index + 1).toString(),
        serviceName: tx.serviceName,
        dateBooked: tx.dateBooked,
        status: tx.status,
        dateFinished: tx.dateFinished,
        assignedTo: tx.assignedTo,
        hasScheduleChange: false, // Always set to false to hide the highlight
        onTap: () {
          // Mark as viewed if it's a closed transaction that hasn't been viewed
          if (tx.status.toLowerCase() == 'closed' && !_viewedTransactionIds.contains(tx.taskid)) {
            _markTransactionViewed(tx.taskid);
          }
            
            // Mark schedule change as viewed if applicable
            if (hasScheduleChange) {
              _markScheduleChangeViewed(tx.taskid, tx.preferredTime ?? "");
            }
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaintenanceStatusPage(transaction: tx),
              ),
            );
          },
        );
      },
    );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFD2AB59),
        unselectedItemColor: Colors.black54,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;

          setState(() => _currentIndex = index);

          if (index == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ResidentHomePage(properties: widget.properties, userid: widget.userid)));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ResidentProfilePage(properties: widget.properties, userid: widget.userid)));
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Transactions'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class TransactionCard extends StatelessWidget {
  final String number;
  final String serviceName;
  final String dateBooked;
  final String status;
  final String dateFinished;
  final String? assignedTo;
  final bool hasScheduleChange;
  final VoidCallback onTap;

  const TransactionCard({
    Key? key,
    required this.number,
    required this.serviceName,
    required this.dateBooked,
    required this.status,
    required this.dateFinished,
    this.assignedTo,
    this.hasScheduleChange = false,
    required this.onTap,
  }) : super(key: key);

  String formatDate(String dateStr) {
    try {
      final dateTime = DateTime.parse(dateStr);
      final formatter = DateFormat('MMM dd, yyyy');
      return formatter.format(dateTime);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. $serviceName',
                    style: const TextStyle(
                      color: Color(0xFFD2AB59),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Booked Date: ${formatDate(dateBooked)}', style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text(
                    'Status: $status', 
                    style: TextStyle(
                      color: status.toLowerCase() == 'closed' ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Assigned To: ${assignedTo ?? "Not assigned yet"}', style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
            if (hasScheduleChange)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.schedule, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Schedule Updated',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Transaction {
  final String taskid;
  final String serviceName;
  final String dateBooked;
  final String status;
  final String dateFinished;
  final String property; 
  final String room;
  final String? assignedTo;
  final String? preferredTime; // Added preferredTime property

  Transaction({
    required this.taskid,
    required this.serviceName,
    required this.dateBooked,
    required this.status,
    required this.dateFinished,
    required this.property, 
    required this.room,
    this.assignedTo,
    this.preferredTime, // Added to constructor
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      taskid: json['taskid'] ?? '',
      serviceName: json['Sname'] ?? '',
      dateBooked: json['createdAt'] ?? '',
      status: json['status'] ?? '',
      dateFinished: json['updatedAt'] ?? '-',
      property: json['property'] ?? '', 
      room: json['room'] ?? '',
      assignedTo: json['assignedTo'] ?? '',
      preferredTime: json['preferredTime'] ?? 'Not specified', // Extract from JSON
    );
  }
}
