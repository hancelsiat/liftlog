import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/exercise_video.dart';

class TrainerVideosScreen extends StatefulWidget {
  const TrainerVideosScreen({super.key});

  @override
  _TrainerVideosScreenState createState() => _TrainerVideosScreenState();
}

class _TrainerVideosScreenState extends State<TrainerVideosScreen> {
  final ApiService _apiService = ApiService();
  List<ExerciseVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTrainerVideos();
  }

  Future<void> _fetchTrainerVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final videos = await _apiService.getTrainerVideos();
      
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load videos: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Training Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to video upload screen
              Navigator.pushNamed(context, '/video-upload');
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: _fetchTrainerVideos,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _videos.isEmpty
            ? const Center(
                child: Text(
                  'No videos uploaded yet',
                  style: TextStyle(fontSize: 18),
                ),
              )
            : ListView.builder(
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  return ListTile(
                    leading: const Icon(Icons.video_library),
                    title: Text(video.title),
                    subtitle: Text(video.description ?? 'No description'),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        // TODO: Implement video options (edit/delete)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Video options coming soon')),
                        );
                      },
                    ),
                    onTap: () {
                      // TODO: Implement video preview or details
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Video details coming soon')),
                      );
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to video upload screen
          Navigator.pushNamed(context, '/video-upload');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}