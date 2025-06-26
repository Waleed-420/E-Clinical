import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapRouteScreen extends StatelessWidget {
  final double userLat;
  final double userLng;

  const MapRouteScreen({
    super.key,
    required this.userLat,
    required this.userLng,
  });

  void _openGoogleMaps(BuildContext context) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$userLat,$userLng&travelmode=driving';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      Navigator.pop(context); // Close the screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Google Maps")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Immediately launch on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openGoogleMaps(context);
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
