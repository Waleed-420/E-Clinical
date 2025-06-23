import 'package:e_clinical/screens/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import './screens/splash_screen.dart';
import './screens/sign_in_screen.dart';
import './screens/scan_photo_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onMessage.listen((message) {
    if (message.notification?.title == 'Incoming Video Call') {
      final token = message.data['token'];
      final channelName = message.data['channelName'];
      // TODO: Implement navigation to call screen with token & channelName
      print('Incoming call: $channelName, token: $token');
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

  @override
  void initState() {
    super.initState();
    _messaging = FirebaseMessaging.instance;

    // ask permissions (iOS/macOS)
    _messaging.requestPermission();

    // foreground
    FirebaseMessaging.onMessage.listen(_handleIncomingCall);
    // if app was backgrounded & opened via tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleIncomingCall);
    // if app was terminated
    _messaging.getInitialMessage().then((msg) {
      if (msg != null) _handleIncomingCall(msg);
    });
  }

  void _handleIncomingCall(RemoteMessage message) {
    final data = message.data;
    final channelName = data['channelName'];
    final token = data['token'];
    if (channelName == null || token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Incoming Video Call'),
        content: const Text('Dr. is calling you now.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dismiss
              // you could also notify backend here if you want to “reject”
            },
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    token: token,
                    channelName: channelName,
                    isCaller: false, // the callee
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
