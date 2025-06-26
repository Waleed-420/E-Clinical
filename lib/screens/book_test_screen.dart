import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BookTestScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const BookTestScreen({super.key, required this.user});

  @override
  State<BookTestScreen> createState() => _BookTestScreenState();
}

class _BookTestScreenState extends State<BookTestScreen> {
  List tests = [];
  List filtered = [];
  String searchQuery = '';
  String sortOption = 'None';

  @override
  void initState() {
    super.initState();
    fetchTests();
  }

  void fetchTests() async {
    final url = Uri.parse('http://192.168.1.6:5000/api/lab/tests');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          tests = data['tests'];
          applyFilters();
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void applyFilters() {
    List result = tests.where((test) {
      return test['testName'].toString().toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
    }).toList();

    if (sortOption == 'PriceAsc') {
      result.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    } else if (sortOption == 'PriceDesc') {
      result.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
    }

    setState(() {
      filtered = result;
    });
  }

  void bookTest(Map test) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final locationController = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Sample Collection Location",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  hintText: "Enter location (e.g. Home address)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text("Confirm Booking"),
                onPressed: () async {
                  final location = locationController.text.trim();
                  if (location.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter location")),
                    );
                    return;
                  }

                  final bookingData = {
                    'userId': widget.user['_id'],
                    'labUserId': test['labUserId'],
                    'testId': test['_id'],
                    'location': location,
                  };

                  final res = await http.post(
                    Uri.parse('http://192.168.1.6:5000/api/book-test'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(bookingData),
                  );

                  if (res.statusCode == 201) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Test booked successfully")),
                    );
                  } else {
                    final err = jsonDecode(res.body);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: ${err['message']}")),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Lab Test"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                sortOption = value;
                applyFilters();
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'None', child: Text('No Sorting')),
              const PopupMenuItem(
                value: 'PriceAsc',
                child: Text('Price: Low to High'),
              ),
              const PopupMenuItem(
                value: 'PriceDesc',
                child: Text('Price: High to Low'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search test name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                searchQuery = val;
                applyFilters();
              },
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No tests available'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final test = filtered[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.science,
                            color: Colors.teal,
                          ),
                          title: Text(test['testName']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sample: ${test['sampleType']}'),
                              Text('Price: Rs. ${test['price']}'),
                              if (test['description'] != null &&
                                  test['description'].toString().isNotEmpty)
                                Text('Note: ${test['description']}'),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () => bookTest(test),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
