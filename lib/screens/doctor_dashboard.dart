import 'dart:convert';

import 'package:e_clinical/screens/user_appointments.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'doctor_schedule_setup.dart';

class DoctorDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  Map<String, dynamic>? _doctorDetails;
  String? _errorMessage;
  bool _isLoading = true;
  List<dynamic> _upcomingAppointments = [];

  DoctorDashboard({super.key, required this.user});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _currentIndex = 0;
  double _balance = 1250.00; // Example balance
  bool _isVerified = false; // Example verification status
  int _dailyTarget = 8; // Example daily target
  int _monthlyTarget = 200; // Example monthly target
  int _completedAppointments = 156; // Example completed
  int _totalAppointments = 200; // Example total
  int _remainingDays = 14; // Example remaining days

  final List<Widget> _pages = [];

  @override
  void initState() {  
    super.initState();
    _loadData();
    _fetchDoctorData();
    _fetchUpcomingAppointments();
    _pages.addAll([
      _buildMainDashboard(),
      BookedAppointmentsPage(user: widget.user),
      SchedulePage(user: widget.user),
      PaymentCardPage(user: widget.user),
    ]);
  }

  Future<void> _fetchUpcomingAppointments() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.1.8:5000/api/appointments?doctorId=${widget.user['_id']}&status=booked',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          widget._upcomingAppointments = data['appointments'];
        }
      }
    } catch (e) {
      widget._errorMessage = 'Failed to load appointments';
    }
  }

  Future<void> _fetchDoctorData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.1.8:5000/api/doctors?doctorId=${widget.user['_id']}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data['doctors'].isNotEmpty) {
          widget._doctorDetails = data['doctors'][0];
          setState(() {
            _isVerified = widget._doctorDetails?['verified'] ?? false;
          });
        }
      }
    } catch (e) {
      widget._errorMessage = 'Failed to load doctor details';
    }
  }

  Future<void> _loadData() async {
    setState(() {
      widget._isLoading = true;
      widget._errorMessage = null;
    });

    try {
      await _fetchDoctorData();
      await _fetchUpcomingAppointments();
    } catch (e) {
      setState(() {
        widget._errorMessage = 'Failed to load dashboard';
      });
    } finally {
      setState(() {
        widget._isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget._isLoading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget currentPage;
  switch (_currentIndex) {
    case 0:
      currentPage = _buildMainDashboard();
      break;
    case 1:
      currentPage = BookedAppointmentsPage(user: widget.user);
      break;
    case 2:
      currentPage = SchedulePage(user: widget.user);
      break;
    case 3:
      currentPage = PaymentCardPage(user: widget.user);
      break;
    default:
      currentPage = _buildMainDashboard();
  }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      
      body: currentPage,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF15A196),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'Appointments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.schedule), label: 'Schedule'),
          BottomNavigationBarItem(
              icon: Icon(Icons.credit_card), label: 'Payments'),
        ],
      ),
    );
  }

  Widget _buildMainDashboard() {
    final progress = _completedAppointments / _monthlyTarget;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // … the Profile Card and Milestone Card …
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
                                  _isVerified
                                      ? 'Verified'
                                      : 'Pending Verification',
                                  style: TextStyle(
                                    color: _isVerified
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                backgroundColor: _isVerified
                                    ? Colors.green
                                    : Colors.yellow,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Specialization: ${widget._doctorDetails?['specialization'] ?? 'Not Set'}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
Card(
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Available Balance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '\$${_balance.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF15A196),
          ),
        ),
      ],
    ),
  ),
),

                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget._upcomingAppointments.isNotEmpty) ...[
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
                    ...widget._upcomingAppointments
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
                    if (widget._upcomingAppointments.length > 3)
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All Appointments'),
                      ),
                    const SizedBox(height: 24),
                  ],
            // Progress Chart using fl_chart
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _createSampleSections(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 4,
                          pieTouchData: PieTouchData(enabled: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildProgressIndicator(
                          'Completed',
                          _completedAppointments,
                          Colors.green,
                        ),
                        _buildProgressIndicator(
                          'Remaining',
                          _totalAppointments - _completedAppointments,
                          Colors.orange,
                        ),
                        _buildProgressIndicator(
                          'Days Left',
                          _remainingDays,
                          Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF15A196),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}% completed',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (progress >= 1.0)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _completedAppointments = 0;
                                _totalAppointments = _monthlyTarget;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Reset'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _createSampleSections() {
    final completed = _completedAppointments.toDouble();
    final remaining = (_totalAppointments - _completedAppointments).toDouble();
    final total = completed + remaining;
    return [
      PieChartSectionData(
        color: Colors.green,
        value: completed,
        title: '${completed.toInt()}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: remaining,
        title: '${remaining.toInt()}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }
}

class ProgressData {
  final String label;
  final int value;
  final Color color;

  ProgressData(this.label, this.value, this.color);
}

class BookedAppointmentsPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const BookedAppointmentsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return UserAppointments(user: user);
  }
}

class SchedulePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const SchedulePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DoctorScheduleSetup(
      user: user,
      specialization: user['specialization'], // Pass actual specialization
      name: user['name'], // Pass actual name
    );
  }
}

class PaymentCardPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const PaymentCardPage({super.key, required this.user});

  @override
  State<PaymentCardPage> createState() => _PaymentCardPageState();
}

class _PaymentCardPageState extends State<PaymentCardPage> {
  String _cardNumber = '';
  String _expiryDate = '';
  String _cvv = '';
  String _cardHolder = '';
  double _balance = 1250.00;
  bool _showWithdrawSuccess = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_showWithdrawSuccess)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, size: 50, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Withdrawal Successful!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Your funds will be transferred within 3-5 business days',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Card Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _cardNumber = value,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              border: OutlineInputBorder(),
                              hintText: 'MM/YY',
                            ),
                            onChanged: (value) => _expiryDate = value,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            onChanged: (value) => _cvv = value,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Card Holder Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (value) => _cardHolder = value,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Save card info
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Card information saved')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15A196),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Save Card'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Withdraw Funds',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: const Text('Available Balance'),
                      trailing: Text(
                        '\$${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Withdrawal Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _balance = 0.00;
                          _showWithdrawSuccess = true;
                        });
                        Future.delayed(const Duration(seconds: 3), () {
                          setState(() {
                            _showWithdrawSuccess = false;
                          });
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15A196),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Withdraw Full Amount'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}