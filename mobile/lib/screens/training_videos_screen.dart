import 'package:flutter/material.dart';
import '../models/exercise_video.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TrainingVideosScreen extends StatefulWidget {
  const TrainingVideosScreen({super.key});

  @override
  State<TrainingVideosScreen> createState() => _TrainingVideosScreenState();
}

class _TrainingVideosScreenState extends State<TrainingVideosScreen> {
  List<ExerciseVideo> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  void _fetchVideos() async {
    try {
      final apiService = ApiService();
      final videos = await apiService.getExerciseVideos();

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterVideos(String exerciseType) {
    if (exerciseType == 'all') {
      _fetchVideos();
    } else {
      setState(() {
        _videos = _videos.where((video) => video.exerciseType == exerciseType).toList();
      });
    }
  }

  void _launchVideo(String videoUrl) async {
    final Uri url = Uri.parse(videoUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $videoUrl')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Videos'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _filterVideos,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('All Videos'),
              ),
              const PopupMenuItem<String>(
                value: 'strength',
                child: Text('Strength'),
              ),
              const PopupMenuItem<String>(
                value: 'cardio',
                child: Text('Cardio'),
              ),
              const PopupMenuItem<String>(
                value: 'flexibility',
                child: Text('Flexibility'),
              ),
              const PopupMenuItem<String>(
                value: 'upper_body',
                child: Text('Upper Body'),
              ),
              const PopupMenuItem<String>(
                value: 'lower_body',
                child: Text('Lower Body'),
              ),
              const PopupMenuItem<String>(
                value: 'core',
                child: Text('Core'),
              ),
              const PopupMenuItem<String>(
                value: 'full_body',
                child: Text('Full Body'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _fetchVideos,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? const Center(
                      child: Text('No training videos available'),
                    )
                  : ListView.builder(
                      itemCount: _videos.length,
                      itemBuilder: (context, index) {
                        final video = _videos[index];
                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          child: ListTile(
                            title: Text(
                              video.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('By: ${video.trainerName}'),
                                Text(
                                  video.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Chip(
                                      label: Text(video.exerciseType),
                                      labelStyle: const TextStyle(fontSize: 10),
                                      backgroundColor: _getExerciseTypeColor(video.exerciseType),
                                    ),
                                    const SizedBox(width: 4),
                                    Chip(
                                      label: Text(video.difficulty),
                                      labelStyle: const TextStyle(fontSize: 10),
                                      backgroundColor: _getDifficultyColor(video.difficulty),
                                    ),
                                  ],
                                ),
                                if (video.tags.isNotEmpty)
                                  Wrap(
                                    spacing: 4.0,
                                    children: video.tags
                                        .map((tag) => Chip(
                                              label: Text(tag),
                                              labelStyle:
                                                  const TextStyle(fontSize: 10),
                                            ))
                                        .toList(),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_fill),
                              onPressed: () => _launchVideo(video.videoUrl),
                            ),
                            onTap: () => _launchVideo(video.videoUrl),
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getExerciseTypeColor(String exerciseType) {
    switch (exerciseType) {
      case 'strength':
        return Colors.red.shade100;
      case 'cardio':
        return Colors.blue.shade100;
      case 'flexibility':
        return Colors.green.shade100;
      case 'upper_body':
        return Colors.orange.shade100;
      case 'lower_body':
        return Colors.purple.shade100;
      case 'core':
        return Colors.yellow.shade100;
      case 'full_body':
        return Colors.teal.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return Colors.green.shade100;
      case 'intermediate':
        return Colors.yellow.shade100;
      case 'advanced':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}