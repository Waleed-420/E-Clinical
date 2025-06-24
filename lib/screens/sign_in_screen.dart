import 'package:e_clinical/screens/doctor_dashboard.dart';
import 'package:e_clinical/screens/laboratory_home_page.dart';

import 'sign_up_screen.dart';
import 'user_home_page.dart';
import 'doctor_license_upload.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  Future<void> saveToken(String userId, bool isDoctor) async {
    String? token = await FirebaseMessaging.instance.getToken();
    
    if (kDebugMode){
      print("Token: $token");
    }

    await http.post(
      Uri.parse('http://192.168.1.12:5000/api/save-token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'isDoctor': isDoctor,
        'deviceToken': token,
      }),
    );
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("http://192.168.1.12:5000/api/signin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result["success"] == true) {
        final user = result["user"];
        final String role = (user['role'] ?? 'General User')
            .toString()
            .toLowerCase();

        if (kDebugMode) {
          print("User Role: $role");
        } // Debug log

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Successful!"),
            backgroundColor: Colors.green,
          ),
        );

        saveToken(user['_id'], role == 'doctor');

        if (role == 'doctor') {
          // Check if doctor has completed first-time setup
          bool isSetupComplete = user['isSetupComplete'] ?? false;

          if (!isSetupComplete) {
            // First-time setup flow for doctors
            Future.delayed(Duration(milliseconds: 500), () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorLicenseUpload(user: user),
                ),
              );
            });
          } else {
            // Regular login flow for doctors
            Future.delayed(Duration(milliseconds: 500), () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorDashboard(user: user),
                ),
              );
            });
          }
        } else if (role == 'laboratory') {
          Future.delayed(Duration(milliseconds: 500), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LaboratoryHomePage(user: user),
              ),
            );
          });
        } else {
          Future.delayed(Duration(milliseconds: 500), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserHomePage(user: user)),
            );
          });
        }
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Login failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error connecting to server."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF15A196),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 214),
                          padding: const EdgeInsets.fromLTRB(16, 80, 16, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                Center(
                                  child: Text(
                                    "Sign In",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15A196),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                _buildTextField(
                                  'Email',
                                  _emailController,
                                  Icons.email,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  'Password',
                                  _passwordController,
                                  Icons.lock,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          activeColor: const Color(0xFF15A196),
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value!;
                                            });
                                          },
                                        ),
                                        const Text('Remember me'),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // Forgot password action
                                      },
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: Color(0xFF15A196),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              _signIn();
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF15A196),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 12,
                                      ),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text('Sign In'),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SignUpScreen(),
                                        ),
                                      );
                                    },
                                    child: RichText(
                                      text: const TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "Don't have an account? ",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "Sign Up",
                                            style: TextStyle(
                                              color: Color(0xFF15A196),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: SizedBox(
                            height: 250,
                            width: 250,
                            child: Image.asset(
                              'assets/images/doctor_top.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool obscureText = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          icon: Icon(icon, color: Color(0xFF15A196)),
          hintText: hint,
          border: InputBorder.none,
        ),
        validator: (value) => value!.isEmpty ? '$hint is required' : null,
      ),
    );
  }
}
