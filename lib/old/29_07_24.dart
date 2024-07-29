import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'dart:math';

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
  String _selfId = _generateRandomId(6);
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
      if (data['type'] == 'offer' || data['type'] == 'answer') {
        _handleSignalingMessage(data);
      } else if (data['type'] == 'candidate') {
        _peerConnection!.addCandidate(RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        ));
        Fluttertoast.showToast(
          msg: "ICE candidate added: ${data['candidate']}",
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    });

    _registerWithServer();
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
          'type': 'candidate',
          'targetId': _remoteId,
          'id': _selfId,
          'candidate': candidate.toMap()
        }));
        print('Sent candidate: ${candidate.toMap()}');
        Fluttertoast.showToast(
          msg: "ICE candidate sent: ${candidate.toMap()}",
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel dataChannel) {
      _dataChannel = dataChannel;
      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        setState(() {
          _messages.add(message.text);
        });
        print('Received data message: ${message.text}');
        Fluttertoast.showToast(
          msg: "Data message received: ${message.text}",
          toastLength: Toast.LENGTH_SHORT,
        );
      };
      Fluttertoast.showToast(
        msg: "Data channel is open",
        toastLength: Toast.LENGTH_SHORT,
      );
    };

    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    _dataChannel = await _peerConnection!.createDataChannel('dataChannel', dataChannelDict);
    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      setState(() {
        _messages.add(message.text);
      });
      print('Received data message: ${message.text}');
      Fluttertoast.showToast(
        msg: "Data message received: ${message.text}",
        toastLength: Toast.LENGTH_SHORT,
      );
    };
  }

  void _registerWithServer() {
    _channel.sink.add(json.encode({
      'type': 'register',
      'id': _selfId,
    }));
    print('Registered with ID: $_selfId');
    Fluttertoast.showToast(
      msg: "Registered with ID: $_selfId",
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void _connect() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    if (_remoteId != null) {
      _channel.sink.add(json.encode({
        'type': 'offer',
        'targetId': _remoteId,
        'id': _selfId,
        'sdp': description.toMap()
      }));
      print('Sent offer: ${description.toMap()}');
      Fluttertoast.showToast(
        msg: "Offer sent: ${description.toMap()}",
        toastLength: Toast.LENGTH_SHORT,
      );
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
      Fluttertoast.showToast(
        msg: "Remote description set: ${description.toMap()}",
        toastLength: Toast.LENGTH_SHORT,
      );
      if (description.type == 'offer') {
        _createAnswer();
      }
    }
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);
    if (_remoteId != null) {
      _channel.sink.add(json.encode({
        'type': 'answer',
        'targetId': _remoteId,
        'id': _selfId,
        'sdp': description.toMap()
      }));
      print('Sent answer: ${description.toMap()}');
      Fluttertoast.showToast(
        msg: "Answer sent: ${description.toMap()}",
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  void _sendMessage(String message) {
    _dataChannel!.send(RTCDataChannelMessage(message));
    print('Sent data message: $message');
    Fluttertoast.showToast(
      msg: "Data message sent: $message",
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  static String _generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
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
            'Your ID: $_selfId',
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
            onPressed: _connect,
            child: Text('Connect'),
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
