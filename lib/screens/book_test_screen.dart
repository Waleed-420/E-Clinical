import 'package:flutter/material.dart';

class BookTestScreen extends StatefulWidget {
  const BookTestScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<BookTestScreen> createState() => _BookTestScreenState();
}

class _BookTestScreenState extends State<BookTestScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
