import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Predefined network configurations
  final networkConfigs = {
    'pc': '192.168.1.16',     // PC IP
    'phone': '192.168.100.192', // Phone IP
    'emulator': '10.0.2.2'    // Android emulator
  };

  try {
    // First, attempt automatic IP detection
    await ApiService.configureBaseUrl();

    // If auto-detection fails, log the detected interfaces
    final detectedInterfaces = await ApiService.getDetectedNetworkInterfaces();
    print('Detected Network Interfaces: $detectedInterfaces');

    // Fallback to predefined configurations if no suitable IP found
    if (ApiService.getCurrentBaseUrl().contains('localhost')) {
      print('Auto-detection failed. Falling back to predefined network configs.');
      await ApiService.configureBaseUrl(manualIp: networkConfigs['phone']);
    }
  } catch (e) {
    print('Error during IP configuration: $e');
    // Extreme fallback to a predefined IP
    await ApiService.configureBaseUrl(manualIp: networkConfigs['phone']);
  }
  
  final apiService = ApiService();
  final token = await apiService.getToken();
  final isLoggedIn = token != null;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
      ],
      child: MaterialApp(
        title: 'LiftLog',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }
}
