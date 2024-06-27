import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
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
  late WebSocketChannel _channel;
  String? _selfId;
  String? _remoteId;
  TextEditingController _remoteIdController = TextEditingController();
  TextEditingController _textController = TextEditingController();
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _channel = IOWebSocketChannel.connect('ws://106.51.106.43');
    _initializeWebRTC();

    _channel.stream.listen((message) {
      final data = json.decode(message);
      print('Received message: $message');
      if (data['type'] == 'id') {
        setState(() {
          _selfId = data['id'];
        });
        print('Assigned ID: $_selfId');
      } else if (data['id'] != null && data['message']['sdp'] != null) {
        _handleSignalingMessage(data['message']);
      } else if (data['message']['candidate'] != null) {
        _peerConnection!.addCandidate(RTCIceCandidate(
          data['message']['candidate']['candidate'],
          data['message']['candidate']['sdpMid'],
          data['message']['candidate']['sdpMLineIndex'],
        ));
      }
    });
  }

  Future<void> _initializeWebRTC() async {
    final configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'}
      ]
    };
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null && _remoteId != null) {
        _channel.sink.add(json.encode({
          'targetId': _remoteId,
          'message': {'candidate': candidate.toMap()}
        }));
        print('Sent candidate: ${candidate.toMap()}');
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
    if (_remoteId != null) {
      _channel.sink.add(json.encode({
        'targetId': _remoteId,
        'message': {'sdp': description.toMap()}
      }));
      print('Sent offer: ${description.toMap()}');
    }
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);
    if (_remoteId != null) {
      _channel.sink.add(json.encode({
        'targetId': _remoteId,
        'message': {'sdp': description.toMap()}
      }));
      print('Sent answer: ${description.toMap()}');
    }
  }

  void _handleSignalingMessage(dynamic message) async {
    if (message['sdp'] != null) {
      RTCSessionDescription description = RTCSessionDescription(
        message['sdp']['sdp'],
        message['sdp']['type'],
      );
      await _peerConnection!.setRemoteDescription(description);
      print('Set remote description: ${description.toMap()}');
      if (description.type == 'offer') {
        _createAnswer();
      }
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
          Text(
            _selfId ?? "Id not found",
          ),
          SizedBox(height: 10,),
          TextField(
            controller: _remoteIdController,
            decoration: InputDecoration(labelText: 'Remote Peer ID'),
            onChanged: (value) {
              setState(() {
                _remoteId = value;
              });
            },
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
    _channel.sink.close();
    super.dispose();
  }
}
