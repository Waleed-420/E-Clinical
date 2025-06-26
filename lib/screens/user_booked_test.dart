import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_screen.dart'; // Use the reusable ChatScreen here

class UserBookedTestsPage extends StatefulWidget {
  final String userId;
  const UserBookedTestsPage({super.key, required this.userId});

  @override
  State<UserBookedTestsPage> createState() => _UserBookedTestsPageState();
}

class _UserBookedTestsPageState extends State<UserBookedTestsPage> {
  List tests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBookedTests();
  }

  void fetchBookedTests() async {
    final uri = Uri.parse(
      "http://192.168.1.3:5000/api/user/booked-tests/${widget.userId}",
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final jsonRes = jsonDecode(res.body);
        setState(() {
          tests = jsonRes['tests'];
          isLoading = false;
        });
      } else {
        print("Error: ${res.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Failed to fetch tests: $e");
      setState(() => isLoading = false);
    }
  }

  void startChat(String labUserId) async {
    // Reuse the lab API to ensure chat channel exists
    final uri = Uri.parse("http://192.168.1.3:5000/api/lab/chat/start");
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'labUserId': labUserId, 'userId': widget.userId}),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final channel = json['channel'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(channel: channel, currentUser: {"_id": widget.userId}),
        ),
      );
    } else {
      print("Failed to start chat: ${res.body}");
    }
  }

  void startCall(String labUserId, String bookingId) async {
    final uri = Uri.parse("http://192.168.1.3:5000/api/start-audio-call");
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channelName': bookingId,
        'userId': widget.userId,
        'labUserId': labUserId,
        'callerType': 'user',
      }),
    );

    if (res.statusCode == 200) {
      print("Call started successfully");
    } else {
      print("Call failed: ${res.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Booked Tests"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tests.isEmpty
          ? const Center(child: Text("No tests booked yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tests.length,
              itemBuilder: (context, index) {
                final test = tests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Test: ${test['testName']}"),
                              Text("Lab: ${test['labName']}"),
                              Text("Location: ${test['location']}"),
                              Text("Price: Rs. ${test['price']}"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.teal),
                              onPressed: () => startChat(test['labUserId']),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.teal),
                              onPressed: () =>
                                  startCall(test['labUserId'], test['_id']),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
