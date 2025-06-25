import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'doctor_detail.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const BookAppointmentScreen({super.key, required this.user});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedSpecialization;
  List<dynamic> _doctors = [];
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _controller;

  final List<String> _specializations = [
    'Cardiologist',
    'Dentist',
    'Dermatologist',
    'Endocrinologist',
    'Gastroenterologist',
    'Neurologist',
    'Oncologist',
    'Pediatrician',
    'Psychiatrist',
    'Radiologist',
    'Surgeon',
    'Gynaecologist',
  ];

  final List<Map<String, dynamic>> popularSpecializations = [
    {'title': 'Cardiologist', 'image': 'assets/images/Heart.png'},
    {'title': 'Dentist', 'image': 'assets/images/Tooth.png'},
    {'title': 'Neurologist', 'image': 'assets/images/Brain.png'},
    {'title': 'Gynaecologist', 'image': 'assets/images/Gynae.png'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchDoctors() async {
    if (_selectedSpecialization == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _doctors = [];
    });

    try {
      final uri = Uri.parse(
        'http://192.168.10.19:5000/api/doctors?specialization=${Uri.encodeComponent(_selectedSpecialization!)}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          setState(() {
            _doctors = result['doctors'];
          });
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to load doctors';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
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
      appBar: AppBar(title: const Text('Book Appointment'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Most Popular',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => CustomPaint(
                      painter: BubblePainter(animation: _controller),
                      size: const Size(double.infinity, 150),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.only(left: 49),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: popularSpecializations.length,
                        itemBuilder: (context, index) {
                          final item = popularSpecializations[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSpecialization =
                                    item['title'] as String;
                              });
                              _fetchDoctors();
                            },
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF15A196),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (item.containsKey('image'))
                                    SizedBox(
                                      height: 60,
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Image.asset(item['image']),
                                      ),
                                    )
                                  else if (item.containsKey('icon'))
                                    const Icon(
                                      Icons.child_care,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item['title'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 0,
                    child: Image.asset(
                      'assets/images/doctor_indicating.png',
                      height: 120,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Find a Doctor',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CustomDropdown<String>(
              hintText: 'Select Specialization',
              items: _specializations,
              initialItem: _specializations.contains(_selectedSpecialization)
                  ? _selectedSpecialization
                  : null,
              onChanged: (value) {
                setState(() {
                  _selectedSpecialization = value;
                });
                _fetchDoctors();
              },
              decoration: CustomDropdownDecoration(
                closedFillColor: Colors.grey[100],
                closedBorder: Border.all(color: Colors.grey.shade400, width: 1),
                closedBorderRadius: BorderRadius.circular(12),
                hintStyle: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_doctors.isEmpty && _selectedSpecialization != null)
              const Expanded(
                child: Center(
                  child: Text('No doctors found with available schedule.'),
                ),
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
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(doctor['name'] ?? 'Dr. Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor['specialization'] ?? ''),
                            Text(
                              'Fee: ₹${doctor['fees']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
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

class BubblePainter extends CustomPainter {
  final Animation<double> animation;
  final Random _random = Random();

  BubblePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 15; i++) {
      final radius = _random.nextDouble() * 12 + 6;
      final dx = _random.nextDouble() * size.width;
      final dy = ((animation.value + i * 0.1) % 1.0) * size.height;

      paint.color = Colors.white.withOpacity(0.15 + _random.nextDouble() * 0.2);
      canvas.drawCircle(Offset(dx, size.height - dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
