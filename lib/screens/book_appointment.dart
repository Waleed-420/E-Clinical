import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


import './doctor_detail.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const BookAppointmentScreen({Key? key, required this.user}) : super(key: key);

  @override
  _BookAppointmentScreenState createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  String? _selectedSpecialization;
  List<dynamic> _doctors = [];
  bool _isLoading = false;
  String? _errorMessage;

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

  Future<void> _fetchDoctors() async {
    if (_selectedSpecialization == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('http://192.168.10.18:5000/api/doctors?specialization=$_selectedSpecialization');
      final response = await http.get(uri);
      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success']) {
        setState(() {
          _doctors = result['doctors'];
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load doctors';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching doctors: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find a Doctor',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSpecialization,
              decoration: const InputDecoration(
                labelText: 'Specialization',
                border: OutlineInputBorder(),
              ),
              items: _specializations
                  .map((spec) => DropdownMenuItem(
                        value: spec,
                        child: Text(spec),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSpecialization = value;
                  _doctors = [];
                });
                _fetchDoctors();
              },
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (_doctors.isEmpty && _selectedSpecialization != null)
              const Center(
                child: Text('No doctors found for this specialization'),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = _doctors[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(doctor['name'] ?? 'Dr. Unknown'),
                        subtitle: Text(doctor['specialization'] ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Replace Placeholder with actual DoctorDetailScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DoctorDetailScreen(
                                 user: widget.user,
                                 doctor: doctor,
                               ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
