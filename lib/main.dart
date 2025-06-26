import 'dart:convert';
import 'package:e_clinical/screens/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import './screens/splash_screen.dart';
import './screens/sign_in_screen.dart';
import './screens/scan_photo_page.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import './screens/audio_call_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    _messaging = FirebaseMessaging.instance;
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(appId: 'dff72470ec104f92aa6cc17e36337822'),
    );
    await _messaging.requestPermission();

    FirebaseMessaging.onMessage.listen(_handleCallMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleCallMessage);

    final initialMsg = await _messaging.getInitialMessage();
    if (initialMsg != null) _handleCallMessage(initialMsg);

    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification?.title == 'CallRejected') {
        _engine.leaveChannel();
        _engine.release();
        Navigator.of(navigatorKey.currentContext!).pop();

        showDialog(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            title: Text('Call Rejected'),
            content: Text('The patient rejected your call.'),
          ),
        );

        Future.delayed(const Duration(seconds: 10), () {
          Navigator.of(navigatorKey.currentContext!).pop();
        });
      }
    });
  }

  void _handleCallMessage(RemoteMessage message) {
    final type = message.data['type'];
    final channelName = message.data['channelName'];
    final token = message.data['token'];
    final uidStr = message.data['uid'];

    if (channelName == null || token == null || uidStr == null) return;

    final uid = int.tryParse(uidStr) ?? 0;

    if (type == 'audio') {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (_) => AudioCallScreen(
            channel: channelName,
            isCaller: false,
            token: token,
          ),
        ),
      );
    } else if (type == 'video' ||
        message.notification?.title == 'Incoming Video Call') {
      _showVideoCallDialog(channelName, token, uid);
    }
  }

  void _showVideoCallDialog(String channelName, String token, int uid) {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Incoming Video Call'),
        content: const Text('Doctor is calling you now.'),
        actions: [
          TextButton(
            onPressed: () async {
              await http.post(
                Uri.parse('http://192.168.1.3:5000/api/reject-call'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'channelName': channelName}),
              );
              Navigator.of(navigatorKey.currentContext!).pop();
            },
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(navigatorKey.currentContext!).pop();
              Navigator.of(navigatorKey.currentContext!).push(
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    channel: channelName,
                    isCaller: false,
                    token: token,
                    uid: uid,
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
