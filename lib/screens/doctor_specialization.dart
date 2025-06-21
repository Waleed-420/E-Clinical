import 'package:flutter/material.dart';
import 'doctor_schedule_setup.dart';

class DoctorSpecializationScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DoctorSpecializationScreen({Key? key, required this.user}) : super(key: key);

  @override
  _DoctorSpecializationScreenState createState() => _DoctorSpecializationScreenState();
}

class _DoctorSpecializationScreenState extends State<DoctorSpecializationScreen> {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Specialization'),
        elevation: 0,
      ),
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
                            ? const Icon(Icons.check_circle, color: Colors.green)
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
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DoctorScheduleSetup(
                                user: widget.user,
                                specialization: _selectedSpecialization!,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
