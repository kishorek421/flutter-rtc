import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rtc/26_07_24/models/user.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hive/hive.dart';

class AddUserPage extends StatefulWidget {
  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
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
        var newUser = userBox.get(_phoneNumberController.text)!;
        newUser.candidate = json.encode(candidate.toMap());
        userBox.put(_phoneNumberController.text, newUser);
      }
    };
  }

  Future<void> _addNewUser() async {
    var userBox = Hive.box<User>('users');
    var user = User(_phoneNumberController.text, '', '');
    userBox.put(_phoneNumberController.text, user);

    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    user.sdp = json.encode(description.toMap());
    userBox.put(_phoneNumberController.text, user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New User')),
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
                await _addNewUser();
                Navigator.pop(context);
              },
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
