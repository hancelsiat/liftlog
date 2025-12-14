import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for premium look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Always use Render backend URL for production deployment
  const String renderBackendUrl = 'https://liftlog-7.onrender.com'; // Your actual Render URL
  ApiService.setBaseUrl(renderBackendUrl);

  final apiService = ApiService();
  final token = await apiService.getToken();

  // Validate token on app start - if invalid, remove it
  bool isLoggedIn = false;
  if (token != null) {
    try {
      // Attempt to load profile to validate token
      await apiService.getProfile();
      isLoggedIn = true;
    } catch (e) {
      // Token is invalid, remove it
      await apiService.removeToken();
      isLoggedIn = false;
    }
  }

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
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }
}
