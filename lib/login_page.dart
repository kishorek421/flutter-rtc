import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rtc/web_rtc_page.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const platform = MethodChannel('com.bw.flutter_rtc');
  String _phoneNumber = "";

  Future<void> _requestPhoneNumber() async {
    if (await Permission.phone.request().isGranted) {
      try {
        final String phoneNumber = await platform.invokeMethod('getPhoneNumber');
        setState(() {
          _phoneNumber = phoneNumber;
        });
      } on PlatformException catch (e) {
        log("Failed to get phone number: '${e.message}'.");
      }
    }
  }

  Future<void> _savePhoneNumber() async {
    var box = Hive.box('settings');
    await box.put('selfId', _phoneNumber);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WebRtcPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    _requestPhoneNumber();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _phoneNumber.isNotEmpty ? "Your phone number is $_phoneNumber" : "Fetching phone number...",
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePhoneNumber,
              child: Text('Save and Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
