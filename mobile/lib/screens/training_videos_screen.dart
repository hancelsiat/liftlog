import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/exercise_video.dart';
import '../utils/url_helpers.dart';
import 'video_player_screen.dart';

class TrainingVideosScreen extends StatefulWidget {
  const TrainingVideosScreen({super.key});

  @override
  State<TrainingVideosScreen> createState() => _TrainingVideosScreenState();
}

class _TrainingVideosScreenState extends State<TrainingVideosScreen> {
  List<ExerciseVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final apiService = ApiService();
      final videos = await apiService.getExerciseVideos();

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load videos: ${e.toString()}';
        _isLoading = false;
      });
      if (e.toString().contains('Authentication required')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        // Navigate back to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _playVideo(String videoUrl, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user?.role != UserRole.member) {
      return const Scaffold(
        body: Center(child: Text('This screen is only for members')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVideos,
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
                        onPressed: _fetchVideos,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? const Center(
                      child: Text(
                        'No videos available',
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
                          subtitle: Text(video.trainerName),
                          trailing: const Icon(Icons.play_arrow),
                          onTap: () => _playVideo(video.videoUrl, video.title),
                        );
                      },
                    ),
    );
  }
}
