import 'dart:convert';

import 'package:e_clinical/screens/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import './screens/splash_screen.dart';
import './screens/sign_in_screen.dart';
import './screens/scan_photo_page.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http; // make sure you have this

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onMessage.listen((message) {
    if (message.notification?.title == 'Incoming Video Call') {
      final token = message.data['token'];
      final channelName = message.data['channelName'];
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            channel: channelName,
            isCaller: false, // the callee
            token: token,
          ),
        ),
      );
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final FirebaseMessaging _messaging;
  late final RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    _messaging = FirebaseMessaging.instance;
    _engine = createAgoraRtcEngine();
    _engine.initialize(
      RtcEngineContext(appId: 'dff72470ec104f92aa6cc17e36337822'),
    );
    // ask permissions (iOS/macOS)
    _messaging.requestPermission();

    // foreground
    FirebaseMessaging.onMessage.listen(_handleIncomingCall);
    // if app was backgrounded & opened via tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleIncomingCall);
    // if app was terminated
    _messaging.getInitialMessage().then((msg) {
      if (msg != null) _handleIncomingCall(msg);

      FirebaseMessaging.onMessage.listen((message) {
        final t = message.notification?.title;
        if (t == 'CallRejected') {
          // tear down Agora
          _engine.leaveChannel();
          _engine.release();
          // pop the call screen if it’s open
          Navigator.of(
            navigatorKey.currentContext!,
          ).pop(); // dismiss call screen

          // Show a dialog or modal
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: Text('Call Rejected'),
              content: Text('The patient rejected your call.'),
            ),
          );

          // Auto-dismiss after 10 sec
          Future.delayed(Duration(seconds: 10), () {
            Navigator.of(navigatorKey.currentContext!).pop(); // dismiss alert
          });
        }
      });
    });
  }

  void _handleIncomingCall(RemoteMessage message) {
    final channelName = message.data['channelName'];
    final token = message.data['token'];
    if (channelName == null || token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Incoming Video Call'),
        content: const Text('Dr. is calling you now.'),
        actions: [
          TextButton(
            // ← make this callback async
            onPressed: () async {
              // 1) tell your backend the call was rejected
              await http.post(
                Uri.parse('http://192.168.1.5:5000/api/reject-call'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'channelName': channelName}),
              );

              // 2) then dismiss the dialog
              Navigator.of(context).pop();
            },
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    channel: channelName,
                    isCaller: false,
                    token: token,
                  ),
                ),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Clinical',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: SplashScreen(),
      routes: {
        '/signin': (context) => SignInScreen(),
        '/scan-photo': (context) => const ScanPhotoPage(),
      },
    );
  }
}
