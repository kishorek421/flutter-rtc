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
        _showToast('New ICE candidate: ${candidate.toMap()}');
        // Send candidate to the other peer if needed
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel dataChannel) {
      _showToast('Data channel received: ${dataChannel.label}');
      _setupDataChannel(dataChannel);
    };

    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    _dataChannel = await _peerConnection!.createDataChannel('dataChannel', dataChannelDict);
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

  // void _handleSDP(String sdp) async {
  //   Map<String, dynamic> sdpMap = json.decode(sdp);
  //   RTCSessionDescription description = RTCSessionDescription(
  //     sdpMap['sdp'],
  //     sdpMap['type'],
  //   );
  //   await _peerConnection!.setRemoteDescription(description);
  //   _showToast('Set remote description: ${description.toMap()}');
  // }

  void _handleSDP(String sdp) async {
    try {
      Map<String, dynamic> sdpMap = json.decode(sdp);

      // Validate SDP
      if (!sdpMap.containsKey('sdp') || !sdpMap.containsKey('type')) {
        _showToast('Invalid SDP format');
        return;
      }

      // if (sdpMap['type'] != 'answer') {
      //   _showToast('SDP type must be an answer');
      //   return;
      // }

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

  void _sendMessage(String message) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
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
        fontSize: 16.0
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
