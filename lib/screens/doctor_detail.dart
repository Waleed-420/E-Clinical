import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DoctorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> doctor;

  const DoctorDetailScreen({
    super.key,
    required this.user,
    required this.doctor,
  });

  @override
  // ignore: library_private_types_in_public_api
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
      final uri = Uri.parse(
        'http://192.168.1.8:5000/api/doctor/$doctorId/slots?date=$date',
      );

      final response = await http.get(uri);

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
        _errorMessage =
            'Error fetching slots: ${e.toString().replaceAll(RegExp(r'<!DOCTYPE.*'), 'Server error')}';
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
        Uri.parse('http://192.168.1.8:5000/api/appointments'),
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
      appBar: AppBar(title: const Text('Book Appointment'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Info
            Card(
              elevation: 2,
              child: ListTile(
                leading: const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 30),
                ),
                title: Text(
                  doctorName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
                onDaySelected: (selectedDay, _) {
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
                    // ignore: deprecated_member_use
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
            Text(
              'Available Time Slots',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            else if (_availableSlots.isEmpty)
              const Text('No available slots for this day')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSlots.expand<Widget>((slotRange) {
                  final List<dynamic> slots = slotRange['slots'] ?? [];

                  final Set<String> seenTimes =
                      {}; // To track and skip duplicates

                  return slots.map<Widget>((slotObj) {
                    final String? time = slotObj['time'];
                    final bool isBooked = slotObj['booked'] ?? false;

                    if (time == null || seenTimes.contains(time)) {
                      return const SizedBox();
                    }

                    seenTimes.add(time);

                    // Convert time (e.g. "08:00") to 30-minute range "08:00 - 08:30"
                    final timeParts = time.split(':');
                    final int hour = int.parse(timeParts[0]);
                    final int minute = int.parse(timeParts[1]);

                    final start = TimeOfDay(hour: hour, minute: minute);
                    final end = start.replacing(
                      minute: (minute + 30) % 60,
                      hour: hour + ((minute + 30) ~/ 60),
                    );
                    final rangeLabel =
                        '${start.format(context)} - ${end.format(context)}';

                    return ChoiceChip(
                      label: Text(rangeLabel),
                      selected: _selectedSlot == time && !isBooked,
                      onSelected: isBooked
                          ? null
                          : (selected) {
                              setState(() {
                                _selectedSlot = selected ? time : null;
                              });
                            },
                      backgroundColor: isBooked ? Colors.grey.shade300 : null,
                      disabledColor: Colors.grey.shade300,
                    );
                  }).toList();
                }).toList(),
              ),

            const SizedBox(height: 32),

            // Book Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading || _selectedSlot == null
                    ? null
                    : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Book Appointment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
