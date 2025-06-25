import 'dart:async';
import 'dart:convert';
import 'package:e_clinical/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'video_call_screen.dart';
import 'package:collection/collection.dart';

class _RxItem {
  String name;
  int dosagePerDay;          // 1, 2 or 3
  int days;                  // number of days the patient takes the drug
  _RxItem({this.name = '', this.dosagePerDay = 1, this.days = 1});
}

class UserAppointments extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserAppointments({super.key, required this.user});

  @override
  State<UserAppointments> createState() => _UserAppointmentsState();
}

class _UserAppointmentsState extends State<UserAppointments> {
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchAppointments();
    // rebuild every minute so the "now" for enabling video-call stays up to date
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchAppointments() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://10.8.149.233:5000/api/user/${widget.user['_id']}/appointments',
        ),
      );

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody['success'] == true) {
          final List raw = jsonBody['appointments'] as List;
          setState(() {
            // ensure we have a List<Map<String,dynamic>>
            appointments = raw.cast<Map<String, dynamic>>();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                jsonBody['message'] ?? 'Failed to load appointments',
              ),
            ),
          );
        }
      } else {
        setState(() => isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load appointments')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> initiateVideoCall(Map<String, dynamic> appointment) async {
    final res = await http.post(
      Uri.parse('http://10.8.149.233:5000/api/start-call'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channelName': appointment['_id']}),
    );
    final data = jsonDecode(res.body);
    if (!mounted) return;
    if (data['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            channel: appointment['_id'],
            isCaller: true,
            token: data['token'],
          ),
        ),
      );
    } else if (data['message'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data['message'])));
    }
  }

  Widget _buildUserFeatures(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Available Actions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureButton(context, Icons.chat, 'Chat', Colors.blue, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    channel: appointment['doctorId'] + appointment['userId'],
                    currentUser: widget.user,
                  ),
                ),
              );
            }),
            
            _buildFeatureButton(
              context,
              Icons.upload_file,
              'Send Reports',
              const Color.fromARGB(255, 245, 108, 108),
              () => _showFeatureDialog(
                context,
                'Send medical reports to ${appointment['otherName']}',
              ),
            ),
            _buildFeatureButton(
              context,
              Icons.star,
              'Rate',
              const Color.fromARGB(255, 238, 211, 91),
              (appointment['rating'] as num?) != null
                  ? null // Disable if rating exists
                  : () => _showRatingDialog(context, appointment),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoctorFeatures(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    final now = DateTime.now();
    final scheduled = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).parse('${appointment['date']} ${appointment['time']}');
    final videoEnabled =
        now.isAtSameMomentAs(scheduled) || now.isAfter(scheduled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Available Actions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureButton(
              context,
              Icons.chat,
              'Chat',
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    channel: appointment['doctorId'] + appointment['userId'],
                    currentUser: widget.user,
                  ),
                ),
              ),
            ),
            _buildFeatureButton(
              context,
              Icons.video_call,
              'Video Call',
              Colors.purple,
              () => initiateVideoCall(appointment),
            ),
            _buildFeatureButton(
              context,
              Icons.download,
              'Request Reports',
              Colors.teal,
              () => _showFeatureDialog(
                context,
                'Request medical reports from ${appointment['otherName']}',
              ),
            ),
            _buildFeatureButton(
              context,
              Icons.medical_services,
              'Prescribe',
              Colors.green,
              () => _showPrescriptionDialog(context, appointment),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback? onPressed,
  ) {
    final background = onPressed != null
        ? color
        : color.withAlpha((0.5 * 255).round());
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showFeatureDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Feature Preview'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionDialog(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    final formKey = GlobalKey<FormState>();
    final List<_RxItem> items = [ _RxItem() ];          // at least one row
    bool noMeds = false;
    bool saving = false;

    Future<void> _save() async {
    if (!noMeds && !formKey.currentState!.validate()) return;
    formKey.currentState?.save();
    setState(() => saving = true);

    final body = noMeds
        ? {'noMedication': true}
        : {
            'prescription': items
                .map((e) => {
                      'medicine': e.name.trim(),
                      'dosagePerDay': e.dosagePerDay,
                      'days': e.days,
                    })
                .toList(),
          };

    try {
      final res = await http.post(
        Uri.parse(
          'http://192.168.1.9:5000/api/appointments/${appointment['_id']}/prescription',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;

      if (res.statusCode == 200 && data['success'] == true) {
        Navigator.pop(context);             // close modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription saved')),
        );
        fetchAppointments();                // refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Save failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,               // can’t dismiss by tapping outside
    builder: (_) => WillPopScope(            // blocks Android back button
      onWillPop: () async => false,
      child: StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Write prescription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: noMeds,
                  title: const Text('No medication to prescribe'),
                  onChanged: saving
                      ? null
                      : (v) => setState(() {
                            noMeds = v ?? false;
                          }),
                ),
                if (!noMeds)
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        ...items.mapIndexed((index, item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  // Medicine name
                                  Expanded(
                                    flex: 4,
                                    child: TextFormField(
                                      initialValue: item.name,
                                      decoration: const InputDecoration(
                                        labelText: 'Medicine',
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                      onSaved: (v) => item.name = v!.trim(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Dosage per day
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      value: item.dosagePerDay,
                                      decoration: const InputDecoration(
                                        labelText: 'Times/day',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 1, child: Text('1×')),
                                        DropdownMenuItem(
                                            value: 2, child: Text('2×')),
                                        DropdownMenuItem(
                                            value: 3, child: Text('3×')),
                                      ],
                                      onChanged: saving
                                          ? null
                                          : (v) =>
                                              item.dosagePerDay = v ?? 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Number of days
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.days.toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Days',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        final n = int.tryParse(v ?? '');
                                        if (n == null || n <= 0) {
                                          return '≥1';
                                        }
                                        return null;
                                      },
                                      onSaved: (v) =>
                                          item.days = int.parse(v ?? '1'),
                                    ),
                                  ),

                                  // Remove row (not for first row)
                                  if (items.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: saving
                                          ? null
                                          : () => setState(
                                                () => items.removeAt(index),
                                              ),
                                    ),
                                ],
                              ),
                            )),

                        // Add-row button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: saving
                                ? null
                                : () => setState(
                                      () => items.add(_RxItem()),
                                    ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add medicine'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                      // Force doctor to finish: only allow closing if saved
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please save the prescription first')),
                      );
                    },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator())
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
}
  void _showRatingDialog(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    double rating = (appointment['rating'] as num?)?.toDouble() ?? 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Rate ${appointment['otherName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you rate your experience?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      size: 32,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      if ((appointment['rating'] as num?) == null) {
                        setState(() => rating = i + 1.0);
                      }
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text('Selected: ${rating.toInt()} star${rating == 1 ? '' : 's'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: (appointment['rating'] as num?) != null
                  ? null
                  : () async {
                      final appointmentId = appointment['_id'];

                      try {
                        final response = await http.post(
                          Uri.parse(
                            'http://10.8.149.233:5000/api/appointments/$appointmentId/rate',
                          ),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({'rating': rating}),
                        );

                        final data = jsonDecode(response.body);
                        if (!mounted) return;

                        if (response.statusCode == 200 &&
                            data['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Thanks for rating ${appointment['otherName']} with $rating stars!',
                              ),
                            ),
                          );
                          Navigator.pop(context);
                          fetchAppointments(); // Refresh list to show new rating
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(data['message'] ?? 'Rating failed'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: const Text(
                'Submit Rating',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isDoctor = widget.user['role']?.toString().toLowerCase() == 'doctor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAppointments,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : appointments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withAlpha(
                      (0.3 * 255).round(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Appointments Found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(
                        (0.6 * 255).round(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You currently have no upcoming appointments',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(
                        (0.4 * 255).round(),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchAppointments,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appointments.length,
                itemBuilder: (context, i) {
                  final appt = appointments[i];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  appt['otherName'] ?? 'Unknown',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    appt['status'] ?? '',
                                  ).withAlpha((0.2 * 255).round()),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (appt['status'] ?? '')
                                      .toString()
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      appt['status'] ?? '',
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                appt['date'] ?? 'No date specified',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                appt['time'] ?? 'No time specified',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          if ((appt['notes'] as String?)?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notes,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    appt['notes']!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if ((appt['rating'] as num?) != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rated: ${(appt['rating'] as num).toDouble().toStringAsFixed(1)} stars',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          isDoctor
                              ? _buildDoctorFeatures(context, appt)
                              : _buildUserFeatures(context, appt),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
