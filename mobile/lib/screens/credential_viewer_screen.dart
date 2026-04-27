
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class CredentialViewerScreen extends StatelessWidget {
  final String imageUrl;

  const CredentialViewerScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Credential'),
        backgroundColor: AppTheme.darkBackground,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: InteractiveViewer(
          panEnabled: false, // Set to true to allow panning
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
              return const Center(
                child: Text(
                  'Could not load credential image.',
                  style: TextStyle(color: Colors.red),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
