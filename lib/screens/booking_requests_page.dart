import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import './chat_screen.dart';
import './audio_call_screen.dart';

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
      "http://192.168.1.3:5000/api/lab/bookings/${widget.labId}",
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
    final uri = Uri.parse("http://192.168.1.3:5000/api/lab/chat/start");
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'labUserId': widget.labId, 'userId': userId}),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final channel = json['channel'];

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
    final uri = Uri.parse("http://192.168.1.3:5000/api/start-audio-call");
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channelName': bookingId,
        'userId': userId,
        'labUserId': widget.labId,
        'callerType': 'lab',
      }),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final token = json['token'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AudioCallScreen(channel: bookingId, token: token, isCaller: true),
        ),
      );
    } else {
      print("Call failed: ${res.body}");
    }
  }

  void showMap(String locationString) async {
    try {
      final parts = locationString.split(',');
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());

      final url =
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid location data")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Requests"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
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
                final locationStr = booking['location'];

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['testName'] ?? "Unknown Test",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "User: ${booking['userName'] ?? 'N/A'}",
                          style: const TextStyle(fontSize: 15),
                        ),
                        Text(
                          "Sample Location: $locationStr",
                          style: const TextStyle(fontSize: 15),
                        ),
                        Text(
                          "Price: Rs. ${booking['price'] ?? 'N/A'}",
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(Icons.chat, color: Colors.white),
                              label: const Text(
                                "Open Chat",
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: () => startChat(booking['userId']),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(Icons.call, color: Colors.white),
                              label: const Text(
                                "Call the Patient",
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: () =>
                                  startCall(booking['userId'], booking['_id']),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.location_on_outlined,
                                size: 20,
                              ),
                              label: const Text(
                                "Start Journey",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              onPressed: () => showMap(locationStr),
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
