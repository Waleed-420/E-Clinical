import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DoctorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> doctor;

  const DoctorDetailScreen({
    Key? key,
    required this.user,
    required this.doctor,
  }) : super(key: key);

  @override
  _DoctorDetailScreenState createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  DateTime _selectedDay = DateTime.now();
  List<dynamic> _availableSlots = [];
  bool _isLoading = false;
  String? _selectedSlot;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAvailableSlots();
  }

  Future<void> _fetchAvailableSlots() async {
    setState(() {
      _isLoading = true;
      _availableSlots = [];
      _selectedSlot = null;
      _errorMessage = null;
    });

    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDay);
      final doctorId = widget.doctor['_id'];
      final uri = Uri.parse('http://192.168.10.18:5000/api/doctor/$doctorId/slots?date=$date');

      final response = await http.get(uri);
      
      // First check if response is HTML (error page)
      if (response.headers['content-type']?.contains('text/html') ?? false) {
        throw Exception('Server returned HTML error page');
      }

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success']) {
        setState(() {
          _availableSlots = result['slots'];
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load slots';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching slots: ${e.toString().replaceAll(RegExp(r'<!DOCTYPE.*'), 'Server error')}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedSlot == null) {
      _showMessage('Please select a time slot');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.18:5000/api/appointments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.user['_id'],
          'doctorId': widget.doctor['_id'],
          'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
          'time': _selectedSlot,
          'status': 'booked',
        }),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success']) {
        if (mounted) {
          Navigator.pop(context, true);
          _showMessage('Appointment booked successfully!');
        }
      } else {
        _showMessage(result['message'] ?? 'Booking failed');
      }
    } catch (e) {
      _showMessage('Error booking appointment: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = widget.doctor['name'] ?? 'Dr. Unknown';
    final specialization = widget.doctor['specialization'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Card
            Card(
              elevation: 2,
              child: ListTile(
                leading: const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 30),
                ),
                title: Text(doctorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(specialization),
              ),
            ),
            const SizedBox(height: 24),

            // Calendar
            Text('Select Date', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 30)),
                focusedDay: _selectedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() => _selectedDay = selectedDay);
                    _fetchAvailableSlots();
                  }
                },
                calendarFormat: CalendarFormat.week,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Time Slots
            Text('Available Time Slots', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              )
            else if (_availableSlots.isEmpty)
              const Text('No available slots for this day')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSlots.map<Widget>((slot) {
                  return ChoiceChip(
                    label: Text(slot),
                    selected: _selectedSlot == slot,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSlot = selected ? slot : null;
                      });
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 32),

            // Book Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookAppointment,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Book Appointment'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}