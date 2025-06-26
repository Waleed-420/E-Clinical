import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioCallScreen extends StatefulWidget {
  final String channel;
  final String token;
  final bool isCaller;

  const AudioCallScreen({
    super.key,
    required this.channel,
    required this.token,
    required this.isCaller,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  late final RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await Permission.microphone.request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(appId: 'dff72470ec104f92aa6cc17e36337822'),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          print("✅ Local user joined: ${connection.localUid}");
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          print("✅ Remote user joined: $remoteUid");
        },
        onUserOffline: (connection, remoteUid, reason) {
          print("❌ Remote user left: $remoteUid");
        },
      ),
    );

    await _engine.enableAudio();

    await _engine.joinChannel(
      token: widget.token,
      channelId: widget.channel,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(title: const Text("Audio Call")),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.call_end, color: Colors.white),
          label: const Text("End Call", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            _engine.leaveChannel();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
