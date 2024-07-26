import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_rtc/models/user.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatPage extends StatefulWidget {
  final User user;

  ChatPage({required this.user});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  late WebSocketChannel _channel;
  TextEditingController _textController = TextEditingController();
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    _channel = IOWebSocketChannel.connect('ws://106.51.106.43');
    _channel.stream.listen((message) {
      final data = json.decode(message);
      log('Received message: $message');
      if (data['id'] != null && data['message']['sdp'] != null) {
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

    _peerConnection!.onDataChannel = (RTCDataChannel dataChannel) {
      _dataChannel = dataChannel;
      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        setState(() {
          _messages.add(message.text);
        });
        log('Received data message: ${message.text}');
      };
    };

    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    _dataChannel = await _peerConnection!
        .createDataChannel('dataChannel', dataChannelDict);
    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      setState(() {
        _messages.add(message.text);
      });
      log('Received data message: ${message.text}');
    };

    if (widget.user.sdp.isNotEmpty) {
      await _setRemoteDescription(widget.user.sdp);
    } else {
      _createOffer();
    }
  }

  void _createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    _channel.sink.add(json.encode({
      'targetId': widget.user.mobileNumber,
      'message': {'sdp': description.toMap()}
    }));
    log('Sent offer: ${description.toMap()}');
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);
    _channel.sink.add(json.encode({
      'targetId': widget.user.mobileNumber,
      'message': {'sdp': description.toMap()}
    }));
    log('Sent answer: ${description.toMap()}');
  }

  void _handleSignalingMessage(dynamic message) async {
    if (message['sdp'] != null) {
      RTCSessionDescription description = RTCSessionDescription(
        message['sdp']['sdp'],
        message['sdp']['type'],
      );
      await _peerConnection!.setRemoteDescription(description);
      log('Set remote description: ${description.toMap()}');
      if (description.type == 'offer') {
        _createAnswer();
      }
    }
  }

  Future<void> _setRemoteDescription(String sdp) async {
    RTCSessionDescription description = RTCSessionDescription(
      json.decode(sdp)['sdp'],
      json.decode(sdp)['type'],
    );
    await _peerConnection!.setRemoteDescription(description);

    if (widget.user.candidate.isNotEmpty) {
      RTCIceCandidate candidate = RTCIceCandidate(
        json.decode(widget.user.candidate)['candidate'],
        json.decode(widget.user.candidate)['sdpMid'],
        json.decode(widget.user.candidate)['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    }
  }

  void _sendMessage(String message) {
    _dataChannel!.send(RTCDataChannelMessage(message));
    log('Sent data message: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.user.mobileNumber}'),
      ),
      body: Column(
        children: <Widget>[
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
