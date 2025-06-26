import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class SelectLocationSheet extends StatefulWidget {
  final String userId;
  final String labUserId;
  final String testId;

  const SelectLocationSheet({
    super.key,
    required this.userId,
    required this.labUserId,
    required this.testId,
  });

  @override
  State<SelectLocationSheet> createState() => _SelectLocationSheetState();
}

class _SelectLocationSheetState extends State<SelectLocationSheet> {
  LatLng? selectedLocation;
  String? address;
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
    }

    Position pos = await Geolocator.getCurrentPosition();
    LatLng current = LatLng(pos.latitude, pos.longitude);
    mapController.animateCamera(CameraUpdate.newLatLngZoom(current, 15));
    _updateLocation(current);
  }

  void _updateLocation(LatLng pos) async {
    setState(() {
      selectedLocation = pos;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        setState(() {
          address = '${p.street}, ${p.locality}, ${p.country}';
        });
      }
    } catch (e) {
      print("Reverse geocoding failed: $e");
    }
  }

  void _confirmBooking() async {
    if (selectedLocation == null) return;

    final body = {
      'userId': widget.userId,
      'labUserId': widget.labUserId,
      'testId': widget.testId,
      'location': {
        'lat': selectedLocation!.latitude,
        'lng': selectedLocation!.longitude,
        'address': address ?? '',
      },
    };

    final response = await http.post(
      Uri.parse('http://192.168.18.130:5000/api/book-test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test booked successfully')));
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${error['message']}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "Select Sample Collection Location",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(33.6844, 73.0479), // default: Islamabad
                zoom: 12,
              ),
              onMapCreated: (controller) => mapController = controller,
              onTap: _updateLocation,
              markers: selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: selectedLocation!,
                      ),
                    }
                  : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),
          ),
          if (address != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Selected Address: $address"),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.my_location),
                label: const Text("Use Current"),
                onPressed: _getCurrentLocation,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text("Confirm"),
                onPressed: _confirmBooking,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
