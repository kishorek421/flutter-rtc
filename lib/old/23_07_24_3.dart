import 'dart:developer';

import 'package:easy_sms_receiver/easy_sms_receiver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

import 'package:permission_handler/permission_handler.dart';

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
  TextEditingController _mobileNumberController = TextEditingController();
  TextEditingController _messageController = TextEditingController();
  List<String> _messages = [];
  Set<RTCIceCandidate> _iceCandidates = {}; // Use a set to avoid duplicates
  static const platform = MethodChannel('sendSms');

  Map<String, String> _receivedMessageBuffer = {};

  bool isCandidateSent = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeWebRTC();
    _listenForSms();
  }

  Future<void> _initializeWebRTC() async {
    final configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'}
      ],
      'iceCandidatePoolSize': 1,
    };
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _iceCandidates.add(candidate);
      _showToast('New ICE candidate added: ${candidate.toMap()}');
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

  void _requestPermissions() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      await Permission.sms.request();
    }
  }

  void _createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    String optimizedSdp = _optimizeSdp(description.sdp!);
    var optimizedDescription = RTCSessionDescription(optimizedSdp, description.type);
    await _peerConnection!.setLocalDescription(optimizedDescription);
    String sdp = json.encode({'sdp': optimizedSdp, 'type': description.type});
    Fluttertoast.showToast(msg: sdp);
    log("offer sdp -> $sdp");
    _sendSms('OFFER_SDP', sdp);
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    String optimizedSdp = _optimizeSdp(description.sdp!);
    await _peerConnection!.setLocalDescription(
        RTCSessionDescription(optimizedSdp, description.type));
    String sdp = json.encode({'sdp': optimizedSdp, 'type': description.type});
    Fluttertoast.showToast(msg: sdp);
    _sendSms('ANSWER_SDP', sdp);
    // Send all collected ICE candidates after the answer is created
    _sendIceCandidates();
  }

  String _optimizeSdp(String sdp) {
    List<String> lines = sdp.split('\r\n');
    List<String> optimizedLines = [];

    bool insideMediaSection = false;
    for (String line in lines) {
      if (line.startsWith('m=')) {
        insideMediaSection = line.contains('application');
      }
      if (!insideMediaSection &&
          (line.startsWith('m=') || line.startsWith('a='))) {
        continue;
      }
      optimizedLines.add(line);
    }

    return optimizedLines.join('\r\n');
  }

  void _handleSDP(String sdp, bool isOffer) async {
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

      if (isOffer) {
        _createAnswer();
      }
    } catch (e) {
      _showToast('Error parsing SDP: $e');
    }
  }

  void _handleIceCandidate(String candidateJson) async {
    try {
      Map<String, dynamic> candidateMap = json.decode(candidateJson);
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
      _showToast('Added ICE candidate: ${candidate.toMap()}');
    } catch (e) {
      _showToast('Error adding ICE candidate: $e');
    }
  }

  void _sendSms(String type, dynamic data) {
    String mobileNumber = _mobileNumberController.text;
    if (mobileNumber.isNotEmpty) {
      String message = json.encode({'type': type, 'data': data});
      _sendLongSms(mobileNumber, message);
    } else {
      _showToast('Mobile number is empty');
    }
  }

  void _sendLongSms(String mobile, String msg) {
    int chunkSize = 140; // 140 characters to leave some space for metadata
    for (int i = 0; i < msg.length; i += chunkSize) {
      String chunk = msg.substring(
          i, i + chunkSize > msg.length ? msg.length : i + chunkSize);
      sendSms(mobile, chunk);
    }
  }

  Future<Null> sendSms(mobile, msg) async {
    log("SendSMS");
    try {
      final String result = await platform.invokeMethod(
          'send', <String, dynamic>{"phone": "+91$mobile", "msg": msg});
      log(result);
    } on PlatformException catch (e) {
      log("Failed to send sms");
      log(e.toString());
    }
  }

  void _listenForSms() async {
    final EasySmsReceiver easySmsReceiver = EasySmsReceiver.instance;
    easySmsReceiver.listenIncomingSms(
      onNewMessage: (msg) {
        _showToast('SMS received: ${msg.body}');
        String sender = msg.address!;
        if (!_receivedMessageBuffer.containsKey(sender)) {
          _receivedMessageBuffer[sender] = '';
        }
        _receivedMessageBuffer[sender] =
            _receivedMessageBuffer[sender]! + msg.body!;

        try {
          Map<String, dynamic> message =
          json.decode(_receivedMessageBuffer[sender]!);
          if (message.containsKey('type') && message.containsKey('data')) {
            String type = message['type'];
            dynamic data = message['data'];
            if (type == 'OFFER_SDP') {
              _handleSDP(data, true);
            } else if (type == 'ANSWER_SDP') {
              _handleSDP(data, false);
            } else if (type == 'ICE_CANDIDATE') {
              _handleIceCandidate(data);
            }
            _receivedMessageBuffer[sender] =
            ''; // Clear the buffer after successfully processing the message
          }
        } catch (e) {
          log(e.toString());
        }
      },
    );
  }

  void _sendIceCandidates() {
    if (_iceCandidates.isEmpty) return;

    List<dynamic> candidatesMap =
    _iceCandidates.map((candidate) => candidate.toMap()).toList();
    _sendSms('ICE_CANDIDATES', json.encode(candidatesMap));
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
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('WebRTC Data Channel'),
        ),
        body: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            TextField(
              controller: _mobileNumberController,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
            ),
            ElevatedButton(
              onPressed: _createOffer,
              child: const Text('Create Offer and Send via SMS'),
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
                      controller: _messageController,
                      decoration:
                      const InputDecoration(labelText: 'Enter Message'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      _sendMessage(_messageController.text);
                      _messageController.clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  void dispose() {
    _dataChannel?.close();
    _peerConnection?.close();
    super.dispose();
  }
}
