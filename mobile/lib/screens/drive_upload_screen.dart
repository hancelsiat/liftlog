// drive_upload_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['https://www.googleapis.com/auth/drive.readonly', 'profile', 'email'],
);

class DriveUploadScreen extends StatefulWidget {
  const DriveUploadScreen({super.key});

  @override
  _DriveUploadScreenState createState() => _DriveUploadScreenState();
}

class _DriveUploadScreenState extends State<DriveUploadScreen> {
  GoogleSignInAccount? _account;
  String? _accessToken;
  List<Map<String, dynamic>> _files = [];
  bool _loading = false;
  String _status = '';
  final _apiService = ApiService();

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _status = 'Signing in...';
    });
    try {
      final acc = await _googleSignIn.signIn();
      final auth = await acc!.authentication;
      setState(() {
        _account = acc;
        _accessToken = auth.accessToken;
        _status = 'Signed in as ${acc.email}';
      });
    } catch (e) {
      setState(() {
        _status = 'Sign in failed: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _listMp4Files() async {
    if (_accessToken == null) return;
    setState(() {
      _loading = true;
      _status = 'Listing Drive MP4s...';
      _files = [];
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
        _files = files;
        _status = 'Found ${files.length} mp4 files';
      });
    } catch (e) {
      setState(() {
        _status = 'List failed: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadToBackend(String fileId) async {
    if (_accessToken == null) {
      setState(() {
        _status = 'Not signed in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _status = 'Requesting server to upload file...';
    });

    try {
      final result = await _apiService.uploadVideoFromDrive(
        fileId: fileId,
        accessToken: _accessToken!,
        userId: _account?.id,
      );

      setState(() {
        _status = 'Upload successful! File: ${result['filename']}';
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video "${result['filename']}" uploaded successfully from Drive')),
      );
    } catch (e) {
      setState(() {
        _status = 'Upload request error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drive → GridFS Upload')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          ElevatedButton(onPressed: _signIn, child: const Text('Sign in with Google')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _listMp4Files, child: const Text('List mp4 files in Drive')),
          const SizedBox(height: 12),
          _loading ? const CircularProgressIndicator() : Container(),
          Text(_status),
          Expanded(child: ListView.builder(
            itemCount: _files.length,
            itemBuilder: (_, i) {
              final f = _files[i];
              return ListTile(
                title: Text(f['name'] ?? 'unknown'),
                subtitle: Text('${f['size'] ?? '?'} bytes'),
                trailing: ElevatedButton(
                  child: const Text('Upload'),
                  onPressed: () => _uploadToBackend(f['id']),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}
