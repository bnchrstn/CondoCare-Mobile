import 'package:flutter/material.dart';

class TaskHistoryPage extends StatelessWidget {
  const TaskHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task History'),
      ),
      body: Center(
        child: ListView(
          children: <Widget>[
            ListTile(
              title: Text('Task 1'),
              subtitle: Text('Completed on: 4/4/2025'),
            ),
            ListTile(
              title: Text('Task 2'),
              subtitle: Text('Completed on: 4/5/2025'),
            ),
    
          ],
        ),
      ),
    );
  }
}