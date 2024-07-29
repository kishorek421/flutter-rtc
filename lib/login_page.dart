// import 'package:flutter/material.dart';
// import 'package:flutter_rtc/main_page.dart';
// import 'package:hive/hive.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:fluttertoast/fluttertoast.dart';
//
// class LoginPage extends StatefulWidget {
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController _mobileController = TextEditingController();
//   final _userBox = Hive.box('user_data');
//
//   Future<void> _login() async {
//     final mobileNumber = _mobileController.text;
//
//     if (mobileNumber.isEmpty) {
//       Fluttertoast.showToast(msg: 'Please enter your mobile number');
//       return;
//     }
//
//     // Fetch SDP and ICE information (placeholder logic)
//     final rtc = await _createRTC();
//     final sdp = rtc.localDescription.sdp;
//     final iceCandidates = rtc.iceCandidates;
//
//     // Store SDP and ICE in Hive
//     await _userBox.put('mobile_number', mobileNumber);
//     await _userBox.put('sdp', sdp);
//     await _userBox.put('ice', iceCandidates);
//
//     // Navigate to main page
//     Navigator.of(context).pushReplacement(MaterialPageRoute(
//       builder: (context) => MainPage(),
//     ));
//   }
//
//   Future<RTCPeerConnection> _createRTC() async {
//     final config = {'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]};
//     final rtc = await createPeerConnection(config);
//
//     // Placeholder for setting up local description and ICE candidates
//     final offer = await rtc.createOffer();
//     await rtc.setLocalDescription(offer);
//
//     // Placeholder for storing ICE candidates
//     final iceCandidates = await rtc.getIceCandidates();
//
//     return rtc;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Login')),
//       body: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: _mobileController,
//               decoration: InputDecoration(labelText: 'Mobile Number'),
//               keyboardType: TextInputType.phone,
//             ),
//             SizedBox(height: 16.0),
//             ElevatedButton(
//               onPressed: _login,
//               child: Text('Login'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
