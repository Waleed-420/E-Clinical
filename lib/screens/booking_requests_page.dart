import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookingRequestsPage extends StatefulWidget {
  final String labId;
  const BookingRequestsPage({super.key, required this.labId});

  @override
  State<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage> {
  List bookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  void fetchBookings() async {
    final uri = Uri.parse(
      "http://192.168.1.6:5000/api/lab/bookings/${widget.labId}",
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final jsonRes = jsonDecode(res.body);
        setState(() {
          bookings = jsonRes['bookings'];
          isLoading = false;
        });
      } else {
        print("Error: ${res.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Failed to fetch bookings: $e");
      setState(() => isLoading = false);
    }
  }

  void startChat(String userId) async {
    final uri = Uri.parse("http://192.168.1.6:5000/api/lab/chat/start");
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'labUserId': widget.labId, 'userId': userId}),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final channel = json['channel'];

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(channel: channel, currentUser: {"_id": widget.labId}),
        ),
      );
    } else {
      print("Failed to start chat: ${res.body}");
    }
  }

  void startCall(String userId, String bookingId) async {
    final uri = Uri.parse("http://192.168.1.6:5000/api/lab/start-audio-call");
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channelName': bookingId, 'userId': userId}),
    );

    if (res.statusCode == 200) {
      print("Call started");
    } else {
      print("Call failed: ${res.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Requests"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
          ? const Center(child: Text("No bookings yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text("Test: ${booking['testName']}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("User: ${booking['userName']}"),
                        Text("Sample Location: ${booking['location']}"),
                        Text("Price: Rs. ${booking['price']}"),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.teal),
                          onPressed: () => startChat(booking['userId']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.teal),
                          onPressed: () =>
                              startCall(booking['userId'], booking['_id']),
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

// Dummy ChatScreen placeholder — replace with your actual ChatScreen
class ChatScreen extends StatelessWidget {
  final String channel;
  final Map<String, dynamic> currentUser;

  const ChatScreen({
    super.key,
    required this.channel,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat: $channel")),
      body: Center(child: Text("Chat with user")),
    );
  }
}
