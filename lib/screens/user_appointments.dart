import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserAppointments extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserAppointments({super.key, required this.user});

  @override
  State<UserAppointments> createState() => _UserAppointmentsState();
}

class _UserAppointmentsState extends State<UserAppointments> {
  List appointments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.10.10:5000/api/user/${widget.user['_id']}/appointments',
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          setState(() {
            appointments = json['appointments'];
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load appointments')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Feature for General Users
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
            _buildFeatureButton(
              context,
              Icons.chat,
              'Chat',
              Colors.blue,
              () => _showFeatureDialog(
                context,
                'Chat with ${appointment['otherName']}',
              ),
            ),
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

  // Feature for Doctors
  Widget _buildDoctorFeatures(
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
            _buildFeatureButton(
              context,
              Icons.chat,
              'Chat',
              Colors.blue,
              () => _showFeatureDialog(
                context,
                'Chat with ${appointment['otherName']}',
              ),
            ),
            _buildFeatureButton(
              context,
              Icons.video_call,
              'Video Call',
              Colors.purple,
              () => _showFeatureDialog(
                context,
                'Start video consultation with ${appointment['otherName']}',
              ),
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
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {},

      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showFeatureDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Rate ${appointment['otherName']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How would you rate your experience?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selected: ${rating.toInt()} star${rating == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                  ),
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
            );
          },
        );
      },
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
    final isDoctor = widget.user['role']?.toLowerCase() == 'doctor';

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
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Appointments Found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You currently have no upcoming appointments',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
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
                itemBuilder: (context, index) {
                  final appointment = appointments[index];
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
                                  appointment['otherName'] ?? 'Unknown',
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
                                    appointment['status'] ?? '',
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  appointment['status']?.toUpperCase() ?? '',
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      appointment['status'] ?? '',
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
                                appointment['date'] ?? 'No date specified',
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
                                appointment['time'] ?? 'No time specified',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          if (appointment['notes']?.isNotEmpty ?? false) ...[
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
                                    appointment['notes'] ?? '',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          isDoctor
                              ? _buildDoctorFeatures(context, appointment)
                              : _buildUserFeatures(context, appointment),
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
