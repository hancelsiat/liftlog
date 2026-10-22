import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/gym/gym.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  String _currentBaseUrl = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBaseUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
      setState(() => _saving = true);
      try {
        if (url.startsWith('http://') || url.startsWith('https://')) {
          // Full URL provided (for production/Render)
          ApiService.setBaseUrl(url);
        } else {
          // IP address provided (for development) - also update the PC IP in code
          ApiService.updatePCIP(url); // Update the hardcoded IP in the code
          await ApiService.configureBaseUrl(manualIp: url);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server URL updated successfully')),
        );
        setState(() {
          _currentBaseUrl = ApiService.getCurrentBaseUrl();
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating server URL: $e'),
            backgroundColor: AuthColors.danger,
          ),
        );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Admin / Settings',
      title: 'Server',
      bottomBar: GymBottomBar(
        child: PressableButton(
          label: 'Update Server URL',
          loading: _saving,
          onPressed: _saving ? null : _saveServerUrl,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          GymScaffold.side,
          AuthSpace.xs,
          GymScaffold.side,
          AuthSpace.l,
        ),
        children: [
          EntranceRise(
            index: 0,
            child: PressableSurface(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT SERVER URL',
                    style: AuthType.mono(color: AuthColors.accent),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_currentBaseUrl, style: AuthType.input()),
                ],
              ),
            ),
          ),
          const SizedBox(height: AuthSpace.l),
          const EntranceRise(
            index: 1,
            child: GymSectionLabel(index: 1, label: 'Change server'),
          ),
          const SizedBox(height: AuthSpace.s),
          EntranceRise(
            index: 2,
            child: AuthTextField(
              label: 'Server URL',
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saving ? null : _saveServerUrl(),
            ),
          ),
          const SizedBox(height: AuthSpace.xs),
          EntranceRise(
            index: 3,
            child: Text(
              'Examples:\n'
              '• Development: 192.168.1.16\n'
              '• Production: https://liftlog-6.onrender.com',
              style: AuthType.body(size: 13, color: AuthColors.textFaint),
            ),
          ),
          const SizedBox(height: AuthSpace.l),
          const EntranceRise(
            index: 4,
            child: GymSectionLabel(
              index: 2,
              label: 'How to set up your server',
            ),
          ),
          const SizedBox(height: AuthSpace.s),
          EntranceRise(
            index: 5,
            child: Column(
              children: [
                for (final (i, step) in const [
                  'Run your backend server',
                  "Find your computer's IP address",
                  'Enter the URL in this screen',
                  'Example: http://192.168.1.16:5000',
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            (i + 1).toString().padLeft(2, '0'),
                            style: AuthType.mono(color: AuthColors.accent),
                          ),
                        ),
                        Expanded(
                          child: Text(step, style: AuthType.body(size: 14)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
