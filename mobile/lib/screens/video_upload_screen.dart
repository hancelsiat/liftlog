import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/exercise_video.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  _VideoUploadScreenState createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  File? _selectedVideo;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowCompression: true,
    );

    if (result != null) {
      setState(() {
        _selectedVideo = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final metadata = {
        'title': _titleController.text,
        'description': _descriptionController.text,
      };

      final uploadedVideo = await _apiService.uploadVideo(
        videoFile: _selectedVideo!,
        metadata: metadata,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video "${uploadedVideo.title}" uploaded successfully')),
      );

      // Clear form after successful upload
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedVideo = null;
        _isUploading = false;
      });
    } catch (e) {
      if (e.toString().contains('Authentication required')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        // Navigate back to login
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Training Video'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Video Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a video title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Video Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Video Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Video Selection
              ElevatedButton.icon(
                icon: const Icon(Icons.video_library),
                label: Text(_selectedVideo == null 
                  ? 'Select Video' 
                  : 'Change Video'),
                onPressed: _pickVideo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_selectedVideo != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Selected: ${_selectedVideo!.path.split('/').last}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              const SizedBox(height: 24),

              // Upload Button
              _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _uploadVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Upload Video',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}