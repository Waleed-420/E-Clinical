import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String channel;
  final Map<String, dynamic> currentUser;

  const ChatScreen({
    super.key,
    required this.channel,
    required this.currentUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  String? _chatId;
  bool _isSending = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadChat();
    });
  }

  Future<void> _loadChat() async {
    final url = 'http://192.168.1.6:5000/api/chat/channel/${widget.channel}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final chat = data['chat'];

      setState(() {
        _chatId = chat['_id'];
        _messages = chat['messages'];
      });

      _scrollToBottom();
    } else if (response.statusCode == 404) {
      await _createNewChat();
    }
  }

  Future<void> _createNewChat() async {
    final url = 'http://192.168.1.6:5000/api/chat/channel/${widget.channel}';
    final response = await http.post(Uri.parse(url));
    if (response.statusCode == 200) {
      _loadChat();
    }
  }

  Future<void> _sendMessage(String text) async {
    if (_chatId == null || text.trim().isEmpty) return;

    setState(() => _isSending = true);

    final response = await http.post(
      Uri.parse('http://192.168.1.6:5000/api/chat/$_chatId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender': widget.currentUser['_id'],
        'content': text.trim(),
      }),
    );

    if (response.statusCode == 200) {
      _controller.clear();
      await _loadChat();
    }

    setState(() => _isSending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map message, bool isUser, bool showAvatar) {
    final messageTime = DateFormat(
      'HH:mm',
    ).format(DateTime.parse(message['timestamp']));
    final isDelivered = message['delivered'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && showAvatar)
            const Padding(
              padding: EdgeInsets.only(right: 6.0),
              child: Icon(Icons.person, size: 28, color: Color(0xFF15A196)),
            ),
          if (!isUser && !showAvatar) const SizedBox(width: 34),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(left: 8, right: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF15A196)
                    : const Color(0xFFB8E3DF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'],
                    style: TextStyle(
                      fontSize: 15,
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        messageTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: isUser ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      if (isUser)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(
                            Icons.done_all,
                            size: 16,
                            color: isDelivered
                                ? Colors.blueAccent
                                : Colors.white54,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Consultation Chat',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['sender'] == widget.currentUser['_id'];
                final prevSender = index > 0
                    ? _messages[index - 1]['sender']
                    : null;
                final showAvatar =
                    !isUser && (index == 0 || prevSender != message['sender']);

                return _buildMessageBubble(message, isUser, showAvatar);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF15A196),
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending
                          ? null
                          : () => _sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
