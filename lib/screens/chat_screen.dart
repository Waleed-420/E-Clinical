import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String? _chatId;
  final _messageController = TextEditingController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyChannelAndLoadMessages();
  }

  void _verifyChannelAndLoadMessages() {
    if (widget.channel.length != 48) {
      setState(() {
        _errorMessage = 'Invalid chat channel format';
        _isLoading = false;
      });
      return;
    }
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      print('Loading messages for channel: ${widget.channel}');

      final response = await http.get(
        Uri.parse(
          'http://192.168.10.10:5000/api/chat/channel/${widget.channel}',
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final chat = data['chat'];
          setState(() {
            _messages = chat['messages'] ?? [];
            _chatId = chat['_id'];
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load chat';
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
        await _createNewChat();
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading messages: $e');
    }
  }

  Future<void> _createNewChat() async {
    try {
      print('Attempting to create new chat for channel: ${widget.channel}');

      final response = await http.post(
        Uri.parse(
          'http://192.168.10.10:5000/api/chat/channel/${widget.channel}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        await _loadMessages();
      } else {
        setState(() {
          _errorMessage = 'Failed to create chat';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating chat: ${e.toString()}';
        _isLoading = false;
      });
      print('Error creating chat: $e');
    }
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty || _chatId == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.10:5000/api/chat/$_chatId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender': widget.currentUser['_id'],
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages.add({
            'sender': widget.currentUser['_id'],
            'content': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
          _messageController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation Chat')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUserMessage =
                          message['sender'] == widget.currentUser['_id'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: isUserMessage
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isUserMessage
                                  ? Colors.blue[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['content'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('HH:mm').format(
                                    DateTime.parse(message['timestamp']),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(_messageController.text),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
