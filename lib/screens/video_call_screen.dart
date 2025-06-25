import 'dart:async';
import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

const appId = "dff72470ec104f92aa6cc17e36337822";

class VideoCallScreen extends StatefulWidget {
  final String? channel;
  final bool isCaller;
  final String token;

  const VideoCallScreen({
    Key? key,
    this.channel,
    required this.isCaller,
    required this.token,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  bool _isLocalBig = false;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              setState(() {
                _remoteUid = null;
              });
            },
        onTokenPrivilegeWillExpire: (_, __) async {
          final res = await http.post(
            Uri.parse('http://10.8.149.233:5000/api/refresh-token'),
            body: jsonEncode({'channelName': widget.channel}),
          );
          final newToken = jsonDecode(res.body)['token'];
          await _engine.renewToken(newToken);
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: widget.token,
      channelId: widget.channel!,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  Widget _videoView({required bool isLocal}) {
    return AgoraVideoView(
      controller: isLocal
          ? VideoViewController(
              rtcEngine: _engine,
              canvas: const VideoCanvas(uid: 0),
            )
          : VideoViewController.remote(
              rtcEngine: _engine,
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
              _engine.switchCamera();
            },
            child: const Icon(Icons.flip_camera_android),
          ),
          FloatingActionButton(
            backgroundColor: Colors.red,
            heroTag: "end",
            onPressed: () {
              _engine.leaveChannel();
              _engine.release();
              Navigator.pop(context);
              final res = http.post(
                Uri.parse('http://10.8.149.233:5000/api/end-call'),
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
      child: Scaffold(backgroundColor: Colors.black, body: _buildVideoLayout()),
    );
  }
}
