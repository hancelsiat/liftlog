
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class ClientDetailScreen extends StatefulWidget {
  final User client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late Future<List<Workout>> _progressFuture;
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _progressFuture = _fetchProgress();
    _notesController.text = widget.client.privateNotes ?? '';
  }

  Future<List<Workout>> _fetchProgress() async {
    final response = await _apiService.getClientProgress(widget.client.id);
    return (response as List).map((data) => Workout.fromJson(data)).toList();
  }

  void _saveNotes() async {
    try {
      await _apiService.saveClientNotes(widget.client.id, _notesController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.client.username),
          backgroundColor: AppTheme.darkBackground,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Progress'),
              Tab(text: 'Private Notes'),
            ],
          ),
        ),
        backgroundColor: AppTheme.darkBackground,
        body: TabBarView(
          children: [
            _buildProgressTab(),
            _buildNotesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    return FutureBuilder<List<Workout>>(
      future: _progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No workouts assigned yet.', style: TextStyle(color: Colors.white)));
        }

        final workouts = snapshot.data!;
        return ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            return Card(
              color: AppTheme.cardBackground,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(workout.title, style: const TextStyle(color: Colors.white)),
                subtitle: Text('Assigned on: ${workout.date.toLocal()}`.split(' ')[0]}', style: const TextStyle(color: Colors.white70)),
                trailing: workout.completedAt != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _notesController,
              maxLines: null,
              expands: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter private notes for this client...',
                hintStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveNotes,
            child: const Text('Save Notes'),
          ),
        ],
      ),
    );
  }
}
