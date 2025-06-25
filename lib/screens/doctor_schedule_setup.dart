import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:table_calendar/table_calendar.dart';
import 'package:time_range/time_range.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'doctor_dashboard.dart';

class DoctorScheduleSetup extends StatefulWidget {
  final Map<String, dynamic> user;
  final String specialization;
  final String name;

  const DoctorScheduleSetup({
    super.key,
    required this.user,
    required this.specialization,
    required this.name,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DoctorScheduleSetupState createState() => _DoctorScheduleSetupState();
}

class _DoctorScheduleSetupState extends State<DoctorScheduleSetup> {
  final Map<int, List<TimeRangeResult>> _weeklySchedule = {};
  bool _isSubmitting = false;

  Future<void> _addTimeSlot(int weekday) async {
    TimeRangeResult? selectedRange;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Select Time Slot for ${_getWeekdayName(weekday)}"),
              content: SizedBox(
                height: 300,
                width: MediaQuery.of(context).size.width * 0.8,
                child: TimeRange(
                  fromTitle: const Text('From'),
                  toTitle: const Text('To'),
                  textStyle: const TextStyle(color: Colors.black),
                  activeTextStyle: const TextStyle(color: Colors.white),
                  borderColor: Theme.of(context).primaryColor,
                  backgroundColor: Colors.transparent,
                  activeBackgroundColor: Theme.of(context).primaryColor,
                  firstTime: const TimeOfDay(hour: 8, minute: 0),
                  lastTime: const TimeOfDay(hour: 20, minute: 0),
                  timeStep: 30,
                  timeBlock: 60,
                  onRangeCompleted: (range) {
                    setDialogState(() {
                      selectedRange = range;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: selectedRange == null
                      ? null
                      : () {
                          setState(() {
                            _weeklySchedule[weekday] ??= [];
                            _weeklySchedule[weekday]!.add(selectedRange!);
                          });
                          Navigator.pop(context);
                        },
                  child: const Text("Add Slot"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getWeekdayName(int weekday) {
    return DateFormat('EEEE').format(DateTime(2023, 1, weekday + 1));
  }

  Future<void> _submitSchedule() async {
    if (_weeklySchedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time slot')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.5:5000/api/doctor/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'doctorId': widget.user['_id'].toString(),
          'name': widget.name,
          'specialization': widget.specialization,
          'schedule': _weeklySchedule.map(
            (key, value) => MapEntry(
              key.toString(),
              value
                  .map(
                    (tr) => {
                      'start':
                          '${tr.start.hour}:${tr.start.minute.toString().padLeft(2, '0')}',
                      'end':
                          '${tr.end.hour}:${tr.end.minute.toString().padLeft(2, '0')}',
                    },
                  )
                  .toList(),
            ),
          ),
        }),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success']) {
        print('Schedule saved. Navigating to dashboard...');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorDashboard(user: widget.user),
          ),
        );
      } else {
        print('API failed: ${result['message']}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to save schedule'),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> fetchDoctorSchedule() async {
    final doctorId = widget.user['_id'];
    final url = Uri.parse(
      'http://192.168.1.5:5000/api/doctor/$doctorId/schedule',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final schedule = data['schedule'] as Map<String, dynamic>;

        Map<int, List<TimeRangeResult>> tempSchedule = {};

        schedule.forEach((day, slots) {
          final intDay = int.tryParse(day);
          if (intDay == null) return;

          final List<TimeRangeResult> timeSlots = [];
          for (var slot in slots) {
            final startParts = slot['start'].split(':');
            final endParts = slot['end'].split(':');

            final start = TimeOfDay(
              hour: int.parse(startParts[0]),
              minute: int.parse(startParts[1]),
            );
            final end = TimeOfDay(
              hour: int.parse(endParts[0]),
              minute: int.parse(endParts[1]),
            );

            timeSlots.add(TimeRangeResult(start, end));
          }

          tempSchedule[intDay] = timeSlots;
        });

        setState(() {
          _weeklySchedule.clear();
          _weeklySchedule.addAll(tempSchedule);
        });
      } else {
        if (kDebugMode) {
          print('Failed to fetch schedule: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching schedule: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchDoctorSchedule();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set Your Schedule'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Availability',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your regular weekly time slots. These will repeat every week.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: 7,
                itemBuilder: (context, index) {
                  final weekday = index + 1;
                  final slots = _weeklySchedule[weekday] ?? [];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getWeekdayName(weekday),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _addTimeSlot(weekday),
                              ),
                            ],
                          ),
                          if (slots.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No time slots added',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ...slots.map(
                            (slot) => ListTile(
                              title: Text(
                                '${slot.start.format(context)} - ${slot.end.format(context)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _weeklySchedule[weekday]!.remove(slot);
                                    if (_weeklySchedule[weekday]!.isEmpty) {
                                      _weeklySchedule.remove(weekday);
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitSchedule,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
