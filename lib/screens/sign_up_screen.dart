import 'package:flutter/material.dart';
import 'sign_in_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _selectedGender;
  String _role = 'General User';
  bool _isLoading = false;

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse('http://192.168.18.130:5000/api/signup'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': _nameController.text.trim(),
        'dob': _dobController.text.trim(),
        'email': _emailController.text.trim(),
        'gender': _selectedGender,
        'password': _passwordController.text,
        'confirmPassword': _confirmPasswordController.text,
        'role': _role,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final responseData = json.decode(response.body);

    if (response.statusCode == 201) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            responseData['message'] ?? 'Registered successfully',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(Duration(seconds: 2));
      // ignore: use_build_context_synchronously
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => SignInScreen()));
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            responseData['message'] ?? 'Registration failed',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
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
                          margin: const EdgeInsets.only(top: 257),
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
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
                                    "Sign Up",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15A196),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildTextField(
                                  'Name',
                                  _nameController,
                                  Icons.person,
                                ),
                                _buildTextField(
                                  'Date of Birth',
                                  _dobController,
                                  Icons.cake,
                                  readOnly: true,
                                  onTap: _pickDate,
                                ),
                                _buildTextField(
                                  'Email',
                                  _emailController,
                                  Icons.email,
                                ),
                                _buildDropdownGender(context),
                                _buildTextField(
                                  'Password',
                                  _passwordController,
                                  Icons.lock,
                                  obscureText: true,
                                ),
                                _buildTextField(
                                  'Confirm Password',
                                  _confirmPasswordController,
                                  Icons.lock_outline,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Register as:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children:
                                      [
                                        'General User',
                                        'Doctor',
                                        'Laboratory',
                                      ].map((role) {
                                        return Row(
                                          children: [
                                            Radio<String>(
                                              value: role,
                                              groupValue: _role,
                                              activeColor: const Color(
                                                0xFF15A196,
                                              ),
                                              onChanged: (value) => setState(
                                                () => _role = value!,
                                              ),
                                            ),
                                            Text(role),
                                          ],
                                        );
                                      }).toList(),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              _registerUser();
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF15A196),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 12,
                                      ),
                                      foregroundColor: const Color.fromARGB(
                                        255,
                                        255,
                                        255,
                                        255,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text('Register'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SignInScreen(),
                                      ),
                                    ),
                                    child: RichText(
                                      text: const TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "Already have an account? ",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "Sign In",
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
                            height: 300,
                            width: 300,
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
    bool readOnly = false,
    VoidCallback? onTap,
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
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          icon: Icon(icon),
          hintText: hint,
          border: InputBorder.none,
        ),
        validator: (value) => value!.isEmpty ? '$hint is required' : null,
      ),
    );
  }

  Widget _buildDropdownGender(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF15A196)),
        iconSize: 24,
        elevation: 0,
        dropdownColor: Colors.white,
        style: TextStyle(color: Colors.black87, fontSize: 16),
        decoration: const InputDecoration(
          icon: Icon(Icons.wc, color: Color(0xFF15A196)),
          border: InputBorder.none,
          hintText: 'Select Gender',
        ),
        items: ['Male', 'Female', 'Other']
            .map(
              (gender) => DropdownMenuItem(
                value: gender,
                child: Text(gender, style: TextStyle(color: Color(0xFF15A196))),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedGender = value),
        validator: (value) => value == null ? 'Gender is required' : null,
        isExpanded: true,
      ),
    );
  }

  void _pickDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    _dobController.text =
        "${date?.year}-${date?.month.toString().padLeft(2, '0')}-${date?.day.toString().padLeft(2, '0')}";
  }
}
