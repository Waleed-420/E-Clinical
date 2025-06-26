import 'package:e_clinical/screens/start_new_test_page.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './booking_requests_page.dart';

class LaboratoryHomePage extends StatefulWidget {
  final Map user;
  const LaboratoryHomePage({super.key, required this.user});

  @override
  State<LaboratoryHomePage> createState() => _LaboratoryHomePageState();
}

class _LaboratoryHomePageState extends State<LaboratoryHomePage> {
  final int pendingReports = 12;
  final double totalEarnings = 35450.75;

  List tests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTests();
  }

  void fetchTests() async {
    final uri = Uri.parse(
      'http://192.168.1.3:5000/api/lab/tests/${widget.user['_id']}',
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
        print("Error fetching tests: ${res.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Failed to fetch tests: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 235, 255, 248),
      appBar: AppBar(
        title: const Text("Laboratory Home"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircularPercentIndicator(
                    radius: 40.0,
                    lineWidth: 8.0,
                    percent: pendingReports / 100,
                    center: Text(
                      "$pendingReports",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    progressColor: Colors.teal,
                    backgroundColor: Colors.teal.shade100,
                    animation: true,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? 'Lab Name',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Total Earnings: Rs. ${totalEarnings.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Action Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _buildActionCard(
                  icon: Icons.add_circle_outline,
                  label: "Set a New Test",
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            StartNewTestPage(labUserId: user['_id']),
                      ),
                    ).then((_) => fetchTests());
                  },
                ),
                _buildActionCard(
                  icon: Icons.pending_actions,
                  label: "Pending Tests",
                  color: Colors.orange,
                  onTap: () {},
                ),
                _buildActionCard(
                  icon: Icons.calendar_month,
                  label: "Booking Requests",
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookingRequestsPage(labId: user['_id']),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Tests Offered Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.2,
                  colors: [
                    const Color.fromARGB(255, 74, 236, 220).withOpacity(0.1),
                    Colors.teal.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Tests Offered",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (tests.isEmpty)
                    const Text("No tests added yet.")
                  else
                    Column(
                      children: tests.map((test) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                test['testName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("Sample: ${test['sampleType']}"),
                              Text("Price: Rs. ${test['price']}"),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
