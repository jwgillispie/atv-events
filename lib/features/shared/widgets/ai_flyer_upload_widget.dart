import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import '../../../core/theme/hipop_colors.dart';

/// Reusable AI flyer upload widget
/// Can be embedded in any creation form to extract data from flyers
class AIFlyerUploadWidget extends StatefulWidget {
  final Function(Map<String, dynamic> extractedData) onDataExtracted;
  final String buttonText;
  final Color? accentColor;

  const AIFlyerUploadWidget({
    super.key,
    required this.onDataExtracted,
    this.buttonText = 'Upload Flyer & Extract Data',
    this.accentColor,
  });

  @override
  State<AIFlyerUploadWidget> createState() => _AIFlyerUploadWidgetState();
}

class _AIFlyerUploadWidgetState extends State<AIFlyerUploadWidget> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  String? _error;

  Future<void> _pickAndExtract(ImageSource source) async {
    try {
      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _error = null;
      });

      // Upload to Firebase Storage
      final fileName = 'flyers/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(File(image.path));
      final flyerUrl = await ref.getDownloadURL();

      // Call Cloud Function to extract data
      final callable = FirebaseFunctions.instance.httpsCallable('extractFlyerData');
      final result = await callable.call({'imageUrl': flyerUrl});

      if (result.data['success'] == true) {
        final extractedData = Map<String, dynamic>.from(result.data['data'] as Map);

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Data extracted successfully! Form fields have been pre-filled.'),
              backgroundColor: HiPopColors.successGreen,
              duration: const Duration(seconds: 3),
            ),
          );

          // Pass data to parent
          widget.onDataExtracted(extractedData);
        }
      } else {
        throw Exception('Failed to extract data from flyer');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process flyer: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: widget.accentColor ?? HiPopColors.vendorAccent),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndExtract(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: widget.accentColor ?? HiPopColors.vendorAccent),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndExtract(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? HiPopColors.vendorAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AI-Powered',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Upload flyer to auto-fill form fields',
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _showImageSourceDialog,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                _isProcessing ? 'Processing...' : widget.buttonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
