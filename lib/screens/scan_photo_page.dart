import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ScanPhotoPage extends StatefulWidget {
  const ScanPhotoPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ScanPhotoPageState createState() => _ScanPhotoPageState();
}

class _ScanPhotoPageState extends State<ScanPhotoPage> {
  File? _image;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  Map<String, dynamic>? _scanResult;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _image = kIsWeb ? null : File(pickedFile.path);
          _scanResult = null;
        });
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _scanDocument() async {
    if (_imageBytes == null && _image == null) return;

    setState(() {
      _isLoading = true;
      _scanResult = null;
    });

    try {
      final uri = Uri.parse(
        'http://192.168.1.8:5000/api/scan-medical-report',
      );
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'document',
            _imageBytes!,
            filename: 'web_image.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'document',
            _image!.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final result = json.decode(response.body);
          if (result is Map<String, dynamic>) {
            setState(() => _scanResult = result);
          } else {
            throw Exception("Invalid response format");
          }
        } catch (e) {
          throw Exception("Failed to parse server response: $e");
        }
      } else {
        throw Exception('Server responded with ${response.statusCode}');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error scanning document: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTestResultTable(List<dynamic> tests) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Test Name')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Normal Range')),
        ],
        rows: tests.map<DataRow>((test) {
          return DataRow(
            cells: [
              DataCell(Text(test['field']?.toString() ?? 'N/A')),
              DataCell(Text(test['value']?.toString() ?? 'N/A')),
              DataCell(Text(test['unit']?.toString() ?? 'N/A')),
              DataCell(Text(test['normal_range']?.toString() ?? 'N/A')),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Medical Report'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'How to scan:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Place your medical report on a flat surface'),
                    Text('2. Ensure good lighting'),
                    Text('3. Capture the entire document'),
                    Text('4. Avoid glare and shadows'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _image != null && !kIsWeb
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    )
                  : _imageBytes != null && kIsWeb
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Text(
                        'No image selected',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_image == null && _imageBytes == null) || _isLoading
                  ? null
                  : _scanDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Scan Document'),
            ),
            const SizedBox(height: 20),
            if (_scanResult != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical Report',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_scanResult!['structuredData']?['institute_name'] !=
                          null)
                        Text(
                          "Hospital: ${_scanResult!['structuredData']['institute_name']}",
                        ),
                      if (_scanResult!['structuredData']?['date'] != null)
                        Text("Date: ${_scanResult!['structuredData']['date']}"),
                      const SizedBox(height: 12),
                      Text('Test Results:', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if ((_scanResult!['structuredData']?['tests'] as List)
                          .isNotEmpty)
                        _buildTestResultTable(
                          _scanResult!['structuredData']['tests'],
                        )
                      else
                        const Text('No test results found'),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('View Raw Text'),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SelectableText(
                              _scanResult!['extractedText'] ??
                                  'No text extracted',
                            ),
                          ),
                        ],
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
}
