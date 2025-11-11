import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // For production/Render deployment, use the Render backend URL
  // For development, use local IP
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  const String renderBackendUrl = 'https://liftlog-6.onrender.com'; // Your actual Render URL

  if (isProduction) {
    // Production: Use Render backend (no port needed, Render handles it)
    ApiService.setBaseUrl(renderBackendUrl);
  } else {
    // Development: Use Render URL for testing or local network IP
    await ApiService.configureBaseUrl(
      renderUrl: renderBackendUrl // Use Render URL even in development for testing
    );
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
