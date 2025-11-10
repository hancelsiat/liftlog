import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  _ServerSettingsScreenState createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  String _currentBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentBaseUrl();
  }

  void _loadCurrentBaseUrl() {
    setState(() {
      _currentBaseUrl = ApiService.getCurrentBaseUrl();
      _urlController.text = _currentBaseUrl.replaceAll('/api', '');
    });
  }

  void _saveServerUrl() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      try {
        // Remove '/api' if user includes it
        final cleanUrl = url.endsWith('/api') ? url : '$url/api';
        await ApiService.configureBaseUrl(manualIp: Uri.parse(cleanUrl).host);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server URL updated successfully')),
        );
        
        setState(() {
          _currentBaseUrl = ApiService.getCurrentBaseUrl();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating server URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Server Configuration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current Server URL:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              _currentBaseUrl,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Server URL (e.g., http://192.168.1.16:5000)',
                border: OutlineInputBorder(),
                helperText: 'Enter the full server URL without "/api"',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveServerUrl,
              child: Text('Update Server URL'),
            ),
            SizedBox(height: 20),
            Text(
              'How to set up your server:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '1. Run your backend server\n'
              '2. Find your computer\'s IP address\n'
              '3. Enter the URL in this screen\n'
              '4. Example: http://192.168.1.16:5000',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}