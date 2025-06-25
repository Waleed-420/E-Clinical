import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

// TODO: Replace this with actual import path
import 'doctor_specialization.dart';

class DoctorLicenseUpload extends StatefulWidget {
  final Map<String, dynamic> user;

  const DoctorLicenseUpload({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _DoctorLicenseUploadState createState() => _DoctorLicenseUploadState();
}

class _DoctorLicenseUploadState extends State<DoctorLicenseUpload> {
  File? _licenseFile;
  bool _isUploading = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _licenseFile = File(pickedFile.path);
        _errorMessage = null;
      });
    }
  }

  Future<void> _uploadLicense() async {
    if (_licenseFile == null) {
      setState(() {
        _errorMessage = 'Please select a license file';
      });
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.10.16:5000/api/upload-license'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('license', _licenseFile!.path),
      );

      request.fields['userId'] = widget.user['_id'].toString(); // ensure string
      request.fields['email'] = widget.user['email'];

      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      final result = json.decode(respStr);

      if (response.statusCode == 200 && result['success'] == true) {
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
            builder: (context) => DoctorSpecializationScreen(user: widget.user),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'License verification failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading license: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Verification'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'License Verification',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload a clear photo or scan of your medical license for verification.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _licenseFile != null
                        ? Image.file(_licenseFile!, fit: BoxFit.cover)
                        : const Icon(
                            Icons.upload_file,
                            size: 50,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload),
                    label: const Text('Select License'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadLicense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit for Verification'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
