import 'dart:async';
import 'dart:convert';
import 'package:e_clinical/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'video_call_screen.dart';

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
          'http://192.168.10.10:5000/api/user/${widget.user['_id']}/appointments',
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
      Uri.parse('http://192.168.1.8:5000/api/start-call'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channelName': appointment['_id'],
        'targetFCMToken': appointment['otherFcmToken'],
      }),
    );
    final data = jsonDecode(res.body);
    if (!mounted) return;
    if (data['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            token: data['token'],
            channelName: appointment['_id'],
            isCaller: true,
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
              Icons.medical_services,
              'Prescription',
              Colors.green,
              () => _showFeatureDialog(
                context,
                'View prescription from ${appointment['otherName']}',
              ),
            ),
            _buildFeatureButton(
              context,
              Icons.upload_file,
              'Send Reports',
              Colors.orange,
              () => _showFeatureDialog(
                context,
                'Send medical reports to ${appointment['otherName']}',
              ),
            ),
            _buildFeatureButton(
              context,
              Icons.star,
              'Rate',
              Colors.amber,
              () => _showRatingDialog(context, appointment),
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
              videoEnabled ? () => initiateVideoCall(appointment) : null,
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
              () => _showFeatureDialog(
                context,
                'Write prescription for ${appointment['otherName']}',
              ),
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

  void _showRatingDialog(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    double rating = 0;
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
                    onPressed: () => setState(() => rating = i + 1.0),
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Thanks for rating ${appointment['otherName']} with $rating stars!',
                    ),
                  ),
                );
                Navigator.pop(context);
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
                          const SizedBox(height: 8),
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
