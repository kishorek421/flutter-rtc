import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WebRTCPage(),
    );
  }
}

class WebRTCPage extends StatefulWidget {
  @override
  _WebRTCPageState createState() => _WebRTCPageState();
}

class _WebRTCPageState extends State<WebRTCPage> {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  TextEditingController _sdpController = TextEditingController();
  TextEditingController _candidateController = TextEditingController();
  TextEditingController _textController = TextEditingController();
  List<String> _messages = [];
  List<RTCIceCandidate> _iceCandidates = [];

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
        _iceCandidates.add(candidate);
        _showToast('New ICE candidate added: ${candidate.toMap()}');
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel dataChannel) {
      _showToast('Data channel received: ${dataChannel.label}');
      _setupDataChannel(dataChannel);
    };

    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    _dataChannel = await _peerConnection!
        .createDataChannel('dataChannel', dataChannelDict);
    _setupDataChannel(_dataChannel!);
  }

  void _setupDataChannel(RTCDataChannel dataChannel) {
    dataChannel.onMessage = (RTCDataChannelMessage message) {
      setState(() {
        _messages.add(message.text);
      });
      _showToast('Received data message: ${message.text}');
    };

    dataChannel.onDataChannelState = (RTCDataChannelState state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _showToast('Data channel opened');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _showToast('Data channel closed');
      } else {
        _showToast('Data channel state: $state');
      }
    };

    _dataChannel = dataChannel;
  }

  void _createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    String sdp = json.encode(description.toMap());
    _shareSDP(sdp);
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);
    String sdp = json.encode(description.toMap());
    _shareSDP(sdp);
  }

  void _handleSDP(String sdp) async {
    try {
      Map<String, dynamic> sdpMap = json.decode(sdp);
      if (!sdpMap.containsKey('sdp') || !sdpMap.containsKey('type')) {
        _showToast('Invalid SDP format');
        return;
      }

      RTCSessionDescription description = RTCSessionDescription(
        sdpMap['sdp'],
        sdpMap['type'],
      );

      await _peerConnection!.setRemoteDescription(description);
      _showToast('Set remote description: ${description.toMap()}');
    } catch (e) {
      _showToast('Error parsing SDP: $e');
    }
  }

  void _shareSDP(String sdp) {
    Share.share(sdp, subject: 'SDP');
  }

  void _addCandidate() async {
    try {
      String candidateInput = _candidateController.text;
      List<dynamic> candidateMapList = json.decode(candidateInput);

      var addedCount = 0;

      for (var candidateMap in candidateMapList) {
        if (candidateMap.containsKey('candidate') &&
            candidateMap.containsKey('sdpMid') &&
            candidateMap.containsKey('sdpMLineIndex')) {
          RTCIceCandidate candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
          addedCount += 1;
        }
      }

      if (addedCount == candidateMapList.length) {
        addedCount += 1;
        _showToast('Added ICE candidate: $addedCount');
      } else {
        _showToast('Invalid ICE candidate format');
      }
    } catch (e) {
      _showToast('Error adding ICE candidate: $e');
    }
  }

  void _shareCandidates() {
    if (_iceCandidates.isNotEmpty) {
      List<Map<String, dynamic>> candidateMaps = _iceCandidates
          .map((candidate) => candidate.toMap() as Map<String, dynamic>)
          .toList();
      String candidatesJson = json.encode(candidateMaps);
      Share.share(candidatesJson, subject: 'ICE Candidates');
    } else {
      _showToast('No ICE candidates to share');
    }
  }

  void _sendMessage(String message) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(message));
      _showToast('Sent data message: $message');
    } else {
      _showToast('Data channel is not open');
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebRTC Data Channel'),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(height: 10),
          TextField(
            controller: _sdpController,
            decoration: InputDecoration(labelText: 'Remote SDP'),
          ),
          ElevatedButton(
            onPressed: () {
              _handleSDP(_sdpController.text);
            },
            child: Text('Set Remote SDP'),
          ),
          ElevatedButton(
            onPressed: _createOffer,
            child: Text('Create Offer and Share'),
          ),
          ElevatedButton(
            onPressed: _createAnswer,
            child: Text('Create Answer and Share'),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _candidateController,
            decoration: InputDecoration(labelText: 'ICE Candidate JSON'),
          ),
          ElevatedButton(
            onPressed: _addCandidate,
            child: Text('Add ICE Candidate'),
          ),
          ElevatedButton(
            onPressed: _shareCandidates,
            child: Text('Share ICE Candidates'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _textController,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_textController.text);
                    _textController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dataChannel?.close();
    _peerConnection?.close();
    super.dispose();
  }
}
