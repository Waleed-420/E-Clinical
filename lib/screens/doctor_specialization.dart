import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'doctor_schedule_setup.dart';

class DoctorSpecializationScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DoctorSpecializationScreen({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _DoctorSpecializationScreenState createState() =>
      _DoctorSpecializationScreenState();
}

class _DoctorSpecializationScreenState
    extends State<DoctorSpecializationScreen> {
  String? _selectedSpecialization;
  final List<String> _specializations = [
    'Cardiologist',
    'Dermatologist',
    'Endocrinologist',
    'Gastroenterologist',
    'Neurologist',
    'Oncologist',
    'Pediatrician',
    'Psychiatrist',
    'Radiologist',
    'Surgeon',
  ];

  @override
  void initState() {
    super.initState();
    fetchDoctorSpecialization(); // fetch specialization on load
  }

  Future<bool> updateSpecializationOnServer() async {
    final doctorId = widget.user['_id'];
    final url = Uri.parse(
      'http://192.168.1.6:5000/api/doctor/$doctorId/specialization',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'specialization': _selectedSpecialization}),
      );

      final result = json.decode(response.body);
      return result['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating specialization: $e');
      }
      return false;
    }
  }

  Future<void> fetchDoctorSpecialization() async {
    final doctorId = widget.user['_id'];
    final url = Uri.parse(
      'http://192.168.1.6:5000/api/doctor/$doctorId/specialization',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final spec = data['specialization'];
        if (kDebugMode) {
          print('Fetched specialization from API: $spec');
        }

        if (spec != null) {
          // Match against list using lowercase comparison
          final match = _specializations.firstWhere(
            (s) => s.toLowerCase() == spec.toString().toLowerCase(),
            orElse: () => '',
          );

          if (match.isNotEmpty && mounted) {
            setState(() {
              _selectedSpecialization = match;
            });
          } else {
            if (kDebugMode) {
              print('No matching specialization found in list');
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('Error loading doctor specialization: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Specialization')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Specialization',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please select your medical specialization from the list below.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: _specializations.length,
                  itemBuilder: (context, index) {
                    final specialization = _specializations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(specialization),
                        trailing: _selectedSpecialization == specialization
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedSpecialization = specialization;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedSpecialization == null
                      ? null
                      : () async {
                          final updated = await updateSpecializationOnServer();
                          if (updated) {
                            Navigator.pushReplacement(
                              // ignore: use_build_context_synchronously
                              context,
                              MaterialPageRoute(
                                builder: (context) => DoctorScheduleSetup(
                                  user: widget.user,
                                  name: widget.user['name'],
                                  specialization: _selectedSpecialization!,
                                ),
                              ),
                            );
                          } else {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to update specialization',
                                ),
                              ),
                            );
                          }
                        },

                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _selectedSpecialization == null ? 'Continue' : 'Save',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
