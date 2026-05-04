import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'client_detail_screen.dart';

class TrainerClientsScreen extends StatefulWidget {
  const TrainerClientsScreen({super.key});

  @override
  State<TrainerClientsScreen> createState() => _TrainerClientsScreenState();
}

class _TrainerClientsScreenState extends State<TrainerClientsScreen> {
  late Future<List<User>> _clientsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _clientsFuture = _fetchClients();
  }

  Future<List<User>> _fetchClients() async {
    final response = await _apiService.getClients();
    return (response as List).map((data) => User.fromJson(data)).toList();
  }

  void _refreshClients() {
    setState(() {
      _clientsFuture = _fetchClients();
    });
  }

  void _removeClient(String clientId) async {
    try {
      await _apiService.removeClient(clientId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client removed successfully!'), backgroundColor: Colors.green),
      );
      _refreshClients();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing client: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrainerId = Provider.of<AuthProvider>(context, listen: false).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Clients'),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshClients,
          ),
        ],
      ),
      backgroundColor: AppTheme.darkBackground,
      body: FutureBuilder<List<User>>(
        future: _clientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no clients yet.', style: const TextStyle(color: Colors.white)));
          }

          final clients = snapshot.data!;
          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final bool hasLeft = client.trainer != currentTrainerId;

              return Card(
                color: AppTheme.cardBackground,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(client.username[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(client.username, style: const TextStyle(color: Colors.white)),
                  subtitle: hasLeft
                      ? const Text('This client has left', style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic))
                      : Text(client.email, style: const TextStyle(color: Colors.white70)),
                  trailing: hasLeft
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeClient(client.id),
                        )
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClientDetailScreen(client: client),
                      ),
                    ).then((_) => _refreshClients());
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
