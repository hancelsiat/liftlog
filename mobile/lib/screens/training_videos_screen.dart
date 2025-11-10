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
}