import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StartNewTestPage extends StatefulWidget {
  final String labUserId;
  const StartNewTestPage({super.key, required this.labUserId});

  @override
  State<StartNewTestPage> createState() => _StartNewTestPageState();
}

class _StartNewTestPageState extends State<StartNewTestPage> {
  final _formKey = GlobalKey<FormState>();
  final _testNameController = TextEditingController();
  final _priceController = TextEditingController();
  String? selectedSample;

  final Map<String, IconData> sampleIcons = {
    'Blood': Icons.bloodtype,
    'Urine': Icons.opacity,
    'Saliva': Icons.masks,
    'Plasma': Icons.science,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Test"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Test name input
              TextFormField(
                controller: _testNameController,
                decoration: const InputDecoration(
                  labelText: 'Test Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter test name' : null,
              ),
              const SizedBox(height: 20),

              // Price input
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (Rs)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter price' : null,
              ),
              const SizedBox(height: 20),

              // Sample type selector
              const Text(
                'Select Sample Required:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: sampleIcons.entries.map((entry) {
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(entry.value, size: 20),
                        const SizedBox(width: 4),
                        Text(entry.key),
                      ],
                    ),
                    selected: selectedSample == entry.key,
                    onSelected: (_) {
                      setState(() {
                        selectedSample = entry.key;
                      });
                    },
                    selectedColor: Colors.teal.shade100,
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),

              // Submit button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() &&
                      selectedSample != null) {
                    _submitTest();
                  } else if (selectedSample == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a sample type'),
                      ),
                    );
                  }
                },
                child: const Text('Save Test'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitTest() async {
    final data = {
      'labUserId': widget.labUserId,
      'testName': _testNameController.text.trim(),
      'sampleType': selectedSample,
      'price': double.parse(_priceController.text.trim()),
    };

    final url = Uri.parse('http://192.168.18.130:5000/api/lab/tests');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test added successfully!')),
        );
        Navigator.pop(context); // go back to previous screen
      } else {
        final res = jsonDecode(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${res['message']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to server: $e')),
      );
    }
  }
}
