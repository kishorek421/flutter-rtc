import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rtc/models/user.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hive/hive.dart';

class AddUserPage extends StatefulWidget {
  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  TextEditingController _mobileNumberController = TextEditingController();
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
        _storeCandidate(candidate);
      }
    };

    _createOffer();
  }

  void _createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    _storeSDP(description);
  }

  void _storeSDP(RTCSessionDescription description) async {
    var box = Hive.box<User>('users');
    var user = User(_mobileNumberController.text, json.encode(description.toMap()), '');
    await box.add(user);
  }

  void _storeCandidate(RTCIceCandidate candidate) async {
    var box = Hive.box<User>('users');
    var user = box.values.firstWhere((user) => user.mobileNumber == _mobileNumberController.text);
    user.candidate = json.encode(candidate.toMap());
    await user.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _mobileNumberController,
              decoration: InputDecoration(labelText: 'Mobile Number'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _peerConnection?.close();
    super.dispose();
  }
}
