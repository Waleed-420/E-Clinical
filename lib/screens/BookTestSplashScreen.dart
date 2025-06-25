import 'package:flutter/material.dart';
import 'book_test_screen.dart';

class BookTestSplashScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const BookTestSplashScreen({super.key, required this.user});

  @override
  State<BookTestSplashScreen> createState() => _BookTestSplashScreenState();
}

class _BookTestSplashScreenState extends State<BookTestSplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 111, 247, 195),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Icons (big and closer)
            Positioned(
              top: 30,
              left: 20,
              child: _rotatedImage("assets/images/report.png", -0.1, 180),
            ),
            Positioned(
              top: 30,
              right: 20,
              child: _rotatedImage("assets/images/Defibrillator.png", 0.2, 180),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              child: Image.asset("assets/images/First_aid.png", height: 210),
            ),

            // Stethoscope image (moved more to the right)
            Positioned(
              bottom: 240,
              right: 10,
              child: _rotatedImage("assets/images/Stetoscope.png", -0.7, 200),
            ),

            // Thermometer image (drawn after for higher z-index)
            Positioned(
              bottom: 260,
              left: 20,
              child: _rotatedImage("assets/images/Thermometer.png", 0.1, 170),
            ),

            // Rounded box with text and button
            Positioned(
              bottom: 50,
              left: 30,
              right: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Are you ready for a health checkup?",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00796B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Improving your life by checking all your cells",
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BookTestScreen(user: widget.user),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                        shadowColor: Colors.black26,
                      ),
                      child: const Text(
                        "Get Started",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _rotatedImage(String path, double angle, double height) {
    return Transform.rotate(
      angle: angle,
      child: Image.asset(path, height: height),
    );
  }
}
