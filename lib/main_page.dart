import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final _userBox = Hive.box('user_data');
    final mobileNumber = _userBox.get('mobile_number');
    final sdp = _userBox.get('sdp');
    final ice = _userBox.get('ice');

    return Scaffold(
      appBar: AppBar(title: Text('Main Page')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mobile Number: $mobileNumber'),
            SizedBox(height: 8.0),
            Text('SDP: $sdp'),
            SizedBox(height: 8.0),
            Text('ICE: $ice'),
          ],
        ),
      ),
    );
  }
}
