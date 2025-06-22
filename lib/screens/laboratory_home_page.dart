import 'package:flutter/material.dart';

class LaboratoryHomePage extends StatelessWidget {
  final Map user;

  const LaboratoryHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Laboratory Home")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Lab: ${user['name']}"),
            Text("Email: ${user['email']}"),
            Text("Role: ${user['role']}"),
            Text("DOB: ${user['dob']}"),
            Text("Gender: ${user['gender']}"),
          ],
        ),
      ),
    );
  }
}
