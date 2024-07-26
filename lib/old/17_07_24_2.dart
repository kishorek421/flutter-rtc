import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:share_plus/share_plus.dart';
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
      // Handle ICE candidates if necessary
      print('New ICE candidate: ${candidate.toMap()}');
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
    Map<String, dynamic> sdpMap = json.decode(sdp);
    RTCSessionDescription description = RTCSessionDescription(
      sdpMap['sdp'],
      sdpMap['type'],
    );
    await _peerConnection!.setRemoteDescription(description);
    print('Set remote description: ${description.toMap()}');
  }

  void _shareSDP(String sdp) {
    Share.share(sdp, subject: 'SDP');
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
