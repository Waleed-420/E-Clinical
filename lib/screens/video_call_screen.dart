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
  final int uid;

  const VideoCallScreen({
    Key? key,
    this.channel,
    required this.isCaller,
    required this.token,
    required this.uid,
  }) : super(key: key);

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
    void showSnack(String msg) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
      }
    }

    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
          setState(() {
            _agoraReady = true;
            _localUserJoined = true;
          });
          showSnack("Joined channel: ${conn.channelId}");
        },
        onUserJoined: (RtcConnection conn, int uid, int elapsed) {
          setState(() {
            _remoteUid = uid;
          });
          showSnack("Remote user joined: $uid");
        },
        onUserOffline:
            (RtcConnection conn, int uid, UserOfflineReasonType reason) {
              setState(() {
                _remoteUid = null;
              });
              showSnack("User left: $uid");
            },
        onError: (ErrorCodeType code, String msg) {
          showSnack("Agora error: $msg ($code)");
        },
      ),
    );

    await _engine!.enableVideo();
    await _engine!.startPreview();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    await _engine!.joinChannel(
      token: widget.token,
      channelId: widget.channel!,
      uid: widget.uid,
      options: ChannelMediaOptions(),
    );
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
    if (isLocal) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: widget.uid),
        ),
      );
    } else {
      if (_remoteUid == null || _remoteUid == 0) {
        return const Center(
          child: Text(
            'Waiting for user to join...',
            style: TextStyle(color: Colors.white),
          ),
        );
      }

      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channel!),
        ),
      );
    }
  }

  Widget _buildVideoLayout() {
    final hasRemote = _remoteUid != null && _remoteUid != 0;
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
              await http.post(
                Uri.parse('http://192.168.1.3:5000/api/end-call'),
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
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _agoraReady
            ? _buildVideoLayout()
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
