import 'package:e_clinical/screens/BookTestSplashScreen.dart';

import 'scan_photo_page.dart';
import 'user_prescription_screen.dart';
import 'package:flutter/material.dart';
import 'book_appointment_splashscreen.dart';
import 'user_reports.dart';
import 'user_appointments.dart';
import 'user_settings.dart';
import 'upload_pdf_screen.dart';
import 'past_reports_screen.dart';

class UserHomePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const UserHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top image
              Container(
                margin: const EdgeInsets.only(top: 20),
                height: 160,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/doctor_top.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickAction(
                              context,
                              Icons.camera_alt,
                              'Scan Photo',
                              colorScheme.primary,
                              () => _navigateTo(context, const ScanPhotoPage()),
                            ),
                            _buildQuickAction(
                              context,
                              Icons.upload_file,
                              'Upload PDF',
                              colorScheme.secondary,
                              () =>
                                  _navigateTo(context, const UploadPdfScreen()),
                            ),
                            _buildQuickAction(
                              context,
                              Icons.settings,
                              'Settings',
                              Colors.orange,
                              () => _navigateTo(context, const UserSettings()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildActionCard(
                      context,
                      Icons.medical_services,
                      'Book Test',
                      colorScheme.primary,
                      () => _navigateTo(
                        context,
                        BookTestSplashScreen(user: user),
                      ),
                    ),
                    _buildActionCard(
                      context,
                      Icons.calendar_today,
                      'Book Appointment',
                      colorScheme.secondary,
                      () => _navigateTo(
                        context,
                        BookAppointmentSplashScreen(user: user),
                      ),
                    ),
                    _buildActionCard(
                      context,
                      Icons.assignment,
                      'Past Reports',
                      Colors.orange,
                      () => _navigateTo(context, const PastReportsScreen()),
                    ),
                    _buildActionCard(
                      context,
                      Icons.description,
                      'Prescription',
                      Colors.green,
                      () =>
                          _navigateTo(context, UserPrescriptionScreen(userId: user['_id'])),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(
        context,
        0,
        colorScheme,
        isDarkMode,
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDarkMode ? 0.3 : 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(
    BuildContext context,
    int currentIndex,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Reports'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Appointments',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      onTap: (index) {
        switch (index) {
          case 1:
            _navigateTo(context, const UserReports());
            break;
          case 2:
            _navigateTo(context, UserAppointments(user: user));
            break;
          case 3:
            _navigateTo(context, const UserSettings());
            break;
        }
      },
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}
