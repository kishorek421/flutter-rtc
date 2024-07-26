import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rtc/list_page.dart';
import 'package:flutter_rtc/models/user.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hive/hive.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController _phoneNumberController = TextEditingController();
  RTCPeerConnection? _peerConnection;

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  Future<void> _initializeWebRTC() async {
    final configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'}
      ]
    };
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        var userBox = Hive.box<User>('users');
        var currentUser = userBox.get('currentUser')!;
        currentUser.candidate = json.encode(candidate.toMap());
        userBox.put('currentUser', currentUser);
      }
    };
  }

  Future<void> _saveCurrentUser(String phoneNumber) async {
    var userBox = Hive.box<User>('users');
    var user = User(phoneNumber, '', '');
    userBox.put('currentUser', user);

    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    user.sdp = json.encode(description.toMap());
    userBox.put('currentUser', user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneNumberController,
              decoration: InputDecoration(labelText: 'Phone Number'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveCurrentUser(_phoneNumberController.text);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MainPage()),
                );
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
