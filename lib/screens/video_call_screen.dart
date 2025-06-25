import 'dart:async';
import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

const appId = "93fa8e9ec1464959abd941f1f35b5470";

class VideoCallScreen extends StatefulWidget {
  final String? channel;
  final bool isCaller;
  final String token;

  const VideoCallScreen({
    super.key,
    this.channel,
    required this.isCaller,
    required this.token,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  RtcEngine? _engine;
  bool _agoraReady = false;

  bool _isLocalBig = false;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
  // Utility to show messages
  void showSnack(String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  debugPrint("🔧 Requesting permissions...");
  await [Permission.camera, Permission.microphone].request();
  debugPrint("✅ Permissions requested.");
  showSnack("Permissions granted");

  debugPrint("🔧 Creating Agora engine...");
  _engine = createAgoraRtcEngine();
  await _engine!.initialize(RtcEngineContext(appId: appId));
  debugPrint("✅ Agora engine initialized.");
  showSnack("Agora engine initialized");

  debugPrint("🔧 Registering event handlers...");
  _engine!.registerEventHandler(RtcEngineEventHandler(
    onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
      debugPrint("🎉 onJoinChannelSuccess: channel=${conn.channelId}, uid=${conn.localUid}");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Joined channel: ${conn.channelId}")),
        );
      }
      setState(() {
        _agoraReady = true;
        _localUserJoined = true;
      });
    },
    onUserJoined: (RtcConnection conn, int uid, int elapsed) {
      debugPrint("👤 onUserJoined: uid=$uid");
      showSnack("Remote user joined: $uid");
      setState(() {
        _remoteUid = uid;
      });
    },
    onUserOffline: (RtcConnection conn, int uid, UserOfflineReasonType reason) {
      debugPrint("👋 onUserOffline: uid=$uid, reason=$reason");
      showSnack("User left: $uid");
      setState(() {
        _remoteUid = null;
      });
    },
    onError: (ErrorCodeType code, String msg) {
      debugPrint("❌ Agora error: $code, $msg");
      showSnack("Agora error: $msg ($code)");
    },
  ));
  debugPrint("✅ Event handlers registered.");
  showSnack("Event handlers registered");

  debugPrint("🎥 Enabling video...");
  await _engine!.enableVideo();
  await _engine!.startPreview();
  debugPrint("✅ Video enabled and preview started.");
  showSnack("Video preview started");

  debugPrint("👤 Setting client role to broadcaster...");
  await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
  debugPrint("✅ Client role set.");
  showSnack("Client role: Broadcaster");

  debugPrint("🚀 Joining channel: ${widget.channel}, token: ${widget.token}");
  await _engine!.joinChannel(
    token: widget.token,
    channelId: widget.channel!,
    uid: 0,
    options: ChannelMediaOptions(),
  );
  debugPrint("✅ joinChannel() called.");
  showSnack("Joining channel...");
}

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
  if (_engine != null) {
    try {
      await _engine!.leaveChannel();
      await _engine!.release();
    } catch (_) {}
    _engine = null;
  }

  setState(() {
    _agoraReady = false;
    _localUserJoined = false;
    _remoteUid = null;
  });
}

  Widget _videoView({required bool isLocal}) {
    return AgoraVideoView(
      controller: isLocal
          ? VideoViewController(
              rtcEngine: _engine!,
              canvas: const VideoCanvas(uid: 0),
            )
          : VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.channel!),
            ),
    );
  }

  Widget _buildVideoLayout() {
    final hasRemote = _remoteUid != null;

    Widget bigView = _videoView(isLocal: _isLocalBig || !hasRemote);
    Widget smallView = _videoView(isLocal: !_isLocalBig && hasRemote);

    return Stack(
      children: [
        Positioned.fill(child: bigView),
        if (hasRemote || _localUserJoined)
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isLocalBig = !_isLocalBig;
                });
              },
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: smallView,
                ),
              ),
            ),
          ),
        _buildControls(),
      ],
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.grey[800],
            heroTag: "flip",
            onPressed: () {
              _engine!.switchCamera();
            },
            child: const Icon(Icons.flip_camera_android),
          ),
          FloatingActionButton(
            backgroundColor: Colors.red,
            heroTag: "end",
            onPressed: () async {
              await _engine!.leaveChannel();
              await _engine!.release();
              Navigator.pop(context);
              final res = await http.post(
                Uri.parse('http://192.168.1.9:5000/api/end-call'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'channelName': widget.channel}),
              );
            },
            child: const Icon(Icons.call_end),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        // return false to disable popping
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _agoraReady
            ? _buildVideoLayout()
            : Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
