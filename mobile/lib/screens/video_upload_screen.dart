import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.readonly', 'profile', 'email'],
  );

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedExerciseType = 'strength'; // Default value
  bool _isUploading = false;
  bool _isPublic = true;

  // Available exercise types matching backend enum
  final List<String> _exerciseTypes = [
    'cardio',
    'strength',
    'flexibility',
    'balance',
    'sports',
    'other',
  ];

  // Google Drive related state
  GoogleSignInAccount? _account;
  String? _accessToken;
  List<Map<String, dynamic>> _driveFiles = [];
  bool _isLoadingDrive = false;
  String _driveStatus = '';
  final bool _showDriveUpload = false;



  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final jwt = await _apiService.getToken();
      if (jwt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final result = await _apiService.uploadVideo(
        jwt: jwt,
        title: _titleController.text,
        exerciseType: _selectedExerciseType,
        description: _descriptionController.text,
        isPublic: _isPublic,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully')),
        );

        // Clear form after successful upload
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedExerciseType = 'strength'; // Reset to default
        });
      } else {
        final message = result['message'];
        final displayMessage = (message is Map) ? message.toString() : (message ?? 'Upload failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(displayMessage)),
        );
      }

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString()}')),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoadingDrive = true;
      _driveStatus = 'Signing in...';
    });
    try {
      final acc = await _googleSignIn.signIn();
      final auth = await acc!.authentication;
      setState(() {
        _account = acc;
        _accessToken = auth.accessToken;
        _driveStatus = 'Signed in as ${acc.email}';
      });
    } catch (e) {
      setState(() {
        _driveStatus = 'Sign in failed: $e';
      });
    } finally {
      setState(() => _isLoadingDrive = false);
    }
  }

  Future<void> _listDriveMp4Files() async {
    if (_accessToken == null) return;
    setState(() {
      _isLoadingDrive = true;
      _driveStatus = 'Listing Drive MP4s...';
      _driveFiles = [];
    });
    try {
      // Query Drive for video/mp4 files owned by or shared with the user
      final q = Uri.encodeQueryComponent("mimeType='video/mp4' and trashed=false");
      final url = 'https://www.googleapis.com/drive/v3/files?q=$q&fields=files(id,name,size,mimeType)';

      final resp = await http.get(Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'});
      if (resp.statusCode != 200) throw Exception('Drive list failed: ${resp.statusCode} ${resp.body}');

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>).map((f) => Map<String, dynamic>.from(f)).toList();
      setState(() {
        _driveFiles = files;
        _driveStatus = 'Found ${files.length} mp4 files';
      });
    } catch (e) {
      setState(() {
        _driveStatus = 'List failed: $e';
      });
    } finally {
      setState(() => _isLoadingDrive = false);
    }
  }

  Future<void> _uploadFromDrive(String fileId) async {
    if (_accessToken == null) {
      setState(() {
        _driveStatus = 'Not signed in';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _driveStatus = 'Uploading from Drive...';
    });

    try {
      final metadata = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'exerciseType': _selectedExerciseType,
        'difficulty': 'beginner',
        'duration': 0,
        'tags': [],
        'isPublic': true,
      };

      final uploadedVideo = await _apiService.uploadVideoFromDrive(
        fileId: fileId,
        accessToken: _accessToken!,
        userId: _account?.id,
        metadata: metadata,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video "${uploadedVideo.title}" uploaded successfully from Drive')),
      );

      // Clear form after successful upload
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedExerciseType = 'strength'; // Reset to default
        _isUploading = false;
        _driveStatus = 'Upload completed successfully';
      });

      // Navigate to training videos to see the uploaded video
      Navigator.of(context).pushReplacementNamed('/training-videos');

    } catch (e) {
      setState(() {
        _driveStatus = 'Upload failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
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

              // Exercise Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedExerciseType,
                decoration: const InputDecoration(
                  labelText: 'Exercise Type',
                  border: OutlineInputBorder(),
                  helperText: 'Select the type of exercise',
                ),
                items: _exerciseTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedExerciseType = newValue;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an exercise type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Make Public Checkbox
              CheckboxListTile(
                title: const Text('Make video public (visible to members)'),
                value: _isPublic,
                onChanged: (bool? value) {
                  setState(() {
                    _isPublic = value ?? true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),



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
                      'Select and Upload Video',
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
    _googleSignIn.signOut();
    super.dispose();
  }
}
