// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'dart:convert';
// import 'package:sms_advanced/sms_advanced.dart';
//
// void main() => runApp(MyApp());
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: WebRTCPage(),
//     );
//   }
// }
//
// class WebRTCPage extends StatefulWidget {
//   @override
//   _WebRTCPageState createState() => _WebRTCPageState();
// }
//
// class _WebRTCPageState extends State<WebRTCPage> {
//   RTCPeerConnection? _peerConnection;
//   RTCDataChannel? _dataChannel;
//   TextEditingController _mobileNumberController = TextEditingController();
//   TextEditingController _messageController = TextEditingController();
//   List<String> _messages = [];
//   List<RTCIceCandidate> _iceCandidates = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeWebRTC();
//     _listenForSms();
//   }
//
//   Future<void> _initializeWebRTC() async {
//     final configuration = {
//       'iceServers': [
//         {'url': 'stun:stun.l.google.com:19302'}
//       ]
//     };
//     _peerConnection = await createPeerConnection(configuration);
//
//     _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
//       _iceCandidates.add(candidate);
//       _sendSms('ICE_CANDIDATE', candidate.toMap());
//       _showToast('New ICE candidate added: ${candidate.toMap()}');
//     };
//
//     _peerConnection!.onDataChannel = (RTCDataChannel dataChannel) {
//       _showToast('Data channel received: ${dataChannel.label}');
//       _setupDataChannel(dataChannel);
//     };
//
//     RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
//     _dataChannel = await _peerConnection!
//         .createDataChannel('dataChannel', dataChannelDict);
//     _setupDataChannel(_dataChannel!);
//   }
//
//   void _setupDataChannel(RTCDataChannel dataChannel) {
//     dataChannel.onMessage = (RTCDataChannelMessage message) {
//       setState(() {
//         _messages.add(message.text);
//       });
//       _showToast('Received data message: ${message.text}');
//     };
//
//     dataChannel.onDataChannelState = (RTCDataChannelState state) {
//       if (state == RTCDataChannelState.RTCDataChannelOpen) {
//         _showToast('Data channel opened');
//       } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
//         _showToast('Data channel closed');
//       } else {
//         _showToast('Data channel state: $state');
//       }
//     };
//
//     _dataChannel = dataChannel;
//   }
//
//   void _createOffer() async {
//     RTCSessionDescription description = await _peerConnection!.createOffer();
//     await _peerConnection!.setLocalDescription(description);
//     String sdp = json.encode(description.toMap());
//     _sendSms('OFFER_SDP', sdp);
//   }
//
//   void _createAnswer() async {
//     RTCSessionDescription description = await _peerConnection!.createAnswer();
//     await _peerConnection!.setLocalDescription(description);
//     String sdp = json.encode(description.toMap());
//     _sendSms('ANSWER_SDP', sdp);
//   }
//
//   void _handleSDP(String sdp, bool isOffer) async {
//     try {
//       Map<String, dynamic> sdpMap = json.decode(sdp);
//       if (!sdpMap.containsKey('sdp') || !sdpMap.containsKey('type')) {
//         _showToast('Invalid SDP format');
//         return;
//       }
//
//       RTCSessionDescription description = RTCSessionDescription(
//         sdpMap['sdp'],
//         sdpMap['type'],
//       );
//
//       await _peerConnection!.setRemoteDescription(description);
//       _showToast('Set remote description: ${description.toMap()}');
//
//       if (isOffer) {
//         _createAnswer();
//       }
//     } catch (e) {
//       _showToast('Error parsing SDP: $e');
//     }
//   }
//
//   void _handleIceCandidate(String candidateJson) async {
//     try {
//       Map<String, dynamic> candidateMap = json.decode(candidateJson);
//       RTCIceCandidate candidate = RTCIceCandidate(
//         candidateMap['candidate'],
//         candidateMap['sdpMid'],
//         candidateMap['sdpMLineIndex'],
//       );
//       await _peerConnection!.addCandidate(candidate);
//       _showToast('Added ICE candidate: ${candidate.toMap()}');
//     } catch (e) {
//       _showToast('Error adding ICE candidate: $e');
//     }
//   }
//
//   void _sendSms(String type, dynamic data) {
//     String mobileNumber = _mobileNumberController.text;
//     if (mobileNumber.isNotEmpty) {
//       SmsSender sender = SmsSender();
//       String message = json.encode({'type': type, 'data': data});
//       sender.sendSms(SmsMessage(mobileNumber, message));
//     } else {
//       _showToast('Mobile number is empty');
//     }
//   }
//
//   void _listenForSms() {
//     SmsReceiver receiver = SmsReceiver();
//     receiver.onSmsReceived?.listen((SmsMessage msg) {
//       _showToast('SMS received: ${msg.body}');
//       Map<String, dynamic> message = json.decode(msg.body!);
//       if (message.containsKey('type') && message.containsKey('data')) {
//         String type = message['type'];
//         dynamic data = message['data'];
//         if (type == 'OFFER_SDP') {
//           _handleSDP(data, true);
//         } else if (type == 'ANSWER_SDP') {
//           _handleSDP(data, false);
//         } else if (type == 'ICE_CANDIDATE') {
//           _handleIceCandidate(data);
//         }
//       }
//     });
//   }
//
//   void _showToast(String message) {
//     Fluttertoast.showToast(
//       msg: message,
//       toastLength: Toast.LENGTH_SHORT,
//       gravity: ToastGravity.BOTTOM,
//       timeInSecForIosWeb: 1,
//       backgroundColor: Colors.black,
//       textColor: Colors.white,
//       fontSize: 16.0,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('WebRTC Data Channel'),
//       ),
//       body: Column(
//         children: <Widget>[
//           const SizedBox(height: 10),
//           TextField(
//             controller: _mobileNumberController,
//             decoration: const InputDecoration(labelText: 'Mobile Number'),
//           ),
//           ElevatedButton(
//             onPressed: _createOffer,
//             child: const Text('Create Offer and Send via SMS'),
//           ),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text(_messages[index]),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: <Widget>[
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: const InputDecoration(labelText: 'Enter Message'),
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.send),
//                   onPressed: () {
//                     _sendMessage(_messageController.text);
//                     _messageController.clear();
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _sendMessage(String message) {
//     if (_dataChannel != null &&
//         _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
//       _dataChannel!.send(RTCDataChannelMessage(message));
//       _showToast('Sent data message: $message');
//     } else {
//       _showToast('Data channel is not open');
//     }
//   }
//
//   @override
//   void dispose() {
//     _dataChannel?.close();
//     _peerConnection?.close();
//     super.dispose();
//   }
// }
