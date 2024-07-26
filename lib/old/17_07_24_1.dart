import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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
  TextEditingController _remoteSdpController = TextEditingController();
  TextEditingController _textController = TextEditingController();
  List<String> _messages = [];

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
        final candidateString = json.encode(candidate.toMap());
        print('ICE Candidate: $candidateString');
        // Handle sharing the candidate string via a messaging service
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel dataChannel) {
      _dataChannel = dataChannel;
      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        setState(() {
          _messages.add(message.text);
        });
        print('Received data message: ${message.text}');
      };
    };

    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    _dataChannel = await _peerConnection!.createDataChannel('dataChannel', dataChannelDict);
    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      setState(() {
        _messages.add(message.text);
      });
      print('Received data message: ${message.text}');
    };
  }

  void _createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    setState(() {
      _sdpController.text = json.encode(description.toMap());
    });
    print('Created offer: ${description.toMap()}');
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);
    setState(() {
      _sdpController.text = json.encode(description.toMap());
    });
    print('Created answer: ${description.toMap()}');
  }

  void _setRemoteDescription() async {
    final sdpMap = json.decode(_remoteSdpController.text);
    RTCSessionDescription description = RTCSessionDescription(
      sdpMap['sdp'],
      sdpMap['type'],
    );
    await _peerConnection!.setRemoteDescription(description);
    print('Set remote description: ${description.toMap()}');
    if (description.type == 'offer') {
      _createAnswer();
    }
  }

  void _sendMessage(String message) {
    _dataChannel!.send(RTCDataChannelMessage(message));
    print('Sent data message: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebRTC Data Channel'),
      ),
      body: Column(
        children: <Widget>[
          TextField(
            controller: _sdpController,
            decoration: InputDecoration(labelText: 'Local SDP'),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _remoteSdpController,
            decoration: InputDecoration(labelText: 'Remote SDP'),
          ),
          ElevatedButton(
            onPressed: _createOffer,
            child: Text('Create Offer'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_peerConnection?.getRemoteDescription() != null) {
                _createAnswer();
              }
            },
            child: Text('Create Answer'),
          ),
          ElevatedButton(
            onPressed: _setRemoteDescription,
            child: Text('Set Remote Description'),
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
