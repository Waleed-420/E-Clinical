import 'package:flutter/material.dart';

class DoctorHomePage extends StatelessWidget {
  final Map user;

  DoctorHomePage({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Doctor Home")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dr. ${user['name']}"),
            Text("Email: ${user['email']}"),
            Text("Special Role: ${user['role']}"),
            Text("DOB: ${user['dob']}"),
            Text("Gender: ${user['gender']}"),
          ],
        ),
      ),
    );
  }
}
