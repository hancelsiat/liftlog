import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/gym/gym.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

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

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final jwt = await _apiService.getToken();
      if (!mounted) return;
      if (jwt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
          ),
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
      if (!mounted) return;

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
        final displayMessage = (message is Map)
            ? message.toString()
            : (message ?? 'Upload failed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayMessage)));
      }

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to upload video. Please check your connection.',
            ),
          ),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Trainer / Library',
      title: 'Upload Video',
      bottomBar: GymBottomBar(
        child: PressableButton(
          label: 'Select and Upload Video',
          loading: _isUploading,
          onPressed: _isUploading ? null : _uploadVideo,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GymScaffold.side,
            AuthSpace.xs,
            GymScaffold.side,
            AuthSpace.l,
          ),
          children: [
            const EntranceRise(
              index: 0,
              child: GymSectionLabel(index: 1, label: 'Details'),
            ),
            const SizedBox(height: AuthSpace.s),

            // Video Title
            EntranceRise(
              index: 1,
              child: AuthTextField(
                label: 'Video Title',
                controller: _titleController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a video title';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AuthSpace.s),

            // Video Description
            EntranceRise(
              index: 2,
              child: GymLabeledField(
                label: 'Video Description',
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: AuthType.input(),
                  decoration: const InputDecoration(
                    hintText: 'What does this video cover?',
                  ),
                ),
              ),
            ),
            const SizedBox(height: AuthSpace.l),

            const EntranceRise(
              index: 3,
              child: GymSectionLabel(index: 2, label: 'Exercise Type'),
            ),
            const SizedBox(height: AuthSpace.s),

            // Exercise type chips (replaces the dropdown; same values)
            EntranceRise(
              index: 4,
              child: Semantics(
                label: 'Exercise type',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _exerciseTypes)
                      GymChoiceChip(
                        label: type,
                        selected: _selectedExerciseType == type,
                        onTap: _isUploading
                            ? null
                            : () =>
                                  setState(() => _selectedExerciseType = type),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuthSpace.l),

            const EntranceRise(
              index: 5,
              child: GymSectionLabel(index: 3, label: 'Visibility'),
            ),
            const SizedBox(height: AuthSpace.s),

            // Make Public toggle
            EntranceRise(
              index: 6,
              child: PressableSurface(
                semanticLabel: 'Make video public (visible to members)',
                onTap: _isUploading
                    ? null
                    : () => setState(() => _isPublic = !_isPublic),
                child: Row(
                  children: [
                    Icon(
                      _isPublic ? Icons.public : Icons.lock_outline,
                      size: 20,
                      color: _isPublic
                          ? AuthColors.accent
                          : AuthColors.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPublic ? 'PUBLIC' : 'PRIVATE',
                            style: AuthType.label(
                              color: AuthColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Make video public (visible to members)',
                            style: AuthType.body(size: 13),
                          ),
                        ],
                      ),
                    ),
                    GymSwitch(
                      value: _isPublic,
                      onChanged: _isUploading
                          ? null
                          : (value) => setState(() => _isPublic = value),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
