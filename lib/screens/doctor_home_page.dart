import 'user_appointments.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'doctor_license_upload.dart';
import 'doctor_schedule_setup.dart';
import 'doctor_specialization.dart';

class DoctorHomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const DoctorHomePage({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _DoctorHomePageState createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage> {
  Map<String, dynamic>? _doctorDetails;
  List<dynamic> _upcomingAppointments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchDoctorData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _fetchDoctorData();
      await _fetchUpcomingAppointments();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dashboard';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDoctorData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.10.19:5000/api/doctors?doctorId=${widget.user['_id']}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data['doctors'].isNotEmpty) {
          _doctorDetails = data['doctors'][0];
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load doctor details';
    }
  }

  Future<void> _fetchUpcomingAppointments() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.10.19:5000/api/appointments?doctorId=${widget.user['_id']}&status=booked',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _upcomingAppointments = data['appointments'];
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load appointments';
    }
  }

  @override
  Widget build(BuildContext context) {
    final specialization = _doctorDetails?['specialization'] ?? 'Not specified';
    final isVerified = _doctorDetails?['verified'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Dr. ${widget.user['name']?.split(' ').first ?? ''}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Chip(
                                label: Text(
                                  isVerified
                                      ? 'Verified'
                                      : 'Pending Verification',
                                  style: TextStyle(
                                    color: isVerified
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                backgroundColor: isVerified
                                    ? Colors.green
                                    : Colors.yellow,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Specialization: $specialization',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_upcomingAppointments.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Upcoming Appointments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._upcomingAppointments
                        .take(3)
                        .map(
                          (appointment) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                'Patient: ${appointment['patientName'] ?? 'Anonymous'}',
                              ),
                              subtitle: Text(
                                '${appointment['date']} at ${appointment['time']}',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                    if (_upcomingAppointments.length > 3)
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All Appointments'),
                      ),
                    const SizedBox(height: 24),
                  ],
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildFeatureCard(
                        context,
                        icon: Icons.verified_user,
                        title: 'License Verification',
                        subtitle: isVerified ? 'Verified' : 'Pending',
                        color: isVerified ? Colors.green : Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DoctorLicenseUpload(user: widget.user),
                            ),
                          ).then((_) => _loadData());
                        },
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.medical_services,
                        title: 'Specialization',
                        subtitle: specialization,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DoctorSpecializationScreen(user: widget.user),
                            ),
                          ).then((_) => _loadData());
                        },
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.schedule,
                        title: 'Schedule Setup',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DoctorScheduleSetup(
                                user: widget.user,
                                name: widget.user['name'],
                                specialization: specialization,
                              ),
                            ),
                          ).then((_) => _loadData());
                        },
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.calendar_today,
                        title: 'Appointments',
                        badge: _upcomingAppointments.length,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserAppointments(
                                user: widget.user,
                                // doctor: _doctorDetails ?? widget.user,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    int? badge,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 40,
                    color: color ?? Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              if (badge != null && badge > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
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
